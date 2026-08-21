import Foundation

/// 单条日志文件（崩溃报告、jetsam、spin、log 等）
struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let processName: String
    let bundleIdentifier: String?
    let logType: LogType
    let date: Date
    let fileSize: Int64
    /// 概要信息（异常类型/终止原因等），从文件头部解析
    var summary: String

    enum LogType: String, CaseIterable {
        case crash    = "崩溃"
        case jetsam   = "内存终止"
        case wakeups  = "唤醒过载"
        case cpuUsage = "CPU 过载"
        case spin     = "无响应"
        case hang     = "卡顿"
        case analytics = "分析"
        case log      = "日志"
        case unknown  = "其他"

        var symbol: String {
            switch self {
            case .crash:     return "exclamationmark.triangle.fill"
            case .jetsam:    return "memorychip.fill"
            case .wakeups:   return "bolt.fill"
            case .cpuUsage:  return "cpu.fill"
            case .spin:      return "hourglass"
            case .hang:      return "pause.circle.fill"
            case .analytics: return "chart.bar.fill"
            case .log:       return "doc.text.fill"
            case .unknown:   return "doc.fill"
            }
        }

        var color: String {
            switch self {
            case .crash:     return "red"
            case .jetsam:    return "orange"
            case .wakeups:   return "yellow"
            case .cpuUsage:  return "pink"
            case .spin:      return "purple"
            case .hang:      return "indigo"
            case .analytics: return "blue"
            case .log:       return "gray"
            case .unknown:   return "secondary"
            }
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
