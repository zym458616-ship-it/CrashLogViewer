import Foundation
import Combine

/// 全局数据管理：扫描 App 与日志、建立关联、过滤
@MainActor
final class LogStore: ObservableObject {

    @Published var apps: [InstalledApp] = []
    @Published var logs: [LogEntry] = []
    @Published var isScanning = false
    @Published var scanProgress = ""
    @Published var accessibleDirectories: [String] = []
    @Published var inaccessibleDirectories: [String] = []

    /// 进程名 → App 的映射，用于把日志归属到 App
    private var processIndex: [String: InstalledApp] = [:]
    private var bundleIndex: [String: InstalledApp] = [:]

    func refresh() async {
        isScanning = true
        scanProgress = "正在枚举已安装 App…"

        let scannedApps = await Task.detached(priority: .userInitiated) {
            AppScanner.shared.scanInstalledApps()
        }.value

        scanProgress = "正在扫描崩溃日志…"
        let scannedLogs = await Task.detached(priority: .userInitiated) {
            LogScanner.shared.scanAllLogs()
        }.value

        // 建立索引
        var pIndex: [String: InstalledApp] = [:]
        var bIndex: [String: InstalledApp] = [:]
        for app in scannedApps {
            bIndex[app.bundleIdentifier] = app
            pIndex[app.executableName] = app
            pIndex[app.name] = app
        }
        self.processIndex = pIndex
        self.bundleIndex = bIndex

        // 统计每个 App 的日志数量
        var counts: [String: Int] = [:]
        for log in scannedLogs {
            if let app = matchApp(for: log) {
                counts[app.bundleIdentifier, default: 0] += 1
            }
        }
        var appsWithCounts = scannedApps
        for i in appsWithCounts.indices {
            appsWithCounts[i].logCount = counts[appsWithCounts[i].bundleIdentifier] ?? 0
        }

        // 目录可访问性诊断
        var ok: [String] = []
        var bad: [String] = []
        let fm = FileManager.default
        for dir in LogScanner.logDirectories {
            if fm.fileExists(atPath: dir), (try? fm.contentsOfDirectory(atPath: dir)) != nil {
                ok.append(dir)
            } else {
                bad.append(dir)
            }
        }

        self.apps = appsWithCounts
        self.logs = scannedLogs
        self.accessibleDirectories = ok
        self.inaccessibleDirectories = bad
        self.scanProgress = ""
        self.isScanning = false
    }

    /// 将日志匹配到 App
    func matchApp(for log: LogEntry) -> InstalledApp? {
        if let bid = log.bundleIdentifier, let app = bundleIndex[bid] { return app }
        if let app = processIndex[log.processName] { return app }
        return nil
    }

    /// 某个 App 的全部日志
    func logs(for app: InstalledApp) -> [LogEntry] {
        logs.filter { log in
            if let bid = log.bundleIdentifier, bid == app.bundleIdentifier { return true }
            return log.processName == app.executableName || log.processName == app.name
        }
    }

    /// 未能归属到已安装 App 的日志（系统进程等）
    var unmatchedLogs: [LogEntry] {
        logs.filter { matchApp(for: $0) == nil }
    }

    // 统计信息
    var totalLogSize: Int64 { logs.reduce(0) { $0 + $1.fileSize } }
    var crashCount: Int { logs.filter { $0.logType == .crash }.count }
}
