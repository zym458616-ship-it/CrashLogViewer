import Foundation

/// 日志导出：单文件 / 批量打包
enum LogExporter {

    /// 导出目录
    static var exportDir: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 复制单个日志文件到可分享位置
    static func exportSingle(_ log: LogEntry) -> URL? {
        let dest = exportDir.appendingPathComponent(log.fileName)
        try? FileManager.default.removeItem(at: dest)
        if FileManager.default.fileExists(atPath: log.filePath) {
            try? FileManager.default.copyItem(atPath: log.filePath, toPath: dest.path)
            if FileManager.default.fileExists(atPath: dest.path) { return dest }
        }
        // 回退：读取内容后写出
        let content = LogScanner.shared.readFullLog(at: log.filePath)
        try? content.write(to: dest, atomically: true, encoding: .utf8)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }

    /// 导出纯文本内容为 .txt
    static func exportText(_ content: String, name: String) -> URL? {
        let safe = name.replacingOccurrences(of: "/", with: "_")
        let dest = exportDir.appendingPathComponent("\(safe).txt")
        try? FileManager.default.removeItem(at: dest)
        try? content.write(to: dest, atomically: true, encoding: .utf8)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }

    /// 将多个日志打包为一个 zip（使用系统 NSFileCoordinator 生成目录 zip）
    static func exportBundle(_ logs: [LogEntry], bundleName: String = "CrashLogs") -> URL? {
        let stage = exportDir.appendingPathComponent(bundleName, isDirectory: true)
        try? FileManager.default.removeItem(at: stage)
        try? FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)

        for log in logs {
            let dest = stage.appendingPathComponent(log.fileName)
            if FileManager.default.fileExists(atPath: log.filePath) {
                try? FileManager.default.copyItem(atPath: log.filePath, toPath: dest.path)
            } else {
                let content = LogScanner.shared.readFullLog(at: log.filePath)
                try? content.write(to: dest, atomically: true, encoding: .utf8)
            }
        }

        return zipDirectory(stage, zipName: bundleName)
    }

    /// 使用 NSFileCoordinator 的 forUploading 语义生成 zip
    static func zipDirectory(_ directory: URL, zipName: String) -> URL? {
        let coordinator = NSFileCoordinator()
        var zipURL: URL?
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: directory,
                              options: [.forUploading],
                              error: &coordError) { tmpURL in
            let dest = exportDir.appendingPathComponent("\(zipName).zip")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: tmpURL, to: dest)
                zipURL = dest
            } catch {
                zipURL = nil
            }
        }
        return zipURL
    }
}
