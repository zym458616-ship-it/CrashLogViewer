import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: LogStore

    var body: some View {
        TabView {
            AppListView()
                .tabItem { Label("应用", systemImage: "square.grid.2x2.fill") }

            AllLogsView()
                .tabItem { Label("全部日志", systemImage: "list.bullet.rectangle.fill") }

            DiagnosticsView()
                .tabItem { Label("诊断", systemImage: "stethoscope") }
        }
    }
}
