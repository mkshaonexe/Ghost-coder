//
//  KeyboardInterceptor.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import Cocoa
import CoreGraphics
import os

class KeyboardInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var watchdogTimer: Timer?
    private var permissionRetryTimer: Timer?

    private let state: GhostState
    private let injector: CharacterInjector



    // Serial queue: one injection at a time; subsequent keypresses are blocked while injecting
    let injectionQueue = DispatchQueue(label: "com.ghostcoder.injection", qos: .userInteractive)

    // OSAllocatedUnfairLock: faster than NSLock, safe for flag read/write from any thread
    private let injectionLock = OSAllocatedUnfairLock<Bool>(initialState: false)

    var isInjecting: Bool {
        get { injectionLock.withLock { $0 } }
        set { injectionLock.withLock { $0 = newValue } }
    }

    init(state: GhostState) {
        self.state = state
        self.injector = CharacterInjector(state: state)
    }

    // MARK: - Start / Stop

    func start() {
        guard eventTap == nil else { return }

        state.log("Starting keyboard interceptor...")

        guard checkAccessibilityPermission() else {
            state.log("Warning: Accessibility permission not granted. Retrying every 1s...")
            // No retry timer already running — start one that polls every second
            if permissionRetryTimer == nil {
                permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.checkAccessibilityPermission() {
                        self.state.log("Accessibility permission detected. Starting tap...")
                        self.permissionRetryTimer?.invalidate()
                        self.permissionRetryTimer = nil
                        self.start()
                    }
                }
            }
            return
        }

        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                // userInfo is an unretained pointer to KeyboardInterceptor
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<KeyboardInterceptor>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return interceptor.handleKeyDown(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            state.log("Error: Failed to create CGEventTap. Accessibility permission may need to be reset.")
            // Retry after a short delay in case the system needs a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.eventTap = nil
                self?.start()
            }
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        state.log("Keyboard interceptor active. Event tap registered on RunLoop.")

        // Watchdog: macOS can silently disable taps that appear unresponsive
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                self.state.log("Watchdog alert: Event tap was disabled by the OS. Re-enabling...")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
    }

    func stop() {
        state.log("Stopping keyboard interceptor...")
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        watchdogTimer?.invalidate()
        watchdogTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        state.log("Keyboard interceptor stopped.")
    }

    // MARK: - Accessibility Permission

    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        // Prompt user to grant permission in System Settings → Privacy & Security → Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        return false
    }

    // MARK: - Event Handler (called on CGEventTap callback thread — must return fast)

    private func handleKeyDown(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        // Check cached active state — Bool read is atomic on Apple platforms (single-word)
        guard state.isActiveCached else {
            return Unmanaged.passUnretained(event)  // pass through
        }

        // Double check synchronously that the target IDE is indeed the active app
        // to prevent race conditions during focus transitions.
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
                return Unmanaged.passUnretained(event) // Never intercept inside our own app
            }
            if let targetBundleID = state.ideTarget.bundleID,
               frontApp.bundleIdentifier != targetBundleID {
                return Unmanaged.passUnretained(event) // Frontmost app changed but cache is stale
            }
        }

        // Atomically check and claim the injection lock.
        // If we are already injecting, block incoming key silently.
        let wasInjecting = injectionLock.withLock { isInjecting in
            if isInjecting {
                return true
            }
            isInjecting = true
            return false
        }

        if wasInjecting {
            return nil
        }

        // --- Hot-Fix guard ---
        // While HotFixEngine is running a Cmd+A / Cmd+V correction, swallow all
        // non-Cmd keypresses so injection state stays consistent.
        // NOTE: this check MUST come after the Cmd-key passthrough (Rule 1) so
        // that Ghost Coder's own synthetic Cmd+A / Cmd+V events are not blocked.
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // --- Rule 1: Any Cmd+key combination → always pass through ---
        if flags.contains(.maskCommand) {
            isInjecting = false
            return Unmanaged.passUnretained(event)
        }



        // --- Rule 2: Explicit passthrough key codes ---
        let passthroughKeyCodes: Set<Int> = [
            123, 124, 125, 126,  // Arrow keys (Left, Right, Down, Up)
            53,                   // Escape
            117,                  // Forward Delete
            115, 119,             // Home, End
            116, 121,             // Page Up, Page Down
            // Function keys F1–F12
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111
        ]
        if passthroughKeyCodes.contains(keyCode) {
            isInjecting = false
            return Unmanaged.passUnretained(event)
        }

        // --- Rule 3: Backspace (keyCode 51) ---
        if keyCode == 51 {
            guard !state.isHistoryEmpty else {
                isInjecting = false
                return nil  // Nothing to undo; swallow the backspace
            }
            let physicalChar = event.getUnicodeString()
            injectionQueue.async { [weak self] in
                guard let self else { return }
                if let undone = self.injector.handleBackspace() {
                    let seq = self.state.keystrokeLogs.first.map { $0.id + 1 } ?? 1
                    self.state.responseLogger?.logUndoEvent(
                        physicalKeyCode: keyCode,
                        physicalFlags: flags,
                        physicalChar: physicalChar,
                        undoneChunkSize: undone.count,
                        undoneText: undone.text
                    )
                    let entry = KeystrokeLogEntry(
                        id: seq,
                        timestamp: self.formattedTimestamp(),
                        type: .undo,
                        physicalKey: "[BS]",
                        injectedText: undone.text,
                        chunkSize: undone.count,
                        mode: self.state.safeInputMode.rawValue,
                        targetApp: self.state.frontmostAppName,
                        sourceFile: self.state.sourceFileName,
                        workspaceFolder: self.state.workspaceFolderPath
                    )
                    self.state.appendKeystrokeLog(entry)
                }
                self.isInjecting = false
            }
            return nil  // Block original backspace
        }

        // --- Rule 4: Enter/Return (keyCode 36) ---
        // Pass through Enter unless the next source character is \n
        if keyCode == 36 {
            if state.getNextChar() != "\n" {
                isInjecting = false
                return Unmanaged.passUnretained(event)
            }
            // Fall through to injection logic below — treat as a normal injection key
        }

        // --- Rule 5: Normal typing key → atomically claim the next chunk and inject ---
        // getAndAdvanceNextChunk is atomic: both the read and advance happen under one lock.
        // This prevents a second keypress from stealing the same chunk before we advance.
        let chunk = state.getAndAdvanceNextChunk()
        guard !chunk.isEmpty else {
            isInjecting = false
            return Unmanaged.passUnretained(event)  // Source exhausted; pass through
        }

        let physicalChar = event.getUnicodeString()

        // Inject asynchronously so the tap callback returns immediately
        // Note: isInjecting is already set to true
        injectionQueue.async { [weak self] in
            guard let self else { return }
            self.injector.injectString(chunk)
            self.state.responseLogger?.logKeystrokeEvent(
                physicalKeyCode: keyCode,
                physicalFlags: flags,
                physicalChar: physicalChar,
                injectedChunk: chunk,
                mode: self.state.safeInputMode.rawValue
            )

            // Build live UI keystroke log entry
            let seq = (self.state.keystrokeLogs.first?.id ?? 0) + 1
            let displayPhysical: String
            if let p = physicalChar, !p.isEmpty {
                displayPhysical = p == "\n" ? "[↵]" : (p == " " ? "[SP]" : p)
            } else {
                displayPhysical = "[?]"
            }
            let displayInjected: String
            if chunk.count <= 40 {
                displayInjected = chunk
                    .replacingOccurrences(of: "\n", with: "⏎")
                    .replacingOccurrences(of: "\t", with: "→")
            } else {
                let preview = String(chunk.prefix(37))
                    .replacingOccurrences(of: "\n", with: "⏎")
                    .replacingOccurrences(of: "\t", with: "→")
                displayInjected = preview + "..."
            }
            let entry = KeystrokeLogEntry(
                id: seq,
                timestamp: self.formattedTimestamp(),
                type: .injection,
                physicalKey: displayPhysical,
                injectedText: displayInjected,
                chunkSize: chunk.count,
                mode: self.state.safeInputMode.rawValue,
                targetApp: self.state.frontmostAppName,
                sourceFile: self.state.sourceFileName,
                workspaceFolder: self.state.workspaceFolderPath
            )
            self.state.appendKeystrokeLog(entry)



            self.isInjecting = false
        }

        return nil  // Block the original keypress
    }

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

fileprivate extension CGEvent {
    func getUnicodeString() -> String? {
        var actualLength = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        self.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &actualLength, unicodeString: &buffer)
        guard actualLength > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: actualLength)
    }
}
