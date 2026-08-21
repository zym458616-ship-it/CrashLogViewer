import Foundation

/// 扫描并解析系统崩溃/诊断日志
final class LogScanner {

    static let shared = LogScanner()
    private init() {}

    /// 常见的崩溃/诊断日志目录（越狱/巨魔环境可访问）
    static let logDirectories: [String] = [
        "/var/mobile/Library/Logs/CrashReporter",
        "/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs",
        "/var/mobile/Library/Logs/CrashReporter/Retired",
        "/var/mobile/Library/Logs/CrashReporter/WiFi",
        "/var/mobile/Library/Logs/DiagnosticReports",
        "/private/var/mobile/Library/Logs/CrashReporter",
        "/var/mobile/Library/Logs/AppleSupport",
        "/Library/Logs/CrashReporter",
        "/Library/Logs/DiagnosticReports",
        "/var/root/Library/Logs/CrashReporter",
        "/var/logs/CrashReporter",
        "/var/mobile/Library/Logs",
    ]

    /// 扫描全部日志文件
    func scanAllLogs() -> [LogEntry] {
        var entries: [LogEntry] = []
        let fm = FileManager.default
        var visited = Set<String>()

        for dir in Self.logDirectories {
            guard fm.fileExists(atPath: dir) else { continue }
            collect(in: dir, fm: fm, into: &entries, visited: &visited, depth: 0)
        }

        entries.sort { $0.date > $1.date }
        return entries
    }

    private func collect(in dir: String, fm: FileManager,
                         into entries: inout [LogEntry],
                         visited: inout Set<String>, depth: Int) {
        if depth > 4 { return }              // 限制递归深度
        if visited.contains(dir) { return }
        visited.insert(dir)

        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for item in items {
            let fullPath = (dir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                collect(in: fullPath, fm: fm, into: &entries, visited: &visited, depth: depth + 1)
                continue
            }

            let ext = (item as NSString).pathExtension.lowercased()
            // 在已知崩溃目录内，接受所有文件（不再局限于固定后缀），
            // 避免漏掉命名特殊的巨魔/越狱崩溃文件；仅跳过明显的非日志文件。
            let skip: Set<String> = ["plist", "db", "sqlite", "sqlite-wal", "sqlite-shm", "png", "jpg", "jpeg"]
            if skip.contains(ext) { continue }
            if item.hasPrefix(".") { continue }   // 跳过隐藏文件

            autoreleasepool {
                if let entry = parse(path: fullPath, fileName: item, fm: fm) {
                    entries.append(entry)
                }
            }
        }
    }

    /// 解析单个日志文件的元信息
    private func parse(path: String, fileName: String, fm: FileManager) -> LogEntry? {
        let attrs = try? fm.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modDate = (attrs?[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)

        let type = classifyLog(fileName: fileName)

        // 读取头部用于概要和进程名
        let (processName, bundleID, summary, headerDate) = readHeader(path: path, type: type)

        return LogEntry(
            fileName: fileName,
            filePath: path,
            processName: processName ?? deriveProcessName(from: fileName),
            bundleIdentifier: bundleID,
            logType: type,
            date: headerDate ?? modDate,
            fileSize: size,
            summary: summary
        )
    }

    /// 根据文件名判定日志类型
    private func classifyLog(fileName: String) -> LogEntry.LogType {
        let lower = fileName.lowercased()
        if lower.contains("jetsam") { return .jetsam }
        if lower.contains("wakeups") { return .wakeups }
        if lower.contains("cpu_resource") || lower.contains("cpu") { return .cpuUsage }
        if lower.contains("spin") { return .spin }
        if lower.contains("hang") { return .hang }
        if lower.contains(".synced") || lower.contains("analytics") { return .analytics }
        if lower.hasSuffix(".ips") || lower.hasSuffix(".crash") || lower.hasSuffix(".beta") || lower.hasSuffix(".panic") { return .crash }
        if lower.hasSuffix(".log") || lower.hasSuffix(".stacks") { return .log }
        return .unknown
    }

    private func deriveProcessName(from fileName: String) -> String {
        // 形如 ProcessName-2024-01-01-120000.ips
        let base = (fileName as NSString).deletingPathExtension
        if let dashRange = base.range(of: "-", options: .backwards) {
            let candidate = String(base[..<dashRange.lowerBound])
            // 继续去掉日期段
            if let firstDate = candidate.range(of: "-20") {
                return String(candidate[..<firstDate.lowerBound])
            }
            return candidate
        }
        return base
    }

    /// 读取文件头部，抽取进程名、bundleID、概要及时间
    private func readHeader(path: String, type: LogEntry.LogType)
        -> (String?, String?, String, Date?) {

        guard let handle = FileHandle(forReadingAtPath: path) else {
            return (nil, nil, "无法读取", nil)
        }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: 16384)  // 读多一点以覆盖 payload 内的 bundleID
        guard let text = String(data: data, encoding: .utf8) else {
            return (nil, nil, "二进制内容", nil)
        }

        // 新版 .ips 为多行 JSON：第 1 行 header（app_name/bug_type/...），
        // 第 2 行 payload（含 bundleID/procName/exception 等）
        if let firstBrace = text.firstIndex(of: "{") {
            let jsonPart = String(text[firstBrace...])
            if let parsed = parseIPSHeader(jsonPart) {
                return parsed
            }
        }

        // 旧版纯文本格式
        return parsePlainText(text: text)
    }

    /// 解析 .ips 的 JSON（第 1 行 header + 第 2 行 payload 合并取值）
    private func parseIPSHeader(_ jsonPart: String)
        -> (String?, String?, String, Date?)? {

        // .ips 通常是两段独立 JSON：header 在第 1 行，payload 在其后
        let lines = jsonPart.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let firstLine = lines.first,
              let d = firstLine.data(using: .utf8),
              let header = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            return nil
        }

        // 尝试解析 payload（第 2 段起，可能多行）——bundleID/procName 常在这里
        var payload: [String: Any] = [:]
        if lines.count > 1 {
            let rest = lines.dropFirst().joined(separator: "\n")
            if let firstBrace = rest.firstIndex(of: "{"),
               let pd = String(rest[firstBrace...]).data(using: .utf8),
               let p = try? JSONSerialization.jsonObject(with: pd) as? [String: Any] {
                payload = p
            }
        }

        func pick(_ keys: [String]) -> String? {
            for k in keys {
                if let v = header[k] as? String, !v.isEmpty { return v }
                if let v = payload[k] as? String, !v.isEmpty { return v }
            }
            return nil
        }

        let proc = pick(["app_name", "procName", "name", "process"])
        // 注意：bug_type 是崩溃类型编号（如 "309"），不是 BundleID，绝不能当作 bundleID
        let bundleID = pick(["bundleID", "bundleId", "coalitionName"])

        var summaryParts: [String] = []
        if let bugType = header["bug_type"] as? String { summaryParts.append("类型 \(bugType)") }
        // 异常/终止原因（来自 payload）
        if let ex = payload["exception"] as? [String: Any] {
            if let t = ex["type"] as? String { summaryParts.append(t) }
            if let sig = ex["signal"] as? String { summaryParts.append(sig) }
        }
        if let term = payload["termination"] as? [String: Any],
           let reason = term["namespace"] as? String {
            summaryParts.append(reason)
        }
        if let ver = pick(["app_version"]) { summaryParts.append("v\(ver)") }
        if let os = pick(["os_version"]) { summaryParts.append(os) }

        var date: Date? = nil
        if let ts = (header["timestamp"] as? String) ?? (payload["captureTime"] as? String) {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = f.date(from: ts) ?? {
                let f2 = DateFormatter()
                f2.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
                return f2.date(from: ts)
            }()
        }

        let summary = summaryParts.isEmpty ? "崩溃报告" : summaryParts.joined(separator: " · ")
        return (proc, bundleID, summary, date)
    }

    /// 解析旧版纯文本崩溃日志头
    private func parsePlainText(text: String) -> (String?, String?, String, Date?) {
        var proc: String?
        var bundleID: String?
        var exception: String?
        var termination: String?

        for raw in text.split(separator: "\n").prefix(40) {
            let line = String(raw)
            if proc == nil, line.hasPrefix("Process:") {
                proc = value(after: "Process:", in: line)
            } else if bundleID == nil, line.hasPrefix("Identifier:") {
                bundleID = value(after: "Identifier:", in: line)
            } else if exception == nil, line.hasPrefix("Exception Type:") {
                exception = value(after: "Exception Type:", in: line)
            } else if termination == nil, line.hasPrefix("Termination Reason:") {
                termination = value(after: "Termination Reason:", in: line)
            }
        }

        var parts: [String] = []
        if let e = exception { parts.append(e) }
        if let t = termination { parts.append(t) }
        let summary = parts.isEmpty ? "崩溃报告" : parts.joined(separator: " · ")
        return (proc, bundleID, summary, nil)
    }

    private func value(after key: String, in line: String) -> String? {
        guard let range = line.range(of: key) else { return nil }
        var v = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        // Process 行常为 "Name [pid]"
        if let bracket = v.range(of: " [") {
            v = String(v[..<bracket.lowerBound])
        }
        return v.isEmpty ? nil : v
    }

    /// 读取完整日志正文
    func readFullLog(at path: String) -> String {
        guard let data = FileManager.default.contents(atPath: path) else {
            return "无法读取文件：\(path)"
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        return "（二进制内容，共 \(data.count) 字节，无法以文本显示）"
    }
}
