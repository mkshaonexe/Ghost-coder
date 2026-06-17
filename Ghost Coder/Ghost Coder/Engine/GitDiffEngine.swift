//
//  GitDiffEngine.swift
//  Ghost Coder
//
//  Created by AI on 17/6/26.
//

import Foundation

class GitDiffEngine {
    private var repoPath: String = ""
    private var targetFile: String = ""
    private var commits: [GitCommit] = []
    
    // Step state
    private var currentStepIndex: Int = 0
    private var targetCommitContent: String = ""
    private var addedLineIndices: Set<Int> = []
    private var addedLinesList: [String] = []
    private var addedLinesString: String = ""
    
    init() {}
    
    // Helper to run git command
    private func runGit(_ args: [String]) -> String {
        guard !repoPath.isEmpty else { return "" }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output
            }
        } catch {
            print("GitDiffEngine: failed to run git \(args.joined(separator: " ")): \(error.localizedDescription)")
        }
        return ""
    }
    
    // Load git commits for the target file
    func loadRepo(repoPath: String, targetFile: String) throws -> [GitCommit] {
        self.repoPath = repoPath
        self.targetFile = targetFile
        
        let relativePath = getRelativePath(of: targetFile, in: repoPath)
        let logOutput = runGit(["log", "--oneline", "--reverse", "--", relativePath])
        
        var loadedCommits: [GitCommit] = []
        let lines = logOutput.components(separatedBy: .newlines)
        var idx = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count >= 1 {
                let hash = String(parts[0])
                let message = parts.count > 1 ? String(parts[1]) : "Commit \(hash)"
                loadedCommits.append(GitCommit(id: hash, message: message, index: idx))
                idx += 1
            }
        }
        
        self.commits = loadedCommits
        return loadedCommits
    }
    
    private func getRelativePath(of file: String, in repo: String) -> String {
        let filePath = URL(fileURLWithPath: file).path
        let repoPath = URL(fileURLWithPath: repo).path
        
        if filePath.hasPrefix(repoPath) {
            var rel = filePath.replacingOccurrences(of: repoPath, with: "")
            if rel.hasPrefix("/") {
                rel.removeFirst()
            }
            return rel
        }
        return file
    }
    
    // Fetch file content at specific commit
    func getFileContent(at commit: GitCommit, file: String) -> String {
        let relativePath = getRelativePath(of: file, in: repoPath)
        return runGit(["show", "\(commit.id):\(relativePath)"])
    }
    
    // Set up the state for the current step (transition from index to index + 1)
    func setupStep(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0, toIndex < commits.count else { return }
        let fromCommit = commits[fromIndex]
        let toCommit = commits[toIndex]
        
        let relativePath = getRelativePath(of: targetFile, in: repoPath)
        let diffOutput = runGit(["diff", fromCommit.id, toCommit.id, "--", relativePath])
        
        targetCommitContent = getFileContent(at: toCommit, file: targetFile)
        
        // Parse line numbers that were added in the target commit
        addedLineIndices = parseAddedLineNumbers(from: diffOutput)
        
        // Split target content and build the added lines lists
        let allLines = targetCommitContent.components(separatedBy: "\n")
        addedLinesList.removeAll()
        
        for (index, line) in allLines.enumerated() {
            let lineNumber = index + 1
            if addedLineIndices.contains(lineNumber) {
                addedLinesList.append(line)
            }
        }
        
        addedLinesString = addedLinesList.joined(separator: "\n")
        currentStepIndex = fromIndex
    }
    
    // Get the added lines to type
    func getAddedLinesString() -> String {
        return addedLinesString
    }
    
    // Get the base state (the target commit content with all added lines removed)
    func getBaseStateString() -> String {
        let allLines = targetCommitContent.components(separatedBy: "\n")
        var baseLines: [String] = []
        
        for (index, line) in allLines.enumerated() {
            let lineNumber = index + 1
            if !addedLineIndices.contains(lineNumber) {
                baseLines.append(line)
            }
        }
        
        return baseLines.joined(separator: "\n")
    }
    
    // Get the exact final target commit content
    func getFinalStateString() -> String {
        return targetCommitContent
    }
    
    // Construct the partial file content based on character typing progress
    func getPartialFileContent(typedCharCount: Int) -> String {
        let prefixText = String(addedLinesString.prefix(typedCharCount))
        let prefixLines = prefixText.components(separatedBy: "\n")
        
        let allLines = targetCommitContent.components(separatedBy: "\n")
        var resultLines: [String] = []
        var addedLineIndex = 0
        
        for (index, line) in allLines.enumerated() {
            let lineNumber = index + 1
            if addedLineIndices.contains(lineNumber) {
                if addedLineIndex < prefixLines.count {
                    resultLines.append(prefixLines[addedLineIndex])
                }
                addedLineIndex += 1
            } else {
                resultLines.append(line)
            }
        }
        
        return resultLines.joined(separator: "\n")
    }
    
    // Helper to parse line numbers that are added (+) in new file
    private func parseAddedLineNumbers(from diffOutput: String) -> Set<Int> {
        var addedLines = Set<Int>()
        let lines = diffOutput.components(separatedBy: "\n")
        
        var newLineIndex = 0
        
        for line in lines {
            if line.hasPrefix("@@ ") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    let newPart = parts[2]
                    if newPart.hasPrefix("+") {
                        let cleanNewPart = newPart.dropFirst()
                        let subParts = cleanNewPart.components(separatedBy: ",")
                        if let start = Int(subParts[0]) {
                            newLineIndex = start
                        }
                    }
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                addedLines.insert(newLineIndex)
                newLineIndex += 1
            } else if line.hasPrefix(" ") {
                newLineIndex += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                // deleted line, doesn't increment newLineIndex
            }
        }
        
        return addedLines
    }
}
