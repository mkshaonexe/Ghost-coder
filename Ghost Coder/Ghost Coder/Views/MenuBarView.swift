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
        Group {
            Text("Ghost Coder")
            
            Text("Status: \(statusText)")
            
            Divider()
            
            Button(action: toggleGhostMode) {
                Text(state.isGhostModeEnabled ? "Pause Ghost Mode" : "Start Ghost Mode")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            
            Button(action: showMainWindow) {
                Text("Show Window")
            }
            
            Divider()
            
            Button(role: .destructive, action: quitApp) {
                Text("Quit Ghost Coder")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private var statusText: String {
        if state.isActiveCached {
            return "Active"
        } else if state.isGhostModeEnabled {
            if !state.isSourceLoaded {
                return "Paused: No File"
            } else if !state.isIDEFocused {
                return "Paused: IDE Focus Needed"
            } else if !state.isFolderScopeActive {
                return "Paused: Workspace Mismatch"
            } else {
                return "Paused"
            }
        } else {
            return "Inactive"
        }
    }

    private func toggleGhostMode() {
        state.isGhostModeEnabled.toggle()
        state.updateCachedActiveState()
        
        // Hide/show window accordingly
        if state.isGhostModeEnabled {
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
