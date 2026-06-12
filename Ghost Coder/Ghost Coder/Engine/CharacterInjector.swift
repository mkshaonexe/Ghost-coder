//
//  CharacterInjector.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//
//  Fixes applied:
//  • Issue 1 — IDE Smart-Feature Interference: newlines and multi-char chunks
//    that contain \n are now delivered via Clipboard Paste Mode (Cmd+V) so
//    VS Code / Xcode auto-indent never fires.
//  • Issue 2 — Auto-Closing Bracket Doubling: an Auto-Close Skip Buffer tracks
//    which closing chars the IDE will insert; Ghost Coder skips injecting them
//    and instead presses Right Arrow to move past the IDE's auto-closer.
//  • Issue 3 — Emoji / Multi-Codepoint Unicode: characters whose UTF-16
//    representation exceeds 2 units (surrogate pairs, flag emoji, etc.) are
//    routed through Clipboard Paste Mode to avoid silent truncation by
//    CGEventKeyboardSetUnicodeString.

import Foundation
import CoreGraphics
import AppKit

class CharacterInjector {
    private let state: GhostState

    // MARK: - Auto-Close Skip Buffer (Issue 2)
    // When Ghost Coder injects an opening bracket/quote, the IDE auto-inserts
    // the matching closer.  We push that closer here so the next time we see
    // it in the source, we skip injecting it and press Right Arrow instead.
    private let autoCloseLock = NSLock()
    private var autoCloseSkipBuffer: [Character] = []

    // Map of opener → IDE-inserted closer
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
        let isMultiChar = text.count > 1

        // Issue 1: If the chunk contains a newline, deliver the whole thing via
        // clipboard paste so VS Code's auto-indent engine never fires.
        if text.contains("\n") {
            pasteViaClipboard(text)
            return
        }

        for char in text {
            injectUnicodeCharacter(char)

            if isMultiChar {
                // Small delay between characters in word/line mode so VS Code processes each
                Thread.sleep(forTimeInterval: delaySeconds)
            }
        }
    }

    // MARK: - Unicode Character Injection (layout-independent)

    private func injectUnicodeCharacter(_ char: Character) {
        // Issue 2: Check if the IDE already auto-inserted this closing char.
        // If so, skip injection and press Right Arrow to move past it.
        autoCloseLock.lock()
        if let first = autoCloseSkipBuffer.first, first == char {
            autoCloseSkipBuffer.removeFirst()
            autoCloseLock.unlock()
            injectVirtualKey(keyCode: 124) // Right Arrow — navigate past IDE's auto-closer
            return
        }
        autoCloseLock.unlock()

        // Issue 3: Characters whose UTF-16 representation is longer than 2 units
        // (surrogate pairs, flag emoji, combining sequences) must go via clipboard
        // because CGEventKeyboardSetUnicodeString silently truncates them.
        var utf16Units = Array(char.utf16)
        if utf16Units.count > 2 {
            pasteViaClipboard(String(char))
            return
        }

        // Use hidSystemState so the event looks like real hardware input.
        // Using combinedSessionState here would risk loop-back through our own tap.
        let source = CGEventSource(stateID: .hidSystemState)

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

        // Issue 2: If we just injected an opening bracket/quote, push the expected
        // IDE-auto-closer into the skip buffer so we skip it when it appears next.
        if let closer = Self.autoClosePairs[char] {
            autoCloseLock.lock()
            autoCloseSkipBuffer.append(closer)
            autoCloseLock.unlock()
        }
    }

    // MARK: - Virtual Key Injection (for Return, Tab, Backspace, Right Arrow)

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

    // MARK: - Clipboard Paste Mode (Issue 1 & 3)
    // Delivers text by writing it to the pasteboard and posting Cmd+V.
    // Restores the previous clipboard contents after a short delay to minimise
    // disruption to the user's copy/paste workflow.

    private func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Snapshot existing clipboard contents (string only; other types are not restored)
        let previousString = pasteboard.string(forType: .string)

        // Write our text to the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Synthesise Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),  // keyCode 9 = V
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            print("Ghost Coder: CharacterInjector — CGEvent creation failed for Cmd+V paste")
            // Restore clipboard even on failure
            if let prev = previousString {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        // Restore previous clipboard after enough time for the paste to complete.
        // 300 ms is well beyond any IDE's paste processing time.
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
