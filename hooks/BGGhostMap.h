//
//  BGGhostMap.h
//  BSSIDGhost
//
//  配置读取 + ObjC 胶水层：把 config/bssid_map.json 转成 BGRuleSet，
//  并对 NSString 形态的 BSSID 做映射。真正的判定逻辑在 BGGhostRules.c（纯 C）。
//

#ifndef BG_GHOST_MAP_H
#define BG_GHOST_MAP_H

#import <Foundation/Foundation.h>

#import "BGGhostRules.h"

/// 配置文件的候选路径（按顺序，取第一个存在的）。
/// 可用环境变量 `BGGHOST_CONFIG` 覆盖为首选路径，便于联调。
NSArray<NSString *> *BGGhostConfigSearchPaths(void);

/// 当前规则表（首次调用时懒加载并缓存）。永不返回 NULL。
/// 读取失败 / 文件缺失时返回「全关闭」的空表，保证默认不改变行为。
const BGRuleSet *BGGhostRuleSet(void);

/// 丢弃缓存，下次访问时重新读取配置文件。
void BGGhostReloadRuleSet(void);

/// 按规则映射 BSSID（不提供 SSID 即只能靠 match.bssid 命中）。
/// 命中返回替换值（格式跟随入参）；未命中 / nil / 空串 / 畸形一律原值返回。
NSString *BGGhostMapBSSID(NSString *realBSSID);

/// 带 SSID 的映射：支持「同 SSID、不同 AP」的按 SSID 命中规则。
NSString *BGGhostMapBSSIDWithSSID(NSString *ssid, NSString *realBSSID);

#endif /* BG_GHOST_MAP_H */
