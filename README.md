# CrashLogViewer · 崩溃日志查看器

适用于 **越狱 / TrollStore（巨魔）** 环境的 iOS 应用，用于查看设备上所有已安装 App（App Store / TrollStore / 系统）的崩溃与诊断日志。

## 功能

- **应用列表**：通过 `LSApplicationWorkspace` 枚举全部已安装 App，显示图标、名称、Bundle ID、版本、来源（App Store / 巨魔 / 系统），并统计每个 App 的日志数量。支持按来源筛选、按名称/Bundle ID 搜索、仅显示有日志的 App。
- **日志详情**：解析 `/var/mobile/Library/Logs/CrashReporter` 等目录下的 `.ips` / `.crash` / `.jetsam` / `.spin` / `.hang` 等文件，自动识别类型（崩溃 / 内存终止 / 唤醒过载 / CPU 过载 / 无响应 / 卡顿 / 分析 / 日志），并从文件头解析异常类型、进程名、时间、版本等概要。
- **全部日志**：按类型彩色筛选、全文搜索、时间倒序排列。
- **日志查看器**：等宽字体、行内搜索过滤、自动换行开关、字体缩放、一键复制。
- **导出**：单文件导出原始 `.ips`、导出为文本、多选批量打包 zip、按 App 导出、全部日志打包导出（通过系统分享面板）。
- **诊断页**：显示统计信息、日志目录可访问性检查、未归属日志、一键全量导出。

## 构建（无需 Mac）

本仓库通过 GitHub Actions 在 macOS runner 上使用 XcodeGen + xcodebuild 编译，产出**未签名 IPA**。

1. push 到 `main` 分支（或手动触发 workflow）。
2. Actions 完成后，在 **Release** 页面或 workflow 的 **Artifacts** 下载 `CrashLogViewer.ipa`。

## 安装

- **TrollStore**：直接用巨魔安装 IPA，会自动应用 `entitlements`，无需签名。
- **越狱**：用 AppSync Unified + 你的签名工具安装，或用 `ldid` 签名后安装。

## 权限说明

App 依赖以下私有 entitlements 访问其它 App 的日志目录：
- `com.apple.crashreporter.access`
- `com.apple.private.security.no-sandbox`
- 绝对路径只读例外 `/`

这些权限仅在越狱 / TrollStore 环境下有效，普通签名安装无法读取其它 App 的沙盒日志。

## CrashCatcher 越狱插件（主动捕获崩溃）

很多闪退（尤其巨魔 App 因签名/权限校验失败被系统在启动阶段 kill、或 watchdog 超时）**不会产生系统 .ips 崩溃日志**，"分析与改进"里也看不到。为此仓库附带一个 `tweak/` 越狱插件 **CrashCatcher**：

- 通过 MobileSubstrate/ElleKit 注入到所有链接 UIKit 的 App。
- 在进程内安装信号处理器（SIGSEGV/SIGABRT/SIGBUS/SIGILL/SIGFPE/SIGTRAP）、`NSSetUncaughtExceptionHandler`。
- 崩溃时主动把详细报告（进程、BundleID、版本、系统、设备、信号/异常、backtrace）写入该 App 自身容器的 `Documents/.CrashCatcher/*.crashlog`。
- CrashLogViewer 会自动扫描每个 App 数据容器内的 `.CrashCatcher` 目录并按容器路径归属到对应 App。

构建：push 到 `main`（改动 `tweak/**` 时）或手动触发 `Build CrashCatcher Tweak` workflow，在 Ubuntu 上用 Theos 编译出 `.deb`，随 release 发布。用 Sileo/Zebra 安装后 `uicache` 或重启即可。

> 仅适用于**已越狱**设备（需要 MobileSubstrate 全局注入）。纯 TrollStore 无越狱环境无法全局注入其它 App，此时只能依赖系统 .ips 日志。

## 技术栈

- SwiftUI（iOS 15+）
- XcodeGen（`project.yml` 生成工程）
- 私有 API：`LSApplicationWorkspace`

## 目录结构

```
Sources/
  Models/      InstalledApp, LogEntry
  Services/    AppScanner, LogScanner, LogStore, LogExporter
  Views/       RootView, AppListView, AppDetailView, AllLogsView, LogDetailView, DiagnosticsView, UIComponents
App/           Info.plist, entitlements, 私有头文件, 图标
.github/workflows/build.yml
```
