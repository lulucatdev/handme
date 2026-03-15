import Foundation

enum CLIInstaller {
    enum Status {
        case installed(path: String)
        case stale(path: String)
        case notInstalled
    }

    enum InstallResult {
        case success(String)
        case failure(String)
    }

    enum UninstallResult {
        case success
        case failure(String)
        case notFound
    }

    private static let searchPaths = [
        "/usr/local/bin/handme",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/handme"
    ]

    static func status() -> Status {
        let expectedTarget = Bundle.main.path(forResource: "handme", ofType: nil)
        for path in searchPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
                if target == expectedTarget { return .installed(path: path) }
                else { return .stale(path: path) }
            }
            return .installed(path: path)
        }
        return .notInstalled
    }

    static func install() -> InstallResult {
        guard let bundleCLI = Bundle.main.path(forResource: "handme", ofType: nil) else {
            return .failure("CLI 二进制未找到（请先构建项目）")
        }
        let primaryPath = "/usr/local/bin/handme"
        if canCreateSymlink(at: primaryPath, from: bundleCLI) { return .success(primaryPath) }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fallbackDir = "\(home)/.local/bin"
        let fallbackPath = "\(fallbackDir)/handme"
        try? FileManager.default.createDirectory(atPath: fallbackDir, withIntermediateDirectories: true)
        if canCreateSymlink(at: fallbackPath, from: bundleCLI) {
            let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
            if !pathEnv.contains(fallbackDir) {
                return .success("\(fallbackPath)\n⚠ ~/.local/bin 不在 PATH 中。请添加：export PATH=\"$HOME/.local/bin:$PATH\"")
            }
            return .success(fallbackPath)
        }
        return .failure("无法创建符号链接。请手动运行：ln -s \"\(bundleCLI)\" /usr/local/bin/handme")
    }

    static func uninstall() -> UninstallResult {
        for path in searchPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            do {
                try FileManager.default.removeItem(atPath: path)
                return .success
            } catch {
                return .failure("无法删除 \(path)。请手动运行：rm \(path)")
            }
        }
        return .notFound
    }

    private static func canCreateSymlink(at destination: String, from source: String) -> Bool {
        if FileManager.default.fileExists(atPath: destination) {
            do { try FileManager.default.removeItem(atPath: destination) }
            catch { return false }
        }
        do {
            try FileManager.default.createSymbolicLink(atPath: destination, withDestinationPath: source)
            return true
        } catch { return false }
    }
}
