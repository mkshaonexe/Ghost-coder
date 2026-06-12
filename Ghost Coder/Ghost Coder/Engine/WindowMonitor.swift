//
//  WindowMonitor.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import AppKit
import Combine

class WindowMonitor {
    private let state: GhostState
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(state: GhostState) {
        self.state = state
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.check()
        }

        // Fast-path focus checking when Ghost Mode is toggled on
        state.$isGhostModeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    // Bring the target IDE to the front immediately to accelerate the transition
                    self.activateIDETarget()
                    
                    // Run focus check immediately and also queue subsequent checks
                    // to ensure focus transition has completed and state is active
                    self.check()
                    for delay in [0.02, 0.05, 0.1, 0.15, 0.2] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.check()
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Observe when any application is activated to instantly update focus state
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func check() {
        // Must run on main thread (NSWorkspace + UI updates)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.check() }
            return
        }

        // 1. Check & Update Permissions status
        let axTrusted = AXIsProcessTrusted()
        let listenTrusted = CGPreflightListenEventAccess()

        if state.isAccessibilityGranted != axTrusted {
            state.isAccessibilityGranted = axTrusted
            state.log("Accessibility permission status changed: \(axTrusted ? "Granted" : "Denied")")
        }
        if state.isInputMonitoringGranted != listenTrusted {
            state.isInputMonitoringGranted = listenTrusted
            state.log("Input Monitoring permission status changed: \(listenTrusted ? "Granted" : "Denied")")
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            state.isIDEFocused = false
            state.isFolderScopeActive = true
            state.frontmostAppName = "None"
            state.frontmostWindowMainTitle = "None"
            state.updateCachedActiveState()
            return
        }

        let appName = frontApp.localizedName ?? "Unknown App"
        if state.frontmostAppName != appName {
            state.frontmostAppName = appName
            state.log("Active application changed to: \(appName)")
        }

        // Check if target IDE is focused
        let isFocused: Bool
        if let targetBundleID = state.ideTarget.bundleID {
            isFocused = frontApp.bundleIdentifier == targetBundleID
        } else {
            // "Any Application" mode — always focused if something is frontmost
            isFocused = true
        }

        // 2. Fetch active window title using Accessibility APIs if trusted
        var windowTitle = "None"
        if axTrusted {
            if let title = getWindowTitle(for: frontApp) {
                windowTitle = title
            } else {
                windowTitle = "No Window"
            }
        } else {
            windowTitle = "Restricted (Accessibility Required)"
        }

        if state.frontmostWindowMainTitle != windowTitle {
            state.frontmostWindowMainTitle = windowTitle
            if isFocused && axTrusted {
                state.log("Active target window title: \"\(windowTitle)\"")
            }
        }

        // Check folder scope constraint
        var isFolderActive = true
        if isFocused && !state.workspaceFolderPath.isEmpty {
            isFolderActive = checkFolderScope(windowTitle: windowTitle)
        }

        state.isIDEFocused = isFocused
        state.isFolderScopeActive = isFolderActive
        state.updateCachedActiveState()
    }

    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindowRef: AnyObject?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        let windowElement: AXUIElement?
        if focusedWindowResult == .success, let focusedWindow = focusedWindowRef as! AXUIElement? {
            windowElement = focusedWindow
        } else {
            var windowsRef: AnyObject?
            let windowsResult = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
            guard windowsResult == .success,
                  let windows = windowsRef as? [AXUIElement],
                  let frontWindow = windows.first else {
                return nil
            }
            windowElement = frontWindow
        }

        guard let windowElement else {
            return nil
        }

        var titleRef: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
        guard titleResult == .success,
              let windowTitle = titleRef as? String else {
            return nil
        }
        return windowTitle
    }

    // Check if the IDE's frontmost window title references the configured folder
    private func checkFolderScope(windowTitle: String) -> Bool {
        if windowTitle == "None" || windowTitle == "No Window" || windowTitle.starts(with: "Restricted") {
            return false
        }

        // Traverse up the workspaceFolderPath hierarchy to find matching directory names.
        // This is robust if the configured path is a deep subfolder.
        var currentURL = URL(fileURLWithPath: state.workspaceFolderPath)
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        
        let ignoredFolders: Set<String> = [
            "lib", "src", "test", "app", "build", "dist", "node_modules", "ui", "features",
            "components", "views", "models", "controllers", "helpers", "utils", "main", "res",
            "assets", "packages", "sources", "ios", "android", "web", "macos", "linux", "windows",
            "desktop", "mobile", "shared", "core"
        ]

        while currentURL.path != "/" && currentURL.path != homeURL.path {
            let folderName = currentURL.lastPathComponent
            if folderName.count > 2 && !ignoredFolders.contains(folderName.lowercased()) {
                if windowTitle.localizedCaseInsensitiveContains(folderName) {
                    return true
                }
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return false
    }

    @objc private func handleAppActivation() {
        check()
    }

    private func activateIDETarget() {
        guard let bundleID = state.ideTarget.bundleID else { return }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
