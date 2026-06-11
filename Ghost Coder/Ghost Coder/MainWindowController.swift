//
//  MainWindowController.swift
//  Ghost Coder
//
//  Created by AI on 11/6/26.
//

import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow

    init(state: GhostState) {
        let hostingView = NSHostingView(rootView: ContentView(state: state))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Ghost Coder"
        window.identifier = NSUserInterfaceItemIdentifier("mainWindow")
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        self.window = window

        super.init()

        self.window.delegate = self
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
