//
//  BGGhostConfig.m
//  BSSIDGhost
//
//  配置层实现。判定逻辑不在这里 —— 这里只做「读 JSON -> 结构体」。
//
//  锁顺序约定（避免死锁）：
//      授权配置锁 -> 日志配置锁 -> 日志写入锁
//  只有 BGGhostLogConfig() 会取日志配置锁，而它从不回调授权配置，故无环。
//

#import "BGGhostConfig.h"
#import "Hooks.h"

#include <os/lock.h>
#include <stdlib.h>
#include <string.h>

#pragma mark - 路径

static NSString *const kBGGhostRootlessDir = @"/var/jb/usr/share/bssidghost";
static NSString *const kBGGhostMobileDir = @"/var/mobile/Library/BSSIDGhost";

NSArray<NSString *> *BGGhostConfigSearchDirs(void) {
    NSMutableArray<NSString *> *dirs = [NSMutableArray arrayWithCapacity:3];

    const char *override = getenv("BGGHOST_CONFIG_DIR");
    if (override != NULL && override[0] != '\0') {
        NSString *overrideDir = [NSString stringWithUTF8String:override];
        if (overrideDir.length > 0) {
            [dirs addObject:overrideDir];
        }
    }

    [dirs addObject:kBGGhostRootlessDir];
    [dirs addObject:kBGGhostMobileDir];
    return dirs;
}

NSString *BGGhostResolveConfigPath(NSString *fileName) {
    if (fileName.length == 0) {
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in BGGhostConfigSearchDirs()) {
        NSString *candidate = [dir stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    NSString *bundled = [[NSBundle mainBundle] pathForResource:[fileName stringByDeletingPathExtension]
                                                       ofType:[fileName pathExtension]];
    if (bundled.length > 0 && [fm fileExistsAtPath:bundled]) {
        return bundled;
    }
    return nil;
}

#pragma mark - 读取工具

static id BGGhostReadJSON(NSString *path) {
    if (path.length == 0) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        NSLog(@"[BSSIDGhost] 配置：读取失败 %@", path);
        return nil;
    }
    NSError *error = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (root == nil) {
        NSLog(@"[BSSIDGhost] 配置：JSON 解析失败 %@ (%@)", path, error.localizedDescription);
        return nil;
    }
    return root;
}

static NSDictionary *BGGhostDictionary(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? (NSDictionary *)value : nil;
}

static NSString *BGGhostString(id value) {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

#pragma mark - 日志配置

static BGLogConfig sBGLogConfig;
static BOOL sBGLogConfigLoaded = NO;
static os_unfair_lock sBGLogConfigLock = OS_UNFAIR_LOCK_INIT;

static const long kBGLogDefaultMaxBytes = 1024 * 1024; // 1 MiB

/// 调用方必须持有 sBGLogConfigLock。本函数刻意只用 NSLog：
/// 此刻日志设置本身还没确定，且不能用 BGGhostLog（会再次取同一把锁）。
static void BGGhostLoadLogConfigLocked(void) {
    memset(&sBGLogConfig, 0, sizeof(sBGLogConfig));
    sBGLogConfig.max_bytes = kBGLogDefaultMaxBytes;
    sBGLogConfigLoaded = YES;

    NSString *path = BGGhostResolveConfigPath(@"bssid_map.json");
    NSDictionary *config = BGGhostDictionary(BGGhostReadJSON(path));
    if (config == nil) {
        NSLog(@"[BSSIDGhost] 日志设置：未找到可用的 bssid_map.json，退化为仅 NSLog");
        return;
    }

    NSDictionary *log = BGGhostDictionary(config[@"log"]);
    if (log == nil) {
        return;
    }

    sBGLogConfig.enabled = [log[@"enabled"] boolValue] ? 1 : 0;

    NSString *logPath = BGGhostString(log[@"path"]);
    if (logPath.length > 0 && logPath.length < sizeof(sBGLogConfig.path)) {
        strncpy(sBGLogConfig.path, logPath.UTF8String, sizeof(sBGLogConfig.path) - 1);
    } else if (logPath.length > 0) {
        NSLog(@"[BSSIDGhost] 日志设置：log.path 过长，已忽略（退化为仅 NSLog）");
        sBGLogConfig.enabled = 0;
    }

    NSNumber *maxBytes = [log[@"max_bytes"] isKindOfClass:[NSNumber class]] ? (NSNumber *)log[@"max_bytes"] : nil;
    if (maxBytes != nil && maxBytes.longValue > 0) {
        sBGLogConfig.max_bytes = maxBytes.longValue;
    }
}

const BGLogConfig *BGGhostLogConfig(void) {
    os_unfair_lock_lock(&sBGLogConfigLock);
    if (!sBGLogConfigLoaded) {
        BGGhostLoadLogConfigLocked();
    }
    os_unfair_lock_unlock(&sBGLogConfigLock);
    return &sBGLogConfig;
}

#pragma mark - 授权与作用域配置

static BGAuthConfig sBGAuthConfig;
static BOOL sBGAuthConfigLoaded = NO;
static os_unfair_lock sBGAuthConfigLock = OS_UNFAIR_LOCK_INIT;

/// 调用方必须持有 sBGAuthConfigLock。
static void BGGhostLoadAuthConfigLocked(void) {
    BGGhostAuthConfigInit(&sBGAuthConfig);
    sBGAuthConfigLoaded = YES;

    NSString *path = BGGhostResolveConfigPath(@"targets.json");
    NSDictionary *config = BGGhostDictionary(BGGhostReadJSON(path));
    if (config == nil) {
        // 读不到就保持全空 -> 授权判定必然拒绝（fail closed）。
        BGGhostLog(@"授权配置：未找到可用的 targets.json，按未授权处理（拒绝启用）");
        return;
    }

    // scope
    NSDictionary *scope = BGGhostDictionary(config[@"scope"]);
    if (scope != nil) {
        BGGhostAuthConfigSetScopeMode(&sBGAuthConfig, BGGhostString(scope[@"mode"]).UTF8String);

        id bundleIds = scope[@"bundle_ids"];
        int skipped = 0;
        if ([bundleIds isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)bundleIds) {
                NSString *bundleId = BGGhostString(item);
                if (bundleId.length == 0) {
                    skipped++;
                    continue;
                }
                if (!BGGhostAuthConfigAddBundleID(&sBGAuthConfig, bundleId.UTF8String)) {
                    skipped++;
                }
            }
        }
        if (skipped > 0) {
            BGGhostLog(@"授权配置：scope.bundle_ids 有 %d 项被忽略（空值 / 超长 / 超出容量 %d）",
                       skipped, BG_AUTH_MAX_BUNDLES);
        }
    }

    // authorization：逐个键写入；未知键名会让 BGGhostAuthConfigSetField 返回 0，
    // 这里显式记录，避免配置写错而无人发现。
    NSDictionary *authorization = BGGhostDictionary(config[@"authorization"]);
    if (authorization != nil) {
        for (id key in authorization) {
            NSString *name = BGGhostString(key);
            if (name == nil || [name hasPrefix:@"_"]) {
                continue; // 注释字段
            }
            NSString *value = BGGhostString(authorization[key]);
            if (value == nil) {
                BGGhostLog(@"授权配置：authorization.%@ 不是字符串，已忽略", name);
                continue;
            }
            if (!BGGhostAuthConfigSetField(&sBGAuthConfig, name.UTF8String, value.UTF8String)) {
                BGGhostLog(@"授权配置：authorization.%@ 不是已知字段（拼写错误？），已忽略", name);
            }
        }
    }

    // constraints：缺失即视为关闭 -> 判定必然拒绝（fail closed）。
    NSDictionary *constraints = BGGhostDictionary(config[@"constraints"]);
    if (constraints != nil) {
        BGGhostAuthConfigSetConstraints(&sBGAuthConfig,
                                       [constraints[@"only_test_devices"] boolValue] ? 1 : 0,
                                       [constraints[@"only_test_network"] boolValue] ? 1 : 0,
                                       [constraints[@"no_production_targets"] boolValue] ? 1 : 0);
    }

    BGGhostLog(@"授权配置：已加载 %@ | scope.mode=%s | bundles=%d | 约束=%d/%d/%d",
               path,
               sBGAuthConfig.scope_mode[0] ? sBGAuthConfig.scope_mode : "(空)",
               sBGAuthConfig.bundle_id_count,
               sBGAuthConfig.only_test_devices,
               sBGAuthConfig.only_test_network,
               sBGAuthConfig.no_production_targets);
}

const BGAuthConfig *BGGhostAuthConfig(void) {
    os_unfair_lock_lock(&sBGAuthConfigLock);
    if (!sBGAuthConfigLoaded) {
        BGGhostLoadAuthConfigLocked();
    }
    os_unfair_lock_unlock(&sBGAuthConfigLock);
    return &sBGAuthConfig;
}

#pragma mark - 重载

void BGGhostReloadConfig(void) {
    os_unfair_lock_lock(&sBGAuthConfigLock);
    sBGAuthConfigLoaded = NO;
    os_unfair_lock_unlock(&sBGAuthConfigLock);

    os_unfair_lock_lock(&sBGLogConfigLock);
    sBGLogConfigLoaded = NO;
    os_unfair_lock_unlock(&sBGLogConfigLock);
}
