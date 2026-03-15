import SwiftUI
import HandmeCore

struct SettingsView: View {
    @AppStorage(HandmeConstants.maxCapacityKey) private var maxCapacity = HandmeConstants.defaultMaxCapacity
    @State private var cliStatus = CLIInstaller.status()
    @State private var actionResult: String?

    var body: some View {
        Form {
            Section("收件箱") {
                Stepper("容量上限: \(maxCapacity)", value: $maxCapacity, in: 10...1000, step: 10)
            }

            Section("命令行工具") {
                switch cliStatus {
                case .installed(let path):
                    LabeledContent("状态", value: "已安装")
                    LabeledContent("路径", value: path)
                    Button("卸载命令行工具") {
                        switch CLIInstaller.uninstall() {
                        case .success:
                            cliStatus = .notInstalled
                            actionResult = "✓ 已卸载"
                        case .failure(let err):
                            actionResult = "✗ \(err)"
                        case .notFound:
                            cliStatus = .notInstalled
                            actionResult = "✓ 未找到已安装的命令行工具"
                        }
                    }
                case .stale(let path):
                    LabeledContent("状态", value: "需要更新")
                    LabeledContent("路径", value: path)
                    Button("更新命令行工具") { doInstall() }
                case .notInstalled:
                    LabeledContent("状态", value: "未安装")
                    Button("安装 handme 命令") { doInstall() }
                }

                if let result = actionResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("✓") ? .green : .red)
                }
            }

            Section("关于") {
                HStack {
                    Spacer()
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .opacity(0.4)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
            }
        }
        .formStyle(.grouped)
    }

    private func doInstall() {
        switch CLIInstaller.install() {
        case .success(let path):
            cliStatus = .installed(path: path.components(separatedBy: "\n")[0])
            actionResult = "✓ 已安装到 \(path)"
        case .failure(let err):
            actionResult = "✗ \(err)"
        }
    }
}
