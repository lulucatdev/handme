import SwiftUI
import HandmeCore

@main
struct HandmeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        HandmeConstants.registerDefaults()
    }

    var body: some Scene {
        Window("Handme", id: "main") {
            ContentView()
        }
        .defaultSize(width: 480, height: 600)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("复制路径") {
                    NotificationCenter.default.post(name: .handmeCopyPaths, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("在 Finder 中显示") {
                    NotificationCenter.default.post(name: .handmeRevealInFinder, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("QuickLook") {
                    NotificationCenter.default.post(name: .handmeQuickLook, object: nil)
                }
                .keyboardShortcut(" ", modifiers: [])
            }
        }

        Settings {
            Text("Settings placeholder")
                .frame(width: 300, height: 200)
        }
    }
}
