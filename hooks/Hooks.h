//
//  Hooks.h
//  BSSIDGhost
//
//  统一 Hook 入口声明。
//

#ifndef BG_HOOKS_H
#define BG_HOOKS_H

#import <Foundation/Foundation.h>

/// 注册全部 Hook。由注入入口在加载时调用一次。
void BGGhostInstallHooks(void);

/// 是否已启用（由 config/targets.json 的 authorization 校验通过后才为 YES）。
BOOL BGGhostIsEnabled(void);

/// 当前是否应作用于该进程。
BOOL BGGhostShouldHookProcess(void);

#endif /* BG_HOOKS_H */
