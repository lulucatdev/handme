import Foundation
import GRDB

public struct InboxItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var filePath: String
    public var fileName: String
    public var addedAt: Date
    public var fileExists: Bool

    public init(
        id: String = UUID().uuidString,
        filePath: String,
        fileName: String,
        addedAt: Date = Date(),
        fileExists: Bool = true
    ) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.addedAt = addedAt
        self.fileExists = fileExists
    }
}

extension InboxItem: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "inbox_items"

    public enum Columns {
        public static let id = Column("id")
        public static let filePath = Column("file_path")
        public static let fileName = Column("file_name")
        public static let addedAt = Column("added_at")
        public static let fileExists = Column("file_exists")
    }

    public init(row: Row) {
        id = row[Columns.id]
        filePath = row[Columns.filePath]
        fileName = row[Columns.fileName]
        addedAt = Date(timeIntervalSince1970: row[Columns.addedAt])
        fileExists = row[Columns.fileExists]
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.filePath] = filePath
        container[Columns.fileName] = fileName
        container[Columns.addedAt] = addedAt.timeIntervalSince1970
        container[Columns.fileExists] = fileExists
    }
}
