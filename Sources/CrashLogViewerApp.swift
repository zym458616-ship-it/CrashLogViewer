import SwiftUI

@main
struct CrashLogViewerApp: App {
    @StateObject private var store = LogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    await store.refresh()
                }
        }
    }
}
