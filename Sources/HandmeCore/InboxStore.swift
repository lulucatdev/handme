import Foundation
import GRDB

public struct AddResult: Sendable {
    public let path: String
    public let success: Bool
    public let updated: Bool
    public let item: InboxItem?
    public let error: String?
}

public class InboxStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(databasePath: String = HandmeConstants.databasePath) throws {
        var config = Configuration()
        config.busyMode = .timeout(TimeInterval(HandmeConstants.busyTimeoutMs) / 1000.0)

        if databasePath == ":memory:" {
            dbQueue = try DatabaseQueue(configuration: config)
        } else {
            dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
        }

        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "inbox_items") { t in
                t.column("id", .text).primaryKey()
                t.column("file_path", .text).notNull().unique()
                t.column("file_name", .text).notNull()
                t.column("added_at", .double).notNull()
                t.column("file_exists", .integer).defaults(to: 1)
            }
        }
        return migrator
    }

    public func add(paths: [String]) throws -> [AddResult] {
        var results: [AddResult] = []
        for path in paths {
            let resolved = Self.resolvedAbsolutePath(path)
            guard FileManager.default.fileExists(atPath: resolved) else {
                results.append(AddResult(path: path, success: false, updated: false, item: nil, error: "no such file"))
                continue
            }
            let fileName = URL(fileURLWithPath: resolved).lastPathComponent
            let now = Date()
            let (item, updated) = try dbQueue.write { db -> (InboxItem, Bool) in
                if var existing = try InboxItem.filter(InboxItem.Columns.filePath == resolved).fetchOne(db) {
                    existing.addedAt = now
                    existing.fileExists = true
                    try existing.update(db)
                    return (existing, true)
                } else {
                    var newItem = InboxItem(filePath: resolved, fileName: fileName, addedAt: now)
                    try newItem.insert(db)
                    return (newItem, false)
                }
            }
            results.append(AddResult(path: path, success: true, updated: updated, item: item, error: nil))
        }
        try evictIfNeeded()
        return results
    }

    public func loadAll() throws -> [InboxItem] {
        try dbQueue.read { db in
            try InboxItem.order(InboxItem.Columns.addedAt.desc).fetchAll(db)
        }
    }

    public func itemCount() throws -> Int {
        try dbQueue.read { db in try InboxItem.fetchCount(db) }
    }

    public func remove(ids: Set<String>) throws {
        _ = try dbQueue.write { db in
            try InboxItem.filter(ids.contains(InboxItem.Columns.id)).deleteAll(db)
        }
    }

    public func removeAll() throws {
        _ = try dbQueue.write { db in try InboxItem.deleteAll(db) }
    }

    public func validateFileExistence() throws {
        try dbQueue.write { db in
            var items = try InboxItem.fetchAll(db)
            for i in items.indices {
                let exists = FileManager.default.fileExists(atPath: items[i].filePath)
                if items[i].fileExists != exists {
                    items[i].fileExists = exists
                    try items[i].update(db)
                }
            }
        }
    }

    static func resolvedAbsolutePath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardized.resolvingSymlinksInPath().path
    }

    private func evictIfNeeded() throws {
        let capacity = HandmeConstants.maxCapacity
        try dbQueue.write { db in
            let count = try InboxItem.fetchCount(db)
            guard count > capacity else { return }
            let toRemove = count - capacity
            let victims = try InboxItem
                .order(InboxItem.Columns.fileExists.asc, InboxItem.Columns.addedAt.asc)
                .limit(toRemove)
                .fetchAll(db)
            for victim in victims {
                try victim.delete(db)
            }
        }
    }
}
