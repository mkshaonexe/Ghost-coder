//
//  ContentView.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var state: GhostState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.3"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.15),
                    Color(red: 0.04, green: 0.14, blue: 0.18),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .blur(radius: 70)
                    .frame(width: 260, height: 260)
                    .offset(x: 180, y: -240)
            )
            .overlay(
                Circle()
                    .fill(Color.cyan.opacity(0.04))
                    .blur(radius: 90)
                    .frame(width: 300, height: 300)
                    .offset(x: -200, y: 240)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .padding(10)
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                let isWide = geometry.size.width > 800
                
                if isWide {
                    HStack(alignment: .top, spacing: 24) {
                        // Left Column (Control & Status Panel)
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard
                            
                            ScrollView {
                                VStack(spacing: 18) {
                                    SourceFileSection(state: state)
                                    ProgressSection(state: state)
                                }
                                .padding(.trailing, 2)
                            }
                            .scrollIndicators(.never)
                            .scrollContentBackground(.hidden)
                            
                            Spacer()
                            
                            activationButtonBlock
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Right Column (System Settings & Diagnostic Logs)
                        VStack(alignment: .leading, spacing: 18) {
                            ScrollView {
                                VStack(spacing: 18) {
                                    PermissionsSection(state: state)
                                    TargetSection(state: state)
                                    ModeSection(state: state)
                                    DiagnosticsSection(state: state)
                                }
                                .padding(.trailing, 6)
                            }
                            .scrollIndicators(.automatic)
                            .scrollContentBackground(.hidden)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 18) {
                        headerCard

                        ScrollView {
                            VStack(spacing: 18) {
                                PermissionsSection(state: state)
                                SourceFileSection(state: state)
                                TargetSection(state: state)
                                ModeSection(state: state)
                                ProgressSection(state: state)
                                DiagnosticsSection(state: state)
                            }
                            .padding(.trailing, 2)
                        }
                        .scrollIndicators(.automatic)
                        .scrollContentBackground(.hidden)

                        activationButtonBlock
                    }
                    .padding(24)
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 500, idealHeight: 680, maxHeight: .infinity)
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
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("Ghost Coder")
                            .font(.custom("Avenir Next", size: 31))
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                        Text("v\(appVersion)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
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
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func quickMetric(title: String, value: String) -> some View {
        let iconName: String = {
            switch title.lowercased() {
            case "source": return "doc.text.fill"
            case "target": return "scope"
            case "mode": return "keyboard"
            default: return "info.circle.fill"
            }
        }()
        
        let iconColor: Color = {
            switch title.lowercased() {
            case "source": return .green
            case "target": return .cyan
            case "mode": return .purple
            default: return .white
            }
        }()

        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .padding(6)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var activationButtonBlock: some View {
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
                .foregroundStyle(.white)
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

    private func toggleGhostMode() {
        withAnimation {
            state.isGhostModeEnabled.toggle()
            state.updateCachedActiveState()

            // Bug #8 fix: Hide the window *after* a brief delay to allow the IDE
            // to receive focus and WindowMonitor to complete its first activation check.
            // This ensures the event tap is active before the first user keystroke.
            if state.isGhostModeEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    NSApp.windows
                        .filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
                        .forEach { $0.orderOut(nil) }
                }
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
