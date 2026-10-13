//
//  BGGhostCoreWLAN.m
//  BSSIDGhost
//
//  CoreWLAN / CWFInterface 通道 Hook。
//
//  ⚠️ 占位实现：接口名与方法签名尚未在真机验证。
//     先按 docs/tech-chain.md 的待办用 Frida 抓调用栈，确认实际符号后再填。
//

#import "BGGhostCoreWLAN.h"
#import "Hooks.h"

// 参考形态（伪代码，待验证后改为 theos %hook / MSHookMessageEx）：
//
//   %hook CWFInterface
//   - (NSString *)bssid {
//       NSString *real = %orig;
//       return BGGhostMapBSSID(real);   // 只替换 BSSID，SSID 不动
//   }
//   %end
//
// 注意：
//   1. CWFInterface 为私有框架，类名/方法名随 iOS 版本变化，必须先确认目标版本。
//   2. 返回形态可能是 NSString / NSData / 出参指针，替换策略不同（见 tech-chain.md 第 3 节）。
//   3. 需处理该方法是同步缓存还是异步回调，避免只改到第一次调用。

/// 按 config/bssid_map.json 的规则映射 BSSID。
/// 无匹配规则时返回原值，保证"默认不改变行为"。
NSString *BGGhostMapBSSID(NSString *realBSSID) {
    if (realBSSID.length == 0) {
        return realBSSID;
    }

    // TODO: 读取 bssid_map.json，按 match.ssid + match.bssid 命中规则，
    //       返回 replace.bssid；注意大小写与分隔符格式必须与入参一致。
    BGGhostLog(@"CoreWLAN: 透传真实 BSSID=%@（尚未启用替换）", realBSSID);
    return realBSSID;
}

void BGGhostInstallCoreWLANHooks(void) {
    // TODO: 确认符号后再注册：
    //   - CWFInterface -bssid / -interfaceState
    //   - CWInterface  -bssid（旧版 API）
    BGGhostLog(@"CoreWLAN 通道：待实现（需先验证符号）");
}
