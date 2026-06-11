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
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // IDE Target Selector
                HStack {
                    Text("Target IDE")
                        .font(.body)
                        .foregroundColor(.primary)
                    
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
                
                // Workspace Folder Constraint
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Workspace Folder Path")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
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
