//
//  GhostState.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import Foundation
import Combine

enum InputMode: String, CaseIterable, Identifiable {
    case character = "Character"
    case word = "Word"
    case line = "Line"
    var id: String { rawValue }
}

enum IDETarget: String, CaseIterable, Identifiable {
    case vsCode         = "VS Code"
    case vsCodeInsiders = "VS Code Insiders"
    case xcode          = "Xcode"
    case any            = "Any Application"

    var bundleID: String? {
        switch self {
        case .vsCode:         return "com.microsoft.VSCode"
        case .vsCodeInsiders: return "com.microsoft.VSCodeInsiders"
        case .xcode:          return "com.apple.dt.Xcode"
        case .any:            return nil
        }
    }

    var id: String { rawValue }
}

enum GhostOperationalState {
    case inactive
    case active
    case pausedNoFile
    case pausedFocusNeeded
    case pausedWorkspaceMismatch
    case pausedReady
    case complete
}

class GhostState: ObservableObject {

    // MARK: - Configuration (user-set, persisted)
    @Published var sourceCode: String = ""
    @Published var sourceFileName: String = ""
    @Published var ideTarget: IDETarget = .vsCode
    @Published var workspaceFolderPath: String = ""
    @Published var inputMode: InputMode = .character
    @Published var injectionDelayMs: Int = 12       // per-character delay for word/line mode

    // MARK: - Runtime State (not persisted)
    @Published var isGhostModeEnabled: Bool = false
    @Published var isIDEFocused: Bool = false
    @Published var isFolderScopeActive: Bool = true  // true when folder constraint passes
    @Published var currentIndex: Int = 0

    // MARK: - Injection History (for backspace undo)
    // Each entry = number of characters injected in one keypress
    var injectionHistory: [Int] = []

    // MARK: - Cached active flag (read by CGEventTap callback — must be thread-safe)
    // Updated on main thread by WindowMonitor. Read on tap thread (Bool is atomic on Apple platforms).
    private(set) var isActiveCached: Bool = false

    // MARK: - Computed Properties
    var progress: Double {
        guard !sourceCode.isEmpty else { return 0 }
        return Double(currentIndex) / Double(sourceCode.count)
    }

    var remainingCharCount: Int {
        max(0, sourceCode.count - currentIndex)
    }

    var isSourceLoaded: Bool {
        !sourceCode.isEmpty
    }

    var completionCount: Int {
        sourceCode.count
    }

    var operationalState: GhostOperationalState {
        if sourceCode.isEmpty {
            return isGhostModeEnabled ? .pausedNoFile : .inactive
        }

        if currentIndex >= sourceCode.count {
            return .complete
        }

        if isActiveCached {
            return .active
        }

        if isGhostModeEnabled {
            if !isIDEFocused {
                return .pausedFocusNeeded
            }
            if !isFolderScopeActive {
                return .pausedWorkspaceMismatch
            }
            return .pausedReady
        }

        return .inactive
    }

    var statusLabel: String {
        switch operationalState {
        case .inactive:
            return "Inactive"
        case .active:
            return "Active"
        case .pausedNoFile:
            return "Paused: No File"
        case .pausedFocusNeeded:
            return "Paused: IDE Focus Needed"
        case .pausedWorkspaceMismatch:
            return "Paused: Workspace Mismatch"
        case .pausedReady:
            return "Paused"
        case .complete:
            return "Completed"
        }
    }

    var statusDetail: String {
        switch operationalState {
        case .inactive:
            return "Load a source file and arm Ghost Mode when you're ready."
        case .active:
            return "Interception is live for the current target and workspace."
        case .pausedNoFile:
            return "Add a source file before turning Ghost Mode loose."
        case .pausedFocusNeeded:
            return "Bring the selected IDE to the front to continue typing."
        case .pausedWorkspaceMismatch:
            return "Open a window from the selected workspace folder to continue."
        case .pausedReady:
            return "Ghost Mode is armed and waiting for the next typing context."
        case .complete:
            return "Every character from the loaded source has been injected."
        }
    }

    // MARK: - State Updates
    func updateCachedActiveState() {
        // Called on main thread by WindowMonitor every 150ms
        isActiveCached = isGhostModeEnabled
            && isSourceLoaded
            && currentIndex < sourceCode.count
            && isIDEFocused
            && isFolderScopeActive
    }

    func loadSourceFile(url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        sourceCode = content
        sourceFileName = url.lastPathComponent
        isGhostModeEnabled = false // Auto-pause
        reset()
        updateCachedActiveState()
    }

    func clearSourceFile() {
        sourceCode = ""
        sourceFileName = ""
        isGhostModeEnabled = false
        reset()
        updateCachedActiveState()
    }

    func reset() {
        currentIndex = 0
        injectionHistory.removeAll()
    }

    // MARK: - Chunk Calculation (called on main/tap thread, fast — no IO)
    func getNextChunk() -> String {
        guard currentIndex < sourceCode.count else { return "" }

        let startOffset = sourceCode.index(sourceCode.startIndex, offsetBy: currentIndex)
        let remaining = sourceCode[startOffset...]

        switch inputMode {
        case .character:
            return String(remaining.prefix(1))

        case .word:
            // Read up to and including the next space or newline
            var result = ""
            for char in remaining {
                result.append(char)
                if char == " " || char == "\n" { break }
            }
            return result

        case .line:
            // Read up to and including the next newline
            var result = ""
            for char in remaining {
                result.append(char)
                if char == "\n" { break }
            }
            // If last line has no trailing newline, return remaining
            return result
        }
    }
}
