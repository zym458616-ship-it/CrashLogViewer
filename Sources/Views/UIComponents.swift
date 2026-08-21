import SwiftUI

/// LogType 颜色映射
extension LogEntry.LogType {
    var uiColor: Color {
        switch self {
        case .crash:     return .red
        case .jetsam:    return .orange
        case .wakeups:   return .yellow
        case .cpuUsage:  return .pink
        case .spin:      return .purple
        case .hang:      return .indigo
        case .analytics: return .blue
        case .log:       return .gray
        case .unknown:   return .secondary
        }
    }
}

/// App 图标视图（支持私有目录读取的 PNG，或占位符）
struct AppIconView: View {
    let app: InstalledApp
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = app.iconData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .fill(LinearGradient(colors: [colorFor(app.name).opacity(0.8),
                                                     colorFor(app.name)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                    Text(String(app.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay(RoundedRectangle(cornerRadius: size * 0.22)
            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func colorFor(_ s: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        let idx = abs(s.hashValue) % colors.count
        return colors[idx]
    }
}

/// 类型标签
struct LogTypeBadge: View {
    let type: LogEntry.LogType
    var body: some View {
        Label(type.rawValue, systemImage: type.symbol)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(type.uiColor.opacity(0.15))
            .foregroundColor(type.uiColor)
            .clipShape(Capsule())
    }
}

/// 来源标签
struct SourceBadge: View {
    let type: InstalledApp.AppSourceType
    var body: some View {
        Label(type.rawValue, systemImage: type.symbol)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
}

/// UIActivityViewController 包装，用于导出/分享
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
