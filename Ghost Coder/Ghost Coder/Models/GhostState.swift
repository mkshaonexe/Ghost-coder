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
    @Published var sourceCode: String = "" {
        didSet {
            stateLock.lock()
            safeSourceCode = sourceCode
            stateLock.unlock()
        }
    }
    @Published var sourceFileName: String = ""
    @Published var ideTarget: IDETarget = .vsCode
    @Published var workspaceFolderPath: String = ""
    @Published var inputMode: InputMode = .character {
        didSet {
            stateLock.lock()
            safeInputMode = inputMode
            stateLock.unlock()
        }
    }
    @Published var injectionDelayMs: Int = 12 {
        didSet {
            stateLock.lock()
            safeInjectionDelayMs = injectionDelayMs
            stateLock.unlock()
        }
    }

    // MARK: - Runtime State (not persisted)
    @Published var isGhostModeEnabled: Bool = false
    @Published var isIDEFocused: Bool = false
    @Published var isFolderScopeActive: Bool = true  // true when folder constraint passes
    @Published var currentIndex: Int = 0 {
        didSet {
            stateLock.lock()
            safeCurrentIndex = currentIndex
            stateLock.unlock()
        }
    }

    // MARK: - Injection History (for backspace undo)
    // Each entry = number of characters injected in one keypress
    var injectionHistory: [Int] = []

    // MARK: - Thread-safety: NSLock + shadow variables
    // All state consumed by CGEventTap callbacks uses these safe mirrors.
    // The @Published variants are only touched on the main thread (UI layer).
    private let stateLock = NSLock()
    private var safeCurrentIndex: Int = 0
    private var safeSourceCode: String = ""
    private var safeInputMode: InputMode = .character
    private var safeInjectionDelayMs: Int = 12
    private var safeInjectionHistory: [Int] = []

    // MARK: - Cached active flag (read by CGEventTap callback — Bool is single-word, atomic on Apple Silicon)
    // Written exclusively on the main thread by WindowMonitor.
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
        // Must be called on main thread (touches @Published properties + isActiveCached)
        isActiveCached = isGhostModeEnabled
            && isSourceLoaded
            && currentIndex < sourceCode.count
            && isIDEFocused
            && isFolderScopeActive
    }

    // MARK: - Source File Loading

    func loadSourceFile(url: URL) throws {
        // Try UTF-8 first (most source files); fall back to system default encoding
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Attempt system-preferred encoding as fallback (handles latin-1 / legacy files)
            guard let fallback = try? String(contentsOf: url, encoding: .isoLatin1) else {
                throw error  // Re-throw the original UTF-8 error with full info
            }
            content = fallback
        }

        stateLock.lock()
        safeSourceCode = content
        safeCurrentIndex = 0
        safeInjectionHistory.removeAll()
        stateLock.unlock()

        sourceCode = content
        sourceFileName = url.lastPathComponent
        isGhostModeEnabled = false // Auto-pause when new file is loaded
        reset()
        updateCachedActiveState()
    }

    func clearSourceFile() {
        stateLock.lock()
        safeSourceCode = ""
        safeCurrentIndex = 0
        safeInjectionHistory.removeAll()
        stateLock.unlock()

        sourceCode = ""
        sourceFileName = ""
        isGhostModeEnabled = false
        reset()
        updateCachedActiveState()
    }

    func reset() {
        stateLock.lock()
        safeCurrentIndex = 0
        safeInjectionHistory.removeAll()
        stateLock.unlock()

        currentIndex = 0
        injectionHistory.removeAll()
    }

    // MARK: - Thread-safe State Modifiers (called from background/tap threads)

    func advanceIndex(by count: Int) {
        stateLock.lock()
        safeCurrentIndex += count
        safeInjectionHistory.append(count)
        let newIndex = safeCurrentIndex
        let historySnapshot = safeInjectionHistory
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = newIndex
            self.injectionHistory = historySnapshot
            self.updateCachedActiveState()
        }
    }

    func popLastInjection() -> Int? {
        stateLock.lock()
        guard let count = safeInjectionHistory.popLast() else {
            stateLock.unlock()
            return nil
        }
        safeCurrentIndex = max(0, safeCurrentIndex - count)
        let newIndex = safeCurrentIndex
        let historySnapshot = safeInjectionHistory
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = newIndex
            self.injectionHistory = historySnapshot
            self.updateCachedActiveState()
        }

        return count
    }

    var isHistoryEmpty: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeInjectionHistory.isEmpty
    }

    var safeDelayMs: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeInjectionDelayMs
    }

    func getNextChar() -> Character? {
        stateLock.lock()
        let localSourceCode = safeSourceCode
        let localCurrentIndex = safeCurrentIndex
        stateLock.unlock()

        guard localCurrentIndex < localSourceCode.count else { return nil }
        let index = localSourceCode.index(localSourceCode.startIndex, offsetBy: localCurrentIndex)
        return localSourceCode[index]
    }

    // MARK: - Chunk Calculation (lock-protected, safe to call from any thread)
    func getNextChunk() -> String {
        stateLock.lock()
        let localSourceCode = safeSourceCode
        let localCurrentIndex = safeCurrentIndex
        let localInputMode = safeInputMode
        stateLock.unlock()

        guard localCurrentIndex < localSourceCode.count else { return "" }

        let startOffset = localSourceCode.index(localSourceCode.startIndex, offsetBy: localCurrentIndex)
        let remaining = localSourceCode[startOffset...]

        switch localInputMode {
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
