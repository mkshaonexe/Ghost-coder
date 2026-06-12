//
//  DiagnosticsSection.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import SwiftUI

struct DiagnosticsSection: View {
    @ObservedObject var state: GhostState
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("DIAGNOSTICS & SYSTEM LOGS")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Spacer()
                    
                    if !state.diagnosticLogs.isEmpty {
                        Text("\(state.diagnosticLogs.count) logs")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    if state.diagnosticLogs.isEmpty {
                        HStack {
                            Spacer()
                            Text("No log messages yet.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(state.diagnosticLogs.enumerated()), id: \.offset) { _, log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(colorForLog(log))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.white.opacity(0.02))
                                            )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(maxHeight: 180)
                        }
                        
                        Divider()
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    state.diagnosticLogs.removeAll()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.caption2)
                                    Text("Clear logs")
                                        .font(.system(.caption2, design: .rounded))
                                }
                                .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func colorForLog(_ log: String) -> Color {
        if log.contains("Error") || log.contains("Failed") {
            return .red.opacity(0.9)
        } else if log.contains("Warning") || log.contains("Watchdog alert") {
            return .orange.opacity(0.9)
        } else if log.contains("Active") || log.contains("Granted") || log.contains("Matched") {
            return .green.opacity(0.9)
        } else if log.contains("Injected") || log.contains("Advanced") {
            return .cyan.opacity(0.9)
        }
        return .white.opacity(0.8)
    }
}

#Preview {
    let state = GhostState()
    state.diagnosticLogs = [
        "[12:05:01] Ghost Coder started.",
        "[12:05:02] Loading main.swift...",
        "[12:05:03] Error: Failed to create CGEventTap. Check accessibility permissions.",
        "[12:05:05] Active application changed to: VS Code.",
    ]
    return DiagnosticsSection(state: state)
        .padding()
        .background(Color.black.opacity(0.8))
}
