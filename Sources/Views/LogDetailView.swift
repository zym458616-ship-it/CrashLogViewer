import SwiftUI

struct LogDetailView: View {
    let log: LogEntry
    @State private var content: String = "加载中…"
    @State private var loaded = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var wrapLines = true
    @State private var fontSize: CGFloat = 12
    @State private var searchText = ""

    var displayContent: String {
        guard !searchText.isEmpty else { return content }
        // 高亮通过过滤行实现（简单版）：只显示包含关键字的行 + 上下文
        let lines = content.components(separatedBy: "\n")
        let matched = lines.enumerated().filter { $0.element.localizedCaseInsensitiveContains(searchText) }
        if matched.isEmpty { return "（未找到匹配「\(searchText)」的行）" }
        return matched.map { "L\($0.offset + 1): \($0.element)" }.joined(separator: "\n")
    }

    var body: some View {
        ScrollView([.vertical, wrapLines ? [] : .horizontal]) {
            Text(displayContent)
                .font(.system(size: fontSize, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: wrapLines ? .infinity : nil, alignment: .leading)
                .padding(12)
                .fixedSize(horizontal: !wrapLines, vertical: false)
        }
        .navigationTitle(log.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "在日志中搜索")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { exportFile() } label: { Label("导出原始文件", systemImage: "doc") }
                    Button { exportAsText() } label: { Label("导出为文本", systemImage: "square.and.arrow.up") }
                    Button {
                        UIPasteboard.general.string = content
                    } label: { Label("复制全部", systemImage: "doc.on.doc") }
                    Divider()
                    Toggle("自动换行", isOn: $wrapLines)
                    Button { fontSize = min(fontSize + 1, 20) } label: { Label("放大字体", systemImage: "textformat.size.larger") }
                    Button { fontSize = max(fontSize - 1, 8) } label: { Label("缩小字体", systemImage: "textformat.size.smaller") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .safeAreaInset(edge: .top) {
            metaBar
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .task {
            if !loaded {
                let path = log.filePath
                let text = await Task.detached(priority: .userInitiated) {
                    LogScanner.shared.readFullLog(at: path)
                }.value
                content = text
                loaded = true
            }
        }
    }

    private var metaBar: some View {
        HStack(spacing: 10) {
            LogTypeBadge(type: log.logType)
            Text(log.formattedDate).font(.caption2)
            Spacer()
            Text(log.formattedSize).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private func exportFile() {
        if let url = LogExporter.exportSingle(log) { shareURL = url; showShare = true }
    }
    private func exportAsText() {
        if let url = LogExporter.exportText(content, name: log.fileName) { shareURL = url; showShare = true }
    }
}
