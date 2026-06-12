//
//  HotFixEngine.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import Foundation
import AppKit
import CoreGraphics
import Darwin

/// HotFixEngine validates the IDE editor content against the source file at key
/// milestones during injection and automatically corrects any discrepancies.
///
/// ## Strategy
/// - **Micro fix** (every 5 completed lines): reads editor via AX API, diffs line-by-line,
///   applies targeted VS Code "Go to Line" fixes for ≤3 mismatches.
/// - **Milestone fix** (15 / 50 / 75 / 99 %): always performs Cmd+A → paste of the
///   expected content — guaranteed to reset any accumulated drift.
/// - **Final fix** (100 %): Cmd+A → paste of the complete source file.
///
/// ## Threading
/// All hot-fixes are dispatched onto the shared `injectionQueue` so they run
/// serially with normal injection blocks. While a hot-fix is executing,
/// `GhostState.isHotFixRunning` is `true`; `KeyboardInterceptor` uses this
/// flag to swallow non-Cmd keypresses until the fix completes.
class HotFixEngine {

    // MARK: - Dependencies

    private let state: GhostState
    /// Weak to avoid a retain cycle (interceptor holds hotFixEngine strongly).
    private weak var interceptor: KeyboardInterceptor?

    // MARK: - Micro-fix line counter

    private var newlinesSinceLastMicroFix: Int = 0
    private let microFixLineThreshold: Int = 10

    // MARK: - Milestone tracking

    private var triggeredMilestones: Set<Int> = []
    private let milestonePercentages: [Int] = [25, 50, 75, 90, 99, 100]

    // MARK: - Init

    init(state: GhostState, interceptor: KeyboardInterceptor) {
        self.state = state
        self.interceptor = interceptor
    }

    // MARK: - Reset (called when a new source file is loaded / pointer reset)

    func reset() {
        triggeredMilestones.removeAll()
        newlinesSinceLastMicroFix = 0
        state.log("HotFix: milestone tracking reset")
    }

    // MARK: - Notification from KeyboardInterceptor

    /// Called by `KeyboardInterceptor` from inside the `injectionQueue` after each
    /// chunk has been injected. Decides whether a hot-fix is needed and schedules one.
    func onChunkInjected(chunk: String, currentIndex: Int, totalLength: Int) {
        guard totalLength > 0, currentIndex > 0 else { return }

        // Count newlines to track micro-fix threshold
        let newlines = chunk.filter { $0 == "\n" }.count
        newlinesSinceLastMicroFix += newlines

        let needsMicroFix = newlinesSinceLastMicroFix >= microFixLineThreshold
        if needsMicroFix { newlinesSinceLastMicroFix = 0 }

        // Check whether a milestone percentage has been crossed
        let progressPercent = Int((Double(currentIndex) / Double(totalLength)) * 100.0)
        var hitMilestone: Int? = nil
        for milestone in milestonePercentages {
            if progressPercent >= milestone && !triggeredMilestones.contains(milestone) {
                triggeredMilestones.insert(milestone)
                hitMilestone = milestone
                break   // Only trigger the lowest new milestone per call
            }
        }

        guard needsMicroFix || hitMilestone != nil else { return }

        let reason    = hitMilestone.map { "\($0)%" } ?? "micro"
        let milestone = hitMilestone != nil

        // Schedule the fix on the injectionQueue so it runs after the current
        // block (and any already-queued injections) complete.
        guard let queue = interceptor?.injectionQueue else { return }
        queue.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            // Re-read index at execution time — may have advanced since we scheduled.
            let execIndex = self.state.safeCurrentIndexValue
            let execTotal = self.state.safeSourceLength
            self.runHotFix(currentIndex: execIndex,
                           totalLength:  execTotal,
                           reason:       reason,
                           isMilestone:  milestone)
        }
    }

    // MARK: - Core Hot-Fix Logic

    private func runHotFix(currentIndex: Int,
                           totalLength:  Int,
                           reason:       String,
                           isMilestone:  Bool) {
        // Raise the running flag — KeyboardInterceptor will swallow keypresses
        state.isHotFixRunning = true
        defer { state.isHotFixRunning = false }

        state.log("HotFix [\(reason)]: start — index \(currentIndex)/\(totalLength)")

        let sourceCode = state.safeSourceCodeCopy
        guard !sourceCode.isEmpty, currentIndex > 0 else {
            state.log("HotFix [\(reason)]: skipped — no source or index is 0")
            return
        }

        // --- 100 % completion: always do a definitive full replace ---
        if currentIndex >= totalLength {
            state.log("HotFix [\(reason)]: 100 % — performing final full-file replace")
            performSelectAndReplace(content: sourceCode, reason: reason)
            return
        }

        // Build what the editor SHOULD contain up to current injection point
        let safeIdx      = min(currentIndex, sourceCode.count)
        let endIdx       = sourceCode.index(sourceCode.startIndex, offsetBy: safeIdx)
        let expectedContent = String(sourceCode[..<endIdx])

        // Try reading the actual editor content via Accessibility API
        if let actualContent = readEditorContent() {
            let expectedLines = expectedContent.components(separatedBy: "\n")
            let actualLines   = actualContent.components(separatedBy: "\n")
            let diffs         = computeDiff(expected: expectedLines, actual: actualLines)

            if diffs.isEmpty {
                state.log("HotFix [\(reason)]: ✅ editor matches source — no fix needed")
                return
            }

            state.log("HotFix [\(reason)]: ⚠️ \(diffs.count) differing line(s) found")

            if isMilestone || diffs.count > 3 {
                // Many diffs or a milestone → full select-and-replace (safest)
                performSelectAndReplace(content: expectedContent, reason: reason)
            } else {
                // Micro fix with few diffs → surgical line-by-line correction
                for diff in diffs {
                    performLineReplace(lineNumber: diff.lineNumber,
                                       newContent: diff.expected,
                                       reason:     reason)
                    Thread.sleep(forTimeInterval: 0.12)
                }
            }
        } else {
            // Cannot read editor — fall back gracefully
            if isMilestone {
                state.log("HotFix [\(reason)]: cannot read editor — precautionary replace")
                performSelectAndReplace(content: expectedContent, reason: reason)
            } else {
                state.log("HotFix [\(reason)]: cannot read editor — skipping micro fix")
            }
        }
    }

    // MARK: - Read Editor Content (Accessibility API)

    private func readEditorContent() -> String? {
        // Use the frontmost application — when Ghost Coder is active the target
        // IDE is always in front.
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success else { return nil }

        let focused = focusedRef as! AXUIElement

        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &valueRef
        ) == .success,
              let value = valueRef as? String,
              !value.isEmpty
        else { return nil }

        return value
    }

    // MARK: - Diff Computation

    private func computeDiff(
        expected: [String],
        actual:   [String]
    ) -> [(lineNumber: Int, expected: String)] {
        var diffs: [(lineNumber: Int, expected: String)] = []

        let checkCount = min(expected.count, actual.count)
        for i in 0..<checkCount {
            if expected[i] != actual[i] {
                diffs.append((lineNumber: i + 1, expected: expected[i]))
            }
        }

        // Flag surplus lines in actual (extra content that shouldn't be there)
        if actual.count > expected.count {
            for i in expected.count..<actual.count {
                diffs.append((lineNumber: i + 1, expected: ""))
            }
        }

        return diffs
    }

    // MARK: - Correction A: Full Select-and-Replace

    /// Replaces ALL editor content with `content` using Cmd+A → Cmd+V.
    /// Guaranteed correct; used for milestone and many-diff scenarios.
    private func performSelectAndReplace(content: String, reason: String) {
        let pasteboard     = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        Thread.sleep(forTimeInterval: 0.05)

        synthesizeKey(keyCode: 0, flags: .maskCommand)   // Cmd+A  (keyCode 0 = A)
        Thread.sleep(forTimeInterval: 0.60)

        synthesizeKey(keyCode: 9, flags: .maskCommand)   // Cmd+V  (keyCode 9 = V)
        Thread.sleep(forTimeInterval: 0.35)

        // Restore previous clipboard content asynchronously
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
            pasteboard.clearContents()
            if let prev = previousString {
                pasteboard.setString(prev, forType: .string)
            }
        }

        state.log("HotFix [\(reason)]: ✅ select-and-replace complete (\(content.count) chars)")
    }

    // MARK: - Correction B: Targeted Line Replace (VS Code — Ctrl+G)

    /// Navigates to a specific line using VS Code's Ctrl+G shortcut, selects it,
    /// and replaces with the correct content.
    /// Used only for micro-fixes with ≤ 3 differing lines.
    private func performLineReplace(lineNumber: Int, newContent: String, reason: String) {
        // Open "Go to Line" prompt (Ctrl+G in VS Code)
        synthesizeKey(keyCode: 5, flags: .maskControl)
        Thread.sleep(forTimeInterval: 0.15)

        // Clear any previous value in the prompt
        synthesizeKey(keyCode: 0, flags: .maskCommand)   // Cmd+A
        Thread.sleep(forTimeInterval: 0.05)

        // Type line number
        for char in "\(lineNumber)" {
            injectUnicodeCharacter(char)
            Thread.sleep(forTimeInterval: 0.02)
        }

        // Confirm
        synthesizeKey(keyCode: 36, flags: [])            // Return
        Thread.sleep(forTimeInterval: 0.10)

        // Move to start of line
        synthesizeKey(keyCode: 115, flags: [])           // Home
        Thread.sleep(forTimeInterval: 0.05)

        // Select to end of line
        synthesizeKey(keyCode: 119, flags: .maskShift)   // Shift+End
        Thread.sleep(forTimeInterval: 0.05)

        // Type correct line content (strip trailing newline)
        let lineContent = newContent.replacingOccurrences(of: "\n", with: "")
        for char in lineContent {
            injectUnicodeCharacter(char)
            Thread.sleep(forTimeInterval: 0.008)
        }

        state.log("HotFix [\(reason)]: fixed line \(lineNumber): \"\(String(lineContent.prefix(50)))\"")
    }

    // MARK: - Key Synthesis Helpers

    private func synthesizeKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        let ts = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        keyDown.timestamp = CGEventTimestamp(ts)
        keyUp.timestamp   = CGEventTimestamp(ts)
        keyDown.flags = flags
        keyUp.flags   = flags

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func injectUnicodeCharacter(_ char: Character) {
        var utf16Units = Array(char.utf16)
        guard utf16Units.count <= 2 else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)

        let ts = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        keyDown.timestamp = CGEventTimestamp(ts)
        keyUp.timestamp   = CGEventTimestamp(ts)

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
