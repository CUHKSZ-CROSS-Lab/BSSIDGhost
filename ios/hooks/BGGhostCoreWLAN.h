//
//  BGGhostCoreWLAN.h
//  BSSIDGhost
//
//  CoreWLAN / CWFInterface 通道（主通道）。
//

#ifndef BG_GHOST_COREWLAN_H
#define BG_GHOST_COREWLAN_H

#import <Foundation/Foundation.h>

/// 注册 CoreWLAN 相关 Hook。
/// 优先级 P0：读取 BSSID 最常见的私有通道，见 docs/ios/tech-chain.md。
void BGGhostInstallCoreWLANHooks(void);

#endif /* BG_GHOST_COREWLAN_H */
