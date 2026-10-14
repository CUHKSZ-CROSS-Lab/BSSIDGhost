# 新会话交接：设备选型与越狱（iPhone 12 / A14 / iOS 26）

> **本文档的用途**：用户准备"新开一轮对话专门讨论越狱与设备环境准备"。
> 新会话请**先读本文档**，再按 §1 的开场指令走。
> 项目其余上下文见 [`RESUME.md`](../../RESUME.md) → [`HANDOFF.md`](../../HANDOFF.md) → [`STATUS.md`](../STATUS.md)。

## 0. 一句话结论（先看这个，别跳过）

> ### ⚠️ R14 校正（2026-10-14）：本文档的**主线已被 ADR-0002 取代**
>
> 本文档现在只剩两个作用：
> 1. 存档「**为什么 iPhone 12（A14 / iOS 26）被否**」——这个结论仍然成立；
> 2. 存档一个**已修正的错误推论**（见 §2.1）：本文档曾用「arm64e 排除」错误地把
>    **iPhone 8 / 8 Plus / X 一并否定**，而它们其实**被 palera1n 与 Dopamine 双重支持**。
>
> **当前主线**：采购 **iPhone 8（A11）+ Dopamine**，见
> [`docs/ios/device-spec.md`](device-spec.md) 与 [`docs/adr/0002-return-to-ios.md`](../adr/0002-return-to-ios.md)。
> 教训已写入 §2.1 与 §5。

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
| **palera1n**（checkm8） | **A8 – A11**（官方 README 机型表**明确列出 iPhone 8 / 8 Plus / X**）；iOS/iPadOS **15.0–18.0**（arm64 设备） | semi-**tethered**（每次重启都要连电脑）；**A11 官方明示不能设密码**；man page 里 `arm64e devices will NEVER be supported` 指的是 **A12 及以上**，**不含 A11** | [仓库描述](https://github.com/palera1n/palera1n)「Jailbreak for **A8 through A11**」、官方 README 机型表、[man page](https://raw.githubusercontent.com/palera1n/palera1n/main/docs/palera1n.1) |

### 2.1 ⚠️ 已修正的错误推论（本文档原稿在此处判断错了）

原稿写「palera1n：arm64（**arm64e 明确排除**）……iPhone 8/8 Plus/X」——
**这句话自相矛盾**（iPhone 8/8 Plus/X 本身就是 arm64e），而且把一整类可行机型误杀了。

第一手原文（palera1n man page）实际是：

```
jailbreaks an arm64 (arm64e excluded) iOS/iPadOS/tvOS 15-26, bridgeOS 5-10 device,
utilizing the checkm8 bootROM exploit.
...
On A11 devices, that is, iPhone 8, iPhone 8 Plus and iPhone X, the passcode cannot be used.
...
.Sh SUPPORTED DEVICES
.It iPhone 8
.It iPhone 8 Plus
.It iPhone X
...
arm64e devices will NEVER be supported.
```

判别依据：**不会给不支持的设备写专门一节**（`On A11 devices …`），且 `SUPPORTED DEVICES`
列表里逐个列出了它们。palera1n 文档的措辞不严谨——把 A8–A11 称作 "arm64"、把 A12+ 称作 "arm64e"。

**对 iPhone 12 的结论（不能越狱）依然成立，但理由不是 arm64e，而是 A14 不在 checkm8 范围内。**
当年"结论对、理由错"，而错误理由被继续外推，差点误杀 iPhone 8。

> **纪律（新增）**：不要用二手推论去否定一整类机型。判断某机型能否越狱，
> 必须回到官方**支持设备列表**本身核对，而不是从一句概括性描述外推。

**推论**：iPhone 12 = **A14** →
- Dopamine 覆盖 A14，但只到 iOS **17.3.1**（当前是 26）→ **不满足**；
- palera1n 需要 checkm8 bootrom 漏洞，而 **checkm8 只到 A11**，A14 没有 → **不适用**。

> 注意归因：**不是**因为「arm64e 被排除」——A11 同样是 arm64e 且被支持。
> 真正的原因是**芯片是否落在 checkm8 范围内**（A11 及以下）。

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

| 路线 | 需要什么 | 优点 | 缺点 | 结论 |
|---|---|---|---|---|
| **① A11 设备 + Dopamine**（iPhone 8 / 8 Plus / X） | 系统 **≤16.6.1** 优先（可装 TrollStore） | 便宜易得；**Dopamine 支持 A8–A11**；rootless `/var/jb` 与仓库假设**完全一致**；semi-untethered（重启后点 App 即可，不需电脑） | 从 16.7.16 退不回 ≤16.6.1（除非有 blobs）→ 版本必须买的时候就对 | ✅ **R14 选定** |
| **② A11 设备 + palera1n** | 同上 | 免签名烦恼；bootrom 漏洞不受系统版本限制 | **A11 官方明示不能设密码**；semi-**tethered**（每次重启要连电脑） | 🟡 备选 |
| **③ A12/A13 设备**（iPhone XS/XR/11/SE2） | 系统在 26.0–26.0.1 或 ≤18.7.1 | 系统新 | 贵；同样要买机验版本 | 🟡 备选 |
| **④ A14–A17 且 ≤17.3.1** | iPhone 12–15 系列停在 ≤17.3.1 | 同 Dopamine/rootless | 二手机少、溢价高 | ❌ 性价比差 |
| **⑤ 不越狱的替代验证** | Mac + iOS 模拟器 | 无需越狱 | CoreWLAN / nehelper 在模拟器上不存在，**对本项目核心链路价值很低** | ❌ 不适用 |

**关键结论：换越狱工具不影响本仓库代码。** Dopamine 与 palera1n 的 rootless 布局都是
`/var/jb`，过滤器目录也都是 `/var/jb/Library/MobileSubstrate/DynamicLibraries`，
所以 `ios/scripts/deploy.sh`、`ios/layout/`、`ios/hooks/` 都不用改——**变的只是装机步骤**。

> 完整采购规格（版本约束、TrollStore 边界、Dopamine 安装 SOP、验机命令）见
> [`docs/ios/device-spec.md`](device-spec.md)。

## 5. 新会话必须问清/核实的清单

**问用户（我无法自行探测）**：

1. 机型与芯片确认：iPhone 12 具体型号（`iPhone13,1` mini / `13,2` / `13,3` Pro / `13,4` Pro Max）？
2. iOS 精确版本：设置 → 通用 → 关于本机 → "iOS 版本"（**26.0 vs 26.0.1 也要看清**）。
3. 是否曾用工具（如 blob 保存工具）为**这台设备的 ECID** 存过 ≤17.3.1 的 SHSH2 blobs？
4. **能否换设备？预算与渠道**（这决定走路线 ①②③ 还是停在原地）。
5. 目标 App 的最低系统要求是什么？（新系统装不上目标 App 的话，越狱出来也没法验证——
   这条会反向约束 §4 的选择）

**核实（R14 已给出答案）**：

- ~~palera1n 对 iPhone 8/X 的实际可越狱上限~~ → ✅ **已核实：支持**。iPhone 8 系统上限
  **16.7.16**，palera1n 支持「arm64 iOS 15.0–18.0」，覆盖该机型全区间；且 Dopamine 也支持 A8–A11；
- ~~是否已有 A14 + iOS 18/26 的公开越狱~~ → 仍然没有（不影响本决策，主线已避开 A14）；
- ~~26.0 vs 26.0.1 对 A12/A13 的支持差异~~ → 与本决策无关（不再走 A12/A13 路线）。

> ⚠️ 上面 §5 的「问用户」清单是为**当年那台 iPhone 12** 写的，已作废。
> 现在要问/要验的项都在 [`docs/ios/device-spec.md`](device-spec.md)。

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
