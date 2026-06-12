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

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            state.isIDEFocused = false
            state.isFolderScopeActive = true
            state.updateCachedActiveState()
            return
        }

        // Check if target IDE is focused
        let isFocused: Bool
        if let targetBundleID = state.ideTarget.bundleID {
            isFocused = frontApp.bundleIdentifier == targetBundleID
        } else {
            // "Any Application" mode — always focused if something is frontmost
            isFocused = true
        }

        // Check folder scope constraint
        var isFolderActive = true
        if isFocused && !state.workspaceFolderPath.isEmpty {
            isFolderActive = checkFolderScope(app: frontApp)
        }

        state.isIDEFocused = isFocused
        state.isFolderScopeActive = isFolderActive
        state.updateCachedActiveState()
    }

    // Check if the IDE's frontmost window title references the configured folder
    private func checkFolderScope(app: NSRunningApplication) -> Bool {
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
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement],
                  let frontWindow = windows.first else {
                return false
            }
            windowElement = frontWindow
        }

        var titleRef: AnyObject?
        guard let windowElement,
              AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef) == .success,
              let windowTitle = titleRef as? String else {
            return false
        }

        // Match on the last path component of workspaceFolderPath
        // VS Code title format: "filename — foldername — Visual Studio Code"
        let folderName = URL(fileURLWithPath: state.workspaceFolderPath).lastPathComponent
        return windowTitle.contains(folderName)
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
