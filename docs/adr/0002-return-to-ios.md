# ADR-0002：主线切回 iOS，Android 暂停冻结

- **状态**：已采纳（R14，2026-10-14）
- **决策者**：用户
- **相关**：`BG-059`、`BG-060`；推翻/修正了 [`ADR-0001`](0001-pivot-to-android.md) 的**主线判断**（结构决策保留）

## 1. 背景

R12 决定从 iOS 转向 Android，理由是「iOS 路线的瓶颈是**必须有一台能越狱的特定机型**，
而用户手上的 iPhone 12（A14 / iOS 26）既不能越狱也不能降级」。

R14 用户提出改为采购 **iPhone 8（A11）**，要求重新评估 iOS 路线是否可行。

重新核实后结论是：**可行，而且成本比预期低**。

## 2. 触发本次反转的关键事实（均为第一手来源）

| 事实 | 来源 | 性质 |
|---|---|---|
| **Dopamine 支持 A8–A11**（`arm64 (A8 - A11)`）、**rootless**、支持到 iOS 15.0–18.7.1（A8–A13） | [ellekit.space/dopamine](https://ellekit.space/dopamine/) 官网原文 | ✅ 官方明示 |
| palera1n 支持 **A8–A11**，官方 README 机型表明确列出 **iPhone 8 / 8 Plus** | [palera1n](https://github.com/palera1n/palera1n) 仓库描述 + README + man page | ✅ 官方明示 |
| iPhone 8 固件区间 **11.0 → 16.7.16**，且 **16.7.16 至今仍在 Apple 签名** | ipsw.me 实测查询（6 个 iPhone 8/8P/X 型号一致） | ✅ 实测 |
| Dopamine 是 **semi-untethered**：重启后点 App 图标即可，**不需要电脑** | [ios.cfw.guide/installing-dopamine](https://ios.cfw.guide/installing-dopamine/) | 🟡 权威社区文档 |
| TrollStore 支持 **14.0b2–16.6.1 / 16.7 RC / 17.0**；**16.7.x 正式版「will NEVER be supported」** | [TrollStore README](https://github.com/opa334/TrollStore) 原文 | ✅ 官方明示 |
| iOS 16.7+ 上 Dopamine **每 7 天需重签一次** | cfw.guide 安装页原文 | 🟡 权威社区文档 |

**最关键的发现**：Dopamine（A8–A11）是 **rootless + `/var/jb`**，
与仓库现有假设（`Makefile` 的 `THEOS_PACKAGE_SCHEME=rootless`、`layout/` 的 `/var/jb`、
`ios/scripts/deploy.sh`、`control` 的 `Depends: ellekit | mobilesubstrate`）
**完全一致——iOS 侧代码一行都不用改**。

## 3. 决策

1. **主线切回 iOS**，目标设备 **iPhone 8（A11）**，越狱工具 **Dopamine**。
2. **目标 iOS 版本：优先采购已在 ≤16.6.1 的机器**（该区间可装 TrollStore → Dopamine 免重签）。
   备案：16.7.16 同样可越狱，代价是每 7 天重签且无 TrollStore。
3. **Android 暂停冻结**（不是删除）：代码、文档、设备规格全部保留，随时可解冻。
4. **本轮只改文档**：不安装任何工具；真编译按 R9 已定的**方案 C（设备端 Procursus 工具链）**，
   等设备到位后执行。

## 4. 被本次核实推翻的错误结论（必须留档）

[`docs/ios/handoff-device-jailbreak.md`](../ios/handoff-device-jailbreak.md) §2 曾写：

> palera1n「arm64（**arm64e 明确排除**）；设备仅到 A11 及以下（iPhone 8/8 Plus/X…）」

**这句话是错的，而且自相矛盾**（iPhone 8/8 Plus/X 本身就是 arm64e）：

- palera1n man page 中 `arm64e devices will NEVER be supported` 指的是 **A12 及以上**
  （palera1n 文档措辞不严谨：把 A8–A11 称作 "arm64"、A12+ 称作 "arm64e"）；
- 同一份 man page 的 `SUPPORTED DEVICES` 明确列出 iPhone 8 / 8 Plus / iPhone X，
  并且有专门一节 `On A11 devices, that is, iPhone 8, iPhone 8 Plus and iPhone X, the passcode cannot be used.`
  ——**不会给不支持的设备写专门一节**。

**对 iPhone 12 的结论（不能越狱）依然成立，但理由不是 arm64e，而是 A14 不在 checkm8 范围内。**
当年"结论对、理由错"，而错误的理由被继续外推到 iPhone 8/X，差点误杀一个可行机型。

> 教训（已写进 `docs/ios/handoff-device-jailbreak.md` 与 §6 纪律）：
> **不要用一个二手推论去否定一整类机型**；支撑矩阵必须回到官方"支持设备列表"本身核对。

## 5. 后果与代价

**正面**

- iOS 是项目的原始定义，回到主线后**代码零改动**（rootless/`/var/jb`/ElleKit 全部对得上）；
- 机器便宜、Apple 至今仍签名 16.7.16 → 系统版本**可复现**，对测试机是优点；
- R12 搭好的单仓双端结构继续有效，切换主线只是文档动作。

**负面 / 风险**

- **采购约束硬**：从 16.7.16 退回 ≤16.6.1 不可行（除非有该机 ECID 的 SHSH2 blobs），
  所以 ≤16.6.1 **只能在买的时候就在那个版本** → 验机流程必须把版本核验放在第一位；
- A11 是 **arm64e** 设备：tweak 需要 arm64e 切片（`Makefile` 已是 `ARCHS = arm64 arm64e`，无需改），
  但 palera1n 文档里 "arm64e excluded" 的措辞是否影响其注入行为，**未实测**；
- **Dopamine 是否要求关闭密码，官方无明示**（palera1n 在 A11 上明示要求关闭）→ **待真机实测**；
- 设备未到位前，iOS 侧仍无法执行真机任务（BG-011 抓栈、BG-030 框架选型、真编译）。

## 6. 本次反转**没有**改变的东西

- 技术定义、授权闸纪律（`shared/config/targets.json` 仍 `fill_me`，助手不代填）、
  验证阶梯 L0→L3、「实测 vs 外部资料」的标注纪律；
- **单仓双端结构**（`shared/` + `ios/` + `android/`，见 ADR-0001 §4）；
- **语言中立向量**（R13 产出，110 条断言）——它是跨端资产，与主线在哪一侧无关；
- 轮次与任务编号体系（`R` 与 `BG-xxx` 继续）。
