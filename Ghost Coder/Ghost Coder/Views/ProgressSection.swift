//
//  ProgressSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ProgressSection: View {
    @ObservedObject var state: GhostState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TYPING PROGRESS")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(percentString)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 12) {
                // Custom Premium Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(state.progress), height: 8)
                            .shadow(color: .accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.progress)
                    }
                }
                .frame(height: 8)
                
                // Character counters
                HStack {
                    Text("\(state.currentIndex) / \(state.sourceCode.count) characters")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if state.remainingCharCount > 0 {
                        Text("\(state.remainingCharCount) remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var percentString: String {
        guard state.isSourceLoaded else { return "0%" }
        let pct = Int(state.progress * 100)
        return "\(pct)%"
    }
}

#Preview {
    let state = GhostState()
    state.sourceCode = "Hello, world!"
    state.currentIndex = 4
    return ProgressSection(state: state)
        .padding()
}
