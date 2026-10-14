# 新会话交接：设备选型与越狱（iPhone 12 / A14 / iOS 26）

> **本文档的用途**：用户准备"新开一轮对话专门讨论越狱与设备环境准备"。
> 新会话请**先读本文档**，再按 §1 的开场指令走。
> 项目其余上下文见 [`RESUME.md`](../../RESUME.md) → [`HANDOFF.md`](../../HANDOFF.md) → [`STATUS.md`](../STATUS.md)。

## 0. 一句话结论（先看这个，别跳过）

**用户手上的 iPhone 12（A14 / iOS 26）无法越狱，而且降级到可越狱版本的路也不通。**
在开始任何刷机操作之前，必须先接受或推翻这个结论（§2、§3 给了依据与确认清单）。

> ⚠️ 这一条如果搞错，代价是**白折腾甚至把设备刷成不可用**。所以本文档把"结论"和"依据"分开写，
> 并把"仍需确认"的项目单列（§5）。**不要在没有确认 §5 的情况下动设备。**

## 1. 新会话开场指令（可直接复制给助手）

```
先读 docs/ios/handoff-device-jailbreak.md（设备选型与越狱交接），再读 RESUME.md、
HANDOFF.md、docs/STATUS.md、docs/ios/ondevice-build-setup.md。

我的设备情况：iPhone 12，A14，当前 iOS 26（待确认具体小版本），我原以为需要刷机降级。

请按该文档 §2/§3 先帮我确认"这台机器到底能不能越狱、能不能降级"，
再按 §4 的路线表给我可执行的方案（含买什么设备、买的时候怎么验版本）。
遵守项目约定：shared/config/targets.json 的授权字段未填齐前不做真机注入、不代填；
外部资料要标注来源与"待实测"。
```

## 2. 已核实的工具支持矩阵（用户设备正好落在缺口里）

| 工具 | 支持范围 | 关键限制 | 来源 |
|---|---|---|---|
| **Dopamine**（rootless，自带 Sileo/Zebra） | iOS 15.0–17.3.1（**A14–A17 / M1–M2**）<br>iOS 15.0–18.7.1 与 26.0–26.0.1（**A8–A13**） | **A14 的上限是 17.3.1**，不支持 iOS 26 | [官方站点](https://ellekit.space/dopamine/)、[cfw.guide](https://ios.cfw.guide/installing-dopamine-trollstore/) |
| **Dopamine 3.0**（iOS 26 首个越狱） | iOS 17.3.1 支持；**iOS 26 仅 A12/A13** | 不含 A14 | [iClarified 报道](https://www.iclarified.com/101697/dopamine-30-jailbreak-released-with-ios-1731-support-ios-26-on-a12a13)、[TechSpot](https://www.techspot.com/news/113408-jailbreak-ios-26-finally-here-326-days-after.html) |
| **palera1n**（checkm8） | arm64（**arm64e 明确排除**）；设备仅到 **A11 及以下**（iPhone 8/8 Plus/X、6s、SE1、7…） | 文档原文："**arm64e devices will NEVER be supported**"；半不完美越狱；多数机型**不能设密码** | [官方 man page](https://raw.githubusercontent.com/palera1n/palera1n/main/docs/palera1n.1) |

**推论**：iPhone 12 = **A14 = arm64e** →
- Dopamine 覆盖 A14，但只到 iOS **17.3.1**（当前是 26）→ **不满足**；
- palera1n 永久排除 arm64e → **完全不适用**。

## 3. 降级（iOS 26 → ≤17.3.1）为什么不可行

四个条件缺一不可，第 2、3、4 条在 A14 + iOS 26 上都过不去：

| # | 条件 | 现状 |
|---|---|---|
| 1 | 目标版本的 **SHSH2 blobs**（按设备 ECID 唯一） | ⏳ 需问用户当年有没有存过 17.3.1 的 blobs；没存就到此为止 |
| 2 | 能在当前系统上**设置 APNonce** 的手段（越狱 / 漏洞） | ❌ iOS 26 上**没有 A14 的越狱**（见 §2），所以设不了 nonce |
| 3 | 苹果仍在签的 **SEP / 基带**与目标版本兼容 | ❌ 26 → 17.3.1 跨度太大，实际不兼容（要降到"当前签名版本附近"才谈得上） |
| 4 | 无需 bootrom 漏洞即可完成 | ❌ A14 **没有** checkm8 类 bootrom 漏洞（checkm8 只到 A11） |

> **结论**：A12 及以上机型的降级，本质上是"有 blobs 也还要有能在当前系统上设 nonce 的漏洞"。
> A14 + iOS 26 两者都没有，所以**降级这条路走不通**。
>
> 说明：这是**结构性推论**（依据上面的四条件），我没有找到官方文档直接写"iPhone 12 不能降级"。
> 因此本文档把它列为"高置信度结论 + 需按 §5 逐条确认"，而不是绝对断言。

**顺带纠正一个常见误解**：checkm8 设备（A11 及以下）**可以**在 DFU 里设 nonce，
所以那类机器"有 blobs 就能降级"。也就是说——**你手上这台 iPhone 12 是最不适合降级的那一档。**

## 4. 可行路线（按推荐度排序）

| 路线 | 需要什么 | 优点 | 缺点 |
|---|---|---|---|
| **① 换一台 A12/A13 设备**（iPhone XS/XR/11/SE2） | 系统在 **26.0–26.0.1** 或 **≤18.7.1** | 与项目当前假设（rootless `/var/jb`）完全一致；iOS 26 也能越狱 | 要买机；买之前必须**当面验系统版本** |
| **② 换一台 A14–A17 且系统 ≤17.3.1 的设备** | iPhone 12–15 系列，停在 ≤17.3.1 | 同样是 Dopamine/rootless | 二手市场这种"低版本"机器少、溢价高；系统版本不能升 |
| **③ 用 A11 及以下设备 + palera1n** | iPhone 8 / X 等（便宜） | 便宜、易得；rootless 路径**同样是 `/var/jb`**，**项目代码不用改** | 半不完美越狱（每次重启要连电脑）；**多数机型不能设密码**；系统上限较低（iPhone X/8 官方止于 iOS 16.7.x） |
| **④ 不越狱的替代验证**（仅部分场景） | Mac + iOS 模拟器等 | 无需越狱 | CoreWLAN / nehelper 在模拟器上不存在，**对本项目的核心链路价值很低**；只能验证 App 侧的一部分逻辑 |

**关键结论：换越狱工具不影响本仓库代码。** Dopamine 与 palera1n 的 rootless 布局都是
`/var/jb`，过滤器目录也都是 `/var/jb/Library/MobileSubstrate/DynamicLibraries`，
所以 `ios/scripts/deploy.sh`、`ios/layout/`、`ios/hooks/` 都不用改——**变的只是装机步骤**。

## 5. 新会话必须问清/核实的清单

**问用户（我无法自行探测）**：

1. 机型与芯片确认：iPhone 12 具体型号（`iPhone13,1` mini / `13,2` / `13,3` Pro / `13,4` Pro Max）？
2. iOS 精确版本：设置 → 通用 → 关于本机 → "iOS 版本"（**26.0 vs 26.0.1 也要看清**）。
3. 是否曾用工具（如 blob 保存工具）为**这台设备的 ECID** 存过 ≤17.3.1 的 SHSH2 blobs？
4. **能否换设备？预算与渠道**（这决定走路线 ①②③ 还是停在原地）。
5. 目标 App 的最低系统要求是什么？（新系统装不上目标 App 的话，越狱出来也没法验证——
   这条会反向约束 §4 的选择）

**核实（可在新会话继续查）**：

- 是否已有 **A14 + iOS 18/26** 的公开越狱（Dopamine 矩阵之外的新工具）；
- 26.0 vs 26.0.1 对 A12/A13 的支持差异（影响路线 ① 的选机验版标准）；
- palera1n 对 iPhone 8/X 的实际可越狱上限（man page 的 "15-26" 与 "15.0-18.0" 两处表述不一致，
  且 iPhone X/8 的官方系统上限本身就在 16.7.x）。

## 6. 本项目对设备的硬性要求（选机时一起考虑）

| 要求 | 说明 |
|---|---|
| **rootless，前缀 `/var/jb`** | 已写死进脚本与文档；Dopamine 与 palera1n rootless 都满足 |
| **能装目标 App，且能触发 Wi-Fi 信息读取** | 否则无法验证；App 的最低系统要求反向约束选机 |
| **可 SSH** | `ios/scripts/deploy.sh` 走 `iproxy` + `ssh`；Dopamine 自带，palera1n 有内置 SSH（端口见其文档） |
| **设备端可编译**（方案 C 的前提） | 见 [`ondevice-build-setup.md`](ondevice-build-setup.md)：`clang-16` / `ld64` / `ldid` / `dpkg` / `make` + `iPhoneOS16.5.sdk`（≈201 MB） |
| **授权登记** | `shared/config/targets.json` 的 6 个字段必须填齐，否则设备上会拒绝启用（**助手不代填**） |

## 7. 设备侧编译（方案 C）的入口

`BG-032` 已由用户选定为 **C（设备端 Procursus 工具链）**，完整步骤在
[`ondevice-build-setup.md`](ondevice-build-setup.md)：越狱 → Sileo 装工具链 → SDK 上机 →
编译（`bash ios/scripts/build.sh --toolchain theos`）→ 装 deb → 跑 T1–T10。

> **一旦确定换设备，`ondevice-build-setup.md` §1 的"推荐 iOS 15.0–16.6.1"需要重新评估**：
> 那条推荐是按"SDK 只到 16.5 + TrollStore 路线最简单"给的。
> 如果改走 iPhone XS/XR/11 on iOS 26，装机路线（TrollStore 不适用）与验证步骤都要按设备改写。

## 8. 本次交接的事实边界（不要含糊）

| 结论 | 性质 |
|---|---|
| Dopamine / palera1n 支持矩阵 | ✅ 官方来源（站点 / man page / 报道），本轮核实 |
| iPhone 12（A14）不在 iOS 26 的可越狱范围 | ✅ 由支持矩阵直接推出 |
| iPhone 12 **不能降级到 ≤17.3.1** | ⚠️ **结构性推论**（四条件分析），非官方文档明示；需按 §5 确认 |
| 设备端编译工具链与体积 | ✅ 包索引 / GitHub tree 实测（见 `ondevice-build-setup.md` §8） |
| 设备端全流程 | ❌ **从未实跑**（无设备、无授权） |
