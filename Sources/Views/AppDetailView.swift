import SwiftUI

struct AppDetailView: View {
    @EnvironmentObject var store: LogStore
    let app: InstalledApp
    @State private var showShare = false
    @State private var shareURL: URL?

    var appLogs: [LogEntry] { store.logs(for: app) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    AppIconView(app: app, size: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.name).font(.title3.bold())
                        Text("版本 \(app.version) (\(app.build))")
                            .font(.subheadline).foregroundColor(.secondary)
                        SourceBadge(type: app.appType)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("信息") {
                InfoRow(label: "Bundle ID", value: app.bundleIdentifier)
                InfoRow(label: "可执行文件", value: app.executableName)
                InfoRow(label: "安装路径", value: app.bundlePath)
                if let dc = app.dataContainerPath {
                    InfoRow(label: "数据容器", value: dc)
                }
            }

            Section {
                if appLogs.isEmpty {
                    Text("该应用暂无崩溃或诊断日志")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(appLogs) { log in
                        NavigationLink(destination: LogDetailView(log: log)) {
                            LogRow(log: log, showProcess: false)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("日志 (\(appLogs.count))")
                    Spacer()
                    if !appLogs.isEmpty {
                        Button {
                            exportAll()
                        } label: {
                            Label("导出全部", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
    }

    private func exportAll() {
        if let url = LogExporter.exportBundle(appLogs, bundleName: "\(app.name)-Logs") {
            shareURL = url
            showShare = true
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.footnote.monospaced()).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

struct LogRow: View {
    let log: LogEntry
    var showProcess: Bool = true
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.logType.symbol)
                .foregroundColor(log.logType.uiColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                if showProcess {
                    Text(log.processName).font(.body.weight(.medium)).lineLimit(1)
                }
                Text(log.summary).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    LogTypeBadge(type: log.logType)
                    Text(log.formattedDate).font(.caption2).foregroundColor(.secondary)
                    Text(log.formattedSize).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}
