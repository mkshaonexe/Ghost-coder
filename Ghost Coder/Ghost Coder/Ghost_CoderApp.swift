//
//  Ghost_CoderApp.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import SwiftUI

@main
struct Ghost_CoderApp: App {
    @StateObject private var state: GhostState
    private var interceptor: KeyboardInterceptor
    private var windowMonitor: WindowMonitor
    private var hotkey: GlobalHotkey
    private var mainWindowController: MainWindowController
    private var cliServer: CLIServer

    init() {
        let s = GhostState()
        let logger = ResponseLogger(state: s)
        s.responseLogger = logger
        
        let i = KeyboardInterceptor(state: s)
        let w = WindowMonitor(state: s)
        let h = GlobalHotkey(state: s, interceptor: i)
        let m = MainWindowController(state: s)
        let c = CLIServer(state: s)

        // Restore any crashed settings backups on startup
        VSCodeSettingsManager.shared.checkAndRestoreCrashedBackups(workspaceFolderPath: s.workspaceFolderPath) { msg in
            s.log(msg)
        }
        
        _state = StateObject(wrappedValue: s)
        self.interceptor = i
        self.windowMonitor = w
        self.hotkey = h
        self.mainWindowController = m
        self.cliServer = c
        
        
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            VSCodeSettingsManager.shared.restoreSettings() { msg in
                s.log(msg)
            }
            s.responseLogger?.endSession()
        }
        
        i.start()
        w.start()
        h.register()
        c.start()
        DispatchQueue.main.async {
            m.show()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            MenuBarIcon(state: state)
        }
        .menuBarExtraStyle(.menu)
    }
}
