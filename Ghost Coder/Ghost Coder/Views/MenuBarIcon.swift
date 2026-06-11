//
//  MenuBarIcon.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct MenuBarIcon: View {
    @ObservedObject var state: GhostState

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .help(state.statusLabel)
    }

    private var iconName: String {
        switch state.operationalState {
        case .inactive:
            return "circle"
        case .pausedNoFile:
            return "exclamationmark.circle"
        case .pausedReady, .pausedFocusNeeded, .pausedWorkspaceMismatch:
            return "pause.circle.fill"
        case .active:
            return "play.circle.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state.operationalState {
        case .active:
            return .green
        case .pausedNoFile, .pausedReady, .pausedFocusNeeded, .pausedWorkspaceMismatch:
            return .orange
        case .complete:
            return .cyan
        case .inactive:
            return .gray
        }
    }
}

#Preview {
    let state = GhostState()
    MenuBarIcon(state: state)
}
