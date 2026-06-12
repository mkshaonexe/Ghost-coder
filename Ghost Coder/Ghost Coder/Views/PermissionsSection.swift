//
//  PermissionsSection.swift
//  Ghost Coder
//
//  Created by AI on 12/6/26.
//

import SwiftUI
import CoreGraphics

struct PermissionsSection: View {
    @ObservedObject var state: GhostState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM PERMISSIONS")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.white.opacity(0.6))

            VStack(spacing: 12) {
                // Accessibility Permission Row
                permissionRow(
                    title: "Accessibility API",
                    description: "Required to intercept keystrokes and inspect active workspace titles.",
                    isGranted: state.isAccessibilityGranted,
                    onRequest: requestAccessibility,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )

                Divider()

                // Input Monitoring Permission Row
                permissionRow(
                    title: "Input Monitoring",
                    description: "Required for the global ⌘⇧G hotkey when Ghost Coder is unfocused.",
                    isGranted: state.isInputMonitoringGranted,
                    onRequest: requestInputMonitoring,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                )
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

    @ViewBuilder
    private func permissionRow(
        title: String,
        description: String,
        isGranted: Bool,
        onRequest: @escaping () -> Void,
        settingsURL: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(isGranted ? "Granted" : "Required")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isGranted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2),
                            in: Capsule()
                        )
                        .foregroundStyle(isGranted ? Color.green : Color.orange)
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !isGranted {
                    HStack(spacing: 8) {
                        Button(action: onRequest) {
                            Text("Request Access")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.orange.opacity(0.3))

                        Button(action: {
                            openSystemSettings(path: settingsURL)
                        }) {
                            Text("Open Settings")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func requestAccessibility() {
        state.log("Requesting Accessibility permission...")
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoring() {
        state.log("Requesting Input Monitoring permission...")
        CGRequestListenEventAccess()
    }

    private func openSystemSettings(path: String) {
        state.log("Opening System Settings: \(path)")
        if let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to general security preference page
            if let generalURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(generalURL)
            }
        }
    }
}

#Preview {
    let state = GhostState()
    state.isAccessibilityGranted = false
    state.isInputMonitoringGranted = true
    return PermissionsSection(state: state)
        .padding()
        .background(Color.black.opacity(0.8))
}
