//
//  BGGhostConfig.h
//  BSSIDGhost
//
//  配置层：把磁盘上的两份 JSON 转成纯 C 配置结构。
//    - shared/config/targets.json   -> BGAuthConfig（授权闸与作用域，判定在 BGGhostAuth.c）
//    - shared/config/bssid_map.json -> BGLogConfig（日志落盘设置）
//
//  规则表（BGRuleSet）由 BGGhostMap.m 单独持有，两份模块各自缓存同一份
//  bssid_map.json 的不同关注点，互不影响。
//
//  安全取向：**读不到、读不懂、字段缺失一律按「拒绝」处理**（fail closed）。
//

#ifndef BG_GHOST_CONFIG_H
#define BG_GHOST_CONFIG_H

#import <Foundation/Foundation.h>

#import "BGGhostAuth.h"

/// 日志落盘设置。
typedef struct {
    int  enabled;        ///< log.enabled，0 = 只输出 NSLog
    char path[512];      ///< log.paths.ios（R13 起按平台取值），为空则只输出 NSLog
    long max_bytes;      ///< log.max_bytes，超过则轮转为 `<path>.1`；<= 0 用默认 1 MiB
} BGLogConfig;

/// 配置目录的候选列表（按顺序，取第一个存在该文件的目录）。
/// 可用环境变量 `BGGHOST_CONFIG_DIR` 覆盖为首选目录，便于联调。
NSArray<NSString *> *BGGhostConfigSearchDirs(void);

/// 在候选目录与 App bundle 中解析 `fileName`，返回第一个存在的完整路径；找不到返回 nil。
NSString *BGGhostResolveConfigPath(NSString *fileName);

/// 当前授权与作用域配置（首次访问时懒加载并缓存）。永不返回 NULL。
/// targets.json 缺失或无法解析时，所有字段为空 -> 判定结果必然是拒绝。
const BGAuthConfig *BGGhostAuthConfig(void);

/// 当前日志设置（首次访问时懒加载并缓存）。永不返回 NULL。
const BGLogConfig *BGGhostLogConfig(void);

/// 丢弃两份配置的缓存，下次访问时重新读取。
void BGGhostReloadConfig(void);

#endif /* BG_GHOST_CONFIG_H */
