//
//  VSCodeSettingsManager.swift
//  Ghost Coder
//
//  Created by AI on 14/6/26.
//

import Foundation

class VSCodeSettingsManager {
    static let shared = VSCodeSettingsManager()
    
    private let fileManager = FileManager.default
    private var originalContents: [URL: String] = [:]
    
    private func findWorkspaceRoot(from path: String) -> String {
        var currentURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: currentURL.path, isDirectory: &isDir) && !isDir.boolValue {
            currentURL = currentURL.deletingLastPathComponent()
        } else if !fileManager.fileExists(atPath: currentURL.path) && !currentURL.pathExtension.isEmpty {
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        let initialURL = currentURL
        
        while currentURL.path != "/" && currentURL.path.count > 1 {
            if fileManager.fileExists(atPath: currentURL.appendingPathComponent(".git").path) ||
               fileManager.fileExists(atPath: currentURL.appendingPathComponent(".vscode").path) ||
               fileManager.fileExists(atPath: currentURL.appendingPathComponent("pubspec.yaml").path) ||
               fileManager.fileExists(atPath: currentURL.appendingPathComponent("package.json").path) {
                return currentURL.path
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return initialURL.path
    }
    
    private func getSettingsURLs(workspaceFolderPath: String?) -> [URL] {
        var urls: [URL] = []
        
        // 1. Workspace settings (if workspace folder is specified)
        if let wsPath = workspaceFolderPath, !wsPath.isEmpty {
            let rootPath = findWorkspaceRoot(from: wsPath)
            let wsURL = URL(fileURLWithPath: rootPath)
                .appendingPathComponent(".vscode")
                .appendingPathComponent("settings.json")
            urls.append(wsURL)
        }
        
        // 2. Global settings
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        let stableURL = homeDir
            .appendingPathComponent("Library/Application Support/Code/User/settings.json")
        urls.append(stableURL)
        
        let insidersURL = homeDir
            .appendingPathComponent("Library/Application Support/Code - Insiders/User/settings.json")
        urls.append(insidersURL)
        
        return urls
    }
    
    func backupAndApplySettings(workspaceFolderPath: String?, isGitDiffMode: Bool = false, logHandler: ((String) -> Void)? = nil) {
        let urls = getSettingsURLs(workspaceFolderPath: workspaceFolderPath)
        
        for url in urls {
            let exists = fileManager.fileExists(atPath: url.path)
            
            // For workspace settings, if it doesn't exist, we can create it.
            // For global settings, if it doesn't exist, we skip.
            if !exists {
                if url.path.contains(".vscode/settings.json") {
                    let dir = url.deletingLastPathComponent()
                    do {
                        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                        try "{\n}".write(to: url, atomically: true, encoding: .utf8)
                        logHandler?("VSCodeSettingsManager: Created empty workspace settings.json at \(url.path)")
                    } catch {
                        logHandler?("VSCodeSettingsManager: Failed to create empty workspace settings.json: \(error.localizedDescription)")
                        continue
                    }
                } else {
                    continue
                }
            }
            
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            // Skip backup if it has already been backed up in this session
            if originalContents[url] == nil {
                originalContents[url] = content
                
                // Write physical backup file to disk for crash recovery
                let backupURL = url.appendingPathExtension("ghostbackup")
                do {
                    try content.write(to: backupURL, atomically: true, encoding: .utf8)
                    logHandler?("VSCodeSettingsManager: Backed up settings to \(backupURL.path)")
                } catch {
                    logHandler?("VSCodeSettingsManager: Failed to write backup settings: \(error.localizedDescription)")
                }
            }
            
            // Apply modifications
            let modified = applyGhostSettings(to: content, isGitDiffMode: isGitDiffMode)
            do {
                try modified.write(to: url, atomically: true, encoding: .utf8)
                logHandler?("VSCodeSettingsManager: Applied Ghost settings to \(url.path)")
            } catch {
                logHandler?("VSCodeSettingsManager: Failed to write modified settings: \(error.localizedDescription)")
            }
        }
    }
    
    func restoreSettings(logHandler: ((String) -> Void)? = nil) {
        for (url, originalContent) in originalContents {
            do {
                try originalContent.write(to: url, atomically: true, encoding: .utf8)
                logHandler?("VSCodeSettingsManager: Restored original settings at \(url.path)")
            } catch {
                logHandler?("VSCodeSettingsManager: Failed to restore settings at \(url.path): \(error.localizedDescription)")
            }
            
            let backupURL = url.appendingPathExtension("ghostbackup")
            try? fileManager.removeItem(at: backupURL)
        }
        originalContents.removeAll()
    }
    
    func checkAndRestoreCrashedBackups(workspaceFolderPath: String?, logHandler: ((String) -> Void)? = nil) {
        let urls = getSettingsURLs(workspaceFolderPath: workspaceFolderPath)
        for url in urls {
            let backupURL = url.appendingPathExtension("ghostbackup")
            if fileManager.fileExists(atPath: backupURL.path) {
                logHandler?("VSCodeSettingsManager: Detected crash backup file at \(backupURL.path). Restoring...")
                if let originalContent = try? String(contentsOf: backupURL, encoding: .utf8) {
                    do {
                        try originalContent.write(to: url, atomically: true, encoding: .utf8)
                        logHandler?("VSCodeSettingsManager: Restored successfully from crash backup.")
                    } catch {
                        logHandler?("VSCodeSettingsManager: Failed to write restored content: \(error.localizedDescription)")
                    }
                }
                try? fileManager.removeItem(at: backupURL)
            }
        }
    }
    
    func verifyAppliedSettings(workspaceFolderPath: String?) -> Bool {
        let urls = getSettingsURLs(workspaceFolderPath: workspaceFolderPath)
        var verifiedAtLeastOne = false
        
        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let expectedSettings = [
                "editor.autoClosingBrackets",
                "editor.autoClosingQuotes",
                "editor.autoIndent",
                "editor.formatOnType",
                "editor.acceptSuggestionOnEnter",
                "editor.acceptSuggestionOnCommitCharacter",
                "editor.quickSuggestions",
                "editor.suggestOnTriggerCharacters",
                "editor.tabCompletion",
                "editor.wordBasedSuggestions",
                "editor.parameterHints.enabled",
                "editor.inlineSuggest.enabled"
            ]
            
            var allMatched = true
            for key in expectedSettings {
                if !content.contains("\"\(key)\"") {
                    allMatched = false
                    break
                }
            }
            
            if allMatched {
                verifiedAtLeastOne = true
            }
        }
        
        return verifiedAtLeastOne
    }
    
    private func applyGhostSettings(to jsonString: String, isGitDiffMode: Bool = false) -> String {
        var result = jsonString
        
        var settingsToApply: [String: String] = [
            "editor.autoClosingBrackets": "\"never\"",
            "editor.autoClosingQuotes": "\"never\"",
            "editor.autoIndent": "\"none\"",
            "editor.formatOnType": "false",
            "editor.acceptSuggestionOnEnter": "\"off\"",
            "editor.acceptSuggestionOnCommitCharacter": "false",
            "editor.quickSuggestions": "{\"other\": \"off\", \"comments\": \"off\", \"strings\": \"off\"}",
            "editor.suggestOnTriggerCharacters": "false",
            "editor.tabCompletion": "\"off\"",
            "editor.wordBasedSuggestions": "\"off\"",
            "editor.parameterHints.enabled": "false",
            "editor.inlineSuggest.enabled": "false"
        ]
        
        if isGitDiffMode {
            settingsToApply["files.autoSave"] = "\"afterDelay\""
            settingsToApply["files.autoSaveDelay"] = "100"
            settingsToApply["dart.flutterHotReloadOnSave"] = "\"allIfDirty\""
            settingsToApply["editor.formatOnSave"] = "false"
            settingsToApply["dart.previewFlutterUiGuides"] = "true"
        }
        
        for (key, value) in settingsToApply {
            let pattern = "\"\(key)\"\\s*:\\s*(?:\\{[^}]*\\}|\\[[^\\]]*\\]|\"[^\"]*\"|[^,\\s}]+)"
            let newSetting = "\"\(key)\": \(value)"
            
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let mutable = NSMutableString(string: result)
                let fullRange = NSRange(result.startIndex..<result.endIndex, in: result)
                let matches = regex.matches(in: result, options: [], range: fullRange)
                
                if !matches.isEmpty {
                    // Replace in reverse order to preserve NSRange validity
                    for match in matches.reversed() {
                        mutable.replaceCharacters(in: match.range, with: newSetting)
                    }
                    result = mutable as String
                } else {
                    if let lastBraceIndex = result.lastIndex(of: "}") {
                        var insertIndex = lastBraceIndex
                        // Backtrack past any whitespace/newlines preceding }
                        while insertIndex > result.startIndex {
                            let prevIndex = result.index(before: insertIndex)
                            let char = result[prevIndex]
                            if char.isNewline || char.isWhitespace {
                                insertIndex = prevIndex
                            } else {
                                break
                            }
                        }
                        
                        let beforeInsertion = result[..<insertIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                        let separator = (beforeInsertion.hasSuffix(",") || beforeInsertion.hasSuffix("{") || beforeInsertion.isEmpty) ? "" : ","
                        let insertString = "\(separator)\n    \(newSetting)"
                        result.insert(contentsOf: insertString, at: insertIndex)
                    }
                }
            }
        }
        
        return result
    }
}
