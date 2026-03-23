import SwiftUI

class WindowManager {
    static let shared = WindowManager()

    private var windows: [String: NSWindow] = [:]

    func openWindow<Content: View>(id: String, title: String, content: Content) {
        // If window already exists, bring it to front
        if let existing = windows[id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windows[id] = window
    }

    func closeWindow(id: String) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}
