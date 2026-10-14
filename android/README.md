# android — Android 实现（**当前主线**）

> 目标：在**已 root 的 Android 设备**上，让目标 App（国内版飞书 `com.ss.android.lark`）
> 从系统接口读到的 **BSSID 返回值**被替换，而真实网络链路完全不变；SSID 刻意保持不变。

## 状态

**R12 建立了目录与选型，R13 落地了两端共用的行为向量；实现与构建脚本在 R14–R16 落地。**

| 轮次 | 交付 | 需要设备 |
|---|---|---|
| ~~R13~~ | ~~`shared/vectors/` 语言中立测试向量~~ → ✅ 已完成（110 条断言，见 [`shared/vectors/`](../shared/vectors/README.md)） | — |
| **R14** | Java 核心（映射 + 授权闸）+ 本机构建链脚本 + 主机单测（**必须消费 `shared/vectors/`**） | ❌ |
| R15 | Frida 只读抓栈：确认飞书实际走哪条 Wi-Fi 信息通道 | ✅ |
| R16 | LSPosed 模块实现 + 部署 + 端到端 T1–T10 | ✅ |

## 已定的技术选型

| 项 | 结论 | 依据 |
|---|---|---|
| 注入路线 | 先 **Frida 只读抓栈**，再落 **LSPosed 模块** | 与 iOS 的 BG-011→BG-030 同构：先证实落点，再写 Hook |
| Root | **Magisk v30.7 stable + 内置 Zygisk** | [设备规格](../docs/android-device-spec.md) |
| Hook 框架 | **Vector v2.2**（`JingMatrix/Vector`） | 官方 LSPosed 停在 v1.9.2（2023-10）且只支持到 Android 14 |
| 模块 API | **legacy XposedBridge API 82** | 覆盖面最大（传统 LSPosed 与 Vector 都支持） |
| 目标设备 | 二手 Pixel 8 / 8a，**Android 15（API 35）** | [设备规格](../docs/android-device-spec.md) |
| 编译链 | `javac` + `d8/R8` + `aapt2` + `apksig`（纯命令行，**无需 Android Studio**） | R12 **已端到端实测**：本机打出并签名了 APK，签名验证通过 |

## 候选 Hook 点（⚠️ 全部待 R15 真机抓栈确认）

> 与 iOS 侧 `CoreWLAN` / `nehelper` 对应的是 Android 的 `WifiManager` / `WifiInfo` 一线。
> **不要 hook 飞书自己的混淆类**——飞书 8.x 会换混淆名与 native 库。

| 优先级 | 目标 | 说明 |
|---|---|---|
| P0 | `WifiManager.getConnectionInfo()` → `WifiInfo.getBSSID()` | 最常走的路径；`getConnectionInfo()` 自 Android 12 起 deprecated 但仍工作 |
| P0 | `WifiManager.getCurrentNetwork()` → `NetworkCapabilities.getTransportInfo()` → `WifiInfo.getBSSID()` | 新代码路径 |
| P1 | `WifiManager.getScanResults()` → `ScanResult.BSSID` | App 可能拿扫描列表交叉比对 |
| P2 | native：`/proc`、`SIOCGIWAP`、wpa_supplicant / HAL | 需 native hook |
| 保持不变 | `WifiInfo.getSSID()` | 与 iOS 一致：SSID 刻意不改 |
| 注意区分 | `WifiInfo.getMacAddress()` | Android 6 起恒为 `02:00:00:00:00:00`，**不是** AP 的 BSSID |

## 纪律（与 iOS 侧一致）

- **授权闸不放宽**：`shared/config/targets.json` 的 6 个授权字段未填齐时，
  Android 端同样拒绝构建与启用；**助手不代填授权字段**。
- 遵守验证阶梯：L0 静态 → L1 主机可跑单测 → L2 真机抓栈（证据落 `tests/evidence/`）→ L3 端到端 T1–T10。
- 外部资料必须标来源与「待实测」；**在真机输出之前，§候选 Hook 点一律只能写「待验证」**。
