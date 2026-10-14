//
//  Hooks.m
//  BSSIDGhost
//
//  统一注册、授权闸与日志落盘。
//
//  安全闸（刻意设计，不要在调试时绕过）：
//    - 判定逻辑在同目录的 BGGhostAuth.c（纯 C，主机侧单测见 ios/tests/host/）；
//    - 本文件只负责「取判定结果 -> 决定是否启用 -> 记录原因」。
//    未登记授权 / 约束未开 / 进程不在作用域 -> 拒绝启用并写明责任字段。
//

#import "Hooks.h"
#import "BGGhostConfig.h"
#import "BGGhostCoreWLAN.h"
#import "BGGhostHotspot.h"

#include <os/lock.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#pragma mark - 状态

static BOOL sBGGhostEnabled = NO;

BOOL BGGhostIsEnabled(void) {
    return sBGGhostEnabled;
}

#pragma mark - 日志：落盘与轮转

/// 串行化文件写入。只保护写文件这一段，不包裹 BGGhostLog 的其余部分。
static os_unfair_lock sBGGhostLogWriteLock = OS_UNFAIR_LOCK_INIT;

static void BGGhostTimestamp(char *out, size_t capacity) {
    time_t now = time(NULL);
    struct tm brokenDown;
    if (localtime_r(&now, &brokenDown) == NULL) {
        snprintf(out, capacity, "?");
        return;
    }
    if (strftime(out, capacity, "%Y-%m-%d %H:%M:%S", &brokenDown) == 0) {
        snprintf(out, capacity, "?");
    }
}

/// 追加一行到日志文件；必要时先创建目录、并在超过上限时轮转为 `<path>.1`。
/// 任何失败都静默退化为「只有 NSLog」——日志写不进去不该影响被测进程。
static void BGGhostAppendToLogFile(const char *path, const char *message, long maxBytes) {
    if (path == NULL || message == NULL || path[0] == '\0') {
        return;
    }

    os_unfair_lock_lock(&sBGGhostLogWriteLock);

    NSString *logPath = [NSString stringWithUTF8String:path];
    if (logPath.length == 0) {
        os_unfair_lock_unlock(&sBGGhostLogWriteLock);
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [logPath stringByDeletingLastPathComponent];
    if (directory.length > 0) {
        [fm createDirectoryAtPath:directory
      withIntermediateDirectories:YES
                       attributes:nil
                            error:NULL];
    }

    struct stat info;
    if (maxBytes > 0 && stat(path, &info) == 0 && (long)info.st_size >= maxBytes) {
        NSString *rotated = [logPath stringByAppendingString:@".1"];
        [fm removeItemAtPath:rotated error:NULL];
        [fm moveItemAtPath:logPath toPath:rotated error:NULL];
    }

    FILE *fp = fopen(path, "a");
    if (fp == NULL) {
        os_unfair_lock_unlock(&sBGGhostLogWriteLock);
        return;
    }

    char stamp[32];
    BGGhostTimestamp(stamp, sizeof(stamp));
    fprintf(fp, "[%s] [pid %d] %s\n", stamp, (int)getpid(), message);
    fclose(fp);

    os_unfair_lock_unlock(&sBGGhostLogWriteLock);
}

void BGGhostLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[BSSIDGhost] %@", message);

    const BGLogConfig *log = BGGhostLogConfig();
    if (!log->enabled || log->path[0] == '\0') {
        return;
    }
    BGGhostAppendToLogFile(log->path, message.UTF8String, log->max_bytes);
}

#pragma mark - 授权闸

BGAuthDecision BGGhostAuthorizationDecision(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return BGGhostAuthCheckProcess(BGGhostAuthConfig(), bundleID.UTF8String);
}

BOOL BGGhostShouldHookProcess(void) {
    return BGGhostAuthorizationDecision().result == BG_AUTH_OK;
}

#pragma mark - 注册

void BGGhostInstallHooks(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *process = bundleID.length > 0 ? bundleID : @"(非 App 进程)";

    BGAuthDecision decision = BGGhostAuthorizationDecision();
    if (decision.result != BG_AUTH_OK) {
        NSString *reason = [NSString stringWithUTF8String:BGGhostAuthResultDescription(decision.result)];
        if (decision.field != NULL) {
            BGGhostLog(@"拒绝启用：%@（字段 %s，进程 %@）", reason, decision.field, process);
        } else {
            BGGhostLog(@"拒绝启用：%@（进程 %@）", reason, process);
        }
        return; // 安全闸：不注册任何 Hook
    }

    sBGGhostEnabled = YES;
    BGGhostLog(@"启用，目标进程: %@", process);

    BGGhostInstallCoreWLANHooks();   // 主通道
    BGGhostInstallHotspotHooks();    // 补充通道
}

#pragma mark - 注入入口

__attribute__((constructor))
static void BGGhostEntry(void) {
    @autoreleasepool {
        BGGhostInstallHooks();
    }
}
