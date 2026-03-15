import AppKit
import HandmeCore

enum FileOperations {
    static func open(_ item: InboxItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath))
    }

    static func revealInFinder(_ items: [InboxItem]) {
        let urls = items.map { URL(fileURLWithPath: $0.filePath) }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func copyFiles(_ items: [InboxItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items.map { URL(fileURLWithPath: $0.filePath) as NSURL })
    }

    static func copyPaths(_ items: [InboxItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(items.map(\.filePath).joined(separator: "\n"), forType: .string)
    }
}
