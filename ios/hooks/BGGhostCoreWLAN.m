//
//  BGGhostCoreWLAN.m
//  BSSIDGhost
//
//  CoreWLAN / CWFInterface 通道 Hook。
//
//  ⚠️ 占位实现：接口名与方法签名尚未在真机验证。
//     先按 docs/ios/tech-chain.md 的待办用 Frida 抓调用栈，确认实际符号后再填。
//

#import "BGGhostCoreWLAN.h"
#import "BGGhostMap.h"
#import "Hooks.h"

// 参考形态（伪代码，待验证后改为 theos %hook / MSHookMessageEx）：
//
//   %hook CWFInterface
//   - (NSString *)bssid {
//       NSString *real = %orig;
//       NSString *ssid = %orig_ssid();          // 同一对象上的 SSID，用于按 SSID 命中规则
//       return BGGhostMapBSSIDWithSSID(ssid, real);   // 只替换 BSSID，SSID 不动
//   }
//   %end
//
// 注意：
//   1. CWFInterface 为私有框架，类名/方法名随 iOS 版本变化，必须先确认目标版本。
//   2. 返回形态可能是 NSString / NSData / 出参指针，替换策略不同（见 tech-chain.md 第 3 节）。
//      当前 BGGhostMapBSSID* 只处理 NSString 形态；NSData / 结构体形态待 BG-012 结论后另做。
//   3. 需处理该方法是同步缓存还是异步回调，避免只改到第一次调用。
//
//  映射逻辑本身在 BGGhostRules.c（纯 C，主机侧单测见 ios/tests/host/）与 BGGhostMap.m，
//  本文件只负责「在哪里 Hook」。

void BGGhostInstallCoreWLANHooks(void) {
    // TODO(BG-030): 确认符号后再注册：
    //   - CWFInterface -bssid / -interfaceState
    //   - CWInterface  -bssid（旧版 API）
    BGGhostLog(@"CoreWLAN 通道：待实现（需先完成 BG-011 抓栈 + BG-030 选定框架）");
}
