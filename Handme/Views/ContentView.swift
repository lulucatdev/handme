import SwiftUI
import HandmeCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = InboxViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        Group {
            if viewModel.items.isEmpty && viewModel.filterText.isEmpty {
                EmptyStateView()
            } else {
                fileListView
            }
        }
        .frame(minWidth: 320, minHeight: 400)
        .onAppear {
            viewModel.setup()
            viewModel.markAsRead()
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
            if let first = viewModel.selectedItems.first { FileOperations.open(first) }
            return .handled
        }
        .onKeyPress(.delete) {
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

            List(viewModel.filteredItems, selection: $viewModel.selection) { item in
                FileRowView(item: item)
                    .contextMenu { contextMenu(for: item) }
                    .draggable(URL(fileURLWithPath: item.filePath))
            }

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

    @ViewBuilder
    private func contextMenu(for item: InboxItem) -> some View {
        let targets = viewModel.selection.contains(item.id) ? viewModel.selectedItems : [item]
        Button("打开") { FileOperations.open(item) }
        Button("在 Finder 中显示") { FileOperations.revealInFinder(targets) }
        Divider()
        Button("复制") { FileOperations.copyFiles(targets) }
        Button("复制路径") { FileOperations.copyPaths(targets) }
        Divider()
        Button("移除") {
            if !viewModel.selection.contains(item.id) {
                viewModel.selection = [item.id]
            }
            viewModel.removeSelected()
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
