import SwiftUI
import HandmeCore
import UniformTypeIdentifiers

struct FileRowView: View {
    let item: InboxItem

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.fileName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Text(RelativeTimeFormatter.string(from: item.addedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(PathFormatter.shortened(item.filePath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.fileExists {
                    Label("文件已不存在", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .opacity(item.fileExists ? 1.0 : 0.5)
        .padding(.vertical, 4)
    }

    private var iconImage: NSImage {
        if item.fileExists {
            return NSWorkspace.shared.icon(forFile: item.filePath)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}
