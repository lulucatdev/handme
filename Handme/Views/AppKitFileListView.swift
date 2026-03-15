import AppKit
import SwiftUI
import HandmeCore

/// AppKit NSTableView bridged into SwiftUI for native file list behavior:
/// single/multi selection, double-click to open, drag files to other apps.
struct AppKitFileListView: NSViewRepresentable {
    let items: [InboxItem]
    @Binding var selection: Set<String>
    var onDoubleClick: (InboxItem) -> Void
    var onDelete: () -> Void
    var contextMenuProvider: ([InboxItem]) -> NSMenu

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let tableView = NSTableView()
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.headerView = nil
        tableView.rowHeight = 52
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = []
        tableView.selectionHighlightStyle = .regular

        // Drag support
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.registerForDraggedTypes([.fileURL])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleClick(_:))
        tableView.target = context.coordinator
        tableView.menu = NSMenu()
        tableView.menu?.delegate = context.coordinator

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = scrollView.documentView as? NSTableView else { return }

        let oldItems = context.coordinator.cachedItems
        context.coordinator.cachedItems = items

        if oldItems.map(\.id) != items.map(\.id) {
            tableView.reloadData()
        } else {
            // Update changed rows in place
            for (i, item) in items.enumerated() {
                if i < oldItems.count && oldItems[i] != item {
                    tableView.reloadData(forRowIndexes: IndexSet(integer: i), columnIndexes: IndexSet(integer: 0))
                }
            }
        }

        // Sync selection from SwiftUI to AppKit
        context.coordinator.isSyncing = true
        let newSelection = NSMutableIndexSet()
        for (i, item) in items.enumerated() {
            if selection.contains(item.id) {
                newSelection.add(i)
            }
        }
        if tableView.selectedRowIndexes != newSelection as IndexSet {
            tableView.selectRowIndexes(newSelection as IndexSet, byExtendingSelection: false)
        }
        context.coordinator.isSyncing = false
    }

    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        var parent: AppKitFileListView
        var tableView: NSTableView?
        var cachedItems: [InboxItem] = []
        var isSyncing = false

        init(parent: AppKitFileListView) {
            self.parent = parent
        }

        // MARK: - DataSource

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < parent.items.count else { return nil }
            let item = parent.items[row]

            let cellID = NSUserInterfaceItemIdentifier("FileCell")
            let cell: FileTableCellView
            if let existing = tableView.makeView(withIdentifier: cellID, owner: nil) as? FileTableCellView {
                cell = existing
            } else {
                cell = FileTableCellView()
                cell.identifier = cellID
            }
            cell.configure(with: item)
            return cell
        }

        // MARK: - Drag Source

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
            guard row < parent.items.count else { return nil }
            let item = parent.items[row]
            return URL(fileURLWithPath: item.filePath) as NSURL
        }

        // MARK: - Drop Target

        func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            if info.draggingSource as? NSTableView === tableView { return [] }
            tableView.setDropRow(-1, dropOperation: .on)
            return .copy
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] else { return false }
            let paths = urls.map(\.path)
            Task { @MainActor in
                (NSApplication.shared.delegate as? AppDelegate)?.viewModel?.addPaths(paths)
            }
            return true
        }

        // MARK: - Selection

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncing, let tableView else { return }
            var newSelection = Set<String>()
            for row in tableView.selectedRowIndexes {
                if row < parent.items.count {
                    newSelection.insert(parent.items[row].id)
                }
            }
            parent.selection = newSelection
        }

        // MARK: - Double Click

        @objc func tableViewDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0 && row < parent.items.count else { return }
            parent.onDoubleClick(parent.items[row])
        }

        // MARK: - Context Menu

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let tableView else { return }
            let clickedRow = tableView.clickedRow
            guard clickedRow >= 0 && clickedRow < parent.items.count else { return }

            // If clicked row is in selection, use selection; otherwise use just clicked row
            let targetItems: [InboxItem]
            if tableView.selectedRowIndexes.contains(clickedRow) {
                targetItems = tableView.selectedRowIndexes.compactMap { row in
                    row < parent.items.count ? parent.items[row] : nil
                }
            } else {
                targetItems = [parent.items[clickedRow]]
            }

            let openItem = NSMenuItem(title: "打开", action: #selector(menuOpen(_:)), keyEquivalent: "")
            openItem.target = self
            openItem.representedObject = parent.items[clickedRow]
            menu.addItem(openItem)

            let revealItem = NSMenuItem(title: "在 Finder 中显示", action: #selector(menuReveal(_:)), keyEquivalent: "")
            revealItem.target = self
            revealItem.representedObject = targetItems
            menu.addItem(revealItem)

            menu.addItem(.separator())

            let copyItem = NSMenuItem(title: "复制", action: #selector(menuCopy(_:)), keyEquivalent: "")
            copyItem.target = self
            copyItem.representedObject = targetItems
            menu.addItem(copyItem)

            let copyPathItem = NSMenuItem(title: "复制路径", action: #selector(menuCopyPath(_:)), keyEquivalent: "")
            copyPathItem.target = self
            copyPathItem.representedObject = targetItems
            menu.addItem(copyPathItem)

            menu.addItem(.separator())

            let removeItem = NSMenuItem(title: "移除", action: #selector(menuRemove(_:)), keyEquivalent: "")
            removeItem.target = self
            menu.addItem(removeItem)
        }

        @objc func menuOpen(_ sender: NSMenuItem) {
            guard let item = sender.representedObject as? InboxItem else { return }
            FileOperations.open(item)
        }

        @objc func menuReveal(_ sender: NSMenuItem) {
            guard let items = sender.representedObject as? [InboxItem] else { return }
            FileOperations.revealInFinder(items)
        }

        @objc func menuCopy(_ sender: NSMenuItem) {
            guard let items = sender.representedObject as? [InboxItem] else { return }
            FileOperations.copyFiles(items)
        }

        @objc func menuCopyPath(_ sender: NSMenuItem) {
            guard let items = sender.representedObject as? [InboxItem] else { return }
            FileOperations.copyPaths(items)
        }

        @objc func menuRemove(_ sender: NSMenuItem) {
            parent.onDelete()
        }
    }
}

// MARK: - Native Cell View

private class FileTableCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let warningLabel = NSTextField(labelWithString: "")
    private var configured = false

    func configure(with item: InboxItem) {
        if !configured {
            setupSubviews()
            configured = true
        }

        let icon: NSImage
        if item.fileExists {
            icon = NSWorkspace.shared.icon(forFile: item.filePath)
        } else {
            icon = NSWorkspace.shared.icon(for: .data)
        }
        icon.size = NSSize(width: 32, height: 32)
        iconView.image = icon

        nameLabel.stringValue = item.fileName
        timeLabel.stringValue = RelativeTimeFormatter.string(from: item.addedAt)
        pathLabel.stringValue = PathFormatter.shortened(item.filePath)

        let alpha: CGFloat = item.fileExists ? 1.0 : 0.5
        iconView.alphaValue = alpha
        nameLabel.alphaValue = alpha
        pathLabel.alphaValue = alpha

        if item.fileExists {
            warningLabel.isHidden = true
        } else {
            warningLabel.isHidden = false
            warningLabel.stringValue = "⚠ 文件已不存在"
        }
    }

    private func setupSubviews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1

        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.maximumNumberOfLines = 1

        warningLabel.font = .systemFont(ofSize: 10)
        warningLabel.textColor = .systemOrange
        warningLabel.isHidden = true

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(timeLabel)
        addSubview(pathLabel)
        addSubview(warningLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            warningLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            warningLabel.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 1),
        ])
    }
}
