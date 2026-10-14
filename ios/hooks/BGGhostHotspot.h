//
//  BGGhostHotspot.h
//  BSSIDGhost
//
//  NetworkExtension / SystemConfiguration 通道（补充通道）。
//

#ifndef BG_GHOST_HOTSPOT_H
#define BG_GHOST_HOTSPOT_H

#import <Foundation/Foundation.h>

/// 注册 NEHotspotNetwork / CNCopyCurrentNetworkInfo 相关 Hook。
/// 优先级 P1：作为主通道的补充，见 docs/ios/tech-chain.md。
void BGGhostInstallHotspotHooks(void);

#endif /* BG_GHOST_HOTSPOT_H */
