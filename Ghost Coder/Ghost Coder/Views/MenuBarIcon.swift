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
    }

    private var iconName: String {
        if !state.isSourceLoaded {
            return "circle"
        } else if !state.isGhostModeEnabled {
            return "play.circle"
        } else if state.isActiveCached {
            return "play.circle.fill"
        } else {
            return "pause.circle.fill"
        }
    }
}

#Preview {
    let state = GhostState()
    MenuBarIcon(state: state)
}
