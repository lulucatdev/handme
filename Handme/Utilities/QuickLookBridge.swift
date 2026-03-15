import SwiftUI
import AppKit
import Quartz
import HandmeCore

class QuickLookResponder: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var items: [InboxItem] = []

    override var acceptsFirstResponder: Bool { true }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func togglePreview(for previewItems: [InboxItem]) {
        items = previewItems
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { items.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        URL(fileURLWithPath: items[index].filePath) as NSURL
    }
}

struct QuickLookBridgeView: NSViewRepresentable {
    let responder: QuickLookResponder
    func makeNSView(context: Context) -> QuickLookResponder { responder }
    func updateNSView(_ nsView: QuickLookResponder, context: Context) {}
}
