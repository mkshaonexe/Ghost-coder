//
//  CharacterInjector.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import Foundation
import CoreGraphics

class CharacterInjector {
    private let state: GhostState

    init(state: GhostState) {
        self.state = state
    }

    // MARK: - Inject a string of characters (runs on injectionQueue)

    func injectString(_ text: String) {
        let delaySeconds = Double(state.injectionDelayMs) / 1000.0
        let isMultiChar = text.count > 1

        for char in text {
            switch char {
            case "\n":
                injectVirtualKey(keyCode: 36)  // Return key — preserves IDE auto-indent
            case "\t":
                injectVirtualKey(keyCode: 48)  // Tab key
            default:
                injectUnicodeCharacter(char)
            }

            if isMultiChar {
                // Small delay between characters in word/line mode so VS Code processes each
                Thread.sleep(forTimeInterval: delaySeconds)
            }
        }
    }

    // MARK: - Unicode Character Injection (layout-independent)

    private func injectUnicodeCharacter(_ char: Character) {
        // Convert to UTF-16 UniChar array (handles BMP and supplementary planes)
        var utf16Units = Array(char.utf16)

        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

        keyDown?.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Virtual Key Injection (for Return, Tab, Backspace)

    func injectVirtualKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    // MARK: - Backspace Undo

    func handleBackspace() {
        guard let lastChunkSize = DispatchQueue.main.sync(execute: { () -> Int? in
            state.injectionHistory.popLast()
        }) else { return }

        // Update the index on the main thread
        DispatchQueue.main.async {
            self.state.currentIndex -= lastChunkSize
            self.state.updateCachedActiveState()
        }

        // Inject N backspace events to delete the injected characters from the IDE
        for i in 0..<lastChunkSize {
            injectVirtualKey(keyCode: 51)  // Backspace
            if lastChunkSize > 1 && i < lastChunkSize - 1 {
                Thread.sleep(forTimeInterval: 0.010)  // 10ms between backspaces
            }
        }
    }
}
