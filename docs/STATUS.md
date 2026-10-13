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
| R10 | 真机执行：按 [设备准备 SOP](ondevice-build-setup.md) 越狱装机 → 设备端编译 → 装 deb → 跑 T1–T10 | ⏳ 待用户执行 |

## 任务板

| ID | 任务 | 状态 | 依赖 | 证据 |
|---|---|---|---|---|
| BG-001 | 建立 git 仓库与 `.gitignore` | done | — | [`.gitignore`](../.gitignore) |
| BG-002 | 建立 STATUS/HANDOFF 轮次节奏（单一进度真源） | done | BG-001 | 本文件、[`HANDOFF.md`](../HANDOFF.md) |
| BG-010 | 确认测试机越狱类型与 iOS 版本 | done | — | 见「已确认环境事实」 |
| BG-011 | 真机 Frida 抓取 Wi-Fi 信息接口真实调用栈 | **blocked** | 授权闸、设备、主机装 frida | 工具已就绪：[`tests/frida/`](../tests/frida/)、[`docs/device-setup.md`](device-setup.md) |
| BG-012 | 确认返回形态与格式（NSString / NSData / 结构体） | blocked | BG-011 | — |
| BG-013 | 枚举交叉校验通道（多接口 / 公网出口 IP / mDNS / ARP） | blocked | BG-011 | — |
| BG-020 | 实现 `BGGhostMapBSSID()` 映射逻辑（含 nil 语义与格式一致性） | **done** | — | [`hooks/BGGhostRules.c`](../hooks/BGGhostRules.c)、[`hooks/BGGhostMap.m`](../hooks/BGGhostMap.m) |
| BG-021 | 主机侧可跑单测（不依赖真机） | **done** | BG-020 | [`tests/host/run.sh`](../tests/host/run.sh)（L0 + 92 条断言全通过） |
| BG-022 | 映射表读取 / 日志落盘 / 授权闸的配置读取实现 | **done** | — | [`hooks/BGGhostAuth.c`](../hooks/BGGhostAuth.c)、[`hooks/BGGhostConfig.m`](../hooks/BGGhostConfig.m)、日志落盘在 [`hooks/Hooks.m`](../hooks/Hooks.m) |
| BG-023 | L0 配置契约检查（JSON ↔ C 键名/容量/格式） | **done** | — | [`tests/host/check-config-contract.sh`](../tests/host/check-config-contract.sh)（含 3 组反向用例验证） |
| BG-030 | 选定 Hook 框架并跑通最小 PoC | blocked | BG-011、设备 | — |
| BG-031 | 补全 `build.sh` / `deploy.sh` / `verify.sh` 真实实现 | **doing** | BG-032（真编译验证） | 三条命令已实现并自检（`--dry-run`）：[`scripts/`](../scripts/)、[`tests/host/check-scripts.sh`](../tests/host/check-scripts.sh)；**待真实工具链验证** |
| BG-032 | 决定编译链落点 | **done（= C，用户 2026-10-13 选定）** | — | 决策说明见 [`docs/build-chain-options.md`](build-chain-options.md)；执行 SOP 见 [`docs/ondevice-build-setup.md`](ondevice-build-setup.md) |
| BG-033 | theos 打包骨架（Makefile / control / layout 过滤器） | **done** | — | [`Makefile`](../Makefile)、[`control`](../control)、[`layout/…/BSSIDGhost.plist`](../layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist) |
| BG-034 | 脚本自检（正向 dry-run + 反向授权闸/占位符） | **done** | — | [`tests/host/check-scripts.sh`](../tests/host/check-scripts.sh)（17/17 通过） |
| BG-035 | ObjC 层编译期检查（最小 Foundation 桩 + `-fsyntax-only`） | **done** | — | [`tests/objc-stub/`](../tests/objc-stub/)、[`tests/host/check-objc-syntax.sh`](../tests/host/check-objc-syntax.sh)（17/17，含 5 条反向用例） |
| BG-036 | 授权闸模拟器（真实判定代码 + 真实配置的端到端判定） | **done** | — | [`tests/host/gate-sim.sh`](../tests/host/gate-sim.sh)、[`tests/host/gate_sim.c`](../tests/host/gate_sim.c)（自检 6/6） |
| BG-037 | 编译链决策说明（BG-032 的决策材料 + 已实测前置条件） | **done** | — | [`docs/build-chain-options.md`](build-chain-options.md) |
| BG-043 | 设备端编译/验证环境搭建 SOP（Dopamine 安装 + Procursus 工具链 + SDK 上机 + 编译验证闭环） | **done** | BG-032 | [`docs/ondevice-build-setup.md`](ondevice-build-setup.md) |
| BG-038 | BSSID 映射模拟器（真实映射代码 + 真实配置的端到端） | **done** | — | [`tests/host/map-sim.sh`](../tests/host/map-sim.sh)、[`tests/host/map_sim.c`](../tests/host/map_sim.c)（自检 8/8） |
| BG-039 | nehelper 可证伪实验设计（假设 / 判别表 / 证伪条件 / 两步 attach） | **done** | — | [`docs/tech-chain.md`](tech-chain.md) §2.2、[`tests/frida/README.md`](../tests/frida/README.md) |
| BG-040 | 交接方案：环境自检 / 5 分钟恢复指南 / 推送与 PR 脚本 | **done** | — | [`RESUME.md`](../RESUME.md)、[`scripts/bootstrap.sh`](../scripts/bootstrap.sh)、[`scripts/publish.sh`](../scripts/publish.sh) |
| BG-041 | 修复「换到 macOS 后 ObjC 检查假通过」风险（桩与真 SDK 二选一 + 反向用例） | **done** | — | [`tests/host/check-objc-syntax.sh`](../tests/host/check-objc-syntax.sh)（18/18，含假 SDK 反向用例） |
| BG-040 | 测试矩阵 T1–T10 执行与取证 | blocked | BG-030、授权闸 | [`tests/README.md`](../tests/README.md)（T5/T7 逻辑部分已由 L1 覆盖） |

## 已确认环境事实（不要重复探测）

### 决策与环境

| 项 | 结论 | 来源 |
|---|---|---|
| 测试机越狱 | Dopamine / rootless | 用户（R1） |
| 目标 iOS | 15.0–16.6.x | 用户（R1） |
| 注入路径前缀 | `/var/jb`（`/var/jb/usr/lib`、`/var/jb/Library/MobileSubstrate/DynamicLibraries`） | 由 rootless 推导 |
| 授权状态 | 未登记（`fill_me`），全部闸门关闭 | [`config/targets.json`](../config/targets.json) |
| Hook 框架 | 未选定，待 BG-011 结论 | 待办 |
| 编译链 | **方案 C：越狱设备上用 Procursus 工具链就地编译**（用户 2026-10-13 选定） | ✅ 已定 |

### 本机（Linux）能力审计

| 能力 | 状态 |
|---|---|
| 真机连接 | ❌ `idevice_id -l` → `Unable to retrieve device list!`（当前无设备） |
| libimobiledevice | ✅ `idevice_id` / `iproxy` / `idevicesyslog` / `idevicedebug` / `idevicescreenshot` / `ideviceinfo` |
| 基础工具 | ✅ `ssh` / `scp` / `jq` / `git`（身份已配）/ `clang 22` / `pacman` + `yay` |
| Frida | ❌ 无 CLI；Python 无 `pip`，故 `frida-tools` 不可装；npm `frida@17.23.3`（npmmirror 有）可行但 R1 决定不装 |
| theos / iPhoneOS SDK / `ldid` / `dpkg-deb` | ❌ 全无；`clang 22` 支持 arm64 目标但**无 SDK，无法在本机交叉编译** |
| 网络 | ⚠️ `registry.npmjs.org` **不可达**（DNS 仅 IPv6、连接超时）；`registry.npmmirror.com` 200；`github.com` 200 |

## 阻塞项（需要用户输入）

1. **授权闸** —— `config/targets.json` 的 6 个授权字段仍为 `fill_me`。按 R1 决策先按未授权处理；
   真机任务（BG-011/012/013/030/031/040）全部 blocked。**助手不代填授权字段**，只在用户提供具体值后写入。
2. **设备就位** —— 当前无 iOS 设备连接，`idevice_id -l` 失败。
3. ~~编译链落点（BG-032）~~ → **已解决（2026-10-13）：用户选定方案 C（设备端 Procursus 工具链）**。
   准备步骤见 [`docs/ondevice-build-setup.md`](ondevice-build-setup.md)；
   决策对比留档在 [`docs/build-chain-options.md`](build-chain-options.md)。
4. **主机 frida** —— R1 决定「都先不装」，因此 BG-011 即便设备与授权就位也还缺执行工具
   （安装路径见 [`docs/device-setup.md`](device-setup.md) 第 2 节）。

## 下一轮（R10）：真机执行（由用户驱动）

主机侧与决策都没问题了，**剩下的是在设备上跑一遍**。步骤全部在
[`docs/ondevice-build-setup.md`](ondevice-build-setup.md)，按顺序：

1. **越狱装机**（用户）：确认机型与 iOS 版本 → Dopamine（rootless）→ Sileo 里装 ElleKit、Preloader。
2. **装工具链**（设备上）：`clang-16`、`ld64`、`ldid`、`dpkg`、`make`（详见 SOP §3）。
3. **SDK 上机**：sparse checkout `iPhoneOS16.5.sdk`（≈201 MB）。
4. **编译**：`bash scripts/build.sh --toolchain theos`（推荐）或直接 clang。
   ⚠️ `build.sh` 会先过**授权闸**，`config/targets.json` 仍是 `fill_me` 时会拒绝构建。
5. **装包并验证**：`dpkg -i packages/*.deb` → 冷启动目标 App → 看
   `/var/mobile/Library/Logs/BSSIDGhost/ghost.log` → 跑 T1–T10。
6. **（可选）抓栈验证 nehelper 假设**：按 [`tech-chain.md`](tech-chain.md) §2.2 的**两步 attach**。

**我可以在你装机时并行做的事**（等你的真机输出）：
- 命名决策（theos 产物名 `BSSIDGhost.dylib` vs `libbssidghost.dylib`，见 [`naming.md`](naming.md#项目标识)）；
- `verify.sh` 设备侧检查细化（等真实日志格式确定后再做更稳）；
- 把首次设备端编译的报错回写 SOP 的「常见坑」。

> 需要你提供的信息（我无法自行探测）：**机型 + 当前 iOS 版本**（决定越狱路线与可选区间）、
> 以及**是否已填 `config/targets.json` 授权字段**。

## 轮次记录

> 最新轮次在最前。

### R9（2026-10-13）BG-032 决策落地：选定方案 C + 设备准备 SOP

**用户决策**：`BG-032 = C` —— 在越狱设备上用 **Procursus 工具链**就地编译并验证。

**交付**：[`docs/ondevice-build-setup.md`](ondevice-build-setup.md) ——
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

发现的问题：[`check-objc-syntax.sh`](../tests/host/check-objc-syntax.sh) 原来无条件带
`-I tests/objc-stub`。在装有 iOS SDK 的 Mac 上，这个 `-I` 会**把真 `Foundation.h` 顶掉**，
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
| [`tests/host/map_sim.c`](../tests/host/map_sim.c) | 读 `global/rule/default/query/querynil` 类型的 TSV，调用 `BGGhostRules.c` 的真实接口，逐条打印「返回什么 + 是替换还是透传」 |
| [`tests/host/map-sim.sh`](../tests/host/map-sim.sh) | 用 jq 抽取真实映射表；无参数时**按配置里的每条规则自动生成查询**；`--ssid/--bssid` 指定查询；`--self-test` 8 组断言 |

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
在 [`docs/tech-chain.md`](tech-chain.md) §2.2 写死了：

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
「以当前 `config/targets.json` 为准，Hook 会对某个 BundleID 启用还是拒绝」：

| 文件 | 内容 |
|---|---|
| [`tests/host/gate_sim.c`](../tests/host/gate_sim.c) | 从 stdin 读 `KIND<TAB>KEY<TAB>VALUE`，调用 `BGGhostAuth.c` 的真实接口，输出判定 + 原因 + 责任字段 |
| [`tests/host/gate-sim.sh`](../tests/host/gate-sim.sh) | 用 jq 从 JSON 抽取输入；`--bundle` 指定进程；`--self-test` 跑 6 组断言 |

```
$ tests/host/gate-sim.sh
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

[`docs/build-chain-options.md`](build-chain-options.md) 把三个选项的前置条件、成本、
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

**动因**：此前 `hooks/*.m` 是全项目**唯一零编译验证**的部分，也是风险最高的部分。
本机没有 iOS SDK，但有 clang —— 于是写一层最小声明桩，让 `-fsyntax-only` 真正跑起来。

**交付**

| 文件 | 内容 |
|---|---|
| [`tests/objc-stub/Foundation/Foundation.h`](../tests/objc-stub/Foundation/Foundation.h) | 最小 Foundation 声明桩：`NSString`/`NSArray`/`NSDictionary`/`NSData`/`NSNumber`/`NSFileManager`/`NSBundle`/`NSJSONSerialization`/`NSError`/`NSLog`、快速枚举、轻量泛型、字面量所需的类方法 |
| [`tests/objc-stub/os/lock.h`](../tests/objc-stub/os/lock.h) | `os_unfair_lock` 声明与 `OS_UNFAIR_LOCK_INIT`（Darwin 头，Linux 没有） |
| [`tests/objc-stub/README.md`](../tests/objc-stub/README.md) | 桩的用途、**查不出来的东西**、维护原则 |
| [`tests/host/check-objc-syntax.sh`](../tests/host/check-objc-syntax.sh) | 检查器：5 个 `.m` + 7 个头文件自包含 + 5 条反向用例 |

**验证证据**

```
$ tests/host/check-objc-syntax.sh
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
必须一致，否则会静默漏掉一整类检查（已写进 `tests/objc-stub/README.md` 的维护原则）。

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
| [`Makefile`](../Makefile) | theos 打包：`THEOS_PACKAGE_SCHEME=rootless`、`TARGET iphone:clang:latest:15.0`、`ARCHS arm64 arm64e`、`-fobjc-arc` |
| [`control`](../control) | deb 元信息；含 `<team>` 占位符（未替换则打包被拒）；`Depends: ellekit \| mobilesubstrate` |
| [`layout/…/BSSIDGhost.plist`](../layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist) | 过滤器（**只按 `scope.bundle_ids` 过滤**），构建时重新生成，L0 检查防止漂移 |
| [`scripts/lib/common.sh`](../scripts/lib/common.sh) | 三个脚本共用：授权闸（脚本侧防线）、过滤器生成、`--dry-run` 执行器 |
| [`scripts/build.sh`](../scripts/build.sh) | 两条编译链（theos / clang 可切换或自动选择）、多架构 + `llvm-lipo`、生成过滤器与随包配置 |
| [`scripts/deploy.sh`](../scripts/deploy.sh) | `deb`（推送 + `dpkg -i`）与 `files`（dylib + plist）两种方式；rootless `/var/jb` 路径；自动选择唯一设备 |
| [`scripts/verify.sh`](../scripts/verify.sh) | 只读验证：本地闸门状态 + SSH 抓日志判定 T1/T9；退出码 0/1/2 区分「通过 / 失败 / 仅本地」 |
| [`tests/host/check-scripts.sh`](../tests/host/check-scripts.sh) | 脚本自检：10 条正向（dry-run 命令拼装）+ 7 条反向（授权闸、`<team>`、参数校验） |

**验证证据**

```
$ tests/host/run.sh
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
| 过滤器与随包配置 | 由 `build.sh` 生成，`layout/usr/share/bssidghost/` 走 `.gitignore` | 避免与 `config/` 漂移；L0 检查兜住提交在仓库里的那份 plist |
| 仓库里的 plist | 保留一份「安全默认」并纳入 L0 一致性检查 | 防止有人直接 `make package` 时插件在所有进程加载 |
| 脚本侧授权闸 | 与 `BGGhostAuth.c` 语义对齐，但**不重复实现判定** | 真正的判定有 36 条单测；脚本只做「明显未授权就停」 |
| `verify.sh` 退出码 | 0 通过 / 1 失败 / 2 仅本地 | 「没做设备侧检查」不能等同于「验证通过」 |
| theos 产物名 | `BSSIDGhost.dylib`（theos 约定），与 `libbssidghost.dylib` 并存 | theos 无法加 `lib` 前缀；**已记入 [`naming.md`](naming.md) 待你确认**，未擅自改 HANDOFF §2 |

### R3（2026-10-13）授权闸 + 日志落盘 + L0 契约检查

**交付**

| 文件 | 内容 |
|---|---|
| [`hooks/BGGhostAuth.h`](../hooks/BGGhostAuth.h) / [`.c`](../hooks/BGGhostAuth.c) | 授权闸与作用域判定的**纯 C 核心**：字段缺值/占位符、约束开关、scope.mode、bundle 匹配 |
| [`hooks/BGGhostConfig.h`](../hooks/BGGhostConfig.h) / [`.m`](../hooks/BGGhostConfig.m) | 读 `targets.json` → `BGAuthConfig`；读 `bssid_map.json` 的 `log` 段 → `BGLogConfig`；**fail closed** |
| [`hooks/Hooks.m`](../hooks/Hooks.m) | 授权闸接入 `BGGhostInstallHooks`（拒绝时写明原因与责任字段）；日志落盘 + 1 MiB 轮转 |
| [`tests/host/test_bgg_auth.c`](../tests/host/test_bgg_auth.c) | 36 条断言 |
| [`tests/host/check-config-contract.sh`](../tests/host/check-config-contract.sh) | L0 契约检查：JSON 键名 ↔ C 侧 `kBGAuthFieldKeys`、容量上限、BSSID 格式、日志设置 |

**验证证据**

```
$ tests/host/run.sh
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
| [`hooks/BGGhostRules.h`](../hooks/BGGhostRules.h) / [`.c`](../hooks/BGGhostRules.c) | BSSID 映射的**纯 C 核心**：归一化、格式跟随、规则匹配、默认值、表容量 |
| [`hooks/BGGhostMap.h`](../hooks/BGGhostMap.h) / [`.m`](../hooks/BGGhostMap.m) | ObjC 胶水：`bssid_map.json` → `BGRuleSet`，对 `NSString` 做映射 |
| [`tests/host/test_bgg_rules.c`](../tests/host/test_bgg_rules.c) / [`run.sh`](../tests/host/run.sh) | 主机侧单测，56 条断言 |
| [`hooks/BGGhostCoreWLAN.m`](../hooks/BGGhostCoreWLAN.m) | 移除占位映射函数，改为调用映射层；保留 Hook 注册 TODO |

验证证据（L1 实测）：

```
$ tests/host/run.sh
编译：clang -std=c11 -Wall -Wextra -Werror -O1
结果：56 通过, 0 失败
```

**B 线交付（工具就绪，执行被授权闸/设备/frida 阻塞）**

| 文件 | 内容 |
|---|---|
| [`tests/frida/capture-wifi-api.js`](../tests/frida/capture-wifi-api.js) | Frida 只读抓栈：ObjC 通道（`CWFInterface` / `CWInterface` / `CWNetwork` / `CWWiFiClient` / `NEHotspotNetwork`）、`CNCopyCurrentNetworkInfo`、**nehelper XPC 请求与应答**、`getifaddrs` 接口 MAC 对照；输出 JSONL |
| [`docs/device-setup.md`](device-setup.md) | 真机准备 SOP：frida-server 版本严格匹配、rootless 路径、`iproxy`/SSH、验证清单、故障排查 |
| [`tests/frida/README.md`](../tests/frida/README.md) | 脚本用法、覆盖点、**已知限制**（嵌套折叠、异步应答、未实跑） |
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
