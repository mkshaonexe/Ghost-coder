//
//  CLIServer.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import Foundation
import Network

@available(macOS 10.14, *)
class CLIServer {
    private var listener: NWListener?
    private let state: GhostState
    private let port: UInt16 = 52934
    
    init(state: GhostState) {
        self.state = state
    }
    
    func start() {
        do {
            let parameters = NWParameters.tcp
            // Restrict listener to loopback interface for local host security
            parameters.requiredInterfaceType = .loopback
            
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let listener = try NWListener(using: parameters, on: nwPort)
            self.listener = listener
            
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.state.log("CLI Server started on port \(self?.port ?? 52934)")
                case .failed(let error):
                    self?.state.log("CLI Server failed to start: \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener.start(queue: DispatchQueue.global(qos: .userInitiated))
        } catch {
            state.log("CLI Server failed to initialize: \(error.localizedDescription)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        readCommand(from: connection)
    }
    
    private func readCommand(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            
            if let data = content, !data.isEmpty, let commandString = String(data: data, encoding: .utf8) {
                let cleaned = commandString.trimmingCharacters(in: .whitespacesAndNewlines)
                self.processCommand(cleaned, connection: connection)
            } else if isComplete {
                connection.cancel()
            } else {
                self.readCommand(from: connection)
            }
        }
    }
    
    private func processCommand(_ command: String, connection: NWConnection) {
        let parts = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let action = parts.first?.lowercased() else {
            sendResponse("Error: empty command", to: connection)
            return
        }
        
        let argument = parts.count > 1 ? String(parts[1]) : ""
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let response = self.executeAction(action, argument: argument)
            self.sendResponse(response, to: connection)
        }
    }
    
    private func executeAction(_ action: String, argument: String) -> String {
        switch action {
        case "status":
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            struct StatusPayload: Codable {
                let statusLabel: String
                let statusDetail: String
                let isGhostModeEnabled: Bool
                let isIDEFocused: Bool
                let isFolderScopeActive: Bool
                let isAccessibilityGranted: Bool
                let isInputMonitoringGranted: Bool
                let enableAutoCloseSkip: Bool
                let sourceFileName: String
                let sourceLength: Int
                let currentIndex: Int
                let progress: Double
                let ideTarget: String
                let inputMode: String
                let speedMs: Int
                let workspacePath: String
            }
            
            let payload = StatusPayload(
                statusLabel: state.statusLabel,
                statusDetail: state.statusDetail,
                isGhostModeEnabled: state.isGhostModeEnabled,
                isIDEFocused: state.isIDEFocused,
                isFolderScopeActive: state.isFolderScopeActive,
                isAccessibilityGranted: state.isAccessibilityGranted,
                isInputMonitoringGranted: state.isInputMonitoringGranted,
                enableAutoCloseSkip: state.enableAutoCloseSkip,
                sourceFileName: state.sourceFileName,
                sourceLength: state.sourceCode.count,
                currentIndex: state.currentIndex,
                progress: state.progress,
                ideTarget: state.ideTarget.rawValue,
                inputMode: state.inputMode.rawValue,
                speedMs: state.injectionDelayMs,
                workspacePath: state.workspaceFolderPath
            )
            
            if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
                return json
            }
            return "Error: failed to encode status"
            
        case "start", "activate":
            if !state.isSourceLoaded {
                return "Error: no source file loaded"
            }
            state.isGhostModeEnabled = true
            state.updateCachedActiveState()
            return "Success: Ghost Mode activated"
            
        case "pause", "deactivate":
            state.isGhostModeEnabled = false
            state.updateCachedActiveState()
            return "Success: Ghost Mode paused"
            
        case "toggle":
            if !state.isSourceLoaded {
                return "Error: no source file loaded"
            }
            state.isGhostModeEnabled.toggle()
            state.updateCachedActiveState()
            return "Success: Ghost Mode is now \(state.isGhostModeEnabled ? "enabled" : "disabled")"
            
        case "set-source":
            let path = argument.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                return "Error: path is required"
            }
            let url = URL(fileURLWithPath: path)
            do {
                try state.loadSourceFile(url: url)
                return "Success: Loaded source file: \(state.sourceFileName)"
            } catch {
                return "Error: \(error.localizedDescription)"
            }
            
        case "clear-source":
            state.clearSourceFile()
            return "Success: Source file cleared"
            
        case "set-target":
            let targetName = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if targetName == "vscode" || targetName == "vs code" {
                state.ideTarget = .vsCode
                return "Success: Target set to VS Code"
            } else if targetName == "vscode-insiders" || targetName == "vs code insiders" {
                state.ideTarget = .vsCodeInsiders
                return "Success: Target set to VS Code Insiders"
            } else if targetName == "xcode" {
                state.ideTarget = .xcode
                return "Success: Target set to Xcode"
            } else if targetName == "any" || targetName == "any application" {
                state.ideTarget = .any
                return "Success: Target set to Any Application"
            } else {
                return "Error: Unknown target '\(argument)'. Available: vscode, vscode-insiders, xcode, any"
            }
            
        case "set-mode":
            if state.isGhostModeEnabled {
                return "Error: Cannot change input mode while Ghost Mode is active"
            }
            let modeName = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if modeName == "character" || modeName == "char" {
                state.inputMode = .character
                return "Success: Mode set to Character"
            } else if modeName == "word" {
                state.inputMode = .word
                return "Success: Mode set to Word"
            } else if modeName == "line" {
                state.inputMode = .line
                return "Success: Mode set to Line"
            } else {
                return "Error: Unknown mode '\(argument)'. Available: character, word, line"
            }
            
        case "set-speed":
            guard let delay = Int(argument.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return "Error: delay must be an integer (in ms)"
            }
            state.injectionDelayMs = delay
            return "Success: Speed set to \(delay) ms"
            
        case "set-workspace":
            let path = argument.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.lowercased() == "clear" || path.isEmpty {
                state.workspaceFolderPath = ""
                return "Success: Workspace path cleared"
            } else {
                state.workspaceFolderPath = path
                return "Success: Workspace path set to: \(path)"
            }
            
        case "enable-autoclose-skip":
            let value = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if value == "true" || value == "1" || value == "yes" || value == "on" {
                state.enableAutoCloseSkip = true
                return "Success: Auto-close skip enabled"
            } else if value == "false" || value == "0" || value == "no" || value == "off" {
                state.enableAutoCloseSkip = false
                return "Success: Auto-close skip disabled"
            } else {
                return "Error: value must be true or false"
            }
            
        case "reset":
            state.reset()
            return "Success: Progress pointer reset to 0"
            
        case "logs":
            let logs = state.diagnosticLogs.reversed().joined(separator: "\n")
            return logs.isEmpty ? "No logs" : logs
            
        case "clear-logs":
            state.diagnosticLogs.removeAll()
            state.log("Logs cleared via CLI")
            return "Success: Logs cleared"

        case "git-diff-load":
            let args = argument.components(separatedBy: " ")
            guard args.count >= 2 else {
                return "Error: expected repoPath and targetFile"
            }
            let repoPath = args[0]
            let targetFile = args.dropFirst().joined(separator: " ")
            do {
                try state.loadGitRepo(repoPath: repoPath, targetFile: targetFile)
                return "Success: Loaded git repo with \(state.gitCommits.count) commits."
            } catch {
                return "Error: \(error.localizedDescription)"
            }
            
        case "git-diff-status":
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            struct GitDiffStatus: Codable {
                let isEnabled: Bool
                let repoPath: String
                let targetFile: String
                let commitsCount: Int
                let currentStep: Int
                let totalSteps: Int
            }
            let status = GitDiffStatus(
                isEnabled: state.isGitDiffModeEnabled,
                repoPath: state.gitRepoPath,
                targetFile: state.gitTargetFile,
                commitsCount: state.gitCommits.count,
                currentStep: state.gitCurrentStepIndex,
                totalSteps: state.gitDiffStepCount
            )
            if let data = try? encoder.encode(status), let json = String(data: data, encoding: .utf8) {
                return json
            }
            return "Error encoding git diff status"
            
        case "git-diff-enable":
            if state.gitCommits.isEmpty {
                return "Error: No git repo loaded"
            }
            state.isGitDiffModeEnabled = true
            return "Success: Git Diff Mode enabled"
            
        case "git-diff-disable":
            state.isGitDiffModeEnabled = false
            return "Success: Git Diff Mode disabled"
            
        case "git-diff-reset":
            state.resetGitDiffMode()
            return "Success: Git Diff Mode reset"
            
        case "git-diff-step":
            guard let step = Int(argument.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return "Error: step index must be an integer"
            }
            if state.jumpToGitStep(step) {
                return "Success: Jumped to step \(step)"
            } else {
                return "Error: Invalid step index"
            }

        default:
            return "Error: Unknown action '\(action)'"
        }
    }
    
    private func sendResponse(_ response: String, to connection: NWConnection) {
        let data = (response + "\n").data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
