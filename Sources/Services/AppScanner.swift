import Foundation
import UIKit

/// 使用私有 API LSApplicationWorkspace 枚举所有已安装的 App
final class AppScanner {

    static let shared = AppScanner()
    private init() {}

    /// 扫描全部已安装 App
    func scanInstalledApps() -> [InstalledApp] {
        var results: [InstalledApp] = []

        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return results
        }
        let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue()
        guard let ws = workspace else { return results }

        // allApplications 返回 LSApplicationProxy 数组
        let selector = NSSelectorFromString("allApplications")
        guard ws.responds(to: selector),
              let apps = ws.perform(selector)?.takeUnretainedValue() as? [NSObject] else {
            return results
        }

        for proxy in apps {
            autoreleasepool {
                if let app = buildApp(from: proxy) {
                    results.append(app)
                }
            }
        }

        // 按名称排序
        results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return results
    }

    private func string(_ obj: NSObject, _ key: String) -> String? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.perform(sel)?.takeUnretainedValue() as? String
    }

    private func url(_ obj: NSObject, _ key: String) -> URL? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.perform(sel)?.takeUnretainedValue() as? URL
    }

    private func buildApp(from proxy: NSObject) -> InstalledApp? {
        guard let bundleID = string(proxy, "applicationIdentifier"),
              !bundleID.isEmpty else { return nil }

        let name = string(proxy, "localizedName") ?? bundleID
        let exe  = string(proxy, "bundleExecutable") ?? name
        let version = string(proxy, "shortVersionString") ?? "-"
        let build   = string(proxy, "bundleVersion") ?? "-"
        let bundleURL = url(proxy, "bundleURL")
        let dataURL   = url(proxy, "dataContainerURL")
        let appTypeRaw = string(proxy, "applicationType") ?? ""

        let type = classify(bundleID: bundleID,
                            appType: appTypeRaw,
                            bundlePath: bundleURL?.path)

        // 尝试读取 App 图标
        var iconData: Data? = nil
        if let bp = bundleURL?.path {
            iconData = loadIcon(bundlePath: bp)
        }

        return InstalledApp(
            bundleIdentifier: bundleID,
            name: name,
            executableName: exe,
            version: version,
            build: build,
            bundlePath: bundleURL?.path ?? "-",
            dataContainerPath: dataURL?.path,
            appType: type,
            iconData: iconData
        )
    }

    /// 判定 App 来源类型
    private func classify(bundleID: String, appType: String, bundlePath: String?) -> InstalledApp.AppSourceType {
        // 系统 App
        if appType == "System" || (bundlePath?.hasPrefix("/Applications/") ?? false) {
            return .system
        }
        // TrollStore 安装的 App 通常带 iTunesMetadata 缺失且位于 /var/containers/Bundle/Application
        // 但 App Store 也在同目录。通过是否存在 _TrollStore 标记 / SC_Info 缺失粗略判断。
        if let bp = bundlePath {
            let fm = FileManager.default
            // TrollStore 会写入 iTunesMetadata.plist 但缺少 SC_Info 目录（正版 App Store 有 SC_Info）
            let scInfo = (bp as NSString).appendingPathComponent("SC_Info")
            let trollMark = (bp as NSString).appendingPathComponent("_TrollStore")
            let trollMarkAlt = (bp as NSString).appendingPathComponent("_TrollStoreLite")
            if fm.fileExists(atPath: trollMark) || fm.fileExists(atPath: trollMarkAlt) {
                return .trollStore
            }
            if !fm.fileExists(atPath: scInfo) {
                // 无 SC_Info 且非系统 → 极可能是 TrollStore/侧载
                return .trollStore
            }
        }
        if appType == "User" {
            return .appStore
        }
        return .user
    }

    /// 从 App bundle 读取图标数据
    private func loadIcon(bundlePath: String) -> Data? {
        let fm = FileManager.default
        guard let plistPath = firstExisting([
            (bundlePath as NSString).appendingPathComponent("Info.plist")
        ], fm: fm),
        let plist = NSDictionary(contentsOfFile: plistPath) else { return nil }

        // 解析 CFBundleIcons → 找到最大尺寸图标文件名
        var iconName: String?
        if let icons = plist["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String], let last = files.last {
            iconName = last
        } else if let files = plist["CFBundleIconFiles"] as? [String], let last = files.last {
            iconName = last
        }
        guard let baseName = iconName else { return nil }

        // 常见后缀
        let candidates = [
            "\(baseName)@3x.png", "\(baseName)@2x.png", "\(baseName).png",
            "\(baseName)@2x~ipad.png", "\(baseName)~ipad.png"
        ].map { (bundlePath as NSString).appendingPathComponent($0) }

        if let path = firstExisting(candidates, fm: fm),
           let data = fm.contents(atPath: path) {
            // iOS 图标经过 CgBI 优化，UIImage 可直接解码
            return data
        }
        return nil
    }

    private func firstExisting(_ paths: [String], fm: FileManager) -> String? {
        for p in paths where fm.fileExists(atPath: p) { return p }
        return nil
    }
}
