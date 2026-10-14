//
//  Hooks.h
//  BSSIDGhost
//
//  统一 Hook 入口声明。
//

#ifndef BG_HOOKS_H
#define BG_HOOKS_H

#import <Foundation/Foundation.h>

#import "BGGhostAuth.h"

/// 注册全部 Hook。由注入入口在加载时调用一次。
void BGGhostInstallHooks(void);

/// 统一日志入口。输出到 NSLog；若 bssid_map.json 的 log.enabled 为真，
/// 同时追加到 log.paths.<平台>（超过 log.max_bytes 时轮转为 `<path>.1`）。
void BGGhostLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

/// 是否已启用（只有授权闸与作用域判定都通过后才为 YES）。
BOOL BGGhostIsEnabled(void);

/// 当前进程的授权与作用域判定结果（含责任字段），供日志与排障使用。
BGAuthDecision BGGhostAuthorizationDecision(void);

/// 当前是否应作用于该进程（等价于判定结果为 BG_AUTH_OK）。
BOOL BGGhostShouldHookProcess(void);

#endif /* BG_HOOKS_H */
