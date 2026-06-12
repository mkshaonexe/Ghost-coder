//
//  cli.swift
//  Ghost Coder CLI Client
//
//  Created by AI on 12/6/26.
//

import Foundation
import Network

let VERSION = "1.3.1"
let PORT: UInt16 = 52934

// ANSI Color codes for premium terminal formatting
struct ANSI {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let red = "\u{001B}[0;31m"
    static let green = "\u{001B}[0;32m"
    static let yellow = "\u{001B}[0;33m"
    static let blue = "\u{001B}[0;34m"
    static let magenta = "\u{001B}[0;35m"
    static let cyan = "\u{001B}[0;36m"
    static let gray = "\u{001B}[0;90m"
}

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

func printHelp() {
    print("""
\(ANSI.bold)👻 GHOST CODER CLI v\(VERSION) 👻\(ANSI.reset)
A premium terminal client for controlling and querying Ghost Coder.

\(ANSI.bold)USAGE:\(ANSI.reset)
  ghost-coder <command> [arguments]

\(ANSI.bold)COMMANDS:\(ANSI.reset)
  \(ANSI.green)status\(ANSI.reset)                      Display the application status dashboard
  \(ANSI.green)status --json\(ANSI.reset)               Display raw status payload in JSON format
  \(ANSI.green)start / activate\(ANSI.reset)           Arm and activate Ghost Mode
  \(ANSI.green)pause / deactivate\(ANSI.reset)         Pause Ghost Mode
  \(ANSI.green)toggle\(ANSI.reset)                     Toggle Ghost Mode
  \(ANSI.green)set-source <file_path>\(ANSI.reset)     Load a source file (resolves relative paths)
  \(ANSI.green)clear-source\(ANSI.reset)               Clear the loaded source file
  \(ANSI.green)set-target <target>\(ANSI.reset)        Set target IDE (vscode, vscode-insiders, xcode, any)
  \(ANSI.green)set-mode <mode>\(ANSI.reset)            Set input mode (character, word, line)
  \(ANSI.green)set-speed <ms>\(ANSI.reset)            Set typing delay in milliseconds
  \(ANSI.green)set-workspace <dir_path>\(ANSI.reset)   Set workspace folder scope restriction (or 'clear')
  \(ANSI.green)enable-autoclose-skip <t|f>\(ANSI.reset) Enable/disable auto-close skip buffer
  \(ANSI.green)reset\(ANSI.reset)                      Reset typing progress to 0
  \(ANSI.green)logs\(ANSI.reset)                       Print diagnostic and system logs
  \(ANSI.green)clear-logs\(ANSI.reset)                 Clear diagnostic logs
  \(ANSI.green)help / --help / -h\(ANSI.reset)         Show this help information

\(ANSI.bold)EXAMPLES:\(ANSI.reset)
  ghost-coder set-source ./main.dart
  ghost-coder set-speed 15
  ghost-coder start
  ghost-coder status
""")
}

func launchApp() {
    print("\(ANSI.yellow)Ghost Coder application is not running. Launching in background...\(ANSI.reset)")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", "-a", "Ghost Coder"]
    try? process.run()
    process.waitUntilExit()
    // Wait for socket server to start
    Thread.sleep(forTimeInterval: 1.5)
}

func renderProgressBar(progress: Double, width: Int = 30) -> String {
    let completedCount = Int(progress * Double(width))
    let remainingCount = max(0, width - completedCount)
    let completedStr = String(repeating: "█", count: completedCount)
    let remainingStr = String(repeating: "░", count: remainingCount)
    return "[\(ANSI.cyan)\(completedStr)\(ANSI.gray)\(remainingStr)\(ANSI.reset)]"
}

func displayPrettyStatus(_ payload: StatusPayload) {
    let statusColor: String
    switch payload.statusLabel.lowercased() {
    case let s where s.contains("active"):
        statusColor = ANSI.green
    case let s where s.contains("paused"):
        statusColor = ANSI.yellow
    case let s where s.contains("completed"):
        statusColor = ANSI.cyan
    default:
        statusColor = ANSI.red
    }
    
    let sourceFileStr = payload.sourceFileName.isEmpty ? "\(ANSI.red)No source file loaded\(ANSI.reset)" : "\(ANSI.green)\(payload.sourceFileName)\(ANSI.reset) (\(payload.sourceLength) chars)"
    let workspaceStr = payload.workspacePath.isEmpty ? "None (Any directory)" : payload.workspacePath
    
    let progressPercent = String(format: "%.1f%%", payload.progress * 100)
    let progressStr = "\(payload.currentIndex) / \(payload.sourceLength) chars (\(progressPercent))"
    
    print("""
\(ANSI.bold)👻 GHOST CODER STATUS 👻\(ANSI.reset)
======================================================
\(ANSI.bold)Status:\(ANSI.reset)         \(statusColor)\(payload.statusLabel)\(ANSI.reset)
\(ANSI.bold)Source File:\(ANSI.reset)    \(sourceFileStr)
\(ANSI.bold)Target IDE:\(ANSI.reset)     \(ANSI.magenta)\(payload.ideTarget)\(ANSI.reset)
\(ANSI.bold)Input Mode:\(ANSI.reset)     \(ANSI.magenta)\(payload.inputMode)\(ANSI.reset)
\(ANSI.bold)Typing Speed:\(ANSI.reset)   \(ANSI.magenta)\(payload.speedMs) ms/char\(ANSI.reset)
\(ANSI.bold)Auto-Close:\(ANSI.reset)     \(payload.enableAutoCloseSkip ? "\(ANSI.green)Enabled\(ANSI.reset)" : "\(ANSI.red)Disabled\(ANSI.reset)")
\(ANSI.bold)Workspace:\(ANSI.reset)      \(workspaceStr)
\(ANSI.bold)Progress:\(ANSI.reset)       \(renderProgressBar(progress: payload.progress)) \(progressStr)
------------------------------------------------------
\(ANSI.bold)Accessibility API:\(ANSI.reset)  \(payload.isAccessibilityGranted ? "\(ANSI.green)Granted\(ANSI.reset)" : "\(ANSI.red)Denied\(ANSI.reset)")
\(ANSI.bold)Input Monitoring:\(ANSI.reset)   \(payload.isInputMonitoringGranted ? "\(ANSI.green)Granted\(ANSI.reset)" : "\(ANSI.red)Denied\(ANSI.reset)")
\(ANSI.bold)IDE Focus:\(ANSI.reset)          \(payload.isIDEFocused ? "\(ANSI.green)Focused\(ANSI.reset)" : "\(ANSI.yellow)Unfocused\(ANSI.reset)")
\(ANSI.bold)Workspace Match:\(ANSI.reset)    \(payload.isFolderScopeActive ? "\(ANSI.green)Matched\(ANSI.reset)" : "\(ANSI.red)Mismatch / Inactive\(ANSI.reset)")
======================================================
\(ANSI.gray)\(payload.statusDetail)\(ANSI.reset)
""")
}

func sendCommand(_ command: String, isStatusJson: Bool = false) -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    var responseData = Data()
    
    let connection = NWConnection(
        host: NWEndpoint.Host("127.0.0.1"),
        port: NWEndpoint.Port(rawValue: PORT)!,
        using: .tcp
    )
    
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            // Send command
            let data = (command + "\n").data(using: .utf8)!
            connection.send(content: data, completion: .contentProcessed { error in
                if error != nil {
                    semaphore.signal()
                }
            })
            
            // Start reading response
            readResponse(connection: connection)
        case .failed:
            semaphore.signal()
        default:
            break
        }
    }
    
    func readResponse(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                responseData.append(data)
            }
            if isComplete || error != nil {
                success = error == nil
                semaphore.signal()
            } else {
                readResponse(connection: connection)
            }
        }
    }
    
    connection.start(queue: DispatchQueue.global())
    
    // Wait up to 3 seconds for TCP operation to complete
    let result = semaphore.wait(timeout: .now() + 3.0)
    
    if result == .timedOut {
        connection.cancel()
        return false
    }
    
    if success, !responseData.isEmpty {
        if let responseString = String(data: responseData, encoding: .utf8) {
            let cleaned = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if command == "status" {
                if isStatusJson {
                    print(cleaned)
                } else if let data = cleaned.data(using: .utf8),
                          let payload = try? JSONDecoder().decode(StatusPayload.self, from: data) {
                    displayPrettyStatus(payload)
                } else {
                    print(cleaned)
                }
            } else {
                // For other commands (logs, clear, set-speed, etc)
                if cleaned.hasPrefix("Success:") {
                    print("\(ANSI.green)\(cleaned)\(ANSI.reset)")
                } else if cleaned.hasPrefix("Error:") {
                    print("\(ANSI.red)\(cleaned)\(ANSI.reset)")
                } else {
                    print(cleaned)
                }
            }
        }
        return true
    }
    
    return false
}

// Parse command line arguments
let args = CommandLine.arguments
guard args.count > 1 else {
    printHelp()
    exit(0)
}

let primaryArg = args[1].lowercased()

if primaryArg == "help" || primaryArg == "--help" || primaryArg == "-h" {
    printHelp()
    exit(0)
}

// Format command string
var cmd = ""
var isJson = false

switch primaryArg {
case "status":
    cmd = "status"
    if args.count > 2 && args[2] == "--json" {
        isJson = true
    }
case "start", "activate":
    cmd = "start"
case "pause", "deactivate":
    cmd = "pause"
case "toggle":
    cmd = "toggle"
case "clear-source":
    cmd = "clear-source"
case "reset":
    cmd = "reset"
case "logs":
    cmd = "logs"
case "clear-logs":
    cmd = "clear-logs"
case "set-source":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: File path is required for set-source.\(ANSI.reset)")
        exit(1)
    }
    let resolvedPath = URL(fileURLWithPath: args[2]).path
    cmd = "set-source \(resolvedPath)"
case "set-target":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: Target is required for set-target.\(ANSI.reset)")
        exit(1)
    }
    cmd = "set-target \(args[2])"
case "set-mode":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: Mode is required for set-mode.\(ANSI.reset)")
        exit(1)
    }
    cmd = "set-mode \(args[2])"
case "set-speed":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: Speed value (in ms) is required for set-speed.\(ANSI.reset)")
        exit(1)
    }
    cmd = "set-speed \(args[2])"
case "set-workspace":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: Workspace path is required for set-workspace.\(ANSI.reset)")
        exit(1)
    }
    let argValue = args[2]
    if argValue.lowercased() == "clear" {
        cmd = "set-workspace clear"
    } else {
        let resolvedPath = URL(fileURLWithPath: argValue).path
        cmd = "set-workspace \(resolvedPath)"
    }
case "enable-autoclose-skip":
    guard args.count > 2 else {
        print("\(ANSI.red)Error: true/false value is required.\(ANSI.reset)")
        exit(1)
    }
    cmd = "enable-autoclose-skip \(args[2])"
default:
    print("\(ANSI.red)Error: Unknown command '\(args[1])'. Run 'ghost-coder help' for usage.\(ANSI.reset)")
    exit(1)
}

// Send command. If it fails, attempt to start the app and retry.
if !sendCommand(cmd, isStatusJson: isJson) {
    launchApp()
    if !sendCommand(cmd, isStatusJson: isJson) {
        print("\(ANSI.red)Error: Could not connect to Ghost Coder app after launching. Please make sure the app has been built and is installed.\(ANSI.reset)")
        exit(1)
    }
}
