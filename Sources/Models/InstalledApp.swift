import Foundation

/// 已安装 App 的信息模型
struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let executableName: String
    let version: String
    let build: String
    let bundlePath: String
    let dataContainerPath: String?
    let appType: AppSourceType
    let iconData: Data?

    /// 与该 App 关联的崩溃/日志文件数量（延迟填充）
    var logCount: Int = 0

    enum AppSourceType: String {
        case appStore   = "App Store"
        case trollStore = "TrollStore"
        case system     = "系统"
        case user       = "用户"
        case unknown    = "未知"

        var symbol: String {
            switch self {
            case .appStore:   return "bag.fill"
            case .trollStore: return "hammer.fill"
            case .system:     return "gearshape.fill"
            case .user:       return "app.fill"
            case .unknown:    return "questionmark.app"
            }
        }
    }
}
