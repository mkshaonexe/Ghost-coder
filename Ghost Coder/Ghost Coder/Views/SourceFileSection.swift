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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE FILE")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.white.opacity(0.6))

            if state.isSourceLoaded {
                loadedView
            } else {
                dropZoneView
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dropZoneView: some View {
        Button(action: selectFile) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    .scaleEffect(isTargeted ? 1.1 : 1.0)
                    .animation(.spring(), value: isTargeted)

                VStack(spacing: 4) {
                    Text("Drag & drop source file here")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("or click to browse files")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.cyan : Color.white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
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
                .foregroundStyle(.accentColor)
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
