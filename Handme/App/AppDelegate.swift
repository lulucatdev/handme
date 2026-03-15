import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?

    var viewModel: InboxViewModel? {
        didSet { observeNewItems() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { reopenMainWindow() }
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "TrayIcon")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        viewModel?.markAsRead()
        updateBadge(false)
        reopenMainWindow()
    }

    /// Stored by ContentView so we can reopen the SwiftUI Window from outside the view hierarchy.
    var openMainWindow: (() -> Void)?

    func reopenMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        // First try to find and show an existing window
        for window in NSApplication.shared.windows {
            if window.frameAutosaveName.contains("main") || window.title == "Handme" {
                if let screen = NSScreen.main, !screen.visibleFrame.intersects(window.frame) {
                    window.center()
                }
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Window was destroyed by SwiftUI — recreate via OpenWindowAction
        openMainWindow?()
    }

    private func observeNewItems() {
        cancellable?.cancel()
        guard let viewModel else { return }
        cancellable = viewModel.$hasNewItems
            .receive(on: RunLoop.main)
            .sink { [weak self] hasNew in
                self?.updateBadge(hasNew)
            }
    }

    private func updateBadge(_ hasNew: Bool) {
        guard let button = statusItem?.button else { return }
        if hasNew {
            let baseImage = NSImage(named: "TrayIcon")
            let badgedImage = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                baseImage?.draw(in: rect)
                NSColor.systemRed.setFill()
                let dotSize: CGFloat = 5
                let dotRect = NSRect(x: rect.maxX - dotSize - 1, y: rect.maxY - dotSize - 1, width: dotSize, height: dotSize)
                NSBezierPath(ovalIn: dotRect).fill()
                return true
            }
            badgedImage.isTemplate = false
            button.image = badgedImage
        } else {
            button.image = NSImage(named: "TrayIcon")
            button.image?.isTemplate = true
        }
    }
}
