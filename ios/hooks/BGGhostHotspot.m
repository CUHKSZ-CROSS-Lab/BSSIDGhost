//
//  BGGhostHotspot.m
//  BSSIDGhost
//
//  NEHotspotNetwork / CNCopyCurrentNetworkInfo 通道 Hook。
//
//  ⚠️ 占位实现，尚未验证目标 App 是否走这条链路。
//

#import "BGGhostHotspot.h"
#import "Hooks.h"

// 候选 Hook 点（见 docs/ios/tech-chain.md 第 2 节）：
//
//   1) NEHotspotNetwork（公开接口，需定位权限）
//      - SSID / - BSSID   —— 注意系统可能对无权限调用方返回 nil 或裁剪值
//
//   2) CNCopyCurrentNetworkInfo(CFStringRef interfaceName)
//      —— C 函数，返回 CFDictionaryRef，字典键为 "BSSID" / "SSID" / "SSIDDATA"
//      —— 需用 fishhook 处理；返回值可能被系统缓存，注意替换后字典不可变
//
//   3) CWWiFiClient（视 iOS 版本而定）
//
// 注意：设备接口 MAC（en0）≠ AP 的 BSSID，不要混淆这两个概念。

void BGGhostInstallHotspotHooks(void) {
    // TODO: 先用 Frida 确认目标 App 是否调用本通道，再决定是否实现
    BGGhostLog(@"Hotspot 通道：待确认调用后实现");
}
