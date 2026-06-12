//
//  KeystrokeLogSection.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import SwiftUI

struct KeystrokeLogSection: View {
    @ObservedObject var state: GhostState
    @State private var isExpanded: Bool = false
    @State private var hasCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Header row ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        // Pulsing dot when active
                        if state.isActiveCached {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .stroke(Color.cyan.opacity(0.4), lineWidth: 3)
                                        .scaleEffect(1.6)
                                )
                        }

                        Text("KEYSTROKE & TYPE LOG")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.white.opacity(0.6))

                        Spacer()

                        if !state.keystrokeLogs.isEmpty {
                            Text("\(state.keystrokeLogs.count) events")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.cyan.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Copy button
                if !state.keystrokeLogs.isEmpty {
                    Button(action: copyLogs) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(hasCopied ? Color.green.opacity(0.8) : Color.white.opacity(0.5))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy keystroke log to clipboard")
                }

                // Chevron expand/collapse
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // ── Expanded log panel ───────────────────────────────────────
            if isExpanded {
                VStack(spacing: 0) {
                    if state.keystrokeLogs.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "keyboard")
                                    .font(.title3)
                                    .foregroundStyle(Color.white.opacity(0.2))
                                Text("No keystrokes recorded yet.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text("Arm Ghost Mode and start typing.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        // Column header
                        keystrokeColumnHeader
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)

                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.bottom, 4)

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 3) {
                                ForEach(state.keystrokeLogs) { entry in
                                    KeystrokeLogRow(entry: entry)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 220)

                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.top, 4)

                        HStack {
                            Text("Showing latest \(min(state.keystrokeLogs.count, 500)) of all events")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.3))

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    state.keystrokeLogs.removeAll()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.caption2)
                                    Text("Clear")
                                        .font(.system(.caption2, design: .rounded))
                                }
                                .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.10), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // ── Column header ────────────────────────────────────────────────────
    private var keystrokeColumnHeader: some View {
        HStack(spacing: 0) {
            Text("TIME")
                .frame(width: 72, alignment: .leading)
            Text("KEY")
                .frame(width: 38, alignment: .center)
            Text("→ VIRTUAL OUTPUT")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("MODE")
                .frame(width: 54, alignment: .center)
            Text("CHARS")
                .frame(width: 42, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.35))
    }

    // ── Copy logs ────────────────────────────────────────────────────────
    private func copyLogs() {
        let lines = state.keystrokeLogs.map { e in
            "[\(e.timestamp)] [\(e.type == .injection ? "INJ" : "UNDO")] key=\(e.physicalKey) out=\(e.injectedText) chars=\(e.chunkSize) mode=\(e.mode) app=\(e.targetApp) src=\(e.sourceFile)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        withAnimation { hasCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { hasCopied = false }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Row
// ─────────────────────────────────────────────────────────────────────────────

struct KeystrokeLogRow: View {
    let entry: KeystrokeLogEntry

    var body: some View {
        HStack(spacing: 0) {
            // Timestamp
            Text(entry.timestamp)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(Color.white.opacity(0.4))

            // Physical key badge
            Text(entry.physicalKey)
                .frame(width: 38, alignment: .center)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(physicalKeyBg)
                )
                .foregroundStyle(physicalKeyFg)

            // Arrow + Virtual output
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.25))
                Text(entry.injectedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(injectedColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)

            // Mode pill
            Text(entry.mode.prefix(4).uppercased())
                .frame(width: 54, alignment: .center)
                .padding(.vertical, 1)
                .background(modeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(modeColor.opacity(0.9))

            // Chunk size
            Text("\(entry.chunkSize)")
                .frame(width: 42, alignment: .trailing)
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .font(.system(size: 10.5, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(rowBg)
        )
        .help(tooltipText)
    }

    private var rowBg: Color {
        switch entry.type {
        case .injection: return Color.white.opacity(0.02)
        case .undo:      return Color.orange.opacity(0.04)
        case .blocked:   return Color.red.opacity(0.04)
        }
    }

    private var physicalKeyBg: Color {
        switch entry.type {
        case .injection: return Color.white.opacity(0.07)
        case .undo:      return Color.orange.opacity(0.15)
        case .blocked:   return Color.red.opacity(0.15)
        }
    }

    private var physicalKeyFg: Color {
        switch entry.type {
        case .injection: return Color.white.opacity(0.85)
        case .undo:      return Color.orange.opacity(0.9)
        case .blocked:   return Color.red.opacity(0.8)
        }
    }

    private var injectedColor: Color {
        switch entry.type {
        case .injection: return Color.cyan.opacity(0.9)
        case .undo:      return Color.orange.opacity(0.8)
        case .blocked:   return Color.red.opacity(0.7)
        }
    }

    private var modeColor: Color {
        switch entry.mode.lowercased() {
        case "character": return .purple
        case "word":      return .green
        case "line":      return .cyan
        default:          return .white
        }
    }

    private var tooltipText: String {
        """
        Time:      \(entry.timestamp)
        Target:    \(entry.targetApp)
        Source:    \(entry.sourceFile)
        Workspace: \(entry.workspaceFolder.isEmpty ? "(none)" : entry.workspaceFolder)
        Key:       \(entry.physicalKey)
        Output:    \(entry.injectedText)
        Chars:     \(entry.chunkSize)
        Mode:      \(entry.mode)
        """
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    let state = GhostState()
    state.keystrokeLogs = [
        KeystrokeLogEntry(id: 3, timestamp: "15:41:32.441", type: .injection,
                          physicalKey: "t", injectedText: "import 'package:flutter/material.dart';⏎",
                          chunkSize: 41, mode: "Line",
                          targetApp: "VS Code",
                          sourceFile: "dashboard_view.dart",
                          workspaceFolder: "/Users/mkshaon/test ghost coder/my_app_fultter_test"),
        KeystrokeLogEntry(id: 2, timestamp: "15:41:31.200", type: .injection,
                          physicalKey: "i", injectedText: "// dashboard_view.dart⏎",
                          chunkSize: 23, mode: "Line",
                          targetApp: "VS Code",
                          sourceFile: "dashboard_view.dart",
                          workspaceFolder: "/Users/mkshaon/test ghost coder/my_app_fultter_test"),
        KeystrokeLogEntry(id: 1, timestamp: "15:41:30.002", type: .undo,
                          physicalKey: "[BS]", injectedText: "// dashboard_view.dart⏎",
                          chunkSize: 23, mode: "Line",
                          targetApp: "VS Code",
                          sourceFile: "dashboard_view.dart",
                          workspaceFolder: "/Users/mkshaon/test ghost coder/my_app_fultter_test"),
    ]
    return KeystrokeLogSection(state: state)
        .padding()
        .background(Color.black.opacity(0.85))
}
