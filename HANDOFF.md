# 交接备忘（HANDOFF）

> 供新会话快速衔接项目上下文。**开新对话时先让助手读本文件**。

## 0. 换机器 / 换会话：先跑这一条

```sh
bash scripts/bootstrap.sh
```

它会做：环境自检（必需 / 可选分开列，附本平台安装命令）→ 跑全套主机检查（**251 项断言**，不需要设备）
→ 检查文档链接（无断链）→ 打印「读取顺序 + 当前阻塞项 + 真机线缺什么」。
完整恢复指南见 [`RESUME.md`](./RESUME.md)（含**换到 macOS 后的专门说明**）。
同步到远端：`bash scripts/publish.sh --dry-run` 看计划，去掉 `--dry-run` 执行。

> ⚠️ **主线已是 iOS**（R14 切回；R12–R13 曾短暂以 Android 为主线）。先读
> [`docs/adr/0002-return-to-ios.md`](./docs/adr/0002-return-to-ios.md)——
> 它同时记录了**被推翻的旧结论**（palera1n「arm64e 排除」其实不含 A11）。
> 下一步是**采购 iPhone 8**：版本硬约束、Dopamine SOP 与验机命令见
> [`docs/ios/device-spec.md`](./docs/ios/device-spec.md)。
> Android 已暂停冻结（代码与文档全部保留）。

## 1. 项目定义（已确认，跨端不变）

**BSSIDGhost**（中文：幻影 BSSID）

> **已 root / 已越狱的移动设备**上，Hook 篡改 Wi-Fi 信息接口，伪造目标 App **读取到的** BSSID 返回值。

当前主线平台是 **Android**（目标 App：国内版飞书 `com.ss.android.lark`）；
iOS 版实现已冻结（目标 App 曾是 iOS 版飞书 `com.ss.iphone.ugc.Lark`）。

⚠️ 表述上曾出现过一次偏差，已纠正，**不要退回旧说法**：

| | 说法 | 判定 |
|---|---|---|
| ❌ | 越狱后 Hook 修改 App 连接的 Wi-Fi BSSID | 错误：会误导实现者去动网络层 |
| ✅ | 越狱后 Hook 篡改 Wi-Fi 信息接口，伪造 App **读取到的** BSSID **返回值** | 正确 |

**核心边界**：改的是「API 返回的字符串」，不是「实际连接的 AP」。
设备真实链路、流量走向完全不变；SSID 刻意保持不变，只改 BSSID。
技术性质是 **spoofing（伪装）**，不是切换网络。

## 2. 已完成的决策（不要重复讨论）

### 2.1 跨端（仍然有效）

| 项 | 结论 |
|---|---|
| 项目名 | `BSSIDGhost` / 幻影 BSSID |
| 为什么不用 Fake/Spoof | 对外更中性，避免安全扫描与商店策略针对；`Ghost` 精确表达"只存在于返回值里的幽灵 AP" |
| 仓库路径 | `/home/zcai/Projects/BSSIDGhost`（由原 `test` 目录改名而来） |
| 代码前缀 | `BG`（`BGGhostCoreWLAN` 等） |
| 关键区分 | **设备接口 MAC ≠ AP 的 BSSID**，不要混淆 |
| 安全闸设计 | 授权字段默认 `fill_me`，未填齐则构建/部署拒绝执行、Hook 拒绝启用（**两端共用**） |
| 目录组织 | 单仓双端：`shared/`（规格与配置）+ `ios/`（冻结）+ `android/`（主线）——[ADR-0001](./docs/adr/0001-pivot-to-android.md) |
| 编号体系 | `R` 轮次与 `BG-xxx` 任务号**延续**，不另起一套（iOS 历史不断链） |

### 2.2 iOS（**当前主线**）

| 项 | 结论 |
|---|---|
| 目标 App / BundleID | 国内版飞书。App Store 元数据显示 **`com.bytedance.ee.lark`**（最低 iOS 13.0）；⚠️ 但配置里目前是 `com.ss.iphone.ugc.Lark`，**待真机确认（BG-061）**。**不是**国际版 Lark `com.larksuite.lark` |
| 目标设备 | **iPhone 8（A11）**；固件上限 **16.7.16**（Apple 至今仍签名）；**优先买已在 ≤16.6.1 的机器** |
| 越狱工具 | **Dopamine**（rootless、semi-untethered、自带 Sileo），palera1n 为备选 |
| 越狱形态 | rootless，前缀 **`/var/jb`** —— 与仓库现有假设完全一致（代码不用改） |
| 注入库名 | `libbssidghost.dylib`（theos 产物为 `BSSIDGhost.dylib`） |
| 插件 BundleID | `com.<team>.bssidghost` |
| Hook 框架 | **ElleKit**（Dopamine 与 palera1n 都落在它上；官方 README 明示 "Used by: palera1n (A8-A11)"，且提供 Substrate/libhooker 兼容层 → 旧 `MSHook*` 写法可用） |
| Hook 点优先级 | P0 `CoreWLAN`/`CWFInterface`；P1 `NEHotspotNetwork`、`CNCopyCurrentNetworkInfo`；P2 `CWWiFiClient`、`getifaddrs`。注意 `nehelper` 可能是**统一后端**（见 [`docs/ios/tech-chain.md`](./docs/ios/tech-chain.md) §2） |
| 编译链 | 方案 C：越狱设备上用 Procursus 工具链就地编译（**未实跑**） |

> 采购的版本硬约束与验机命令见 [`docs/ios/device-spec.md`](./docs/ios/device-spec.md)。

### 2.3 Android（已暂停冻结，不要重复讨论）

| 项 | 结论 |
|---|---|
| 目标 App / 包名 | 国内版飞书 `com.ss.android.lark` |
| 注入路线 | 先 Frida 只读抓栈，再落 LSPosed 模块 |
| Root | Magisk v30.7 stable + 内置 Zygisk |
| Hook 框架 | Vector v2.2 + legacy XposedBridge API 82 |
| 目标设备 | 二手 Google Pixel 8 / 8a，固定 Android 15（API 35） |
| 编译链 | 本机命令行 `javac` + `d8/R8` + `aapt2` + `apksig`（R12 端到端实测通过，无需 Android Studio） |
| Hook 点候选 | P0 `WifiInfo.getBSSID()`（经 `getConnectionInfo()` 或 `NetworkCapabilities.getTransportInfo()`）；P1 `ScanResult.BSSID`；**不 hook 飞书的混淆类** |
| 冻结范围 | BG-054 – BG-057 全部 `frozen`；代码/文档/设备规格全部保留 |

## 3. 当前状态

**阶段：主线 iOS（R14 切回）；主机侧 251 项断言全绿，但尚无任何真机动作；Android 暂停冻结。**

> **进度真源已迁移到 [`docs/STATUS.md`](./docs/STATUS.md)**（任务板 `BG-xxx` + 轮次记录 + 环境事实 + 阻塞项）。
> 本文件保留交接语义：定义、已定决策、风险、下一步。**每轮结束两个文件都要更新。**

目录结构见 [`README.md`](./README.md)。原始骨架 16 个文件（其中链路图后来被移除）：
- `README.md`、`docs/ios/tech-chain.md`、`docs/naming.md`
- `shared/config/bssid_map.json`、`shared/config/targets.json`
- `ios/hooks/`：`Hooks.h/.m`、`BGGhostCoreWLAN.h/.m`、`BGGhostHotspot.h/.m`
- `scripts/`：`build.sh`、`deploy.sh`、`verify.sh`（均已 `bash -n` 通过、已加可执行位）
- `tests/README.md`（测试矩阵 T1–T10）
- ~~`技术链路流程图.jpeg`（原始链路图）~~ → **已按用户要求移除**；
  历史版本仍在，取回：`git show b9f00cd:技术链路流程图.jpeg > 技术链路流程图.jpeg`
  （blob `137be914981ad29392b5b719aed446a67aa108c8`，105513 字节）

**尚未实现**：所有 Hook 逻辑、映射表读取、日志落盘、编译接入。
所有占位处均以 `TODO` / `⚠️ 占位实现` 标注。

**R1 已完成（2026-10-13）**：建立 git 仓库（`main` 分支）+ [`.gitignore`](./.gitignore) +
[`docs/STATUS.md`](./docs/STATUS.md) 进度真源，并确认测试机越狱形态与外部能力清单。

**R2 已完成（2026-10-13，B/C 并行）**：

- **C 线（不依赖真机，已实测）**：[`ios/hooks/BGGhostRules.h`](./ios/hooks/BGGhostRules.h)/[`.c`](./ios/hooks/BGGhostRules.c)
  是 BSSID 映射的**纯 C 核心**（归一化 / 格式跟随 / 规则匹配 / nil 透传），
  [`ios/hooks/BGGhostMap.m`](./ios/hooks/BGGhostMap.m) 负责读 `bssid_map.json` 并映射 `NSString`；
  [`ios/tests/host/run.sh`](./ios/tests/host/run.sh) **56 条断言全部通过**（`-Wall -Wextra -Werror`）。
- **B 线（工具就绪，执行被阻塞）**：[`ios/tests/frida/capture-wifi-api.js`](./ios/tests/frida/capture-wifi-api.js)
  只读抓栈（ObjC 通道 + `CNCopyCurrentNetworkInfo` + **nehelper XPC 请求/应答** + 接口 MAC 对照）、
  [`docs/ios/device-setup.md`](./docs/ios/device-setup.md) 真机 SOP、[`tests/evidence/README.md`](./tests/evidence/README.md) 取证模板。
  脚本仅经 `node --check`，**未在设备上实跑**。
- **顺带修复**：`Hooks.h` 缺 `BGGhostLog` 声明（C99+ 下隐式声明会让真机编译直接失败）。

**R3 已完成（2026-10-13，主机侧策略层）**：

- **授权闸**：[`ios/hooks/BGGhostAuth.h`](./ios/hooks/BGGhostAuth.h)/[`.c`](./ios/hooks/BGGhostAuth.c) 是判定的纯 C 核心
  （授权字段缺值/占位符/空白绕过、constraints 三项、scope.mode、bundle 匹配顺序短路）；
  [`ios/hooks/BGGhostConfig.m`](./ios/hooks/BGGhostConfig.m) 读 `targets.json`，**读不到即按未授权处理**。
- **日志落盘**：[`ios/hooks/Hooks.m`](./ios/hooks/Hooks.m) 按 `bssid_map.json` 的 `log` 段追加写文件，
  超过 `max_bytes`（默认 1 MiB）轮转为 `<path>.1`。
- **L0 契约检查**：[`ios/tests/host/check-config-contract.sh`](./ios/tests/host/check-config-contract.sh)
  交叉校验 JSON 键名 ↔ C 侧字段表、容量上限、BSSID 格式、日志设置，并用 3 组注入故障验证过它不是空转。
- **验证**：`ios/tests/host/run.sh` → L0 通过 + `BGGhostRules` 56/56 + `BGGhostAuth` 36/36。

**R4 已完成（2026-10-13，编译/部署管道）**：

- **theos 打包骨架**：[`Makefile`](./ios/Makefile)（rootless、`ARCHS arm64 arm64e`、`TARGET iphone:clang:latest:15.0`）、
  [`control`](./ios/control)（含 `<team>` 占位符，未替换则拒绝打包）、
  [`ios/layout/…/BSSIDGhost.plist`](./ios/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist)（过滤器）。
- **三个脚本真实实现**：[`ios/scripts/lib/common.sh`](./ios/scripts/lib/common.sh)（共用授权闸 + `--dry-run` 执行器）、
  [`build.sh`](./ios/scripts/build.sh)（theos / clang 双路径，可 `auto`）、
  [`deploy.sh`](./ios/scripts/deploy.sh)（deb 或 files，rootless `/var/jb`）、
  [`verify.sh`](./ios/scripts/verify.sh)（只读，退出码 0/1/2）。
- **脚本自检**：[`ios/tests/host/check-scripts.sh`](./ios/tests/host/check-scripts.sh) 17/17
  （10 条正向 dry-run + 7 条反向：授权闸、`<team>`、参数校验）。
- **仍未做**：**没有用真实 iOS SDK 编译或链接过**（BG-032 已于 R9 定为方案 C，尚未在设备上实跑）。

**R5 已完成（2026-10-13，ObjC 层首次编译检查）**：

- **最小 Foundation 桩**：[`ios/tests/objc-stub/`](./ios/tests/objc-stub/) 把 `ios/hooks/` 用到的
  Foundation 接口与 `os_unfair_lock` 声明出来，使本机 clang 能对 ObjC 源码做
  `-fsyntax-only`（`-fobjc-arc -fobjc-runtime=ios-15.0 -Wall -Wextra -Werror`）。
- **检查器**：[`ios/tests/host/check-objc-syntax.sh`](./ios/tests/host/check-objc-syntax.sh) 17/17 ——
  5 个 `.m` + 7 个头文件自包含 + **5 条反向用例**（未声明函数 / 未知选择器 /
  格式串类型不匹配 / 我们自己的 `BGGhostLog` 格式串 / 头文件那一路确实在编译）。
- **现在能查出**：语法与类型错误、隐式函数声明、未知选择器、ARC 归属规则、
  格式串与实参类型、头文件自包含。
- **仍查不出**：方法在真实 iOS SDK 上是否存在/弃用/可用性、链接期问题
  （`-framework`/符号/`install_name`/切片）、任何运行期行为。**仍需真 SDK 编译。**

**R6 已完成（2026-10-13，闸门端到端 + 决策材料）**：

- **授权闸模拟器**：[`ios/tests/host/gate-sim.sh`](./ios/tests/host/gate-sim.sh) + [`gate_sim.c`](./ios/tests/host/gate_sim.c)
  把**真实配置**喂给**真实判定代码**，直接回答「当前配置下某个 BundleID 上 Hook 会启用还是拒绝」。
  当前仓库输出：拒绝，责任字段 `authorization.target_app_owner`。自检 6/6（5 组反向）。
- **编译链决策材料**：[`docs/ios/build-chain-options.md`](./docs/ios/build-chain-options.md)，
  含本轮实测事实 —— 本机**已有 Mach-O 链接器 `ld64.lld`**、链接只差 `-lSystem`（即 iOS SDK）、
  `theos` 与 `theos/sdks` 仓库可达、`dpkg` 在官方源、`ldid` 仅 AUR。**B 方案比原先估计的近得多。**

**R7 已完成（2026-10-13，映射模拟器 + 实验设计）**：

- **映射模拟器**：[`ios/tests/host/map-sim.sh`](./ios/tests/host/map-sim.sh) + [`map_sim.c`](./ios/tests/host/map_sim.c) ——
  把**真实映射表**喂给**真实映射代码**，回答「给定 (SSID, 真实 BSSID)，App 会读到什么」；
  无参数时按配置里的规则自动生成查询。自检 8/8（含格式跟随、nil 不构造、非法值被拒）。
  与 R6 的 `gate-sim.sh` 配对，形成**离线 dry-run 整份配置**的能力。
- **nehelper 可证伪实验设计**：[`docs/ios/tech-chain.md`](./docs/ios/tech-chain.md) §2.2 ——
  假设 H1、判别表（只有 objc / 只有 xpc / 值不同 / 值相同 → 落点选择）、
  **证伪条件**、以及 App + `nehelper` 两步 attach 步骤。
  抓栈脚本同步增强：加入 `NEHelperWiFiInfoManager -checkIfEntitled:`，
  XPC 写侧过滤扩到 `result-data`/`SSID`/`BSSID`/`SSIDDATA`。

**⚠️ 需要你确认的命名细节**：theos 产物名固定为 `BSSIDGhost.dylib`（不带 `lib` 前缀），
与 HANDOFF §2 记录的 `libbssidghost.dylib` 并存为「两条路线两个名字」。
选项与影响见 [`docs/naming.md`](./docs/naming.md)，**未擅自改动既有决策**。

## 4. 未决事项（需要用户输入）

### 4.1 iOS 主线（当前）

- **iPhone 8 未到位（唯一硬阻塞）** —— 采购规格、**版本硬约束**与验机命令见
  [`docs/ios/device-spec.md`](./docs/ios/device-spec.md)。
  关键：**优先买已在 ≤16.6.1 的机器**（才能用 TrollStore 免每 7 天重签），
  而 **Apple 只签 16.7.16，买错了退不回去**（除非有该机 ECID 的 SHSH2 blobs）。
  阻塞范围：R15 全部真机任务（越狱 → 设备端编译 → 装包 → T1–T10 → BG-011 抓栈）。
- **BG-061：iOS 目标 BundleID 待真机确认** —— 配置里是 `com.ss.iphone.ugc.Lark`，
  App Store 元数据显示飞书是 `com.bytedance.ee.lark`。
  **确认之前不要打包**：过滤器写错 BundleID 的插件不会注入，而且**不报错**。
- **目标 App 授权状态未确认** —— `shared/config/targets.json` 的 `authorization` 字段全为 `fill_me`。
  决策：**先按未授权处理**；**助手不代填**，只在用户给出具体值后写入。
  闸门已落地在 [`ios/hooks/BGGhostAuth.c`](./ios/hooks/BGGhostAuth.c)（36 条单测 + 向量）。
- **主机缺少 frida 执行工具** —— 无 CLI、Python 无 `pip`；npm `frida@17.23.3` 走 npmmirror 可行。
  **BG-011 抓栈前需要一次性安装许可。**
- **飞书实际走哪条 Wi-Fi 信息通道未验证** —— 这是 BG-011 的任务；
  **在此之前不要写 Hook 实现**（iOS 的历史教训：先占位再返工）。
- **Dopamine 是否要求关闭密码** —— 官方文档未提（palera1n 在 A11 上明示要求关闭）→ **待实测**。
- **飞书是否有越狱检测** —— **未查到任何可靠来源**，不编造；真机实测后回写。
- **命名细节（低优先级）**：theos 产物名 `BSSIDGhost.dylib` 与 `libbssidghost.dylib` 并存，
  见 [`docs/naming.md`](./docs/naming.md)。

### 4.2 Android（已冻结，不再是未决项）

- ~~Android 测试机 / 注入路线 / 编译链~~ → **随冻结挂起**，
  历史结论见 [`docs/android-device-spec.md`](./docs/android-device-spec.md)、
  [`android/README.md`](./android/README.md) 与 R12–R13 轮次记录。**代码与文档全部保留。**

## 5. 已识别的技术风险

> 下面是跨端的技术风险。**主线是 iOS**，Android 侧的对应形态仅作备查。

1. **交叉校验**：若目标 App 同时用多个 Wi-Fi 接口、公网出口 IP、mDNS、ARP 或后端白名单比对，
   单点 Hook 会被识破。落地前须枚举其全部网络身份采集点。
   Android 端的具体形态：`getConnectionInfo()` / `getTransportInfo()` / `getScanResults()` 三条路
   可能被互相比对。
2. **返回形态不一致**（Android 版）：可能是 `String`、`byte[]`（6 字节）、
   或 Android 13+ 的 `getApMldMacAddress()`（MLO）；替换策略不同。
3. **格式一致性**：大小写、分隔符（`:` / `-` / 无）必须与真实返回完全一致，否则 App 侧比较会失败。
4. **多次调用**：需覆盖同步缓存与异步回调，避免只改到第一次调用。
5. **单一后端**：iOS 上 SSID/BSSID 很可能统一由 `com.apple.nehelper` 提供
   （详见 [`docs/ios/tech-chain.md`](./docs/ios/tech-chain.md) 第 2 节）；
   Android 侧重在确认「App 是直接读系统接口，还是另有 native 通道」——这正是 R15 要证伪的。
6. **nil 语义（跨端硬性要求）**：无权限/未连接时系统返回 `null` 或裁剪值。
   替换逻辑必须尊重 `null` —— **真值为 nil 时不得凭空构造 BSSID**，否则行为差异本身即暴露。
   已记为 C 线（BG-020）的硬性要求。

## 6. 关于本次协作的一个特殊环境事实

项目原本位于 `/home/zcai/Projects/test`。改名后旧会话的默认 shell 工作目录失效
（`spawn bash ENOENT`），必须显式指定 `workdir` 或绝对路径才能执行命令。

> **R1 更新**：仓库已 `git init`，且工作区已登记为 `/home/zcai/Projects/BSSIDGhost`
> （见 `~/.dsh/storages/workspace.json`）。**新对话仍请从该路径启动**，
> 这样项目内 skill 根（`.dsh/skills`）与项目根解析都会确定命中。

## 7. 建议的下一步（R15，**由设备驱动**）

R14 之后，**iOS 侧能脱离设备做的事已经做完**：主机侧 251 项断言全绿、结论已校正、
设备规格与验机清单就绪。**下一步必须等机器。**

| 步骤 | 谁做 | 内容 |
|---|---|---|
| 1. 采购 | 用户 | iPhone 8（**优先 ≤16.6.1**；8 Plus 是 3GB 内存更稳）。**一页清单可直接发卖家**：[`docs/ios/purchase-checklist.md`](./docs/ios/purchase-checklist.md)；完整依据见 [`device-spec.md`](./docs/ios/device-spec.md) |
| 2. 越狱 | 用户 | Dopamine（rootless）→ Sileo 装 ElleKit + PreferenceLoader；≤16.6.1 再装 TrollStore 免重签 |
| 3. 确认 BundleID | 用户 + 助手 | 设备上确认飞书真实 BundleID（**BG-061**），修正 `scope.bundle_ids` |
| 4. 设备端工具链 | 用户 | `clang-16` / `ld64` / `ldid` / `dpkg` / `make` + `iPhoneOS16.5.sdk`（[SOP](./docs/ios/ondevice-build-setup.md)） |
| 5. 编译 | 双方 | `bash ios/scripts/build.sh --toolchain theos`（⚠️ 先过授权闸） |
| 6. 验证 | 双方 | 装包 → 冷启动飞书 → 看日志 → 跑 T1–T10；再按 `tech-chain` §2.2 两步 attach 抓栈 |

> 用户已选定**不安装**本机 theos/SDK/ldid，因此真编译与真机任务**合并进行**（方案 C）。

## 8. R1 调研结论：skill / plugin 机制（本会话实测）

### Skill（已验证可热加载）

- 扫描根与优先级：`<项目根>/.dsh/skills`(100) → `<项目根>/.agents/skills`(200) →
  自定义 `customSkillDirs`(300) → `~/.dsh/skills`(400) → `~/.agents/skills`(500)。
- 格式：目录包 `<name>/SKILL.md` 或平铺 `<name>.md`；frontmatter 必填 kebab-case 的 `name`
  与 `description`，可选 `whenToUse` / `metadata` / `disable-model-invocation` / `user-invocable`。
  **不递归**扫描嵌套 `**/SKILL.md`；正文按需加载，故推荐「摘要 + `references/`」结构。
- **实测**：写入 `.dsh/skills/bg-probe/SKILL.md` 后会话 skill 目录**当场出现**该项，
  删除后立刻回退为仅 `omarchy` —— 项目内 skill 热加载有效、无需重启。
- 项目根靠「最近含 `.git` 的祖先」解析；本仓库此前无 `.git`，靠回退到 cwd 才命中。
  **R1 已 `git init`，该解析现在确定。**
- 结论：R2 之后可用项目内 skill 固化开发规范（`bg-dev-process` / `bg-hook-research` /
  `bg-hooks-impl` / `bg-verify`），本轮按用户决定**暂不创建**。

### Plugin

- 插件按 profile 安装：`dsh plugin --profile web add <pkg>`，或 Web 侧边栏「插件」页
  （`ui-plugin-manager` 已挂载且服务可用）。
- **本会话 `plugin_manager` 工具是关闭的**（`tool-plugin-manager: disabled: true`），
  且 R1 决策**暂不启用**（插件是宿主进程代码）。
- 官方随包、默认关闭的可选 bundle：`experimental-agent-team-profile`、
  `experimental-voice-input-bundle`、`experimental-auto-review`、`experimental-schedule-bundle`
  —— 与本项目均不相关。
- 存在第三方插件生态（[dsh-plugin](https://www.npmjs.com/package/dsh-plugin) 社区市场、
  [dsh-plugin-marketplace](https://github.com/AwesomeHou/dsh-plugin-marketplace)、
  `dsh-context` 等）；R1 决策**都不装**。
- 网络：`registry.npmjs.org` 在本机**不可达**，`registry.npmmirror.com` 可达；
  plugin-manager 的 `fallbackRegistries` 默认已含 npmmirror，故将来安装仍可行。

### 与本项目相关的外部参考（备查，未引入代码）

- [jb-p1lot](https://github.com/castdrian/jb-p1lot)：Dopamine/rootless iOS 开发桥（Go CLI + stdio MCP + Theos 包），
  提供 root shell/文件、截图/HID、App 控制、日志/崩溃、PCAP、LLDB、Frida、tweak 构建部署回滚。
- [DragonJAR/iOS-Pentesting-Skill](https://github.com/DragonJAR/iOS-Pentesting-Skill)（Apache-2.0）：
  93 篇 reference + 73 个 Frida 脚本，含 `frida-ios-guide`、`jailbreak-setup-guide`。
- npm `frida@17.23.3`（Node 绑定，绕开本机无 pip 的限制）、`frida-mcp`、`frida-mobile-mcp`。
- nehelper XPC 依据：[illusionofchaos/ios-nehelper-wifi-info-0day](https://github.com/illusionofchaos/ios-nehelper-wifi-info-0day)
  —— **外部资料，必须真机复验**。

## 9. 协作约定（R1 最小集，跑一轮后再补文档）

0. **换机器/换会话**：先 `bash scripts/bootstrap.sh`，再按 [`RESUME.md`](./RESUME.md) 的读取顺序上手。
   它会跑主机检查（**251 项断言**）**与文档链接检查**，两者任一失败即退出码 1。
1. **进度真源**：[`docs/STATUS.md`](./docs/STATUS.md) 的任务板（`BG-xxx`）+ 轮次记录。
   任务号**必须唯一**（R12 修过一次 `BG-040` 一号两用）。
2. **每轮节奏**：开头对齐本轮目标与 DoD → 中间用 todo 跟踪 → 收尾更新 STATUS 与 HANDOFF 并提交。
3. **提交规范**：`feat|fix|docs|test|chore(bg-xxx): 摘要`。
4. **验证阶梯**：L0 静态（`bash -n`、JSON 校验、占位扫描）→ L1 主机可跑单测与模拟器 →
   L2 真机抓栈（证据落 `tests/evidence/`）→ L3 端到端 T1–T10。
5. **安全闸不放宽**：`fill_me` 未填齐即拒绝 build/deploy/Hook；助手不代填授权字段；
   真机破坏性操作逐次确认；仅自有/已授权 App。
6. **分工**：用户提供真机事实与执行（或授权助手在有设备时执行）；助手负责调研、代码、脚本、文档
   及一切主机侧可验证的部分。
7. **同步节奏**：`bash scripts/publish.sh`（先 `--dry-run`）；脚本从不 force push、不改写历史。
8. **文档/目录改动后跑两个检查**：`bash scripts/check-links.sh`（Markdown 链接）与
   `bash scripts/check-shell.sh`（shell 语法 + **source 目标存在性**）。
   R12 的目录重构一次产生过 **52 条断链**，而文档是新会话的唯一入口——这类问题必须机器兜住。
9. **改目录结构时**：`ios/scripts/lib/common.sh` 的根解析带哨兵（找不到
   `shared/config/targets.json` 立即报错）。搬迁脚本后请**先跑一次测试套件**，
   不要依赖「看起来路径对」。
