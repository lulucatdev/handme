import SwiftUI
import HandmeCore
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case files
    case settings
}

struct ContentView: View {
    @StateObject private var viewModel = InboxViewModel()
    @State private var sidebarSelection: SidebarItem? = .files
    @State private var showClearConfirmation = false
    @State private var quickLookResponder = QuickLookResponder()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Label("全部文件", systemImage: "tray.full")
                    .tag(SidebarItem.files)
                Label("设置", systemImage: "gear")
                    .tag(SidebarItem.settings)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 170, max: 240)
        } detail: {
            switch sidebarSelection {
            case .files, .none:
                filesDetail
            case .settings:
                SettingsView()
                    .navigationTitle("设置")
            }
        }
        .background(QuickLookBridgeView(responder: quickLookResponder).frame(width: 0, height: 0))
        .onAppear {
            viewModel.setup()
            viewModel.markAsRead()
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.viewModel = viewModel
                appDelegate.openMainWindow = { [openWindow] in openWindow(id: "main") }
            }
        }
        .onDisappear {
            viewModel.tearDown()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .alert("清空收件箱", isPresented: $showClearConfirmation) {
            Button("清空", role: .destructive) { viewModel.removeAll() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要清空收件箱中的 \(viewModel.items.count) 个文件吗？\n这不会删除原文件。")
        }
        .onKeyPress(.return) {
            guard sidebarSelection == .files else { return .ignored }
            if let first = viewModel.selectedItems.first { FileOperations.open(first) }
            return .handled
        }
        .onKeyPress(.delete) {
            guard sidebarSelection == .files else { return .ignored }
            viewModel.removeSelected()
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .handmeCopyFiles)) { _ in
            FileOperations.copyFiles(viewModel.selectedItems)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handmeCopyPaths)) { _ in
            FileOperations.copyPaths(viewModel.selectedItems)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handmeRevealInFinder)) { _ in
            FileOperations.revealInFinder(viewModel.selectedItems)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handmeQuickLook)) { _ in
            quickLookResponder.togglePreview(for: viewModel.selectedItems)
        }
    }

    private var filesDetail: some View {
        Group {
            if viewModel.items.isEmpty && viewModel.filterText.isEmpty {
                EmptyStateView()
            } else {
                fileListView
            }
        }
        .frame(minWidth: 320, minHeight: 400)
        .navigationTitle("全部文件")
    }

    private var fileListView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("过滤...", text: $viewModel.filterText)
                    .textFieldStyle(.plain)
                Spacer()
                Button("清空") { showClearConfirmation = true }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            AppKitFileListView(
                items: viewModel.filteredItems,
                selection: $viewModel.selection,
                onDoubleClick: { FileOperations.open($0) },
                onDelete: { viewModel.removeSelected() },
                contextMenuProvider: { _ in NSMenu() }
            )

            Divider()

            HStack {
                Text("\(viewModel.filteredItems.count) 个文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in viewModel.addPaths([url.path]) }
            }
        }
    }
}


extension Notification.Name {
    static let handmeCopyFiles = Notification.Name("handmeCopyFiles")
    static let handmeCopyPaths = Notification.Name("handmeCopyPaths")
    static let handmeRevealInFinder = Notification.Name("handmeRevealInFinder")
    static let handmeQuickLook = Notification.Name("handmeQuickLook")
}
