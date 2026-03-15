import ArgumentParser
import HandmeCore
import Foundation

@main
struct HandmeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "handme",
        abstract: "把文件递给自己",
        version: "0.1.0",
        subcommands: [Add.self, List.self, Clear.self],
        defaultSubcommand: Add.self
    )
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "添加文件到收件箱（默认命令，可省略 add）"
    )
    @Argument(help: "要添加的文件或目录路径")
    var paths: [String]

    func run() throws {
        let store = try InboxStore()
        let results = try store.add(paths: paths)
        var hasError = false
        for result in results {
            if result.success {
                print(OutputFormatter.successLine(result.item!.fileName, updated: result.updated))
            } else {
                print(OutputFormatter.errorLine(result.path, error: result.error ?? "unknown error"))
                hasError = true
            }
        }
        if hasError { throw ExitCode(1) }
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "列出收件箱内容"
    )
    func run() throws {
        let store = try InboxStore()
        try store.validateFileExistence()
        let items = try store.loadAll()
        if items.isEmpty {
            print("收件箱是空的。用 handme <文件> 添加文件。")
            return
        }
        for item in items { print(OutputFormatter.listLine(item)) }
    }
}

struct Clear: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "清空收件箱"
    )
    @Flag(name: .shortAndLong, help: "跳过确认")
    var yes = false

    func run() throws {
        let store = try InboxStore()
        let count = try store.itemCount()
        if count == 0 {
            print("收件箱已经是空的。")
            return
        }
        if !yes {
            print("确认清空收件箱中的 \(count) 个文件？[y/N] ", terminator: "")
            guard let answer = readLine(), answer.lowercased() == "y" else {
                print("取消。")
                return
            }
        }
        try store.removeAll()
        print("✓ 已清空 \(count) 个文件")
    }
}
