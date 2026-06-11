//
//  ContentView.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var state: GhostState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.17),
                    Color(red: 0.05, green: 0.18, blue: 0.21),
                    Color(red: 0.11, green: 0.11, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .blur(radius: 80)
                    .frame(width: 220, height: 220)
                    .offset(x: 160, y: -220)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .padding(10)
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                headerCard

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        SourceFileSection(state: state)
                        TargetSection(state: state)
                        ModeSection(state: state)
                        ProgressSection(state: state)
                    }
                }
                .scrollContentBackground(.hidden)

                VStack(spacing: 12) {
                    Button(action: toggleGhostMode) {
                        HStack(spacing: 10) {
                            Image(systemName: state.isGhostModeEnabled ? "pause.fill" : "play.fill")
                                .font(.headline)
                            Text(state.isGhostModeEnabled ? "Pause Ghost Mode" : "Activate Ghost Mode")
                                .font(.custom("Avenir Next", size: 15))
                                .fontWeight(.heavy)
                            Spacer()
                            Text(state.isGhostModeEnabled ? "Armed" : "Idle")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(
                        LinearGradient(
                            colors: state.isGhostModeEnabled
                                ? [Color.orange.opacity(0.92), Color.red.opacity(0.88)]
                                : [Color.green.opacity(0.92), Color.cyan.opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
                    .disabled(!state.isSourceLoaded)

                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                        Text("Press")
                        Text("⌘⇧G")
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        Text("system-wide to toggle Ghost Mode.")
                        Spacer()
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 680)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
                .forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ghost Coder")
                        .font(.custom("Avenir Next", size: 31))
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                    Text("A focused keystroke mirror for source-driven coding demos.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Spacer()

                StatusPill(state: state)
            }

            HStack(spacing: 10) {
                quickMetric(title: "Source", value: state.isSourceLoaded ? state.sourceFileName : "No file")
                quickMetric(title: "Target", value: state.ideTarget.rawValue)
                quickMetric(title: "Mode", value: state.inputMode.rawValue)
            }

            Text(state.statusDetail)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func quickMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.54))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleGhostMode() {
        withAnimation {
            state.isGhostModeEnabled.toggle()
            state.updateCachedActiveState()
            
            // Automatically hide window if activated
            if state.isGhostModeEnabled {
                NSApp.windows.filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
                    .forEach { $0.orderOut(nil) }
            }
        }
    }
}

#Preview {
    let state = GhostState()
    state.sourceCode = "struct ContentView: View {}"
    state.sourceFileName = "ContentView.swift"
    return ContentView(state: state)
}
