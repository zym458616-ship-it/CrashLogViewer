import SwiftUI

struct AllLogsView: View {
    @EnvironmentObject var store: LogStore
    @State private var searchText = ""
    @State private var typeFilter: LogEntry.LogType?
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var selectMode = false
    @State private var selected = Set<UUID>()

    var filtered: [LogEntry] {
        store.logs.filter { log in
            let matchSearch = searchText.isEmpty ||
                log.processName.localizedCaseInsensitiveContains(searchText) ||
                log.summary.localizedCaseInsensitiveContains(searchText) ||
                (log.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchType = typeFilter == nil || log.logType == typeFilter
            return matchSearch && matchType
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.isScanning {
                    ScanningView(text: store.scanProgress)
                } else if store.logs.isEmpty {
                    EmptyLogsView()
                } else {
                    List(selection: $selected) {
                        typeFilterBar
                        Section("\(filtered.count) 条日志") {
                            ForEach(filtered) { log in
                                if selectMode {
                                    LogRow(log: log).tag(log.id)
                                } else {
                                    NavigationLink(destination: LogDetailView(log: log)) {
                                        LogRow(log: log)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, .constant(selectMode ? .active : .inactive))
                }
            }
            .navigationTitle("全部日志")
            .searchable(text: $searchText, prompt: "搜索进程 / 概要 / Bundle ID")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectMode {
                        Button("完成") { selectMode = false; selected.removeAll() }
                    } else {
                        Menu {
                            Button {
                                selectMode = true
                            } label: { Label("多选导出", systemImage: "checkmark.circle") }
                            Button {
                                exportAll()
                            } label: { Label("导出全部日志", systemImage: "square.and.arrow.up.on.square") }
                            Button {
                                Task { await store.refresh() }
                            } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                if selectMode {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            exportSelected()
                        } label: {
                            Label("导出所选 (\(selected.count))", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selected.isEmpty)
                    }
                }
            }
            .refreshable { await store.refresh() }
            .sheet(isPresented: $showShare) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", active: typeFilter == nil) { typeFilter = nil }
                ForEach(LogEntry.LogType.allCases, id: \.self) { t in
                    let count = store.logs.filter { $0.logType == t }.count
                    if count > 0 {
                        FilterChip(title: "\(t.rawValue) \(count)", active: typeFilter == t, color: t.uiColor) {
                            typeFilter = (typeFilter == t) ? nil : t
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
    }

    private func exportAll() {
        if let url = LogExporter.exportBundle(store.logs, bundleName: "AllCrashLogs") {
            shareURL = url; showShare = true
        }
    }
    private func exportSelected() {
        let logs = store.logs.filter { selected.contains($0.id) }
        if let url = LogExporter.exportBundle(logs, bundleName: "SelectedLogs") {
            shareURL = url; showShare = true; selectMode = false; selected.removeAll()
        }
    }
}

struct FilterChip: View {
    let title: String
    var active: Bool
    var color: Color = .accentColor
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(active ? color : color.opacity(0.12))
                .foregroundColor(active ? .white : color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyLogsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray").font(.system(size: 54)).foregroundColor(.secondary)
            Text("未发现日志").font(.headline)
            Text("在越狱 / 巨魔环境下，请确认已授予文件系统访问权限，\n且崩溃目录存在日志。可到“诊断”页查看目录可访问性。")
                .font(.footnote).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
