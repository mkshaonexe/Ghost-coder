//
//  GhostState.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import Foundation
import Combine
import ApplicationServices

// MARK: - Keystroke Log Entry (displayed in UI)
struct KeystrokeLogEntry: Identifiable {
    let id: Int          // seq number
    let timestamp: String
    let type: KeystrokeLogType
    let physicalKey: String   // e.g. "t" or "[BS]"
    let injectedText: String  // what was virtually typed (may be multi-char)
    let chunkSize: Int
    let mode: String
    let targetApp: String
    let sourceFile: String
    let workspaceFolder: String
}

enum KeystrokeLogType {
    case injection   // normal keystroke → virtual output
    case undo        // backspace → undo
    case blocked     // key was swallowed with no output
}

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

    // MARK: - Session & Response Logging
    let sessionId: String = {
        let uuid = UUID().uuidString.prefix(8).lowercased()
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(uuid)-\(timestamp)"
    }()
    var responseLogger: ResponseLogger?



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
    @Published var workspaceFolderPath: String = "" {
        didSet {
            if isGhostModeEnabled {
                VSCodeSettingsManager.shared.backupAndApplySettings(workspaceFolderPath: workspaceFolderPath) { [weak self] msg in
                    self?.log(msg)
                }
            }
        }
    }
    @Published var targetFilePath: String = "" {
        didSet {
            stateLock.lock()
            safeTargetFilePath = targetFilePath
            stateLock.unlock()
        }
    }
    @Published var inputMode: InputMode = .character {
        didSet {
            stateLock.lock()
            _safeInputMode = inputMode
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
    @Published var vsCodeTestStatus: String? = nil
    @Published var isTestingVSCode: Bool = false
    @Published var isGhostModeEnabled: Bool = false {
        didSet {
            if isGhostModeEnabled {
                if !AXIsProcessTrusted() {
                    log("Error: Accessibility permission not granted. Cannot activate Ghost Mode.")
                    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                    
                    DispatchQueue.main.async {
                        self.isGhostModeEnabled = false
                        self.updateCachedActiveState()
                    }
                    return
                }
                VSCodeSettingsManager.shared.backupAndApplySettings(workspaceFolderPath: workspaceFolderPath) { [weak self] msg in
                    self?.log(msg)
                }
            } else {
                VSCodeSettingsManager.shared.restoreSettings() { [weak self] msg in
                    self?.log(msg)
                }
            }
        }
    }
    @Published var isIDEFocused: Bool = false
    @Published var isFolderScopeActive: Bool = true  // true when folder constraint passes
    @Published var isAccessibilityGranted: Bool = false
    @Published var isInputMonitoringGranted: Bool = false
    /// When enabled, Ghost Coder uses the Auto-Close Skip Buffer to avoid
    /// doubling brackets/quotes that the IDE already auto-inserted.
    @Published var enableAutoCloseSkip: Bool = true {
        didSet {
            stateLock.lock()
            _safeEnableAutoCloseSkip = enableAutoCloseSkip
            stateLock.unlock()
        }
    }
    @Published var frontmostAppName: String = "None"
    @Published var frontmostWindowMainTitle: String = "None"
    @Published var diagnosticLogs: [String] = []
    @Published var keystrokeLogs: [KeystrokeLogEntry] = []
    
    @Published var currentIndex: Int = 0 {
        didSet {
            stateLock.lock()
            safeCurrentIndex = currentIndex
            stateLock.unlock()
        }
    }

    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let formattedMessage = "[\(timestamp)] \(message)"
        
        print("Ghost Coder Log: \(formattedMessage)")
        responseLogger?.logDiagnosticMessage(formattedMessage)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.diagnosticLogs.insert(formattedMessage, at: 0)
            if self.diagnosticLogs.count > 200 {
                self.diagnosticLogs.removeLast()
            }
        }
    }

    // MARK: - Keystroke Log Appending (thread-safe, called from injection queue)
    func appendKeystrokeLog(_ entry: KeystrokeLogEntry) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.keystrokeLogs.insert(entry, at: 0)
            if self.keystrokeLogs.count > 500 {
                self.keystrokeLogs.removeLast()
            }
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
    private var safeTargetFilePath: String = ""
    private var _safeInputMode: InputMode = .character
    private var safeInjectionDelayMs: Int = 12
    private var safeInjectionHistory: [Int] = []
    private var _safeEnableAutoCloseSkip: Bool = true



    // MARK: - Thread-safe accessors for HotFixEngine

    /// Current injection index, safe to read from any thread.
    var safeCurrentIndexValue: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeCurrentIndex
    }

    /// Total source character count, safe to read from any thread.
    var safeSourceLength: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeSourceCode.count
    }

    /// Full copy of the source code string, safe to read from any thread.
    var safeSourceCodeCopy: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeSourceCode
    }

    /// Target file path, safe to read from any thread.
    var safeTargetFilePathValue: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return safeTargetFilePath
    }

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
            && isAccessibilityGranted  // Cannot intercept without accessibility
    }

    // MARK: - Source File Loading

    func loadSourceFile(url: URL) throws {
        // Try UTF-8 first (most source files); fall back to system default encoding
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
            log("Loaded source file: \(url.lastPathComponent) (UTF-8, \(content.count) characters)")
        } catch {
            // Attempt system-preferred encoding as fallback (handles latin-1 / legacy files)
            guard let fallback = try? String(contentsOf: url, encoding: .isoLatin1) else {
                log("Failed to load source file: \(url.lastPathComponent) (Error: \(error.localizedDescription))")
                throw error  // Re-throw the original UTF-8 error with full info
            }
            content = fallback
            log("Loaded source file: \(url.lastPathComponent) (ISO-Latin1 fallback, \(content.count) characters)")
        }

        stateLock.lock()
        safeSourceCode = content
        safeCurrentIndex = 0
        safeInjectionHistory.removeAll()
        stateLock.unlock()

        sourceCode = content
        sourceFileName = url.lastPathComponent
        
        responseLogger?.startSession(
            sourceFile: sourceFileName,
            ideTarget: ideTarget.rawValue,
            inputMode: inputMode.rawValue
        )
        
        isGhostModeEnabled = false // Auto-pause when new file is loaded
        reset()
        updateCachedActiveState()
    }

    func clearSourceFile() {
        log("Cleared source file: \(sourceFileName)")
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
        log("Reset typing pointer to 0")
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
        stateLock.unlock()

        log("Advanced pointer by \(count) to \(newIndex) / \(sourceCode.count)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = newIndex
            self.injectionHistory.append(count)
            self.updateCachedActiveState()
        }
    }

    func popLastInjection() -> (count: Int, text: String)? {
        stateLock.lock()
        guard let count = safeInjectionHistory.popLast() else {
            stateLock.unlock()
            return nil
        }
        let poppedIndex = max(0, safeCurrentIndex - count)
        
        let text: String
        if poppedIndex + count <= safeSourceCode.count {
            let startIndex = safeSourceCode.index(safeSourceCode.startIndex, offsetBy: poppedIndex)
            let endIndex = safeSourceCode.index(startIndex, offsetBy: count)
            text = String(safeSourceCode[startIndex..<endIndex])
        } else {
            text = ""
        }
        
        safeCurrentIndex = poppedIndex
        let newIndex = safeCurrentIndex
        stateLock.unlock()

        log("Undid last injection: removed \(count) chars ('\(text)'), pointer now at \(newIndex)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = newIndex
            if !self.injectionHistory.isEmpty {
                self.injectionHistory.removeLast()
            }
            self.updateCachedActiveState()
        }

        return (count, text)
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

    var safeEnableAutoCloseSkip: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _safeEnableAutoCloseSkip
    }

    var safeInputMode: InputMode {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _safeInputMode
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

    /// Read the next chunk without advancing. Used only by handleKeyDown to peek at \n.
    func getNextChunk() -> String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _buildChunk(sourceCode: safeSourceCode, index: safeCurrentIndex, mode: _safeInputMode)
    }

    /// Read the next chunk without advancing. Used only by handleKeyDown to peek at \n.
    /// Atomically read the next chunk AND advance the pointer in one lock acquisition.
    /// This prevents a second concurrent keypress from claiming the same characters.
    func getAndAdvanceNextChunk() -> String {
        stateLock.lock()
        let chunk = _buildChunk(sourceCode: safeSourceCode, index: safeCurrentIndex, mode: _safeInputMode)
        if !chunk.isEmpty {
            safeCurrentIndex += chunk.count
            safeInjectionHistory.append(chunk.count)
        }
        let newIndex = safeCurrentIndex
        let chunkCount = chunk.count
        stateLock.unlock()

        if !chunk.isEmpty {
            log("Advanced pointer by \(chunkCount) to \(newIndex) / \(sourceCode.count)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentIndex = newIndex
                self.injectionHistory.append(chunkCount)
                self.updateCachedActiveState()
            }
        }
        return chunk
    }

    /// Internal helper: compute the next chunk from given parameters. Must be called under stateLock.
    private func _buildChunk(sourceCode: String, index: Int, mode: InputMode) -> String {
        guard index < sourceCode.count else { return "" }

        let startOffset = sourceCode.index(sourceCode.startIndex, offsetBy: index)
        let remaining = sourceCode[startOffset...]

        switch mode {
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
            var result = ""
            let chars = Array(remaining)
            guard !chars.isEmpty else { return "" }
            
            let isStartOfLine = (index == 0) || {
                let prevIndex = sourceCode.index(sourceCode.startIndex, offsetBy: index - 1)
                return sourceCode[prevIndex] == "\n"
            }()
            
            if isStartOfLine {
                // Read up to and including the next newline
                for char in chars {
                    result.append(char)
                    if char == "\n" { break }
                }
            } else {
                // We are mid-line.
                if chars[0] == "\n" {
                    // If the first character is a newline, we read it AND the next line up to and including its newline.
                    result.append(chars[0])
                    for char in chars.dropFirst() {
                        result.append(char)
                        if char == "\n" { break }
                    }
                } else {
                    // Read up to (but NOT including) the next newline
                    for char in chars {
                        if char == "\n" { break }
                        result.append(char)
                    }
                }
            }
            return result
        }
    }
}
