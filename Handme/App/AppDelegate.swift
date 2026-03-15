import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?
    private var animationTimer: Timer?
    private var frameIndex = 0
    private var hasNewItems = false

    private let frameNames = ["TrayFrame1", "TrayFrame2", "TrayFrame3", "TrayFrame2"]

    var viewModel: InboxViewModel? {
        didSet { observeNewItems() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startAnimation()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        viewModel?.addPaths(filenames)
        reopenMainWindow()
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { reopenMainWindow() }
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            applyFrame()
        }
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % frameNames.count
        applyFrame()
    }

    private func applyFrame() {
        guard let button = statusItem?.button else { return }
        let baseImage = NSImage(named: frameNames[frameIndex])
        baseImage?.size = NSSize(width: 18, height: 18)

        if hasNewItems {
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
            button.image = baseImage
        }
    }

    @objc private func statusItemClicked() {
        viewModel?.markAsRead()
        hasNewItems = false
        applyFrame()
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
                self?.hasNewItems = hasNew
                self?.applyFrame()
            }
    }
}
