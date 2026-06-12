//
//  ResponseLogger.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import Foundation
import CoreGraphics

nonisolated struct PhysicalKeyInfo: Encodable, Sendable {
    let keycode: Int
    let char: String
    let hex: String
    let modifiers: [String]
}

nonisolated struct VirtualOutputInfo: Encodable, Sendable {
    let char: String
    let hex: String
    let display: String
}

nonisolated struct KeystrokeEvent: Encodable, Sendable {
    let type = "keystroke_event"
    let seq: Int
    let timestamp: String
    let physicalKey: PhysicalKeyInfo
    let virtualOutput: VirtualOutputInfo
    let chunkSize: Int
    let mode: String
}

nonisolated struct SessionMetadata: Encodable, Sendable {
    let type = "session_metadata"
    let sessionId: String
    let startedAt: String
    let sourceFile: String
    let ideTarget: String
    let inputMode: String
    let appVersion: String
}

class ResponseLogger {
    private let sessionId: String
    private let responseLogURL: URL
    private let diagnosticLogURL: URL
    private let logQueue = DispatchQueue(label: "com.ghostcoder.logging", qos: .background)
    private var eventSequence = 0
    private let sequenceLock = NSLock()
    private let state: GhostState
    
    init(state: GhostState) {
        self.state = state
        self.sessionId = state.sessionId
        
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let logsDirectory = homeDirectory.appendingPathComponent(".ghostcoder/logs/session_logs", isDirectory: true)
        
        // Ensure logs directory exists
        do {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("ResponseLogger: Failed to create logs directory: \(error)")
        }
        
        self.responseLogURL = logsDirectory.appendingPathComponent("session_\(sessionId)_response.jsonl")
        self.diagnosticLogURL = logsDirectory.appendingPathComponent("session_\(sessionId)_diagnostic.log")
    }
    
    func startSession(sourceFile: String, ideTarget: String, inputMode: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get App version
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.5"
            
            let metadata = SessionMetadata(
                sessionId: self.sessionId,
                startedAt: self.getISO8601Timestamp(),
                sourceFile: sourceFile.isEmpty ? "none" : sourceFile,
                ideTarget: ideTarget,
                inputMode: inputMode.lowercased(),
                appVersion: version
            )
            
            self.writeLine(metadata)
        }
    }
    
    func logKeystrokeEvent(physicalKeyCode: Int, physicalFlags: CGEventFlags, physicalChar: String?, injectedChunk: String, mode: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let seq = self.nextSequence()
            
            // Map physical key
            let pChar: String
            let pHex: String
            if let p = physicalChar, !p.isEmpty {
                let mapped = self.encodeChar(p.first!)
                pChar = mapped.display
                pHex = mapped.hex
            } else {
                pChar = ""
                pHex = ""
            }
            
            let modifiers = self.parseCGEventFlags(physicalFlags)
            let physicalKey = PhysicalKeyInfo(
                keycode: physicalKeyCode,
                char: pChar,
                hex: pHex,
                modifiers: modifiers
            )
            
            // Map virtual output
            let virtualOutput: VirtualOutputInfo
            if injectedChunk.isEmpty {
                virtualOutput = VirtualOutputInfo(char: "", hex: "", display: "")
            } else if injectedChunk.count == 1 {
                let mapped = self.encodeChar(injectedChunk.first!)
                virtualOutput = VirtualOutputInfo(char: String(injectedChunk.first!), hex: mapped.hex, display: mapped.display)
            } else {
                var charsList: [String] = []
                var hexList: [String] = []
                var displayList: [String] = []
                for char in injectedChunk {
                    let mapped = self.encodeChar(char)
                    charsList.append(String(char))
                    hexList.append(mapped.hex)
                    displayList.append(mapped.display)
                }
                virtualOutput = VirtualOutputInfo(
                    char: injectedChunk,
                    hex: hexList.joined(separator: " "),
                    display: displayList.joined(separator: "")
                )
            }
            
            let event = KeystrokeEvent(
                seq: seq,
                timestamp: self.getISO8601Timestamp(),
                physicalKey: physicalKey,
                virtualOutput: virtualOutput,
                chunkSize: injectedChunk.count,
                mode: mode.lowercased()
            )
            
            self.writeLine(event)
        }
    }
    
    func logDiagnosticMessage(_ message: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = Data("\(message)\n".utf8)
                if FileManager.default.fileExists(atPath: self.diagnosticLogURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.diagnosticLogURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try data.write(to: self.diagnosticLogURL)
                }
            } catch {
                print("ResponseLogger: Error writing diagnostic log: \(error)")
            }
        }
    }
    
    func endSession() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            print("ResponseLogger: Session ended \(self.sessionId)")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            let logMsg = "[\(timestamp)] [SESSION END] Session ended \(self.sessionId)"
            do {
                let data = Data("\(logMsg)\n".utf8)
                if FileManager.default.fileExists(atPath: self.diagnosticLogURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.diagnosticLogURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try data.write(to: self.diagnosticLogURL)
                }
            } catch {
                print("ResponseLogger: Error writing diagnostic log at session end: \(error)")
            }
        }
    }
    
    private func nextSequence() -> Int {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        eventSequence += 1
        return eventSequence
    }
    
    private func writeLine<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            var data = try encoder.encode(object)
            data.append(Data("\n".utf8))
            
            if FileManager.default.fileExists(atPath: responseLogURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: responseLogURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try data.write(to: responseLogURL)
            }
        } catch {
            print("ResponseLogger: Error encoding or writing JSONL line: \(error)")
        }
    }
    
    private func getISO8601Timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.string(from: Date())
    }
    
    private func encodeChar(_ char: Character) -> (display: String, hex: String) {
        if char == " " {
            return ("[SP]", "0x20")
        } else if char == "\n" {
            return ("[LF]", "0x0A")
        } else if char == "\r" {
            return ("[CR]", "0x0D")
        } else if char == "\t" {
            return ("[TAB]", "0x09")
        } else if char == "/" {
            return ("/", "0x2F")
        } else if char == "\\" {
            return ("\\", "0x5C")
        }
        
        // Printable ASCII
        if let ascii = char.asciiValue, ascii >= 32 && ascii <= 126 {
            return (String(char), String(format: "0x%02X", ascii))
        }
        
        // Non-printable or Unicode
        let utf16 = char.utf16
        if let first = utf16.first {
            return (String(format: "[U+%04X]", first), String(format: "0x%04X", first))
        }
        
        return (String(char), "")
    }
    
    private func parseCGEventFlags(_ flags: CGEventFlags) -> [String] {
        var modifiers: [String] = []
        if flags.contains(.maskShift) {
            modifiers.append("shift")
        }
        if flags.contains(.maskCommand) {
            modifiers.append("cmd")
        }
        if flags.contains(.maskAlternate) {
            modifiers.append("opt")
        }
        if flags.contains(.maskControl) {
            modifiers.append("ctrl")
        }
        if flags.contains(.maskSecondaryFn) {
            modifiers.append("fn")
        }
        if flags.contains(.maskAlphaShift) {
            modifiers.append("capslock")
        }
        return modifiers
    }
}
