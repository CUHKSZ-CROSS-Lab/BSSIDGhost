# 项目状态（单一进度真源）

> **规则**：所有进行中的工作都必须有 `BG-` 编号；每轮结束更新本文件 **与** [`HANDOFF.md`](../HANDOFF.md)。
> 状态取值：`todo` / `doing` / `blocked` / `done`。证据一律写仓库内相对路径。

## 当前轮次

| 轮次 | 主题 | 状态 |
|---|---|---|
| R1 | 工程化与流程最小集（决策 A 的先做部分） | ✅ 完成 |
| R2 | B 线（真机抓链路方案）与 C 线（映射逻辑 + 主机侧单测）并行 | ✅ 完成（真机执行仍阻塞） |
| R3 | 授权闸与日志落盘（BG-022）+ L0 配置契约检查 | ✅ 完成 |
| R4 | theos 打包骨架 + 三个脚本真实实现（BG-031/033），均带 `--dry-run` 且已自检 | ✅ 完成 |
| R5 | ObjC 层首次获得编译器检查（BG-035：最小 Foundation 桩 + `-fsyntax-only`） | ✅ 完成 |
| R6 | 授权闸模拟器（BG-036）+ 编译链决策说明（BG-032 的决策材料） | ✅ 完成 |
| R7 | 映射模拟器（BG-038）+ nehelper 可证伪实验设计（BG-039） | ✅ 完成 |
| R8 | 交接方案（BG-040：RESUME/bootstrap/publish）+ 修复换 Mac 后的 ObjC 假通过风险 | ✅ 完成 |
| R9 | **BG-032 决策落地：选定方案 C（设备端 Procursus 工具链）** + 设备准备 SOP（BG-043） | ✅ 完成 |
| R10 | 设备选型与越狱：用户 iPhone 12 / A14 / iOS 26 落在可越狱缺口里 | ⛔ 关闭（结论已留档，路线作废） |
| R11 | iOS 真机执行：越狱装机 → 设备端编译 → 装 deb → 跑 T1–T10 | ⛔ 冻结（随 iOS 版一起冻结） |
| **R12** | **转向 Android：ADR 留档 + 冻结 iOS + 单仓双端重构 + 修两个真实缺陷** | ✅ 完成 |
| R13 | 语言中立测试向量（`shared/vectors/`，两端跑同一份） | ⏳ 待开始（不需要设备） |
| R14 | Android Java 核心（映射 + 授权闸）+ 本机构建链脚本 + 主机单测 | ⏳ 待开始（不需要设备） |
| R15 | Frida 只读抓栈：确认飞书实际走哪条 Wi-Fi 信息通道（等价 iOS 的 BG-011） | ⏳ 阻塞于测试机 |
| R16 | LSPosed 模块实现 + 部署 + 端到端 T1–T10 | ⏳ 阻塞于 R15 |

> **主线已从 iOS 切到 Android**（[ADR-0001](adr/0001-pivot-to-android.md)，R12）。
> iOS 相关任务状态一律记为 `frozen`——**保留代码与证据，不再推进**。

## 任务板

| ID | 任务 | 状态 | 依赖 | 证据 |
|---|---|---|---|---|
| BG-001 | 建立 git 仓库与 `.gitignore` | done | — | [`.gitignore`](../.gitignore) |
| BG-002 | 建立 STATUS/HANDOFF 轮次节奏（单一进度真源） | done | BG-001 | 本文件、[`HANDOFF.md`](../HANDOFF.md) |
| BG-010 | 确认测试机越狱类型与 iOS 版本 | done | — | 见「已确认环境事实」 |
| BG-011 | 真机 Frida 抓取 Wi-Fi 信息接口真实调用栈（iOS） | **frozen** | 授权闸、设备、主机装 frida | 工具已就绪：[`ios/tests/frida/`](../ios/tests/frida/)、[`docs/ios/device-setup.md`](ios/device-setup.md) |
| BG-012 | 确认返回形态与格式（NSString / NSData / 结构体）（iOS） | frozen | BG-011 | — |
| BG-013 | 枚举交叉校验通道（多接口 / 公网出口 IP / mDNS / ARP）（iOS） | frozen | BG-011 | — |
| BG-020 | 实现 `BGGhostMapBSSID()` 映射逻辑（含 nil 语义与格式一致性） | **done** | — | [`ios/hooks/BGGhostRules.c`](../ios/hooks/BGGhostRules.c)、[`ios/hooks/BGGhostMap.m`](../ios/hooks/BGGhostMap.m) |
| BG-021 | 主机侧可跑单测（不依赖真机） | **done** | BG-020 | [`ios/tests/host/run.sh`](../ios/tests/host/run.sh)（L0 + 92 条断言全通过） |
| BG-022 | 映射表读取 / 日志落盘 / 授权闸的配置读取实现 | **done** | — | [`ios/hooks/BGGhostAuth.c`](../ios/hooks/BGGhostAuth.c)、[`ios/hooks/BGGhostConfig.m`](../ios/hooks/BGGhostConfig.m)、日志落盘在 [`ios/hooks/Hooks.m`](../ios/hooks/Hooks.m) |
| BG-023 | L0 配置契约检查（JSON ↔ C 键名/容量/格式） | **done** | — | [`ios/tests/host/check-config-contract.sh`](../ios/tests/host/check-config-contract.sh)（含 3 组反向用例验证） |
| BG-030 | 选定 Hook 框架并跑通最小 PoC（iOS） | frozen | BG-011 | — |
| BG-031 | 补全 `build.sh` / `deploy.sh` / `verify.sh` 真实实现（iOS） | **frozen** | BG-032（真编译验证） | 三条命令已实现并自检（`--dry-run`）：[`scripts/`](../ios/scripts/)、[`ios/tests/host/check-scripts.sh`](../ios/tests/host/check-scripts.sh)；**待真实工具链验证** |
| BG-032 | 决定编译链落点 | **done（= C，用户 2026-10-13 选定）** | — | 决策说明见 [`docs/ios/build-chain-options.md`](ios/build-chain-options.md)；执行 SOP 见 [`docs/ios/ondevice-build-setup.md`](ios/ondevice-build-setup.md) |
| BG-033 | theos 打包骨架（Makefile / control / layout 过滤器） | **done** | — | [`Makefile`](../ios/Makefile)、[`control`](../ios/control)、[`ios/layout/…/BSSIDGhost.plist`](../ios/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist) |
| BG-034 | 脚本自检（正向 dry-run + 反向授权闸/占位符） | **done** | — | [`ios/tests/host/check-scripts.sh`](../ios/tests/host/check-scripts.sh)（17/17 通过） |
| BG-035 | ObjC 层编译期检查（最小 Foundation 桩 + `-fsyntax-only`） | **done** | — | [`ios/tests/objc-stub/`](../ios/tests/objc-stub/)、[`ios/tests/host/check-objc-syntax.sh`](../ios/tests/host/check-objc-syntax.sh)（17/17，含 5 条反向用例） |
| BG-036 | 授权闸模拟器（真实判定代码 + 真实配置的端到端判定） | **done** | — | [`ios/tests/host/gate-sim.sh`](../ios/tests/host/gate-sim.sh)、[`ios/tests/host/gate_sim.c`](../ios/tests/host/gate_sim.c)（自检 6/6） |
| BG-037 | 编译链决策说明（BG-032 的决策材料 + 已实测前置条件） | **done** | — | [`docs/ios/build-chain-options.md`](ios/build-chain-options.md) |
| BG-043 | 设备端编译/验证环境搭建 SOP（Dopamine 安装 + Procursus 工具链 + SDK 上机 + 编译验证闭环） | **done** | BG-032 | [`docs/ios/ondevice-build-setup.md`](ios/ondevice-build-setup.md) |
| BG-044 | 设备选型与越狱交接（支持矩阵核实 + 降级可行性分析 + 路线对比） | **done** | — | [`docs/ios/handoff-device-jailbreak.md`](ios/handoff-device-jailbreak.md) |
| BG-038 | BSSID 映射模拟器（真实映射代码 + 真实配置的端到端） | **done** | — | [`ios/tests/host/map-sim.sh`](../ios/tests/host/map-sim.sh)、[`ios/tests/host/map_sim.c`](../ios/tests/host/map_sim.c)（自检 8/8） |
| BG-039 | nehelper 可证伪实验设计（假设 / 判别表 / 证伪条件 / 两步 attach） | **done** | — | [`docs/ios/tech-chain.md`](ios/tech-chain.md) §2.2、[`ios/tests/frida/README.md`](../ios/tests/frida/README.md) |
| BG-040 | 交接方案：环境自检 / 5 分钟恢复指南 / 推送与 PR 脚本 | **done** | — | [`RESUME.md`](../RESUME.md)、[`scripts/bootstrap.sh`](../scripts/bootstrap.sh)、[`scripts/publish.sh`](../scripts/publish.sh) |
| BG-041 | 修复「换到 macOS 后 ObjC 检查假通过」风险（桩与真 SDK 二选一 + 反向用例） | **done** | — | [`ios/tests/host/check-objc-syntax.sh`](../ios/tests/host/check-objc-syntax.sh)（18/18，含假 SDK 反向用例） |
| BG-045 | 测试矩阵 T1–T10 执行与取证（**R12 由 BG-040 改号**：原先一号两用，见轮次记录） | blocked | BG-030、授权闸 | [`tests/README.md`](../tests/README.md)（T5/T7 逻辑部分已由 L1 覆盖） |
| BG-050 | 转向 Android：ADR 留档 + 冻结 iOS（tag `ios-r11-host-verified`）+ 单仓双端目录重构 | **done** | — | [`docs/adr/0001-pivot-to-android.md`](adr/0001-pivot-to-android.md)、[`ios/README.md`](../ios/README.md)、[`android/README.md`](../android/README.md)、[`shared/README.md`](../shared/README.md) |
| BG-051 | 修复两个真实缺陷：`bootstrap.sh` 过期关键路径提示、任务板 BG-040 重号；并加装文档链接检查器守住重构 | **done** | BG-050 | [`scripts/bootstrap.sh`](../scripts/bootstrap.sh)、[`scripts/check-links.sh`](../scripts/check-links.sh)（203 条内部链接全通过） |
| BG-052 | Android 测试机采购规格与验机清单（机型/版本/root/命令，逐条附来源与性质） | **done** | — | [`docs/android-device-spec.md`](android-device-spec.md) |
| BG-053 | 语言中立测试向量：把 92 条断言抽成 `shared/vectors/`，两端同跑 | todo | BG-050 | 占位：[`shared/vectors/README.md`](../shared/vectors/README.md) |
| BG-054 | Android Java 核心（映射 + 授权闸）移植 + 主机单测（JVM 直接跑） | todo | BG-053 | — |
| BG-055 | Android 本机构建链脚本（`javac` + `d8/R8` + `aapt2` + `apksig`）+ 骨架 APK | todo | BG-050 | R12 已手工实测整链可行（见轮次记录） |
| BG-056 | Android 版 Frida 只读抓栈（确认飞书实际走的 Wi-Fi 信息通道） | blocked | BG-052（设备到位） | — |
| BG-057 | LSPosed 模块实现（Vector + legacy API 82）+ 部署脚本 + 端到端 T1–T10 | todo | BG-054、BG-055、BG-056 | — |

## 已确认环境事实（不要重复探测）

### 决策与环境

| 项 | 结论 | 来源 |
|---|---|---|
| **当前主线** | **Android**（[ADR-0001](adr/0001-pivot-to-android.md)，R12 起） | 用户决策 |
| **目标 App** | 国内版飞书 **`com.ss.android.lark`**（小米应用商店在架 **8.2.6**，2026-10-13 更新） | [设备规格](android-device-spec.md) §6 |
| **目标设备** | 二手 Google Pixel 8 / 8a，固定 **Android 15（API 35）** | 用户 2026-10-14 选定 |
| **注入路线** | 先 Frida 只读抓栈，再落 **LSPosed 模块** | 用户 2026-10-14 选定 |
| **Hook 框架** | **Vector v2.2** + legacy XposedBridge **API 82**（官方 LSPosed 停在 v1.9.2，只到 Android 14） | [ADR-0001](adr/0001-pivot-to-android.md) §5 |
| **Android 编译链** | **本机命令行**：`javac` + `d8/R8` + `aapt2` + `apksig`（镜像取件，无需 Android Studio） | R12 端到端实测 |
| 授权状态 | 未登记（`fill_me`），全部闸门关闭（**两端共用同一套闸门**） | [`shared/config/targets.json`](../shared/config/targets.json) |
| —— 以下为 iOS 冻结存档（不再推进）—— | | |
| 测试机越狱 | Dopamine / rootless | 用户（R1） |
| 目标 iOS | 15.0–16.6.x | 用户（R1） |
| 注入路径前缀 | `/var/jb`（`/var/jb/usr/lib`、`/var/jb/Library/MobileSubstrate/DynamicLibraries`） | 由 rootless 推导 |
| iOS 编译链 | 方案 C：越狱设备上用 Procursus 工具链就地编译（用户 2026-10-13 选定） | 已定，随 iOS 冻存 |

### 本机（Linux）能力审计

| 能力 | 状态 |
|---|---|
| 真机连接 | ❌ `idevice_id -l` → `Unable to retrieve device list!`（当前无设备） |
| libimobiledevice | ✅ `idevice_id` / `iproxy` / `idevicesyslog` / `idevicedebug` / `idevicescreenshot` / `ideviceinfo` |
| 基础工具 | ✅ `ssh` / `scp` / `jq` / `git`（身份已配）/ `clang 22` / `pacman` + `yay` |
| Frida | ❌ 无 CLI；Python 无 `pip`，故 `frida-tools` 不可装；npm `frida@17.23.3`（npmmirror 有）可行但 R1 决定不装 |
| theos / iPhoneOS SDK / `ldid` / `dpkg-deb` | ❌ 全无；`clang 22` 支持 arm64 目标但**无 SDK，无法在本机交叉编译** |
| 网络 | ⚠️ `registry.npmjs.org` **不可达**（DNS 仅 IPv6、连接超时）；`registry.npmmirror.com` 200；`github.com` 200 |

### Android 构建链（R12 **端到端实测**，不要再重复探测）

| 环节 | 工具 | 本机实测结果 |
|---|---|---|
| 编译 | `android.jar`（API 26–37，GitHub raw 镜像） | ✅ 27.7 MB 下载成功；对**真实 API** 编译通过 |
| 资源 / manifest | `aapt2` 9.4.1（阿里云 Google Maven） | ✅ 二进制在本机可执行（`aapt2 2.20-15978811`） |
| dex 化 | `d8`（R8 9.5.26） | ✅ 生成 `classes.dex` |
| 签名 | `apksig`（阿里云 Google Maven） | ✅ 打出签名 APK，**验证 `verified = true`**（v3 方案） |
| 模块 API | legacy `api:82` / `libxposed api:102.0.0` | ✅ 模块骨架编译通过（含 `WifiInfo.getBSSID` hook） |
| 部署 | `android-tools 37.0.0` + `android-udev`（Arch `extra` 官方源） | ✅ 可装（adb / fastboot） |
| 抓栈 | `frida-server 17.23.3 android-arm64`（GitHub Releases） | ✅ 可取，与 npm `frida@17.23.3` **版本匹配** |
| 模拟器 | — | ❌ 本机无 `/dev/kvm`，**跑不了模拟器** → 真机不可替代 |
| 网络 | `dl.google.com` / `repo1.maven.org` | ❌ 不可达（IPv6-only，与 npmjs 同症状）→ **必须走镜像** |

## 阻塞项（需要用户输入）

1. **授权闸（两端共用）** —— `shared/config/targets.json` 的 6 个授权字段仍为 `fill_me`。
   未填齐时 **Android 端同样拒绝构建与启用**。**助手不代填授权字段**，只在用户给出具体值后写入。
2. **Android 测试机未到位（当前唯一硬阻塞）** —— 采购规格、root 方案与验机命令见
   [`docs/android-device-spec.md`](android-device-spec.md)。用户已确认机型档位（二手 Pixel 8/8a）、
   Android 版本（15 / API 35）与「有可访问 Google 的网络」，待实际采购。
   阻塞范围：BG-056（Frida 抓栈）→ BG-057（模块实现与端到端）。
3. **主机缺 frida 执行工具** —— 与 iOS 时期同一处境：无 CLI、Python 无 `pip`；
   npm `frida@17.23.3` 走 npmmirror 可行但 R1 决定不装。**R15 之前需要一次性安装许可。**
4. ~~iOS 设备 / 越狱 / 编译链~~ → **随 iOS 版冻结，不再是阻塞项**（[ADR-0001](adr/0001-pivot-to-android.md)）。

## 下一轮（R13）：语言中立测试向量（不需要设备）

**为什么先做这个**：本次双端化最大的风险是「iOS 的 C 核心与 Android 的 Java 核心行为漂移」。
现有 92 条断言（`BGGhostRules` 56 + `BGGhostAuth` 36）就是规格的可执行表述，
但它们**硬编码在 C 单测里**，Java 端没法直接复用。

R13 的 DoD：

1. 把 92 条断言**抽取**成数据（`shared/vectors/bssid-map.json`、`shared/vectors/auth-gate.json`），
   **覆盖不许减少**；
2. iOS 的 C 单测改为**从向量文件驱动**，仍全绿（141 项断言总数不减）；
3. 向量格式写成两端都能读的（JSON，字段名与 `shared/config/*.json` 的命名风格一致）；
4. 顺带处理已知跨端差异：`bssid_map.json` 的 `log.path` 目前是 iOS 路径，改为**按平台取值**。

## 之后（R14）：Android Java 核心 + 本机构建链（不需要设备）

1. `BGGhostRules` / `BGGhostAuth` 的 **Java 移植**（授权闸语义与顺序**一字不改**）；
2. **主机单测**：JVM 直接跑 `shared/vectors/`，与 C 端结论逐条比对；
3. **构建脚本** `android/scripts/build.sh`：`javac` → `d8` → `aapt2` → `apksig`，
   走镜像取件（R12 已手工验证整链可行），产出可安装的骨架 APK；
4. 授权闸同样接入构建脚本入口：`fill_me` 未填齐即拒绝构建。

> **R15 起需要设备**：Frida 抓栈确认飞书实际走哪条 Wi-Fi 信息通道，
> 拿到结论后才写 Hook（避免像 iOS 那样先占位再返工）。

## 轮次记录

> 最新轮次在最前。

### R12（2026-10-14）转向 Android：ADR + 冻结 iOS + 单仓双端重构

**用户决策**：iPhone 方案否决，主战场转向 Android；仓库组织为**单仓双端**
（`shared/` + `ios/`(冻结) + `android/`）；核心逻辑**移植成 Java + 共享测试向量**；
编译链走**本机脚本化最小链**；测试机买**二手 Pixel 8/8a + Android 15**。

**一、进度评估的真实结论（本轮最重要的判断）**

用户最初的判断是「很多代码要重做」。实测清点后的结论**需要修正**：
仓库 ≈6,683 行里，**要重做的是「壳」，不是「芯」**。

| 层 | 内容 | 行数 | 处置 |
|---|---|---|---|
| ① 平台中立 | `BGGhostRules.c`（映射）、`BGGhostAuth.c`（授权闸）、92 条断言、两个模拟器、配置 schema | ≈2,400 | **留用**，作为规格真源 |
| ② 通用流程 | STATUS/HANDOFF/RESUME、`bootstrap.sh`、`publish.sh`、测试矩阵与证据纪律 | ≈1,100 | 留用，路径改写 |
| ③ iOS 锁定 | ObjC 胶水、Hook 层、theos 构建、objc-stub、Frida 抓栈、iOS 文档 | ≈3,200 | **冻结**，Android 端另写 |

关键事实：③ 里真正要重做的 Hook 实现**只有 102 行，而且本来就是占位**
（`BGGhostCoreWLAN.m` 39 行 + `BGGhostHotspot.m` 29 行，全是 TODO）。
当初把映射与授权判定写成「纯 C + 主机单测」的回报，就是这次转向几乎不损失已验证逻辑。

**二、Android「编译前」可行性：端到端实测通过**

没有停留在「查了镜像有货」，而是**在本机真的打出了一个已签名的 APK**：

| 步骤 | 命令要点 | 结果 |
|---|---|---|
| 编译 | `javac -classpath android-36.jar` | ✅ 对真实 API 编译通过（`getConnectionInfo()` 报 deprecated = 证明用的是真 API） |
| 资源/manifest | `aapt2 link -I android-36.jar --manifest …` | ✅ 产出含二进制 manifest 的 APK |
| dex 化 | `java -cp r8.jar com.android.tools.r8.D8` | ✅ `classes.dex` |
| 签名 | `apksig` 的 `ApkSigner` | ✅ **`verified = true`**，证书 `CN=BGProbe,O=BSSIDGhost` |
| 模块骨架 | `XposedHelpers.findAndHookMethod(WifiInfo.class, "getBSSID", …)` | ✅ 用 legacy API 82 编译通过 |

构件全部来自可达镜像：`android.jar`（GitHub raw，API 到 **37**）、
`aapt2` 9.4.1 / `d8` / `apksig`（阿里云 Google Maven）、Xposed API 82 与 libxposed 102（阿里云 Central）。
**结论：Android 端不存在 iOS 那种「编译链落点三选一」的纠结**，本机纯命令行即可出 APK。

**三、设备选型（BG-052）**

采购规格、root 方案、验机命令与**逐条来源+性质标注**落档：
[`docs/android-device-spec.md`](android-device-spec.md)。核实到的关键事实：

- 国内版飞书 = `com.ss.android.lark`（小米应用商店在架 **8.2.6**，2026-10-13 更新，权限含精确位置）；
  国际版 Lark = `com.larksuite.suite`，**是另一个 App**，不是我们的目标；
- **官方 LSPosed 已停更**（最后 v1.9.2 / 2023-10-11，README 明示只支持 Android 8.1~14）；
  活跃的是 **Vector v2.2**（支持 8.1~17 Beta，需 Magisk/KernelSU + Zygisk）；
- Magisk 稳定版 **v30.7**；KernelSU **v3.3.1** / KernelSU-Next **v3.4.2**；
- **最大风险**：Pixel 的 OEM 解锁需联网校验运营商锁（GrapheneOS 文档明示），
  国内网络环境下可能灰掉——用户已确认有可访问 Google 的网络。

**四、代码与目录变更**

- 冻结：git tag **`ios-r11-host-verified`**（141 项断言全通过的状态）；**未删除任何 iOS 代码**；
- 迁移（`git mv`，保留历史）：`hooks/`→`ios/hooks/`、`layout/`→`ios/layout/`、
  `Makefile`/`control`→`ios/`、`config/`→`shared/config/`、iOS 三个脚本→`ios/scripts/`、
  `tests/{host,objc-stub,frida}`→`ios/tests/`、5 篇 iOS 文档→`docs/ios/`；
- 保留在跨端层：`scripts/bootstrap.sh`、`scripts/publish.sh`、`tests/README.md`（测试矩阵）、
  `tests/evidence/`（证据规范）；
- **根解析加固**：`ios/scripts/lib/common.sh` 推导根目录后会断言 `shared/config/targets.json`
  存在，否则**立即失败**——防止重构后拿错根目录静默跑偏。

**五、修掉两个真实缺陷（BG-051）**

| # | 缺陷 | 影响 | 修法 |
|---|---|---|---|
| 1 | `bootstrap.sh` 的「当前唯一关键路径」还在说「BG-032 编译链三选一，选定前无法产出产物」 | **新会话会被指错方向**（BG-032 在 R9 已定为方案 C），且该提示掩盖了真实阻塞（设备） | 改写为 Android 主线 + 真实阻塞项，并注明 BG-032 已成定论 |
| 2 | 任务板 **BG-040 一号两用**（交接方案 / 测试矩阵） | 违反「进度真源」的基本约束，任务无法唯一引用 | 测试矩阵改为 **BG-045**，并在记录里注明改号 |

**六、新增防线：文档链接检查器**

重构最大的隐性风险是**文档相对链接悄悄断掉**——而文档正是新会话的唯一入口。
新增 [`scripts/check-links.sh`](../scripts/check-links.sh)（纯 bash，无新依赖），
检查全仓库 `.md` 里的 Markdown 内部链接；本轮实测**发现并修掉 52 条断链**，
现已 **210 条内部链接全通过**，并已接入 `bootstrap.sh`（断链会让它退出码 1）。

**七、验证证据**

```
$ bash ios/tests/host/run.sh        # 重构后重新全绿
  配置契约检查 通过
  脚本自检             17 通过, 0 失败
  ObjC 语法检查        18 通过, 0 失败
  授权闸模拟器          6 通过, 0 失败
  映射模拟器            8 通过, 0 失败
  test_bgg_rules       56 通过, 0 失败
  test_bgg_auth        36 通过, 0 失败
  ==> 全部测试目标通过          （合计 141 项）

$ bash scripts/bootstrap.sh
    ✅ 必需工具齐全
    ✅ 主机检查通过
    ✅ 文档链接检查通过（无断链）

$ bash scripts/check-links.sh -v
  检查了 20 个文件、210 条内部链接。链接检查通过：无断链。
```

**八、诚实标注（本轮的缺口）**

- Android 端**一个真机动作都没做过**：没有设备、没有抓栈、没有装过模块；
- APK 只在本机**签名并验证**过，**没有在 Android 上安装运行过**（本机无 `/dev/kvm`，跑不了模拟器）；
- 飞书是否有 root/Xposed 检测、`WifiInfo.getBSSID()` 在 Android 15 上要哪个权限，
  **均为待实测**（见 [设备规格](android-device-spec.md) §8）；
- `docs/android-device-spec.md` 的价格区间是**推断**，无可靠来源。

### R9（2026-10-13）BG-032 决策落地：选定方案 C + 设备准备 SOP

**用户决策**：`BG-032 = C` —— 在越狱设备上用 **Procursus 工具链**就地编译并验证。

**交付**：[`docs/ios/ondevice-build-setup.md`](ios/ondevice-build-setup.md) ——
从"准备一台 iPhone"到"跑通 T1–T10"的完整 SOP。本轮的**核实工作**（这部分才是难点）：

| 核实项 | 结论 | 来源 |
|---|---|---|
| Dopamine 支持矩阵 | iOS 15.0–17.3.1（A14–A17/M1–M2）；15.0–18.7.1 与 26.0–26.0.1（A8–A13）；**rootless**，自带 Sileo/Zebra | [官方站点](https://ellekit.space/dopamine/)、[cfw.guide](https://ios.cfw.guide/installing-dopamine-trollstore/) |
| 推荐 iOS 区间 | **15.0–16.6.1**（TrollStore 路线最简单 + SDK 只到 16.5 + 与 tech-chain 假设一致） | 三条理由见 SOP §1 |
| 设备端编译器 | **`clang-16`**（16.0.0~5.9.2~RELEASE-1），不是 `llvm`（那是元包→clang-14） | 当前 iOS 通道包索引（1364 包） |
| 设备端链接器 | **`ld64` 609-3**（装 `clang-16` 会自动带上）—— **iOS 通道上没有 `cctools` 这个包名** | 同上（修正了我初稿的错误） |
| 签名/打包 | `ldid` 2.1.5-procursus7（0.2 MB）、`dpkg` 1.22.6（6.1 MB）、`make` 4.4.1 | 同上 |
| 体积预算 | SDK `iPhoneOS16.5.sdk` ≈ **201 MB / 8867 文件**；工具链依赖 ~600 MB；**别装 `swift-5.9.2`（1.19 GB）** | GitHub tree 实测 + 包索引 |
| SDK 来源 | `theos/sdks` 最高到 **16.5**（`iPhoneOS15.6`≈60 MB、`16.5`≈201 MB） | 仓库 tree 实测（默认分支是 `master`） |

**诚实标注**：SOP 里所有"未实测"项都带 ⏳ 标记并汇总到 §8；
其中一条明确写了「我无法从 Release 判断 Procursus 的 `dists/{1800,1900,2000,3000}`
哪个对应你的 iOS 版本，以设备上 Sileo 已配置的源为准」。

### R8（2026-10-13）交接方案 + 修复换 Mac 后的假通过风险

**背景**：用户要换机器（**可能是 Mac，未定**），需要一套能快速 resume 的交接方案，
并把当前进度同步到远端 `CUHKSZ-CROSS-Lab/BSSIDGhost`。

**一、交接方案（BG-040）**

| 文件 | 作用 |
|---|---|
| [`RESUME.md`](../RESUME.md) | 5 分钟恢复三步；新机器装什么（Linux/macOS 对照）；**换 Mac 的专门说明**；进度与缺口指针；换 AI 会话的开场模板；离线 bundle 兜底；命令速查 |
| [`scripts/bootstrap.sh`](../scripts/bootstrap.sh) | 环境自检（必需/可选分级 + 按平台给安装命令 + SDK/THEOS 探测）+ 跑全套主机检查 + 打印「读取顺序 / 当前阻塞 / 真机缺什么」；退出码可判定 |
| [`scripts/publish.sh`](../scripts/publish.sh) | 推送 `main` + 推送来源分支 + `gh pr create`；`--dry-run` 可先看命令与 PR 正文；**从不 force push**；缺凭据时明确报错并打印 compare 链接；非 TTY 下禁止 git 弹窗 |
| [`HANDOFF.md`](../HANDOFF.md) §0 / §9 | 新增「换机器先跑这一条」与发布节奏约定 |
| [`README.md`](../README.md) | 新增「快速开始」 |

**二、修复一个会在 Mac 上产生假通过的缺陷（BG-041）**

发现的问题：[`check-objc-syntax.sh`](../ios/tests/host/check-objc-syntax.sh) 原来无条件带
`-I ios/tests/objc-stub`。在装有 iOS SDK 的 Mac 上，这个 `-I` 会**把真 `Foundation.h` 顶掉**，
于是「检查通过」其实是拿声明桩跑出来的——**假通过**，而且在换 Mac 的场景下最容易发生。

修法：脚本改为二选一，并打印所用模式 ——

| 模式 | 触发 | 强度 |
|---|---|---|
| **真 SDK** | 设置了 `BGGHOST_IOS_SDK`，或 `xcrun --sdk iphoneos --show-sdk-path` 可用 | 强：方法存在性 / 弃用 / 可用性标注都参与 |
| 声明桩 | 两者都拿不到（本机 Linux 即此情形） | 弱：仅语法/类型/ARC/格式串 |

并加了一条**反向用例**守住它：构造一个「缺方法声明」的假 SDK 重跑脚本，
**必须失败**——如果通过了，就说明桩把真头文件顶掉了。当前 18/18（原 17 + 本项）。

同时修掉 `bootstrap.sh` 自身一个 bug：套件结果是 `bash run.sh | tail` 取的 `$?`，
那是 `tail` 的退出码，**失败会被误报为通过**；改为先收输出再取退出码，
并用「注入断言失败的副本」验证过：故障副本报失败且退出码 1，正常仓库退出码 0。

### R7（2026-10-13）映射模拟器 + nehelper 可证伪实验设计

**一、BSSID 映射模拟器（BG-038）**

与 R6 的闸门模拟器配对，回答另一半问题：**「给定 (SSID, 真实 BSSID)，App 最终会读到什么」**。

| 文件 | 内容 |
|---|---|
| [`ios/tests/host/map_sim.c`](../ios/tests/host/map_sim.c) | 读 `global/rule/default/query/querynil` 类型的 TSV，调用 `BGGhostRules.c` 的真实接口，逐条打印「返回什么 + 是替换还是透传」 |
| [`ios/tests/host/map-sim.sh`](../ios/tests/host/map-sim.sh) | 用 jq 抽取真实映射表；无参数时**按配置里的每条规则自动生成查询**；`--ssid/--bssid` 指定查询；`--self-test` 8 组断言 |

对当前仓库的实际输出（体现"安全默认"）：

```
全局开关: 关（整表不生效）
规则 #1: SSID=Office_WiFi 真实=AA:BB:CC:DD:EE:FF -> 伪造=11:22:33:44:55:66 [禁用]
默认值: 未启用（未命中规则的网络一律透传）

查询: SSID=Office_WiFi 真实 BSSID=AA:BB:CC:DD:EE:FF
      返回 "AA:BB:CC:DD:EE:FF"  [透传 —— 未命中规则 / 全局关闭 / 入参畸形]
```

自检 8/8：全局关闭透传、命中替换、**格式跟随（小写连字符入参 → 小写连字符输出）**、
未配置网络透传（T7）、**真实值为 NULL 不构造**、default 启用生效、规则禁用透传、
**伪造值非法 → 规则被拒且退出码 1**。

> 附带收益：`BGGhostRuleSetAdd` 会校验 BSSID 格式，所以这个模拟器同时是**比 bash 正则更强的
> 配置格式校验**（用真实代码而非重复实现）。

**二、nehelper 可证伪实验设计（BG-039）**

§2.1 是外部资料，为避免"抓一次栈、看到什么都往结论上套"，
在 [`docs/ios/tech-chain.md`](ios/tech-chain.md) §2.2 写死了：

- **假设 H1** 与「若成立应当出现的 3 类事件」；
- **判别表**：只有 objc / 只有 xpc / 两者值不同 / 两者值相同 → 各自结论与 Hook 落点；
- **证伪条件**：整个过程一次 `src:"xpc"` 都没出现而 App 确实读到 BSSID → H1 被证伪，§2.1 必须改写；
- **两步 attach 步骤**：App 进程 + `nehelper` 进程（`NEHelperWiFiInfoManager` 不在 App 里）。

配套改了抓栈脚本，让这个实验真能执行：
- `OBJC_TARGETS` 增加 `NEHelperWiFiInfoManager -checkIfEntitled:` / `-wifiInfoForInterface:`；
- XPC 写侧过滤从 4 个键扩到 8 个（增加 `result-data`/`SSID`/`BSSID`/`SSIDDATA`），
  这样 attach 到 nehelper 时能看到**应答字典的构造**。

### R6（2026-10-13）授权闸模拟器 + 编译链决策材料

**一、授权闸模拟器（BG-036）**

把**真实配置**喂给**真实判定代码**，在不接触设备的情况下回答
「以当前 `shared/config/targets.json` 为准，Hook 会对某个 BundleID 启用还是拒绝」：

| 文件 | 内容 |
|---|---|
| [`ios/tests/host/gate_sim.c`](../ios/tests/host/gate_sim.c) | 从 stdin 读 `KIND<TAB>KEY<TAB>VALUE`，调用 `BGGhostAuth.c` 的真实接口，输出判定 + 原因 + 责任字段 |
| [`ios/tests/host/gate-sim.sh`](../ios/tests/host/gate-sim.sh) | 用 jq 从 JSON 抽取输入；`--bundle` 指定进程；`--self-test` 跑 6 组断言 |

```
$ ios/tests/host/gate-sim.sh
输入：授权字段 6/6，scope.mode=allowlist，bundle=1，constraints=有
目标进程：com.ss.iphone.ugc.Lark
判定：拒绝 —— Hook 不会启用
原因：授权字段仍为占位符 fill_me
责任字段：authorization.target_app_owner
```

自检 6/6（**5 组反向**）：仓库当前 `fill_me` → 拒绝并指向 `target_app_owner`；
仅 `test_ap` 未填 → 指向 `authorization.test_ap`；`constraints.only_test_network=false`
→ 指向 `constraints`；`scope.mode=whitelist` → 指向 `scope.mode`；
BundleID 不在作用域 → 指向 `scope.bundle_ids`；授权填齐 + 在作用域 → 通过。

> 边界：JSON → 结构体这一步由 jq 完成（不是 `NSJSONSerialization`），
> 所以它覆盖「判定代码 + 配置取值」的端到端，**不覆盖 `BGGhostConfig.m` 的解析实现**。

**二、编译链决策材料（BG-037）**

[`docs/ios/build-chain-options.md`](ios/build-chain-options.md) 把三个选项的前置条件、成本、
能验证到什么都摊开，并附**本轮实测**的环境事实：

| 实测 | 结果 |
|---|---|
| clang 接受 `arm64-apple-ios15.0` / `arm64e-apple-ios15.0` | ✅ |
| **Mach-O 链接器已在位** | `/usr/bin/ld64.lld`（LLD 22.1.6），`-fuse-ld=lld` 对 Darwin 目标自动选它 |
| 链接只差 SDK | 报错**只剩** `ld64.lld: error: library not found for -lSystem` |
| host libc 头能否替代 SDK | ❌ 直接 `-c` 编 arm64 Mach-O：3 个只用 Foundation 桩的文件成功，含 `<stdio.h>`/`<stdlib.h>` 的 2 个失败 |
| theos / theos-sdks 仓库 | ✅ `git ls-remote` 均可达 |
| 打包工具 | `dpkg` 在官方 `extra`；`ldid` **仅 AUR**；`fakeroot` 已装 |
| 磁盘 | `/home` 可用 80 GB |

结论：**B 方案（Linux + SDK）比原先估计的更近 —— 只差 iOS SDK 与 `ldid`**。

### R5（2026-10-13）ObjC 层首次获得编译器检查

**动因**：此前 `ios/hooks/*.m` 是全项目**唯一零编译验证**的部分，也是风险最高的部分。
本机没有 iOS SDK，但有 clang —— 于是写一层最小声明桩，让 `-fsyntax-only` 真正跑起来。

**交付**

| 文件 | 内容 |
|---|---|
| [`ios/tests/objc-stub/Foundation/Foundation.h`](../ios/tests/objc-stub/Foundation/Foundation.h) | 最小 Foundation 声明桩：`NSString`/`NSArray`/`NSDictionary`/`NSData`/`NSNumber`/`NSFileManager`/`NSBundle`/`NSJSONSerialization`/`NSError`/`NSLog`、快速枚举、轻量泛型、字面量所需的类方法 |
| [`ios/tests/objc-stub/os/lock.h`](../ios/tests/objc-stub/os/lock.h) | `os_unfair_lock` 声明与 `OS_UNFAIR_LOCK_INIT`（Darwin 头，Linux 没有） |
| [`ios/tests/objc-stub/README.md`](../ios/tests/objc-stub/README.md) | 桩的用途、**查不出来的东西**、维护原则 |
| [`ios/tests/host/check-objc-syntax.sh`](../ios/tests/host/check-objc-syntax.sh) | 检查器：5 个 `.m` + 7 个头文件自包含 + 5 条反向用例 |

**验证证据**

```
$ ios/tests/host/check-objc-syntax.sh
  ok   BGGhostConfig.m / BGGhostCoreWLAN.m / BGGhostHotspot.m / BGGhostMap.m / Hooks.m
  ok   7 个头文件「单独包含」全部通过
  ok   反向：未声明的函数被查出
  ok   反向：未知选择器被查出
  ok   反向：格式串类型不匹配被查出
  ok   反向：BGGhostLog 的格式串被检查
  ok   反向：头文件单独包含这一路确实在编译
结果：17 通过, 0 失败
```

**一个值得记的技术点**：桩里 `NS_FORMAT_FUNCTION` 最初被我定义成空宏，结果**我们自己的
`BGGhostLog` 格式串完全没被检查**。改成真实的
`__attribute__((format(__NSString__, a, b)))` 后，`BGGhostLog(@"%@", cString)` 这类错误
才会在主机上被抓住 —— 这正是当初 `Hooks.h` 漏声明那类问题的同族。桩与真头文件的属性
必须一致，否则会静默漏掉一整类检查（已写进 `ios/tests/objc-stub/README.md` 的维护原则）。

**R5 之后的事实边界（不要含糊）**

| 已获得 | 仍未获得 |
|---|---|
| 语法、类型、隐式声明、未知选择器 | 方法在真实 iOS SDK 上是否存在 / 弃用 / 可用性标注 |
| ARC 归属规则 | 链接期问题（`-framework`、符号、`install_name`、架构切片） |
| 自己日志函数的格式串与实参类型 | 运行期行为（真实 `nil`、`NSJSONSerialization` 返回等） |
| 头文件自包含 | 桩与真头文件签名差异导致的漏检 |

### R4（2026-10-13）theos 打包骨架 + 三个脚本真实实现

**交付**

| 文件 | 内容 |
|---|---|
| [`Makefile`](../ios/Makefile) | theos 打包：`THEOS_PACKAGE_SCHEME=rootless`、`TARGET iphone:clang:latest:15.0`、`ARCHS arm64 arm64e`、`-fobjc-arc` |
| [`control`](../ios/control) | deb 元信息；含 `<team>` 占位符（未替换则打包被拒）；`Depends: ellekit \| mobilesubstrate` |
| [`ios/layout/…/BSSIDGhost.plist`](../ios/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist) | 过滤器（**只按 `scope.bundle_ids` 过滤**），构建时重新生成，L0 检查防止漂移 |
| [`ios/scripts/lib/common.sh`](../ios/scripts/lib/common.sh) | 三个脚本共用：授权闸（脚本侧防线）、过滤器生成、`--dry-run` 执行器 |
| [`ios/scripts/build.sh`](../ios/scripts/build.sh) | 两条编译链（theos / clang 可切换或自动选择）、多架构 + `llvm-lipo`、生成过滤器与随包配置 |
| [`ios/scripts/deploy.sh`](../ios/scripts/deploy.sh) | `deb`（推送 + `dpkg -i`）与 `files`（dylib + plist）两种方式；rootless `/var/jb` 路径；自动选择唯一设备 |
| [`ios/scripts/verify.sh`](../ios/scripts/verify.sh) | 只读验证：本地闸门状态 + SSH 抓日志判定 T1/T9；退出码 0/1/2 区分「通过 / 失败 / 仅本地」 |
| [`ios/tests/host/check-scripts.sh`](../ios/tests/host/check-scripts.sh) | 脚本自检：10 条正向（dry-run 命令拼装）+ 7 条反向（授权闸、`<team>`、参数校验） |

**验证证据**

```
$ ios/tests/host/run.sh
==> [L0] 配置契约检查 … 通过（含「过滤器 plist 与 bundle_ids 一致」）
==> [L0] 脚本自检 … 结果：17 通过, 0 失败
==> [test_bgg_rules] 结果：56 通过, 0 失败
==> [test_bgg_auth]  结果：36 通过, 0 失败
==> 全部测试目标通过
```

反向用例都是**真的会失败**的路径，不是空转：仓库当前 `fill_me` → `build`/`deploy` 拒绝；
`control` 留 `<team>` → theos 打包拒绝；`--toolchain cargo` / `--method magic` / 未知参数 → 拒绝。

**R4 决策**

| 项 | 结论 | 理由 |
|---|---|---|
| 编译链默认 | `--toolchain auto`：有 `$THEOS` 用 theos，否则 clang | 两种环境都能开箱即用；显式传参可覆盖 |
| 私有框架链接 | **不链接** CoreWLAN 等私有框架，运行时用 `NSClassFromString`/`dlopen` | 避免依赖 SDK 里是否存在对应 stub |
| deb 路线的过滤器 | **始终按 `scope.bundle_ids` 过滤**，不因 `mode=all` 放宽注入范围；`bundle_ids` 为空则拒绝打包 | 防止误注入系统进程；`mode=all` 只影响运行期判定 |
| 过滤器与随包配置 | 由 `build.sh` 生成，`ios/layout/usr/share/bssidghost/` 走 `.gitignore` | 避免与 `shared/config/` 漂移；L0 检查兜住提交在仓库里的那份 plist |
| 仓库里的 plist | 保留一份「安全默认」并纳入 L0 一致性检查 | 防止有人直接 `make package` 时插件在所有进程加载 |
| 脚本侧授权闸 | 与 `BGGhostAuth.c` 语义对齐，但**不重复实现判定** | 真正的判定有 36 条单测；脚本只做「明显未授权就停」 |
| `verify.sh` 退出码 | 0 通过 / 1 失败 / 2 仅本地 | 「没做设备侧检查」不能等同于「验证通过」 |
| theos 产物名 | `BSSIDGhost.dylib`（theos 约定），与 `libbssidghost.dylib` 并存 | theos 无法加 `lib` 前缀；**已记入 [`naming.md`](naming.md) 待你确认**，未擅自改 HANDOFF §2 |

### R3（2026-10-13）授权闸 + 日志落盘 + L0 契约检查

**交付**

| 文件 | 内容 |
|---|---|
| [`ios/hooks/BGGhostAuth.h`](../ios/hooks/BGGhostAuth.h) / [`.c`](../ios/hooks/BGGhostAuth.c) | 授权闸与作用域判定的**纯 C 核心**：字段缺值/占位符、约束开关、scope.mode、bundle 匹配 |
| [`ios/hooks/BGGhostConfig.h`](../ios/hooks/BGGhostConfig.h) / [`.m`](../ios/hooks/BGGhostConfig.m) | 读 `targets.json` → `BGAuthConfig`；读 `bssid_map.json` 的 `log` 段 → `BGLogConfig`；**fail closed** |
| [`ios/hooks/Hooks.m`](../ios/hooks/Hooks.m) | 授权闸接入 `BGGhostInstallHooks`（拒绝时写明原因与责任字段）；日志落盘 + 1 MiB 轮转 |
| [`ios/tests/host/test_bgg_auth.c`](../ios/tests/host/test_bgg_auth.c) | 36 条断言 |
| [`ios/tests/host/check-config-contract.sh`](../ios/tests/host/check-config-contract.sh) | L0 契约检查：JSON 键名 ↔ C 侧 `kBGAuthFieldKeys`、容量上限、BSSID 格式、日志设置 |

**验证证据**

```
$ ios/tests/host/run.sh
==> [L0] 配置契约检查 … 通过
==> [test_bgg_rules] 结果：56 通过, 0 失败
==> [test_bgg_auth]  结果：36 通过, 0 失败
==> 全部测试目标通过
```

契约检查器的**反向验证**（用 /tmp 副本注入故障，确认不是空转）：

| 注入的故障 | 结果 |
|---|---|
| 把 `authorization.target_app_owner` 改名 | ✅ 按预期失败（缺字段 + 多出未知字段） |
| `scope.mode` 改成 `whitelist` | ✅ 按预期失败 |
| 删掉 `constraints.only_test_network` | ✅ 按预期失败 |

**R3 决策**

| 项 | 结论 | 理由 |
|---|---|---|
| 闸门顺序 | 授权字段 → 约束 → 作用域声明 → 进程匹配，**按此顺序短路** | 未授权时不应给出「进程是否在作用域」这类误导性放行线索 |
| 空白值 | 全空白视为「未填写」 | 防止用一个空格绕过授权闸 |
| 占位符识别 | 忽略前后空白、大小写不敏感 | `fill_me` / `  FILL_ME  ` 都要拦住 |
| `constraints` 语义 | 三项必须全为 true，否则拒绝 | 与 targets.json 既有取值一致，是「只在受控环境使用」的硬约束 |
| 未知授权键名 | 记录日志并忽略；L0 检查会直接失败 | 拼错字段 = 授权实际未登记，必须能被发现 |
| 配置读取失败 | 一律按未授权处理（fail closed） | 读不到配置不能等于放行 |
| 日志轮转 | 超过 `log.max_bytes`（默认 1 MiB）改名 `<path>.1`，只留一份备份 | 设备磁盘有限，避免日志无限增长 |
| 锁顺序 | 授权配置锁 → 日志配置锁 → 日志写入锁 | 三者单向获取，无环；配置层自身只用 NSLog，避免自锁 |

**顺带修复**：`BGGhostMap.m` 原先自带一套配置路径解析（`BGGHOST_CONFIG` 环境变量），
已统一到配置层的 `BGGhostResolveConfigPath()`（环境变量改为 `BGGHOST_CONFIG_DIR`），
避免两处路径规则日后漂移。

### R2（2026-10-13）B 线与 C 线并行

**C 线交付（完全不依赖真机，已实测验证）**

| 文件 | 内容 |
|---|---|
| [`ios/hooks/BGGhostRules.h`](../ios/hooks/BGGhostRules.h) / [`.c`](../ios/hooks/BGGhostRules.c) | BSSID 映射的**纯 C 核心**：归一化、格式跟随、规则匹配、默认值、表容量 |
| [`ios/hooks/BGGhostMap.h`](../ios/hooks/BGGhostMap.h) / [`.m`](../ios/hooks/BGGhostMap.m) | ObjC 胶水：`bssid_map.json` → `BGRuleSet`，对 `NSString` 做映射 |
| [`ios/tests/host/test_bgg_rules.c`](../ios/tests/host/test_bgg_rules.c) / [`run.sh`](../ios/tests/host/run.sh) | 主机侧单测，56 条断言 |
| [`ios/hooks/BGGhostCoreWLAN.m`](../ios/hooks/BGGhostCoreWLAN.m) | 移除占位映射函数，改为调用映射层；保留 Hook 注册 TODO |

验证证据（L1 实测）：

```
$ ios/tests/host/run.sh
编译：clang -std=c11 -Wall -Wextra -Werror -O1
结果：56 通过, 0 失败
```

**B 线交付（工具就绪，执行被授权闸/设备/frida 阻塞）**

| 文件 | 内容 |
|---|---|
| [`ios/tests/frida/capture-wifi-api.js`](../ios/tests/frida/capture-wifi-api.js) | Frida 只读抓栈：ObjC 通道（`CWFInterface` / `CWInterface` / `CWNetwork` / `CWWiFiClient` / `NEHotspotNetwork`）、`CNCopyCurrentNetworkInfo`、**nehelper XPC 请求与应答**、`getifaddrs` 接口 MAC 对照；输出 JSONL |
| [`docs/ios/device-setup.md`](ios/device-setup.md) | 真机准备 SOP：frida-server 版本严格匹配、rootless 路径、`iproxy`/SSH、验证清单、故障排查 |
| [`ios/tests/frida/README.md`](../ios/tests/frida/README.md) | 脚本用法、覆盖点、**已知限制**（嵌套折叠、异步应答、未实跑） |
| [`tests/evidence/README.md`](../tests/evidence/README.md) | 证据命名、摘要模板、「实测 vs 外部资料」纪律 |

脚本仅通过 `node --check` 语法校验，**未在任何设备上实跑**；首个真机结论出来前，
不得把 `capture-wifi-api.js` 的预期行为写成「实测」。

**R2 决策（补充 R1 未覆盖的语义）**

| 项 | 结论 | 理由 |
|---|---|---|
| `default` 生效条件 | 必须显式 `default.enabled: true` | 否则未命中规则的网络会被静默改写，与 T7「无规则透传」冲突 |
| SSID 匹配 | **大小写敏感**精确匹配 | 802.11 的 SSID 是字节串，本身大小写敏感 |
| 多条命中 | 取第一条 | 与配置文件自上而下的直觉一致，便于人工排查 |
| 输出格式 | 分隔符与大小写**完全跟随入参** | tech-chain §3 的格式一致性要求 |
| nil / 空 / 畸形入参 | 一律原值透传，且不写输出缓冲 | HANDOFF §5 风险 6；避免「凭差异暴露」 |
| 规则表容量 | `BG_RULE_MAX_COUNT = 16`，超出拒绝且不覆盖 | 固定大小、无动态分配，便于真机稳定 |

**顺带修复**：`Hooks.h` 此前缺少 `BGGhostLog` 声明（各 `.m` 直接调用），
在 C99+ 下是隐式声明错误，会让真机编译直接失败 —— 已补上带 `NS_FORMAT_FUNCTION` 的原型。

### R1（2026-10-13）工程化与流程最小集

用户决策（本轮）：

1. 测试机：**Dopamine / rootless，iOS 15.0–16.6.x，路径前缀 `/var/jb`**。
2. 授权：**暂不确定，先按未授权处理** —— 所有真机相关任务保持 blocked，脚本与 Hook 的安全闸保持关闭，**不代填授权字段**。
3. 主线：**先 A，然后 B、C 并行**。
4. 流程范围：**最小集**（git + STATUS + HANDOFF 节奏）；`process.md` / `decisions.md` 等跑完一轮再补。
5. 外部能力：**都先不装，保持环境干净**（不装 frida、不接 MCP、不启用 `plugin_manager` 工具、不装社区插件市场）。

交付物：

- `git init -b main`，首次提交覆盖原始 16 个骨架文件 + `.gitignore`。
- 本文件（任务板 + 轮次记录 + 环境事实 + 阻塞项）。
