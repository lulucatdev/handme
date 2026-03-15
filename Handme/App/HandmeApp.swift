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
            Text("Handme — Loading...")
                .frame(minWidth: 320, minHeight: 400)
        }
        .defaultSize(width: 480, height: 600)

        Settings {
            Text("Settings placeholder")
                .frame(width: 300, height: 200)
        }
    }
}
