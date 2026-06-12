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
        let delaySeconds = Double(state.safeDelayMs) / 1000.0
        let isMultiChar = text.count > 1

        for char in text {
            // IMPORTANT: Inject ALL characters — including \n and \t — as raw Unicode
            // events rather than virtual key codes.
            //
            // Why: pressing the Return virtual key (keyCode 36) triggers VS Code's
            // auto-indent engine, which inserts its own leading whitespace on the new
            // line.  When we then inject the leading spaces/tabs that already exist in
            // the source file, the result is *double indentation*.  The same problem
            // applies to Tab (keyCode 48) which can fire VS Code's tab-completion.
            //
            // Injecting \n / \t as Unicode bypasses all IDE formatting hooks and
            // delivers exactly the whitespace that is already in the source file.
            injectUnicodeCharacter(char)

            if isMultiChar {
                // Small delay between characters in word/line mode so VS Code processes each
                Thread.sleep(forTimeInterval: delaySeconds)
            }
        }
    }

    // MARK: - Unicode Character Injection (layout-independent)

    private func injectUnicodeCharacter(_ char: Character) {
        // Use hidSystemState so the event looks like real hardware input.
        // Using combinedSessionState here would risk loop-back through our own tap.
        let source = CGEventSource(stateID: .hidSystemState)

        var utf16Units = Array(char.utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            // CGEvent creation can fail under rare system conditions (sandboxing, event tap overload)
            print("Ghost Coder: CharacterInjector — CGEvent creation failed for character '\(char)'")
            return
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)

        // Post to cgAnnotatedSessionEventTap so synthetic events are delivered to the
        // frontmost application but bypass our own .cghidEventTap listener, avoiding loops.
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
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Backspace Undo

    func handleBackspace() {
        guard let lastChunkSize = state.popLastInjection() else { return }

        // Inject N backspace events to delete the injected characters from the IDE
        for i in 0..<lastChunkSize {
            injectVirtualKey(keyCode: 51)  // Backspace
            if lastChunkSize > 1 && i < lastChunkSize - 1 {
                Thread.sleep(forTimeInterval: 0.010)  // 10ms between backspaces
            }
        }
    }
}
