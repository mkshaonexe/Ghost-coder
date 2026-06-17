//
//  MenuBarView.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var state: GhostState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ghost Coder")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Text(state.statusLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            Text(state.statusDetail)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            
            Divider()
            
            Button(action: toggleGhostMode) {
                Label(state.isGhostModeEnabled ? "Pause Ghost Mode" : "Start Ghost Mode", systemImage: state.isGhostModeEnabled ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!state.isSourceLoaded)
            
            Button(action: toggleMainWindow) {
                Label(isMainWindowVisible ? "Hide Window" : "Show Window", systemImage: isMainWindowVisible ? "eye.slash" : "eye")
            }
            
            Divider()
            
            Button(role: .destructive, action: quitApp) {
                Label("Quit Ghost Coder", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(.vertical, 4)
    }

    private func toggleGhostMode() {
        state.isGhostModeEnabled.toggle()
        state.updateCachedActiveState()
        
        // Hide/show window accordingly
        if state.isGhostModeEnabled {
            if state.autoHideOnActivation {
                NSApp.windows.filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
                    .forEach { $0.orderOut(nil) }
            }
        } else {
            showMainWindow()
        }
    }

    private var isMainWindowVisible: Bool {
        NSApp.windows.contains { window in
            (window.title == "Ghost Coder" || window.identifier?.rawValue == "mainWindow") && window.isVisible
        }
    }

    private func toggleMainWindow() {
        if isMainWindowVisible {
            NSApp.windows.filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
                .forEach { $0.orderOut(nil) }
        } else {
            showMainWindow()
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.filter { $0.title == "Ghost Coder" || $0.identifier?.rawValue == "mainWindow" }
            .forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

#Preview {
    let state = GhostState()
    MenuBarView(state: state)
}
