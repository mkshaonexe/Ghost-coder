//
//  CharacterInjector.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import Foundation
import CoreGraphics
import AppKit
import Darwin

class CharacterInjector {
    private let state: GhostState

    // MARK: - Auto-Close Skip Buffer (Issue 2)
    private let autoCloseLock = NSLock()
    private var autoCloseSkipBuffer: [Character] = []

    private static let autoClosePairs: [Character: Character] = [
        "{": "}",
        "(": ")",
        "[": "]",
        "\"": "\"",
        "'": "'"
    ]

    init(state: GhostState) {
        self.state = state
    }

    // MARK: - Inject a string of characters (runs on injectionQueue)

    func injectString(_ text: String) {
        let delaySeconds = Double(state.safeDelayMs) / 1000.0
        let chars = Array(text)
        let isMultiChar = chars.count > 1

        if state.currentIndex <= text.count {
            autoCloseLock.lock()
            autoCloseSkipBuffer.removeAll()
            autoCloseLock.unlock()
        }

        // Issue 1: If the chunk contains a newline, deliver the whole thing via
        // clipboard paste so VS Code's auto-indent engine never fires.
        if text.contains("\n") {
            pasteViaClipboard(text)
            return
        }

        for char in chars {
            // Check if we should skip the character due to IDE auto-close
            autoCloseLock.lock()
            if let last = autoCloseSkipBuffer.last, last == char {
                autoCloseSkipBuffer.removeLast()
                autoCloseLock.unlock()
                injectVirtualKey(keyCode: 124) // Right Arrow — navigate past IDE's auto-closer
            } else {
                autoCloseLock.unlock()
                injectUnicodeCharacter(char)
                if state.safeEnableAutoCloseSkip, let closer = Self.autoClosePairs[char] {
                    autoCloseLock.lock()
                    autoCloseSkipBuffer.append(closer)
                    autoCloseLock.unlock()
                }
            }

            if isMultiChar {
                Thread.sleep(forTimeInterval: delaySeconds)
            }
        }
    }

    // MARK: - Unicode Character Injection (layout-independent)

    private func injectUnicodeCharacter(_ char: Character) {
        // Issue 3: Characters whose UTF-16 representation is longer than 2 units (surrogate pairs, etc.)
        var utf16Units = Array(char.utf16)
        if utf16Units.count > 2 {
            pasteViaClipboard(String(char))
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            print("Ghost Coder: CharacterInjector — CGEvent creation failed for character '\(char)'")
            return
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)

        // macOS 15+ timestamp issue fix: add valid system timestamp to synthetic events
        let timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        keyDown.timestamp = CGEventTimestamp(timestamp)
        keyUp.timestamp = CGEventTimestamp(timestamp)

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Virtual Key Injection (for Return, Tab, Backspace)

    func injectVirtualKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("Ghost Coder: CharacterInjector — CGEvent creation failed for keyCode \(keyCode)")
            return
        }

        // macOS 15+ timestamp issue fix: add valid system timestamp to synthetic events
        let timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        keyDown.timestamp = CGEventTimestamp(timestamp)
        keyUp.timestamp = CGEventTimestamp(timestamp)

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Clipboard Paste Mode (Issue 1 & 3)

    private func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),  // keyCode 9 = V
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            print("Ghost Coder: CharacterInjector — CGEvent creation failed for Cmd+V paste")
            if let prev = previousString {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            return
        }

        // macOS 15+ timestamp issue fix: add valid system timestamp to synthetic events
        let timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        keyDown.timestamp = CGEventTimestamp(timestamp)
        keyUp.timestamp = CGEventTimestamp(timestamp)

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
            if let prev = previousString {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            } else {
                pasteboard.clearContents()
            }
        }
    }

    // MARK: - Backspace Undo

    func handleBackspace() {
        guard let last = state.popLastInjection() else { return }
        let lastChunkSize = last.count
        let poppedText = last.text

        // Revert pending auto-closes for the popped characters (in reverse order)
        if state.safeEnableAutoCloseSkip {
            autoCloseLock.lock()
            for char in poppedText.reversed() {
                if let closingChar = Self.autoClosePairs[char] {
                    if let lastPending = autoCloseSkipBuffer.last, lastPending == closingChar {
                        autoCloseSkipBuffer.removeLast()
                    }
                }
            }
            autoCloseLock.unlock()
        }

        // Inject N backspace events to delete the injected characters from the IDE
        for i in 0..<lastChunkSize {
            injectVirtualKey(keyCode: 51)  // Backspace
            if lastChunkSize > 1 && i < lastChunkSize - 1 {
                Thread.sleep(forTimeInterval: 0.020)  // 20ms between backspaces for stability in VS Code
            }
        }
    }
}
