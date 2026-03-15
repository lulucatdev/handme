import Testing
import Foundation
@testable import HandmeCore

func makeTestStore() throws -> InboxStore {
    try InboxStore(databasePath: ":memory:")
}

@Test func addSingleFile() throws {
    let store = try makeTestStore()
    let tmpFile = NSTemporaryDirectory() + "test_add_\(UUID().uuidString).txt"
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }
    let results = try store.add(paths: [tmpFile])
    #expect(results.count == 1)
    #expect(results[0].success == true)
    let items = try store.loadAll()
    #expect(items.count == 1)
    #expect(items[0].fileName == URL(fileURLWithPath: tmpFile).lastPathComponent)
}

@Test func addNonexistentFile() throws {
    let store = try makeTestStore()
    let results = try store.add(paths: ["/nonexistent/file_\(UUID().uuidString).txt"])
    #expect(results.count == 1)
    #expect(results[0].success == false)
    #expect(try store.loadAll().count == 0)
}

@Test func addDuplicateUpdatesTimestamp() throws {
    let store = try makeTestStore()
    let tmpFile = NSTemporaryDirectory() + "test_dup_\(UUID().uuidString).txt"
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }
    let first = try store.add(paths: [tmpFile])
    let firstTime = first[0].item!.addedAt
    Thread.sleep(forTimeInterval: 0.05)
    let second = try store.add(paths: [tmpFile])
    let secondTime = second[0].item!.addedAt
    #expect(secondTime > firstTime)
    #expect(second[0].updated == true)
    #expect(try store.loadAll().count == 1)
}

@Test func loadAllOrderedByNewest() throws {
    let store = try makeTestStore()
    let dir = NSTemporaryDirectory()
    let files = (0..<3).map { i -> String in
        let path = dir + "test_order_\(i)_\(UUID().uuidString).txt"
        FileManager.default.createFile(atPath: path, contents: nil)
        return path
    }
    defer { files.forEach { try? FileManager.default.removeItem(atPath: $0) } }
    for file in files {
        _ = try store.add(paths: [file])
        Thread.sleep(forTimeInterval: 0.05)
    }
    let items = try store.loadAll()
    #expect(items.count == 3)
    #expect(items[0].addedAt >= items[1].addedAt)
    #expect(items[1].addedAt >= items[2].addedAt)
}

@Test func removeById() throws {
    let store = try makeTestStore()
    let tmpFile = NSTemporaryDirectory() + "test_rm_\(UUID().uuidString).txt"
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }
    let results = try store.add(paths: [tmpFile])
    let id = results[0].item!.id
    try store.remove(ids: Set([id]))
    #expect(try store.loadAll().count == 0)
}

@Test func removeAllItems() throws {
    let store = try makeTestStore()
    let dir = NSTemporaryDirectory()
    let files = (0..<3).map { i -> String in
        let path = dir + "test_rmall_\(i)_\(UUID().uuidString).txt"
        FileManager.default.createFile(atPath: path, contents: nil)
        return path
    }
    defer { files.forEach { try? FileManager.default.removeItem(atPath: $0) } }
    _ = try store.add(paths: files)
    #expect(try store.loadAll().count == 3)
    try store.removeAll()
    #expect(try store.loadAll().count == 0)
}

@Test func evictionRemovesOldest() throws {
    let store = try makeTestStore()
    UserDefaults.standard.set(3, forKey: HandmeConstants.maxCapacityKey)
    defer { UserDefaults.standard.removeObject(forKey: HandmeConstants.maxCapacityKey) }
    let dir = NSTemporaryDirectory()
    var files: [String] = []
    for i in 0..<5 {
        let path = dir + "test_evict_\(i)_\(UUID().uuidString).txt"
        FileManager.default.createFile(atPath: path, contents: nil)
        files.append(path)
        _ = try store.add(paths: [path])
        Thread.sleep(forTimeInterval: 0.05)
    }
    defer { files.forEach { try? FileManager.default.removeItem(atPath: $0) } }
    let items = try store.loadAll()
    #expect(items.count == 3)
    let remaining = Set(items.map { $0.filePath })
    for file in files.suffix(3) {
        let resolved = URL(fileURLWithPath: file).standardized.resolvingSymlinksInPath().path
        #expect(remaining.contains(resolved))
    }
}

@Test func validateFileExistenceBidirectional() throws {
    let store = try makeTestStore()
    let tmpFile = NSTemporaryDirectory() + "test_exist_\(UUID().uuidString).txt"
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    _ = try store.add(paths: [tmpFile])
    #expect(try store.loadAll()[0].fileExists == true)
    try FileManager.default.removeItem(atPath: tmpFile)
    try store.validateFileExistence()
    #expect(try store.loadAll()[0].fileExists == false)
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }
    try store.validateFileExistence()
    #expect(try store.loadAll()[0].fileExists == true)
}
