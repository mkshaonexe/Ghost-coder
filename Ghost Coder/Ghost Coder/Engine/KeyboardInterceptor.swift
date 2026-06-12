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

        // If currently injecting (word/line mode multi-char), block incoming key silently
        if isInjecting {
            return nil
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // --- Rule 1: Any Cmd+key combination → always pass through ---
        if flags.contains(.maskCommand) {
            return Unmanaged.passUnretained(event)
        }

        // --- Rule 2: Explicit passthrough key codes ---
        let passthroughKeyCodes: Set<Int> = [
            123, 124, 125, 126,  // Arrow keys (Left, Right, Down, Up)
            53,                   // Escape
            48,                   // Tab (VS Code autocomplete navigation)
            117,                  // Forward Delete
            115, 119,             // Home, End
            116, 121,             // Page Up, Page Down
            // Function keys F1–F12
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111
        ]
        if passthroughKeyCodes.contains(keyCode) {
            return Unmanaged.passUnretained(event)
        }

        // --- Rule 3: Backspace (keyCode 51) ---
        if keyCode == 51 {
            guard !state.isHistoryEmpty else {
                return nil  // Nothing to undo; swallow the backspace
            }
            isInjecting = true
            injectionQueue.async { [weak self] in
                guard let self else { return }
                self.injector.handleBackspace()
                self.isInjecting = false
            }
            return nil  // Block original backspace
        }

        // --- Rule 4: Enter/Return (keyCode 36) ---
        // Pass through Enter unless the next source character is \n
        if keyCode == 36 {
            if state.getNextChar() != "\n" {
                return Unmanaged.passUnretained(event)
            }
            // Fall through to injection logic below — treat as a normal injection key
        }

        // --- Rule 5: Normal typing key → atomically claim the next chunk and inject ---
        // getAndAdvanceNextChunk is atomic: both the read and advance happen under one lock.
        // This prevents a second keypress from stealing the same chunk before we advance.
        let chunk = state.getAndAdvanceNextChunk()
        guard !chunk.isEmpty else {
            return Unmanaged.passUnretained(event)  // Source exhausted; pass through
        }

        // Inject asynchronously so the tap callback returns immediately
        isInjecting = true
        injectionQueue.async { [weak self] in
            guard let self else { return }
            self.injector.injectString(chunk)
            self.isInjecting = false
        }

        return nil  // Block the original keypress
    }
}
