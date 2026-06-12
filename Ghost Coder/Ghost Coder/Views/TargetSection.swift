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

                Divider()

                // Live Monitor Dashboard
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIVE MONITOR (DUAL-MONITOR DASHBOARD)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))

                    HStack(spacing: 8) {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(state.isIDEFocused ? Color.green : Color.orange)
                        Text("Active App:")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(state.frontmostAppName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(state.isIDEFocused ? "🟢 TARGET MATCHED" : "🔴 TARGET FOCUS NEEDED")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(state.isIDEFocused ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(state.isIDEFocused ? Color.green : Color.orange)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "macwindow.on.rectangle")
                            .foregroundStyle((state.isFolderScopeActive && state.isIDEFocused) ? Color.green : Color.orange)
                        Text("Active Window:")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(state.frontmostWindowMainTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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
