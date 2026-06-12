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
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(state.isIDEFocused ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text("LIVE MONITOR (DUAL-MONITOR DASHBOARD)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }

                    liveMonitorConsole
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
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
    }

    private var liveMonitorConsole: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.caption)
                    .foregroundStyle(state.isIDEFocused ? Color.green : Color.orange)
                Text("Active App:")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(state.frontmostAppName.isEmpty ? "None" : state.frontmostAppName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                statusBadge
            }

            HStack(spacing: 8) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.caption)
                    .foregroundStyle((state.isFolderScopeActive && state.isIDEFocused) ? Color.green : Color.orange)
                Text("Active Window:")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(state.frontmostWindowMainTitle.isEmpty ? "No active window" : state.frontmostWindowMainTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        Text(state.isIDEFocused ? "TARGET MATCHED" : "FOCUS NEEDED")
            .font(.system(size: 8, weight: .black, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(state.isIDEFocused ? Color.green.opacity(0.12) : Color.orange.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(state.isIDEFocused ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(state.isIDEFocused ? Color.green : Color.orange)
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
