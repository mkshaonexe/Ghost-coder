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
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Coder")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.black)
                    Text("System-Wide Keystroke Emulator")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusPill(state: state)
            }
            .padding(.bottom, 5)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    SourceFileSection(state: state)
                    
                    TargetSection(state: state)
                    
                    ModeSection(state: state)
                    
                    ProgressSection(state: state)
                }
            }
            
            Divider()
            
            // Bottom Action
            VStack(spacing: 12) {
                Button(action: toggleGhostMode) {
                    HStack {
                        Image(systemName: state.isGhostModeEnabled ? "pause.fill" : "play.fill")
                            .font(.headline)
                        Text(state.isGhostModeEnabled ? "PAUSE GHOST MODE" : "ACTIVATE GHOST MODE")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isGhostModeEnabled ? Color.orange : Color.green)
                .disabled(!state.isSourceLoaded)
                
                // Hotkey Helper Tip
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                    Text("Press")
                    Text("⌘⇧G")
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
                    Text("system-wide to toggle Ghost Mode.")
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 460, height: 600)
    }

    private func toggleGhostMode() {
        withAnimation {
            state.isGhostModeEnabled.toggle()
            state.updateCachedActiveState()
            
            // Automatically hide window if activated
            if state.isGhostModeEnabled {
                NSApp.windows.filter { $0.identifier?.rawValue == "mainWindow" }
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
