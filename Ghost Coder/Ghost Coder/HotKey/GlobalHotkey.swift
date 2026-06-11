//
//  GlobalHotkey.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import AppKit

class GlobalHotkey {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let state: GhostState
    private let interceptor: KeyboardInterceptor

    init(state: GhostState, interceptor: KeyboardInterceptor) {
        self.state = state
        self.interceptor = interceptor
    }

    func register() {
        // Global monitor: fires even when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
        // Local monitor: fires when app's own window is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    func unregister() {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor  { NSEvent.removeMonitor(lm) }
    }

    private func handleEvent(_ event: NSEvent) {
        // Cmd + Shift + G  (keyCode 5 = 'g')
        guard event.modifierFlags.contains([.command, .shift]),
              event.keyCode == 5 else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.state.isGhostModeEnabled.toggle()
            self.state.updateCachedActiveState()

            if self.state.isGhostModeEnabled {
                // Hide main window when Ghost Mode activates
                NSApp.windows.filter { $0.identifier?.rawValue == "mainWindow" }
                    .forEach { $0.orderOut(nil) }
            } else {
                // Show main window when Ghost Mode deactivates
                NSApp.windows.filter { $0.identifier?.rawValue == "mainWindow" }
                    .forEach { $0.makeKeyAndOrderFront(nil) }
            }
        }
    }
}
