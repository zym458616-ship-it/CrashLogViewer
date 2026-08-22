/*
 * CrashCatcher tweak
 * 注入到所有 App，捕获致命信号 / 未捕获 NSException / C++ terminate，
 * 主动生成详细崩溃日志，写入 App 自身沙盒容器 Documents/.CrashCatcher/。
 * 供 CrashLogViewer（具容器访问 entitlements 的巨魔 App）统一读取。
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <signal.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <fcntl.h>
#import <time.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <pthread.h>

static char gLogDir[1024]      = {0};   // 目标目录（Documents/.CrashCatcher）
static char gProcName[256]     = {0};
static char gBundleID[256]     = {0};
static char gAppVersion[128]   = {0};
static char gOSVersion[128]    = {0};
static char gDeviceModel[128]  = {0};

// 保存旧的信号处理器以便链式调用
static struct sigaction gOldActions[32];
static const int gSignals[] = { SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGFPE, SIGTRAP };
static const int gSignalCount = sizeof(gSignals) / sizeof(gSignals[0]);

static const char *signalName(int sig) {
    switch (sig) {
        case SIGSEGV: return "SIGSEGV (段错误 / 非法内存访问)";
        case SIGABRT: return "SIGABRT (abort / 断言失败)";
        case SIGBUS:  return "SIGBUS (总线错误)";
        case SIGILL:  return "SIGILL (非法指令)";
        case SIGFPE:  return "SIGFPE (算术异常)";
        case SIGTRAP: return "SIGTRAP (陷阱 / 调试中断)";
        default:      return "UNKNOWN";
    }
}

// 生成日志文件路径（时间戳）。返回是否成功。
static bool buildLogPath(char *out, size_t outLen, const char *suffix) {
    if (gLogDir[0] == 0) return false;
    time_t t = time(NULL);
    struct tm tmv;
    localtime_r(&t, &tmv);
    char ts[64];
    strftime(ts, sizeof(ts), "%Y-%m-%d-%H%M%S", &tmv);
    snprintf(out, outLen, "%s/%s-%s-%s.crashlog", gLogDir, gProcName, ts, suffix);
    return true;
}

// 异步信号安全地写字符串
static void wstr(int fd, const char *s) {
    if (s) { size_t n = strlen(s); (void)write(fd, s, n); }
}

// 信号处理：尽量使用 async-signal-safe 操作
static void crashSignalHandler(int sig, siginfo_t *info, void *uap) {
    char path[1200];
    if (buildLogPath(path, sizeof(path), "signal")) {
        int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            char line[1024];

            wstr(fd, "=== CrashCatcher 崩溃报告 (信号) ===\n");
            snprintf(line, sizeof(line), "进程:        %s\n", gProcName);      wstr(fd, line);
            snprintf(line, sizeof(line), "BundleID:    %s\n", gBundleID);      wstr(fd, line);
            snprintf(line, sizeof(line), "App 版本:    %s\n", gAppVersion);    wstr(fd, line);
            snprintf(line, sizeof(line), "系统版本:    %s\n", gOSVersion);     wstr(fd, line);
            snprintf(line, sizeof(line), "设备:        %s\n", gDeviceModel);   wstr(fd, line);
            snprintf(line, sizeof(line), "PID:         %d\n", getpid());       wstr(fd, line);

            time_t t = time(NULL);
            snprintf(line, sizeof(line), "时间戳:      %ld\n", (long)t);       wstr(fd, line);

            snprintf(line, sizeof(line), "信号:        %d %s\n", sig, signalName(sig)); wstr(fd, line);
            if (info) {
                snprintf(line, sizeof(line), "错误地址:    %p\n", info->si_addr);   wstr(fd, line);
                snprintf(line, sizeof(line), "si_code:     %d\n", info->si_code);   wstr(fd, line);
            }

            wstr(fd, "\n--- 调用栈 (backtrace) ---\n");
            void *frames[128];
            int count = backtrace(frames, 128);
            // backtrace_symbols 会 malloc，信号处理里不完全安全，但实践中可用；
            // 用 backtrace_symbols_fd 更安全，直接写 fd。
            backtrace_symbols_fd(frames, count, fd);

            wstr(fd, "\n=== 报告结束 ===\n");
            close(fd);
        }
    }

    // 链式调用原处理器 / 恢复默认后重新触发，保证系统正常终止
    for (int i = 0; i < gSignalCount; i++) {
        if (gSignals[i] == sig) {
            if (gOldActions[i].sa_flags & SA_SIGINFO) {
                if (gOldActions[i].sa_sigaction) gOldActions[i].sa_sigaction(sig, info, uap);
            } else if (gOldActions[i].sa_handler && gOldActions[i].sa_handler != SIG_DFL
                       && gOldActions[i].sa_handler != SIG_IGN) {
                gOldActions[i].sa_handler(sig);
            }
            break;
        }
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

// 未捕获 NSException 处理（信息最丰富）
static void uncaughtExceptionHandler(NSException *exception) {
    @autoreleasepool {
        char path[1200];
        if (!buildLogPath(path, sizeof(path), "exception")) return;

        NSMutableString *s = [NSMutableString string];
        [s appendString:@"=== CrashCatcher 崩溃报告 (未捕获异常) ===\n"];
        [s appendFormat:@"进程:        %s\n", gProcName];
        [s appendFormat:@"BundleID:    %s\n", gBundleID];
        [s appendFormat:@"App 版本:    %s\n", gAppVersion];
        [s appendFormat:@"系统版本:    %s\n", gOSVersion];
        [s appendFormat:@"设备:        %s\n", gDeviceModel];
        [s appendFormat:@"PID:         %d\n", getpid()];
        [s appendFormat:@"时间戳:      %ld\n", (long)time(NULL)];
        [s appendFormat:@"\n异常名称:    %@\n", exception.name];
        [s appendFormat:@"异常原因:    %@\n", exception.reason];
        if (exception.userInfo) {
            [s appendFormat:@"userInfo:    %@\n", exception.userInfo];
        }
        [s appendString:@"\n--- 调用栈 (符号) ---\n"];
        NSArray *symbols = exception.callStackSymbols;
        for (NSString *line in symbols) {
            [s appendFormat:@"%@\n", line];
        }
        [s appendString:@"\n--- 返回地址 ---\n"];
        for (NSNumber *addr in exception.callStackReturnAddresses) {
            [s appendFormat:@"0x%llx\n", (unsigned long long)[addr unsignedLongLongValue]];
        }
        [s appendString:@"\n=== 报告结束 ===\n"];

        [s writeToFile:[NSString stringWithUTF8String:path]
            atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

// 采集进程 / App / 系统信息，并确定日志目录
static void gatherInfoAndPrepareDir(void) {
    @autoreleasepool {
        NSBundle *main = [NSBundle mainBundle];
        NSDictionary *infoPlist = main.infoDictionary;

        NSString *bid  = infoPlist[@"CFBundleIdentifier"] ?: @"unknown";
        NSString *name = infoPlist[@"CFBundleExecutable"]
                         ?: (infoPlist[@"CFBundleName"] ?: @"unknown");
        NSString *ver  = infoPlist[@"CFBundleShortVersionString"] ?: @"-";
        NSString *build= infoPlist[@"CFBundleVersion"] ?: @"-";
        NSString *fullVer = [NSString stringWithFormat:@"%@ (%@)", ver, build];

        strlcpy(gBundleID,   bid.UTF8String   ?: "unknown", sizeof(gBundleID));
        strlcpy(gProcName,   name.UTF8String  ?: "unknown", sizeof(gProcName));
        strlcpy(gAppVersion, fullVer.UTF8String ?: "-",     sizeof(gAppVersion));

        UIDevice *dev = [UIDevice currentDevice];
        NSString *os = [NSString stringWithFormat:@"%@ %@", dev.systemName, dev.systemVersion];
        strlcpy(gOSVersion, os.UTF8String ?: "-", sizeof(gOSVersion));

        struct utsname sys; uname(&sys);
        strlcpy(gDeviceModel, sys.machine, sizeof(gDeviceModel));

        // 日志目录：优先 App 容器 Documents/.CrashCatcher（一定可写）
        NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = nil;
        if (docs.count > 0) {
            dir = [docs.firstObject stringByAppendingPathComponent:@".CrashCatcher"];
        } else {
            dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"CrashCatcher"];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        strlcpy(gLogDir, dir.UTF8String ?: "", sizeof(gLogDir));
    }
}

static void installSignalHandlers(void) {
    stack_t ss;
    ss.ss_sp = malloc(SIGSTKSZ);
    ss.ss_size = SIGSTKSZ;
    ss.ss_flags = 0;
    if (ss.ss_sp) sigaltstack(&ss, NULL);

    for (int i = 0; i < gSignalCount; i++) {
        struct sigaction sa;
        memset(&sa, 0, sizeof(sa));
        sa.sa_sigaction = crashSignalHandler;
        sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
        sigemptyset(&sa.sa_mask);
        sigaction(gSignals[i], &sa, &gOldActions[i]);
    }
}

%ctor {
    @autoreleasepool {
        // 只在有 UI 的 App 进程里启用；跳过一些系统守护/关键进程可自行扩展
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (bid == nil) return;                       // 无 bundle，多为守护进程
        if ([bid isEqualToString:@"com.apple.springboard"]) return;  // 保护 SpringBoard

        gatherInfoAndPrepareDir();
        NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
        installSignalHandlers();
    }
}
