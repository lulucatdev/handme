import Foundation
import HandmeCore
import Combine

@MainActor
class InboxViewModel: ObservableObject {
    @Published var items: [InboxItem] = []
    @Published var filterText: String = ""
    @Published var selection: Set<String> = []
    @Published private(set) var hasNewItems: Bool = false

    private var store: InboxStore?
    private var monitor: DirectoryMonitor?
    private var validationTimer: Timer?
    private var lastSeenCount: Int = 0

    var filteredItems: [InboxItem] {
        if filterText.isEmpty { return items }
        return items.filter { $0.fileName.localizedCaseInsensitiveContains(filterText) }
    }

    var selectedItems: [InboxItem] {
        items.filter { selection.contains($0.id) }
    }

    func setup() {
        do {
            store = try InboxStore()
            reload()
            lastSeenCount = items.count
            startMonitoring()
            startValidationTimer()
        } catch {
            print("InboxStore init failed: \(error)")
        }
    }

    func tearDown() {
        monitor?.stop()
        monitor = nil
        validationTimer?.invalidate()
        validationTimer = nil
    }

    func reload() {
        guard let store else { return }
        do { items = try store.loadAll() }
        catch { print("Load failed: \(error)") }
    }

    func addPaths(_ paths: [String]) {
        guard let store else { return }
        do {
            _ = try store.add(paths: paths)
            reload()
        } catch { print("Add failed: \(error)") }
    }

    func removeSelected() {
        guard let store, !selection.isEmpty else { return }
        do {
            try store.remove(ids: selection)
            selection.removeAll()
            reload()
        } catch { print("Remove failed: \(error)") }
    }

    func removeAll() {
        guard let store else { return }
        do {
            try store.removeAll()
            selection.removeAll()
            reload()
        } catch { print("Clear failed: \(error)") }
    }

    func markAsRead() {
        hasNewItems = false
        lastSeenCount = items.count
    }

    private func startMonitoring() {
        monitor = DirectoryMonitor(url: HandmeConstants.appSupportDirectory) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let oldCount = self.items.count
                self.reload()
                if self.items.count > oldCount {
                    self.hasNewItems = true
                }
            }
        }
        monitor?.start()
    }

    private func startValidationTimer() {
        validationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let store = self.store else { return }
                try? store.validateFileExistence()
                self.reload()
            }
        }
    }
}
