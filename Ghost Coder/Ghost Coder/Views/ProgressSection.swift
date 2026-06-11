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
                            .shadow(color: Color.cyan.opacity(0.32), radius: 6, x: 0, y: 2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.progress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(state.currentIndex) / \(state.completionCount) characters")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
