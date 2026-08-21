import SwiftUI

struct AppListView: View {
    @EnvironmentObject var store: LogStore
    @State private var searchText = ""
    @State private var filter: FilterMode = .all
    @State private var onlyWithLogs = false

    enum FilterMode: String, CaseIterable {
        case all = "全部"
        case appStore = "App Store"
        case trollStore = "巨魔"
        case system = "系统"
    }

    var filteredApps: [InstalledApp] {
        store.apps.filter { app in
            let matchSearch = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            let matchFilter: Bool = {
                switch filter {
                case .all: return true
                case .appStore: return app.appType == .appStore
                case .trollStore: return app.appType == .trollStore
                case .system: return app.appType == .system
                }
            }()
            let matchLogs = !onlyWithLogs || app.logCount > 0
            return matchSearch && matchFilter && matchLogs
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.isScanning {
                    ScanningView(text: store.scanProgress)
                } else {
                    List {
                        summarySection
                        Section {
                            ForEach(filteredApps) { app in
                                NavigationLink(destination: AppDetailView(app: app)) {
                                    AppRow(app: app)
                                }
                            }
                        } header: {
                            Text("\(filteredApps.count) 个应用")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("已安装应用")
            .searchable(text: $searchText, prompt: "搜索名称或 Bundle ID")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("来源", selection: $filter) {
                            ForEach(FilterMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("仅显示有日志的应用", isOn: $onlyWithLogs)
                        Divider()
                        Button {
                            Task { await store.refresh() }
                        } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await store.refresh() }
        }
        .navigationViewStyle(.stack)
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                StatCard(title: "应用", value: "\(store.apps.count)", color: .blue, symbol: "app.badge")
                StatCard(title: "日志", value: "\(store.logs.count)", color: .green, symbol: "doc.text")
                StatCard(title: "崩溃", value: "\(store.crashCount)", color: .red, symbol: "exclamationmark.triangle")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let symbol: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundColor(color)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AppRow: View {
    let app: InstalledApp
    var body: some View {
        HStack(spacing: 12) {
            AppIconView(app: app, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.body.weight(.medium)).lineLimit(1)
                Text(app.bundleIdentifier).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    SourceBadge(type: app.appType)
                    if app.logCount > 0 {
                        Label("\(app.logCount)", systemImage: "doc.text.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.red)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ScanningView: View {
    let text: String
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text(text.isEmpty ? "扫描中…" : text)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
