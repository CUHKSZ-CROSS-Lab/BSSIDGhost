//
//  Hooks.m
//  BSSIDGhost
//
//  统一注册、授权校验与日志。
//
//  ⚠️ 占位实现：当前不含任何真实 Hook 逻辑。
//

#import "Hooks.h"
#import "BGGhostCoreWLAN.h"
#import "BGGhostHotspot.h"

#pragma mark - 状态

static BOOL sBGGhostEnabled = NO;

BOOL BGGhostIsEnabled(void) {
    return sBGGhostEnabled;
}

#pragma mark - 日志

void BGGhostLog(NSString *format, ...) {
    // TODO: 落地到 config/bssid_map.json 中 log.path 指定的文件
    //       当前仅输出到 os_log，便于前期联调
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[BSSIDGhost] %@", message);
}

#pragma mark - 授权校验

/// 读取配置并校验：目标 App 授权信息必须填齐，否则拒绝启用。
/// 这是刻意设计的"安全闸"：未登记授权的环境不会静默生效。
static BOOL BGGhostValidateAuthorization(void) {
    // TODO: 从 config/targets.json 读取，校验 authorization 下各字段非 "fill_me"
    //       校验不通过 -> 返回 NO，并记录明确原因
    return NO; // 默认关闭，填齐授权后再打开
}

BOOL BGGhostShouldHookProcess(void) {
    // TODO: 按 config/targets.json 的 scope.mode / bundle_ids 判断当前进程
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID.length == 0) {
        return NO; // 非 App 进程（如系统守护进程）默认跳过
    }
    return BGGhostValidateAuthorization();
}

#pragma mark - 注册

void BGGhostInstallHooks(void) {
    if (!BGGhostShouldHookProcess()) {
        BGGhostLog(@"跳过：当前进程不在作用域内，或授权校验未通过");
        return;
    }

    sBGGhostEnabled = YES;
    BGGhostLog(@"启用，目标进程: %@", [[NSBundle mainBundle] bundleIdentifier]);

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
