import Foundation

public enum HandmeConstants {
    public static let appName = "Handme"
    public static let defaultMaxCapacity = 100
    public static let busyTimeoutMs = 3000
    public static let maxCapacityKey = "maxCapacity"

    public static var appSupportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var databasePath: String {
        appSupportDirectory.appendingPathComponent("inbox.db").path
    }

    public static var maxCapacity: Int {
        let val = UserDefaults.standard.integer(forKey: maxCapacityKey)
        return val > 0 ? val : defaultMaxCapacity
    }

    public static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            maxCapacityKey: defaultMaxCapacity
        ])
    }
}
