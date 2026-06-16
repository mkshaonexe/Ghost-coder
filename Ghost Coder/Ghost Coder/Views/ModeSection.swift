//
//  ModeSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ModeSection: View {
    @ObservedObject var state: GhostState

    /// Converts the integer delay into a Double binding for Slider — avoids Binding(get:set:) in body.
    private var delayBinding: Binding<Double> {
        Binding(
            get: { Double(state.injectionDelayMs) },
            set: { state.injectionDelayMs = Int($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INPUT MODE & SPEED")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.white.opacity(0.6))

            VStack(spacing: 12) {
                // Segmented picker for InputMode
                Picker("Input Mode", selection: $state.inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(state.isGhostModeEnabled)
                
                // Configurable typing delay (Word/Line modes only)
                if state.inputMode != .character {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Typing Speed")
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text("\(state.injectionDelayMs) ms / char")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .fontWeight(.bold)
                        }
                        
                        Slider(
                            value: delayBinding,
                            in: 5...80,
                            step: 1
                        )
                        .tint(.accentColor)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()
                    .background(Color.white.opacity(0.12))

                Toggle(isOn: $state.enableAutoCloseSkip) {
                    Text("Skip Auto-Closed Brackets")
                        .font(.body)
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
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
