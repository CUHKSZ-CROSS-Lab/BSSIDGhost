//
//  BGGhostMap.m
//  BSSIDGhost
//
//  配置读取 + ObjC 胶水层实现。
//
//  职责边界（刻意收窄，避免把策略散落到各 Hook 点）：
//    - 本文件只负责「读配置 -> BGRuleSet」与「NSString <-> C 字符串」；
//    - 是否替换、替换成什么、输出什么格式，全部由 BGGhostRules.c 决定。
//    - 任何异常路径都返回原值（默认不改变行为）。
//

#import "BGGhostMap.h"
#import "Hooks.h"

#include <os/lock.h>
#include <stdlib.h>

/// rootless（Dopamine，/var/jb 前缀）部署时的首选路径。
static NSString *const kBGGhostRootlessConfigPath = @"/var/jb/usr/share/bssidghost/bssid_map.json";
/// 移动用户目录下的备选路径（日志目录的邻居，便于现场改配置）。
static NSString *const kBGGhostMobileConfigPath = @"/var/mobile/Library/BSSIDGhost/bssid_map.json";

static BGRuleSet sBGGhostRuleSet;
static BOOL sBGGhostRuleSetLoaded = NO;

/// 用 os_unfair_lock 而不是 @synchronized：本文件没有可同步的类对象，
/// 且静态初始化不引入竞态。
static os_unfair_lock sBGGhostRuleSetLock = OS_UNFAIR_LOCK_INIT;

#pragma mark - 路径

NSArray<NSString *> *BGGhostConfigSearchPaths(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithCapacity:4];

    const char *override = getenv("BGGHOST_CONFIG");
    if (override != NULL && override[0] != '\0') {
        NSString *overridePath = [NSString stringWithUTF8String:override];
        if (overridePath.length > 0) {
            [paths addObject:overridePath];
        }
    }

    [paths addObject:kBGGhostRootlessConfigPath];
    [paths addObject:kBGGhostMobileConfigPath];

    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"bssid_map" ofType:@"json"];
    if (bundled.length > 0) {
        [paths addObject:bundled];
    }

    return paths;
}

#pragma mark - 加载

/// 调用方必须持有 sBGGhostRuleSet 的锁。
static void BGGhostLoadRuleSetLocked(void) {
    BGGhostRuleSetInit(&sBGGhostRuleSet);
    sBGGhostRuleSetLoaded = YES;

    NSString *path = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *candidate in BGGhostConfigSearchPaths()) {
        if (candidate.length > 0 && [fm fileExistsAtPath:candidate]) {
            path = candidate;
            break;
        }
    }
    if (path == nil) {
        BGGhostLog(@"映射表：未找到配置文件，按全关闭处理（行为不变）");
        return;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        BGGhostLog(@"映射表：读取失败 %@（按全关闭处理）", path);
        return;
    }

    NSError *error = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![root isKindOfClass:[NSDictionary class]]) {
        BGGhostLog(@"映射表：JSON 解析失败 %@ (%@)（按全关闭处理）", path, error.localizedDescription);
        return;
    }
    NSDictionary *config = (NSDictionary *)root;

    sBGGhostRuleSet.enabled = [config[@"enabled"] boolValue] ? 1 : 0;

    // default 必须显式 enabled:true 才生效，否则未配置的网络一律透传（T7）。
    id defaultBlock = config[@"default"];
    if ([defaultBlock isKindOfClass:[NSDictionary class]]
        && [((NSDictionary *)defaultBlock)[@"enabled"] boolValue]) {
        id fake = ((NSDictionary *)defaultBlock)[@"fake_bssid"];
        if ([fake isKindOfClass:[NSString class]]
            && BGGhostNormalizeBSSID(((NSString *)fake).UTF8String, sBGGhostRuleSet.default_fake_bssid)) {
            sBGGhostRuleSet.has_default = 1;
        } else {
            BGGhostLog(@"映射表：default.fake_bssid 非法，已忽略默认值");
        }
    }

    int skipped = 0;
    id rulesBlock = config[@"rules"];
    if ([rulesBlock isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)rulesBlock) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                skipped++;
                continue;
            }
            NSDictionary *rule = (NSDictionary *)item;
            id matchBlock = rule[@"match"];
            id replaceBlock = rule[@"replace"];
            NSDictionary *match = [matchBlock isKindOfClass:[NSDictionary class]]
                                      ? (NSDictionary *)matchBlock : (NSDictionary *)@{};
            NSDictionary *replace = [replaceBlock isKindOfClass:[NSDictionary class]]
                                        ? (NSDictionary *)replaceBlock : (NSDictionary *)@{};

            id ssidValue = match[@"ssid"];
            id realValue = match[@"bssid"];
            id fakeValue = replace[@"bssid"];

            NSString *ssid = [ssidValue isKindOfClass:[NSString class]] ? (NSString *)ssidValue : @"";
            NSString *real = [realValue isKindOfClass:[NSString class]] ? (NSString *)realValue : @"";
            NSString *fake = [fakeValue isKindOfClass:[NSString class]] ? (NSString *)fakeValue : nil;

            if (fake == nil
                || !BGGhostRuleSetAdd(&sBGGhostRuleSet,
                                      ssid.UTF8String,
                                      real.UTF8String,
                                      fake.UTF8String,
                                      [rule[@"enabled"] boolValue] ? 1 : 0)) {
                skipped++;
            }
        }
    }

    BGGhostLog(@"映射表：已加载 %@ | 全局=%@ | 规则=%d | 默认值=%@ | 跳过=%d",
               path,
               sBGGhostRuleSet.enabled ? @"开" : @"关",
               sBGGhostRuleSet.count,
               sBGGhostRuleSet.has_default ? @"开" : @"关",
               skipped);
}

const BGRuleSet *BGGhostRuleSet(void) {
    // 规则表只在重载时被整体替换，读取方拿到的是稳定地址；
    // 现场改配置后调用 BGGhostReloadRuleSet() 即可生效。
    os_unfair_lock_lock(&sBGGhostRuleSetLock);
    if (!sBGGhostRuleSetLoaded) {
        BGGhostLoadRuleSetLocked();
    }
    os_unfair_lock_unlock(&sBGGhostRuleSetLock);
    return &sBGGhostRuleSet;
}

void BGGhostReloadRuleSet(void) {
    os_unfair_lock_lock(&sBGGhostRuleSetLock);
    sBGGhostRuleSetLoaded = NO;
    os_unfair_lock_unlock(&sBGGhostRuleSetLock);
}

#pragma mark - 映射

NSString *BGGhostMapBSSIDWithSSID(NSString *ssid, NSString *realBSSID) {
    // nil 语义：真实值缺失时不构造任何东西。
    if (realBSSID.length == 0) {
        return realBSSID;
    }

    const char *realC = realBSSID.UTF8String;
    if (realC == NULL) {
        return realBSSID;
    }

    char out[BG_BSSID_STR_MAX];
    const char *ssidC = (ssid.length > 0) ? ssid.UTF8String : NULL;

    if (!BGGhostMapBSSIDC(BGGhostRuleSet(), ssidC, realC, out)) {
        return realBSSID; // 未命中 / 全局关闭 / 畸形 -> 原值透传
    }

    NSString *mapped = [NSString stringWithUTF8String:out];
    return mapped.length > 0 ? mapped : realBSSID;
}

NSString *BGGhostMapBSSID(NSString *realBSSID) {
    return BGGhostMapBSSIDWithSSID(nil, realBSSID);
}
