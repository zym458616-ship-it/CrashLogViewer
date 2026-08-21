import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var store: LogStore
    @State private var showShare = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            List {
                Section("概览") {
                    InfoRow(label: "已安装应用", value: "\(store.apps.count) 个")
                    InfoRow(label: "日志总数", value: "\(store.logs.count) 条")
                    InfoRow(label: "崩溃报告", value: "\(store.crashCount) 条")
                    InfoRow(label: "日志占用空间",
                            value: ByteCountFormatter.string(fromByteCount: store.totalLogSize, countStyle: .file))
                }

                Section {
                    ForEach(store.accessibleDirectories, id: \.self) { dir in
                        HStack {
                            Label(dir, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.footnote.monospaced())
                            Spacer()
                            Text("\(store.directoryFileCounts[dir] ?? 0)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if store.accessibleDirectories.isEmpty {
                        Text("无可访问日志目录").foregroundColor(.secondary)
                    }
                } header: {
                    Text("可访问目录 (\(store.accessibleDirectories.count)) · 右侧为文件数")
                }

                Section {
                    ForEach(store.inaccessibleDirectories, id: \.self) { dir in
                        Label(dir, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.footnote.monospaced())
                    }
                    if store.inaccessibleDirectories.isEmpty {
                        Text("全部目录均可访问").foregroundColor(.secondary)
                    }
                } header: {
                    Text("不可访问 / 不存在 (\(store.inaccessibleDirectories.count))")
                } footer: {
                    Text("若关键目录不可访问，请确认已通过巨魔安装并授予相应 entitlements，或在越狱环境以合适权限运行。")
                }

                Section("未归属日志") {
                    let unmatched = store.unmatchedLogs
                    InfoRow(label: "数量", value: "\(unmatched.count) 条（属于系统进程或已卸载应用）")
                    NavigationLink("查看未归属日志") {
                        UnmatchedLogsView()
                    }
                }

                Section {
                    Button {
                        if let url = LogExporter.exportBundle(store.logs, bundleName: "FullDiagnostics") {
                            shareURL = url; showShare = true
                        }
                    } label: {
                        Label("导出全部日志打包", systemImage: "square.and.arrow.up.on.square.fill")
                    }
                }

                Section {
                    Text("崩溃日志查看器 v1.0.0\n适用于越狱 / TrollStore 环境\n未签名构建，需自行签名或以巨魔安装。")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("诊断")
            .sheet(isPresented: $showShare) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct UnmatchedLogsView: View {
    @EnvironmentObject var store: LogStore
    var body: some View {
        List {
            ForEach(store.unmatchedLogs) { log in
                NavigationLink(destination: LogDetailView(log: log)) {
                    LogRow(log: log)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("未归属日志")
        .navigationBarTitleDisplayMode(.inline)
    }
}
