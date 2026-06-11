//
//  WindowMonitor.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import AppKit

class WindowMonitor {
    private let state: GhostState
    private var timer: Timer?

    init(state: GhostState) {
        self.state = state
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
}
