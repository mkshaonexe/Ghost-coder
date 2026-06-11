//
//  StatusPill.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct StatusPill: View {
    @ObservedObject var state: GhostState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: 3)
            
            Text(statusText)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(statusColor.opacity(0.25), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isActiveCached)
    }

    private var statusColor: Color {
        switch state.operationalState {
        case .active:
            return Color.green
        case .pausedNoFile, .pausedFocusNeeded, .pausedWorkspaceMismatch, .pausedReady:
            return Color.orange
        case .complete:
            return Color.cyan
        case .inactive:
            return Color.gray
        }
    }

    private var statusText: String {
        state.statusLabel
    }
}

#Preview {
    let state = GhostState()
    StatusPill(state: state)
}
