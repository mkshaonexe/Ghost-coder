//
//  SourceFileSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SourceFileSection: View {
    @ObservedObject var state: GhostState
    @State private var isTargeted = false

    enum SourceMode: String, CaseIterable, Identifiable {
        case file = "File Mode"
        case git = "Git Diff Mode"
        var id: String { rawValue }
    }
    
    @State private var sourceTab: SourceMode = .file

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SOURCE")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white.opacity(0.6))
                
                Spacer()
                
                Picker("", selection: $sourceTab) {
                    ForEach(SourceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if sourceTab == .file {
                if state.isSourceLoaded {
                    loadedView
                } else {
                    dropZoneView
                }
            } else {
                gitView
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var gitView: some View {
        VStack(spacing: 12) {
            repoPathRow
            targetFileRow
            loadRepoRow
            
            if !state.gitCommits.isEmpty {
                commitsList
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var repoPathRow: some View {
        HStack {
            Text("Repo Path")
                .frame(width: 80, alignment: .leading)
            TextField("/path/to/flutter/project", text: $state.gitRepoPath)
                .textFieldStyle(.roundedBorder)
            Button("Browse") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    state.gitRepoPath = url.path
                }
            }
        }
    }

    private var targetFileRow: some View {
        HStack {
            Text("Target File")
                .frame(width: 80, alignment: .leading)
            TextField("lib/main.dart", text: $state.gitTargetFile)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var loadRepoRow: some View {
        HStack {
            Button("Load Git Repo") {
                do {
                    try state.loadGitRepo(repoPath: state.gitRepoPath, targetFile: state.gitTargetFile)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to load git repo"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.gitRepoPath.isEmpty || state.gitTargetFile.isEmpty)
            
            Spacer()
            
            if !state.gitCommits.isEmpty {
                Toggle("Enable Git Diff Mode", isOn: $state.isGitDiffModeEnabled)
                    .toggleStyle(.switch)
            }
        }
    }

    private var commitsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Commits Loaded (\(state.gitCommits.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<max(0, state.gitCommits.count - 1), id: \.self) { i in
                        commitRow(for: i)
                    }
                }
            }
            .frame(height: 150)
            .padding(8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }

    private func commitRow(for i: Int) -> some View {
        let isPast = i < state.gitCurrentStepIndex
        let isCurrent = i == state.gitCurrentStepIndex
        
        return HStack {
            Image(systemName: isPast ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                .foregroundStyle(isPast ? .green : (isCurrent ? .blue : .secondary))
            Text("Step \(i)→\(i+1): \(state.gitCommits[i+1].message)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isCurrent ? .primary : .secondary)
            Spacer()
            if !isCurrent && !isPast {
                Button("Jump") {
                    _ = state.jumpToGitStep(i)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isCurrent ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var dropZoneView: some View {
        Button(action: selectFile) {
            VStack(spacing: 14) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(isTargeted ? Color.cyan : Color.white.opacity(0.44))
                    .shadow(color: isTargeted ? Color.cyan.opacity(0.5) : Color.clear, radius: 8)
                    .scaleEffect(isTargeted ? 1.15 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)

                VStack(spacing: 6) {
                    Text("Drag & drop source file here")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("or click to browse files")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(.ultraThinMaterial)
            .background(isTargeted ? Color.cyan.opacity(0.05) : Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.cyan : Color.white.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .shadow(color: isTargeted ? Color.cyan.opacity(0.15) : Color.clear, radius: 12)
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        loadFile(url: url)
                    } else if let nsURL = item as? NSURL {
                        loadFile(url: nsURL as URL)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        loadFile(url: url)
                    }
                }
            }
            return true
        }
    }

    private var loadedView: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(state.sourceFileName)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                
                HStack(spacing: 12) {
                    Label("\(state.sourceCode.count) chars", systemImage: "character")
                    Label("\(lineCount) lines", systemImage: "line.horizontal.3")
                }
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.66))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: selectFile) {
                    Image(systemName: "pencil")
                        .help("Change File")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    withAnimation {
                        state.reset()
                        state.updateCachedActiveState()
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                        .help("Reset Typing Pointer")
                }
                .buttonStyle(.bordered)
                .disabled(state.currentIndex == 0)

                Button(role: .destructive, action: {
                    withAnimation {
                        state.clearSourceFile()
                    }
                }) {
                    Image(systemName: "trash")
                        .help("Remove Loaded File")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var lineCount: Int {
        state.sourceCode.components(separatedBy: .newlines).count
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    private func loadFile(url: URL) {
        do {
            try state.loadSourceFile(url: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to load file"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}

#Preview {
    let state = GhostState()
    SourceFileSection(state: state)
        .padding()
}
