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

    init() {
        let s = GhostState()
        let i = KeyboardInterceptor(state: s)
        let w = WindowMonitor(state: s)
        let h = GlobalHotkey(state: s, interceptor: i)
        
        _state = StateObject(wrappedValue: s)
        self.interceptor = i
        self.windowMonitor = w
        self.hotkey = h
        
        i.start()
        w.start()
        h.register()

        // Automatically activate and show the main configuration window on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "mainWindow" }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            MenuBarIcon(state: state)
        }
        .menuBarExtraStyle(.menu)

        Window("Ghost Coder", id: "mainWindow") {
            ContentView(state: state)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
