//
//  TargetSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct TargetSection: View {
    @ObservedObject var state: GhostState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVATION SCOPE")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.white.opacity(0.6))

            VStack(spacing: 12) {
                HStack {
                    Text("Target IDE")
                        .font(.body)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Picker("", selection: $state.ideTarget) {
                        ForEach(IDETarget.allCases) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .labelsHidden()
                    .onChange(of: state.ideTarget) { _ in
                        state.updateCachedActiveState()
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Workspace Folder Path")
                            .font(.body)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.58))
                    }
                    
                    HStack(spacing: 8) {
                        TextField("e.g. /Users/username/projects/my-app", text: $state.workspaceFolderPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: state.workspaceFolderPath) { _ in
                                state.updateCachedActiveState()
                            }
                        
                        Button(action: selectFolder) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .help("Select Workspace Folder")
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: state.isFolderScopeActive ? "scope" : "exclamationmark.triangle.fill")
                        .foregroundStyle(state.isFolderScopeActive ? Color.green : Color.orange)
                    Text(scopeStatusText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
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
    }

    private var scopeStatusText: String {
        if state.workspaceFolderPath.isEmpty {
            return "No folder filter applied. Ghost Mode can operate in any matching target window."
        }
        if state.isFolderScopeActive {
            return "Workspace filter matches the current window."
        }
        return "The frontmost window title does not match the selected workspace folder."
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            state.workspaceFolderPath = url.path
            state.updateCachedActiveState()
        }
    }
}

#Preview {
    let state = GhostState()
    TargetSection(state: state)
        .padding()
}
