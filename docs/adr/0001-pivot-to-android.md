# ADR-0001：从 iOS 转向 Android，双端单仓组织

- **状态**：已采纳（R12，2026-10-14）
- **决策者**：用户
- **相关**：`BG-050`、`BG-051`；前置轮次 R1–R11（见 [`docs/STATUS.md`](../STATUS.md)）

## 1. 背景

项目原定义（HANDOFF §1）是「**iOS 越狱机**场景下 Hook 篡改 Wi-Fi 信息接口，伪造目标 App
读取到的 BSSID 返回值」。

R10 的核实结论是：用户手上的 **iPhone 12（A14 / iOS 26）既不能越狱、也不能降级**——
Dopamine 对 A14 的上限是 iOS 17.3.1，palera1n 永久排除 arm64e，降级四条件在 A14 + iOS 26 上
全不成立。也就是说，iOS 路线被**设备可得性**卡死，而不是被技术难度卡死。

结论留档见 [`docs/ios/handoff-device-jailbreak.md`](../ios/handoff-device-jailbreak.md)。

## 2. 决策

**主战场转向 Android**，并把仓库改为「单仓双端」。理由：

1. **解除瓶颈**：iOS 必须先有一台**能越狱的特定机型**；Android 只需要一台**能 root 的机器**，
   root 生态（Magisk / KernelSU）远比 iOS 越狱宽松且活跃。
2. **目标 App 一致**：Android 版飞书 = `com.ss.android.lark`；iOS 版飞书 BundleID 是
   `com.ss.iphone.ugc.Lark`（注意**不是**国际版 Lark 的 `com.larksuite.suite`）。
   两端是同一个产品、同一类判定逻辑，项目的技术定义不变。
3. **核心资产可带走**：映射逻辑与授权闸是**纯 C**，且有 92 条主机断言。它们描述的是
   「行为规格」，不是 iOS 实现细节，可以原样作为 Android 端的对照真值。
4. **iOS 侧投入已到边际**：R2–R9 的产出里，Hook 实现本身仍是**占位**（`BGGhostCoreWLAN.m`
   39 行 + `BGGhostHotspot.m` 29 行，全是 TODO）。被冻结的是「壳」，不是「已验证的核心」。

## 3. 两版关系与冻结策略

| 项 | 结论 |
|---|---|
| iOS 版 | **冻结（frozen）**：保留全部代码与文档，可回看、可复现，**不再投入开发** |
| 冻结点 | git tag **`ios-r11-host-verified`**（141 项主机断言全通过的状态） |
| Android 版 | **当前主线**，R12 起的轮次都服务于它 |
| 共享层 | `shared/`：平台中立的规格、配置 schema 与测试向量 |
| 不做的 | **不删除**任何 iOS 资产；不改写历史提交 |

## 4. 目录约定（R12 起）

```
shared/   平台中立：配置 schema（config/）、语言中立测试向量（vectors/）
ios/      iOS 实现（冻结）：hooks/ ObjC+C 核心、layout/、Makefile、control、scripts/、tests/
android/  Android 实现（R14 起填充）
docs/     跨端文档：STATUS.md、adr/；iOS 专属文档在 docs/ios/
scripts/  跨端脚本：bootstrap.sh、publish.sh
tests/    跨端：测试矩阵（T1–T10）与证据规范；平台测试在 <platform>/tests/
```

**根目录解析改为可验证**：`ios/scripts/lib/common.sh` 按相对层级推导仓库根后，
会断言 `shared/config/targets.json` 存在，否则**立即失败并报错**，
而不是拿着错的根目录静默跑偏（这是本次重构引入的风险，已用哨兵封住）。

## 5. Android 端已定的技术选型（R12 核实）

| 项 | 结论 | 性质 |
|---|---|---|
| 注入路线 | 先 **Frida 只读抓栈**确认飞书实际走哪个接口，再落 **LSPosed 模块** | 用户决策（与 iOS 的 BG-011→BG-030 同构） |
| Root | **Magisk v30.7（stable）+ 内置 Zygisk** | 见设备规格 |
| Hook 框架 | **Vector v2.2**（`JingMatrix/Vector`） | 官方 LSPosed 最后发布 v1.9.2（2023-10-11）且 README 明示只支持 **Android 8.1~14**，对 Android 15 已过时 |
| 模块 API | **legacy XposedBridge API 82** 为主 | 覆盖传统 LSPosed 与 Vector；新版 libxposed API 102 作为可选分支 |
| 目标设备 | 二手 **Google Pixel 8 / 8a**，**Android 15（API 35）** | 用户决策，详见 [`docs/android-device-spec.md`](../android-device-spec.md) |
| 编译链 | **本机脚本化最小链**：`javac` + `d8/R8` + `aapt2` + `apksig` | **已端到端实测**（本机打出并签名了一个 APK，签名验证通过） |

> 编译链可用的意义：Android 端**不存在** iOS 那种「编译链落点三选一」的纠结——
> 不需要 Mac、不需要 Android Studio、不需要 `dl.google.com`（本机 IPv6 不可达），
> 全部构件走镜像即可。

## 6. 后果与代价

**正面**

- iOS 的「设备选型 + 越狱 + 降级」整条不确定性消失。
- 92 条断言与两个模拟器继续有效，Android 端用它做交叉验证。
- 主机侧可验证的部分大幅提前：R12–R14 不需要设备即可推进。

**负面 / 风险**

- iOS 侧已投入的 theos 打包、ObjC 桩、抓栈脚本**在 Android 端全部无效**，
  需要按 Android 的方式重写（这部分约 2,000 行，但其中 Hook 实现本就是占位）。
- 结构改动会打断旧文档里的相对链接——已在 R12 用**链接检查器**兜住（见下）。
- 目标 App 在 Android 上是否有 root/Xposed 检测，**仍需真机实测**；
  同目标的开源模块 [FeishuKit](https://modules.lsposed.org/module/com.chekayo.feishuantirecall/)
  在 root 机上正常工作，是「硬阻断不强」的正面证据，但**不能替代实测**。

## 7. 本次转向**没有**改变的东西

- 技术定义：改的是「API 返回的字符串」，不是「实际连接的 AP」；SSID 刻意不变。
- 授权闸纪律：`shared/config/targets.json` 的 6 个字段仍为 `fill_me`，
  **助手不代填**；未填齐则 Android 端同样拒绝构建与启用。
- 验证阶梯 L0→L3 与「实测 vs 外部资料」的标注纪律。
- 轮次与任务编号体系（`R` 与 `BG-xxx` **延续**，不另起一套，iOS 历史不断链）。
