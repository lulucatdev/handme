import Foundation
import HandmeCore

enum OutputFormatter {
    static func successLine(_ fileName: String, updated: Bool) -> String {
        updated ? "✓ \(fileName) (updated)" : "✓ \(fileName)"
    }

    static func errorLine(_ path: String, error: String) -> String {
        "✗ \(path): \(error)"
    }

    static func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    static func listLine(_ item: InboxItem) -> String {
        let name = item.fileName.padding(toLength: 20, withPad: " ", startingAt: 0)
        let path = shortenPath(item.filePath)
        let time = relativeTime(from: item.addedAt)
        let prefix = item.fileExists ? " " : "!"
        return "\(prefix) \(name) \(path)  \(time)"
    }
}
