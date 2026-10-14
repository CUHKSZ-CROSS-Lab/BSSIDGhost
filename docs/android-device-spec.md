# Android 测试机采购规格与验机清单

> 用途：**照着买、照着验**。本文档同时是 [`docs/adr/0001-pivot-to-android.md`](adr/0001-pivot-to-android.md)
> 里「目标设备」决策的依据留档。
>
> **性质标注约定**（全项目通用）：
> ✅ 官方明示 / 我第一手取到　🟡 社区报道　⚠️ 推断或**必须真机实测**才能确认。
> 价格一律是 ⚠️ 推断，我不为此背书。

## 0. 一句话结论

| 项 | 结论 |
|---|---|
| 机型 | **Google Pixel 无锁版**（非运营商 SKU），首选二手 **Pixel 8 / 8a** |
| 价位档 | 约 **¥1,500–2,800**（⚠️ 推断，二手行情波动大） |
| Android 版本 | 固定 **Android 15（API 35）** |
| Root | **Magisk v30.7 stable + 内置 Zygisk** |
| Hook 框架 | **Vector v2.2** |
| 模块 API | **legacy XposedBridge API 82** |
| 最大风险 | Pixel 的 **OEM 解锁需要联网校验运营商锁**，网络不通会直接灰掉 |

## 1. 机型与价位档

### 为什么是 Pixel

1. **官方允许解锁 bootloader**，且**官方工厂镜像齐全**，可以把系统精确固定在某个 Android 版本
   （[官方工厂镜像页](https://developers.google.com/android/images)，R12 实测本机可达 HTTP 200）；
2. Magisk / KernelSU / Vector 三家的社区验证都以 Pixel 为主；
3. Pixel 是 GKI 内核，KernelSU 路线同样可用（留后路）。

### 档位（⚠️ 价格均为推断）

| 档位 | 机型 | 推断价位 | 说明 |
|---|---|---|---|
| 最低成本 | 二手 Pixel 6a / 7 / 7a | ¥800–1,500 | 6a 有已知坑（见 §4 风险 7） |
| **甜点档（本决策选定）** | **二手 Pixel 8 / 8a / 8 Pro** | **¥1,500–2,800** | 性能与价格平衡；Android 15 时代机型，版本好固定 |
| 全新稳档 | Pixel 9 / 9a / 10 | ¥3,000–6,000+ | 出厂可能是 Android 16/17，降级要处理 anti-rollback |

> **必须避开**：**运营商定制版 SKU**（Verizon / AT&T 等），这类机器 bootloader 常被锁死。
> 买「**Google Store unlocked / 无锁版**」。

## 2. Android 版本：固定 Android 15（API 35）

| 候选 | 判定 | 依据 |
|---|---|---|
| **Android 15** | ✅ **选定** | Vector 支持 8.1–17 Beta（15 稳居区间内）；Magisk v30.7 已支持到 Android 16 QPR2；Android 13 的 `NEARBY_WIFI_DEVICES` 变更已包含，权限模型有代表性 |
| Android 14 | 🟡 备选 | 遇到 15 上兼容问题时回退；官方 LSPosed 最高也只到 14 |
| Android 16 | 🟡 可用 | 在支持范围内，但生态验证少于 15 |
| Android 17 | ❌ 不用 | Vector 对 17 只有 **Beta 支持** |
| Android 12 及以下 | ❌ 不用 | 缺 `NEARBY_WIFI_DEVICES` 变更，对现代机型不具代表性 |

**操作原则：买回来先看当前版本，能不动就不动。** 要改版本就刷官方工厂镜像，但必须注意
anti-rollback（§4 风险 2）。

## 3. Root 与 Hook 框架方案

| 层 | 选择 | 版本（R12 第一手核实） | 来源性质 |
|---|---|---|---|
| Root | **Magisk stable** | **v30.7**（2026-02-23），changelog 明示支持 Android 16 QPR2 + Zygisk | ✅ 官方 release |
| Hook 框架 | **Vector**（JingMatrix） | **v2.2**，最新 canary **3112（2026-10-01）** | ✅ 官方 README/release |
| 模块 API | **legacy XposedBridge API 82** | 本机实测镜像可取（`de.robv.android.xposed:api:82`，25 KB） | ✅ 我实测 |
| 隐藏（备用） | Zygisk denylist / Shamiko | — | 🟡 社区惯例 |

### 为什么不用官方 LSPosed

官方仓库最新 release 是 **v1.9.2（2023-10-11）**，README 明示 **Supported Versions: Android 8.1 ~ 14**
——对 Android 15 已过时。活跃的是 Vector 分支（README 明示支持 **Android 8.1 through Android 17 Beta**，
需 Magisk 或 KernelSU 且启用 Zygisk）。

### 备选 root

**KernelSU-Next v3.4.2（2026-10-13）** 更新极活跃，带 selinux hide 等隐藏能力，
但需要匹配内核（Pixel 6+ 的 GKI 可走 LKM）。**第一台设备建议先用 Magisk 把链路跑通。**

## 4. 风险与红线（买之前务必看完）

| # | 风险 | 性质 | 应对 |
|---|---|---|---|
| 1 | **OEM 解锁需联网校验**，国内直连 Google 可能失败 → 开关灰掉，整条方案卡死 | ✅ GrapheneOS 安装文档明示 + ⚠️ 推断（国内网络环境） | 买**非运营商 SKU**；首次解锁时准备可访问 Google 的网络环境 |
| 2 | **anti-rollback 变砖**：刷入比设备 ARB 索引更旧的镜像会变砖 | ✅ 官方机制 | 改版本前逐条核对该机型镜像页的 ARB 说明 |
| 3 | **国行小米/红米解锁门槛高**（社区等级 + 等待期 + 名额），且澎湃 OS 国际版 2026 也开始收紧 | 🟡 [XFastest 报道](https://www.xfastest.com/thread-292775-1-2.html) | 不作为首选 |
| 4 | **一加**：解锁需账号注册满 60 天 + 实名认证，一年 ≤4 台 | 🟡 [IT之家](https://m.ithome.com/html/0981128.htm)、[凤凰科技](https://news.ifeng.com/c/8v1N00Aaxti) | 不满足「本周开工」，排除 |
| 5 | **国行三星 BL 锁死**；港版可解锁但 Knox 熔断影响部分 App | 🟡 社区 / ⚠️ 推断 | 排除 |
| 6 | **飞书可能有 root/Xposed 检测** | ⚠️ **必须真机实测** | 同目标开源模块 [FeishuKit](https://modules.lsposed.org/module/com.chekayo.feishuantirecall/) 在 root 机上正常工作，是正面证据；真遇到就上 Shamiko/denylist |
| 7 | Pixel 6a：出厂系统下 OEM unlocking 不可用，需 OTA 到 2022-06 之后并恢复出厂 | ✅ GrapheneOS 文档明示 | 尽量不选 6a |

## 5. 到手验机命令清单

### Step 0：本机准备（Arch，R12 实测这两个包在官方 `extra` 源）

```sh
sudo pacman -S android-tools android-udev   # adb/fastboot 37.0.0 + udev 规则
adb devices                                  # 授权后应列出设备
```

### Step 1：买之前（界面即可，不需电脑）

| 检查 | 路径 | 期望 |
|---|---|---|
| Android 版本 | 设置 → 关于手机 | 记录完整版本号 |
| 型号 | 设置 → 关于手机 → 型号 | 确认是 Pixel 且**非运营商版** |
| **OEM 解锁开关** | 设置 → 系统 → 开发者选项 → "OEM 解锁" | **存在且不是灰色** ← 最关键 |

### Step 2：到手后（连电脑）

```sh
# 身份与版本（判断 codename、能否对上官方的工厂镜像）
adb shell getprop ro.product.model
adb shell getprop ro.product.device          # codename，去官方镜像页核对
adb shell getprop ro.product.name            # 判断是否运营商 SKU
adb shell getprop ro.build.version.release   # Android 版本
adb shell getprop ro.build.version.sdk       # API level（35 = Android 15）
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.boot.flash.locked       # 1=已锁 0=已解锁

# 解锁能力（最权威的一条）
adb reboot bootloader
fastboot flashing get_unlock_ability         # 期望 get_unlock_ability: 1
fastboot getvar unlocked
fastboot getvar current-slot
fastboot reboot
```

> ⚠️ 诚实标注：`ro.product.name`、`ro.boot.flash.locked`、`fastboot getvar unlocked`
> 这几条的**确切返回语义未在真机上实测**，属「社区常用 / 推断」。若某条返回 `unknown`
> 或报错，**属正常现象**（不同机型/版本支持不一），不要据此判定机器有问题——
> **以 `get_unlock_ability: 1` 和开发者选项里的开关为准。**

### Step 3：root 与框架装完后

```sh
adb shell su -c id                            # 期望 uid=0(root)
adb shell getprop ro.boot.verifiedbootstate   # 解锁后通常为 orange
adb shell pm list packages | grep ss.android.lark   # 确认目标 App 已装
# Vector 装好后：LSPosed 管理器里确认模块已激活 + 作用域勾选 com.ss.android.lark
```

## 6. 目标 App 事实（R12 第一手核实）

| 事实 | 值 | 来源 |
|---|---|---|
| **国内版飞书**包名（**我们的目标**） | `com.ss.android.lark` | ✅ [小米应用商店](https://app.mi.com/details?id=com.ss.android.lark)（R12 抓取） |
| 当前版本 / 更新时间 | **8.2.6** / 2026-10-13 | ✅ 同上 |
| 权限含「精确位置」 | 是 | ✅ 同上（与 Android 读 BSSID 必须定位权限吻合） |
| 国际版 Lark 包名（**不是目标**） | `com.larksuite.suite` | ✅ [Exodus Privacy](https://reports.exodus-privacy.eu.org/de/reports/416295/) |
| iOS 版飞书 BundleID | `com.ss.iphone.ugc.Lark` | 项目既有配置（`shared/config/targets.json`） |

> **飞书 8.x 换了混淆名与 native 库**（`libsqlcipher` → `libwcdb2`），且是 arm64-only（🟡 社区报道，
> 来自 FeishuKit 的发布说明）。**对本项目的直接指导**：Hook 点选 **Android 系统接口**
> （`WifiInfo.getBSSID()` / `NetworkCapabilities.getTransportInfo()`），
> 不要去 hook 飞书自己的混淆类。

## 7. Android 权限事实（官方明示，影响 Hook 点与测试设计）

- target Android 13+ 的应用应申请 **`NEARBY_WIFI_DEVICES`** 运行时权限；
  在更早版本上则需要 **`ACCESS_FINE_LOCATION`**。
- **但若干 Wi-Fi API 即使在 Android 13+ 仍要求 `ACCESS_FINE_LOCATION`**，
  官方文档举的例子是 `WifiManager.getScanResults()` 与 `startScan()`。
- 缺少相应权限时调用 Wi-Fi API 会抛 **`SecurityException`**。

来源：[Android 官方权限文档](https://developer.android.com/develop/connectivity/wifi/wifi-permissions)（R12 抓取）。

> ⚠️ `WifiInfo.getBSSID()` / `getConnectionInfo()` 具体需要哪一个权限，
> 官方该页未逐条列出，**必须真机实测确认**（这与 iOS 侧的 nil 语义风险同族）。

## 8. 必须真机实测才能确认的项（本规格的缺口）

1. 目标 Pixel 的 `fastboot flashing get_unlock_ability` 是否为 1；
2. 国行网络环境下 OEM unlocking 开关是否会因联网校验而灰掉；
3. 飞书 8.2.6 在 root + Vector 环境下能否正常启动与联网（有无 root/Xposed 检测）；
4. `WifiInfo.getBSSID()` / `NetworkCapabilities.getTransportInfo()` 在 Android 15 上的具体权限要求；
5. 飞书实际读取 BSSID 走的是哪条通道（这是 R15 的 Frida 抓栈任务）。
