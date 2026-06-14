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
    
    private func getSettingsURLs(workspaceFolderPath: String?) -> [URL] {
        var urls: [URL] = []
        
        // 1. Workspace settings (if workspace folder is specified)
        if let wsPath = workspaceFolderPath, !wsPath.isEmpty {
            let wsURL = URL(fileURLWithPath: wsPath)
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
    
    func backupAndApplySettings(workspaceFolderPath: String?, logHandler: ((String) -> Void)? = nil) {
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
            let modified = applyGhostSettings(to: content)
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
                "editor.acceptSuggestionOnCommitCharacter"
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
    
    private func applyGhostSettings(to jsonString: String) -> String {
        var result = jsonString
        
        let settingsToApply: [String: String] = [
            "editor.autoClosingBrackets": "\"never\"",
            "editor.autoClosingQuotes": "\"never\"",
            "editor.autoIndent": "\"none\"",
            "editor.formatOnType": "false",
            "editor.acceptSuggestionOnEnter": "\"off\"",
            "editor.acceptSuggestionOnCommitCharacter": "false"
        ]
        
        for (key, value) in settingsToApply {
            let pattern = "\"\(key)\"\\s*:\\s*[^,\\s}]+"
            let newSetting = "\"\(key)\": \(value)"
            
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: result, options: [], range: range)
                if !matches.isEmpty {
                    result = result.replacingOccurrences(of: pattern, with: newSetting, options: .regularExpression)
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
