import SwiftUI

struct EmptyStateView: View {
    @State private var installResult: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("收件箱是空的")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("在终端中使用：")
                    .foregroundStyle(.secondary)
                Text("handme report.pdf")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary)
                    .cornerRadius(6)
            }

            if case .notInstalled = CLIInstaller.status() {
                Divider().frame(width: 200)
                Button("安装 handme 命令") {
                    let result = CLIInstaller.install()
                    switch result {
                    case .success(let path): installResult = "✓ 已安装到 \(path)"
                    case .failure(let err): installResult = "✗ \(err)"
                    }
                }
                .buttonStyle(.borderedProminent)
            } else if case .stale = CLIInstaller.status() {
                Divider().frame(width: 200)
                Button("更新 handme 命令") {
                    let result = CLIInstaller.install()
                    switch result {
                    case .success(let path): installResult = "✓ 已更新到 \(path)"
                    case .failure(let err): installResult = "✗ \(err)"
                    }
                }
                .buttonStyle(.bordered)
            }

            if let result = installResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("✓") ? .green : .red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
