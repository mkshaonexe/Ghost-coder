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
                .foregroundColor(.secondary)
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
        if state.isActiveCached {
            return Color.green
        } else if state.isGhostModeEnabled {
            return Color.orange
        } else {
            return Color.gray
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
}

#Preview {
    let state = GhostState()
    StatusPill(state: state)
}
