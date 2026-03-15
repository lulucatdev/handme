import Testing
import Foundation
@testable import HandmeCore

@Test func inboxItemProperties() {
    let now = Date()
    let item = InboxItem(
        id: "test-id",
        filePath: "/Users/test/file.txt",
        fileName: "file.txt",
        addedAt: now,
        fileExists: true
    )
    #expect(item.id == "test-id")
    #expect(item.filePath == "/Users/test/file.txt")
    #expect(item.fileName == "file.txt")
    #expect(item.addedAt == now)
    #expect(item.fileExists == true)
}

@Test func inboxItemDefaultInit() {
    let item = InboxItem(filePath: "/tmp/a.txt", fileName: "a.txt")
    #expect(!item.id.isEmpty)
    #expect(item.fileExists == true)
}
