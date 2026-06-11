//
//  ModeSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ModeSection: View {
    @ObservedObject var state: GhostState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INPUT MODE & SPEED")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Segmented picker for InputMode
                Picker("Input Mode", selection: $state.inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                // Configurable typing delay (Word/Line modes only)
                if state.inputMode != .character {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Typing Speed")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(state.injectionDelayMs) ms / char")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .fontWeight(.bold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(state.injectionDelayMs) },
                                set: { state.injectionDelayMs = Int($0) }
                            ),
                            in: 5...80,
                            step: 1
                        )
                        .accentColor(.accentColor)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
            .animation(.easeInOut(duration: 0.25), value: state.inputMode)
        }
    }
}

#Preview {
    let state = GhostState()
    state.inputMode = .word
    return ModeSection(state: state)
        .padding()
}
