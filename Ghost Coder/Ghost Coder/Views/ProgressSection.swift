//
//  ProgressSection.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

struct ProgressSection: View {
    @ObservedObject var state: GhostState
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TYPING PROGRESS")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white.opacity(0.6))
                
                Spacer()
                
                Text(percentString)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(state.progress), height: 8)
                            .shadow(color: Color.cyan.opacity(state.isGhostModeEnabled && isAnimating ? 0.65 : 0.32), radius: state.isGhostModeEnabled && isAnimating ? 8 : 4, x: 0, y: 1)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.progress)
                    }
                }
                .frame(height: 8)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
                
                HStack {
                    if state.isGitDiffModeEnabled {
                        Text("Step \(state.gitCurrentStepIndex) / \(state.gitDiffStepCount) commits")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    } else {
                        Text("\(state.currentIndex) / \(state.completionCount) characters")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    if state.isGitDiffModeEnabled {
                        if state.gitCurrentStepIndex + 1 < state.gitCommits.count {
                            Text(state.gitCommits[state.gitCurrentStepIndex + 1].message)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.66))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.green)
                        }
                    } else {
                        if state.remainingCharCount > 0 {
                            Text("\(state.remainingCharCount) remaining")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.66))
                        } else {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.green)
                        }
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
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
