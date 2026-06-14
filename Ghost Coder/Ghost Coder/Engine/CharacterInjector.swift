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

    init(state: GhostState) {
        self.state = state
    }

    // MARK: - Inject a string of characters (runs on injectionQueue)

    func injectString(_ text: String) {
        let delaySeconds = Double(state.safeDelayMs) / 1000.0
        let chars = Array(text)
        let isMultiChar = chars.count > 1

        for char in chars {
            injectUnicodeCharacter(char)

            if isMultiChar {
                Thread.sleep(forTimeInterval: delaySeconds)
            }
        }
    }

    // MARK: - Unicode Character Injection (layout-independent)

    private func injectUnicodeCharacter(_ char: Character) {
        var utf16Units = Array(char.utf16)

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

    // MARK: - Backspace Undo

    func handleBackspace() -> (count: Int, text: String)? {
        guard let last = state.popLastInjection() else { return nil }
        let lastChunkSize = last.count

        // Inject N backspace events to delete the injected characters from the IDE
        for i in 0..<lastChunkSize {
            injectVirtualKey(keyCode: 51)  // Backspace
            if lastChunkSize > 1 && i < lastChunkSize - 1 {
                Thread.sleep(forTimeInterval: 0.020)  // 20ms between backspaces for stability in VS Code
            }
        }
        return last
    }
}
