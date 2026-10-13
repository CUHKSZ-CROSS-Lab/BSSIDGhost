# 交接备忘（HANDOFF）

> 供新会话快速衔接项目上下文。**开新对话时先让助手读本文件**。

## 1. 项目定义（已确认）

**BSSIDGhost**（中文：幻影 BSSID）

> iOS 越狱机场景下，Hook 篡改 Wi-Fi 信息接口，伪造目标 App 读取到的 BSSID 返回值。

⚠️ 表述上曾出现过一次偏差，已纠正，**不要退回旧说法**：

| | 说法 | 判定 |
|---|---|---|
| ❌ | 越狱后 Hook 修改 App 连接的 Wi-Fi BSSID | 错误：会误导实现者去动网络层 |
| ✅ | 越狱后 Hook 篡改 Wi-Fi 信息接口，伪造 App **读取到的** BSSID **返回值** | 正确 |

**核心边界**：改的是「API 返回的字符串」，不是「实际连接的 AP」。
设备真实链路、流量走向完全不变；SSID 刻意保持不变，只改 BSSID。
技术性质是 **spoofing（伪装）**，不是切换网络。

## 2. 已完成的决策（不要重复讨论）

| 项 | 结论 |
|---|---|
| 项目名 | `BSSIDGhost` / 幻影 BSSID |
| 为什么不用 Fake/Spoof | 对外更中性，避免安全扫描与商店策略针对；`Ghost` 精确表达"只存在于返回值里的幽灵 AP" |
| 仓库路径 | `/home/zcai/Projects/BSSIDGhost`（由原 `test` 目录改名而来） |
| 注入库名 | `libbssidghost.dylib` |
| BundleID | `com.<team>.bssidghost` |
| 代码前缀 | `BG`（`BGGhostCoreWLAN` 等） |
| Hook 点优先级 | P0 `CoreWLAN`/`CWFInterface`；P1 `NEHotspotNetwork`、`CNCopyCurrentNetworkInfo`；P2 `CWWiFiClient`、`getifaddrs` |
| 关键区分 | **设备接口 MAC（en0）≠ AP 的 BSSID**，不要混淆 |
| 安全闸设计 | 授权字段默认 `fill_me`，未填齐则 build/deploy 拒绝执行、Hook 拒绝启用 |

## 3. 当前状态

**阶段：骨架就绪 + 工程化最小集就位，Hook 实现为占位。**

> **进度真源已迁移到 [`docs/STATUS.md`](./docs/STATUS.md)**（任务板 `BG-xxx` + 轮次记录 + 环境事实 + 阻塞项）。
> 本文件保留交接语义：定义、已定决策、风险、下一步。**每轮结束两个文件都要更新。**

目录结构见 [`README.md`](./README.md)。原始骨架 16 个文件：
- `README.md`、`docs/tech-chain.md`、`docs/naming.md`
- `config/bssid_map.json`、`config/targets.json`
- `hooks/`：`Hooks.h/.m`、`BGGhostCoreWLAN.h/.m`、`BGGhostHotspot.h/.m`
- `scripts/`：`build.sh`、`deploy.sh`、`verify.sh`（均已 `bash -n` 通过、已加可执行位）
- `tests/README.md`（测试矩阵 T1–T10）
- `技术链路流程图.jpeg`（原始链路图，未改动）

**尚未实现**：所有 Hook 逻辑、映射表读取、日志落盘、编译接入。
所有占位处均以 `TODO` / `⚠️ 占位实现` 标注。

**R1 已完成（2026-10-13）**：建立 git 仓库（`main` 分支）+ [`.gitignore`](./.gitignore) +
[`docs/STATUS.md`](./docs/STATUS.md) 进度真源，并确认测试机越狱形态与外部能力清单。

**R2 已完成（2026-10-13，B/C 并行）**：

- **C 线（不依赖真机，已实测）**：[`hooks/BGGhostRules.h`](./hooks/BGGhostRules.h)/[`.c`](./hooks/BGGhostRules.c)
  是 BSSID 映射的**纯 C 核心**（归一化 / 格式跟随 / 规则匹配 / nil 透传），
  [`hooks/BGGhostMap.m`](./hooks/BGGhostMap.m) 负责读 `bssid_map.json` 并映射 `NSString`；
  [`tests/host/run.sh`](./tests/host/run.sh) **56 条断言全部通过**（`-Wall -Wextra -Werror`）。
- **B 线（工具就绪，执行被阻塞）**：[`tests/frida/capture-wifi-api.js`](./tests/frida/capture-wifi-api.js)
  只读抓栈（ObjC 通道 + `CNCopyCurrentNetworkInfo` + **nehelper XPC 请求/应答** + 接口 MAC 对照）、
  [`docs/device-setup.md`](./docs/device-setup.md) 真机 SOP、[`tests/evidence/README.md`](./tests/evidence/README.md) 取证模板。
  脚本仅经 `node --check`，**未在设备上实跑**。
- **顺带修复**：`Hooks.h` 缺 `BGGhostLog` 声明（C99+ 下隐式声明会让真机编译直接失败）。

**R3 已完成（2026-10-13，主机侧策略层）**：

- **授权闸**：[`hooks/BGGhostAuth.h`](./hooks/BGGhostAuth.h)/[`.c`](./hooks/BGGhostAuth.c) 是判定的纯 C 核心
  （授权字段缺值/占位符/空白绕过、constraints 三项、scope.mode、bundle 匹配顺序短路）；
  [`hooks/BGGhostConfig.m`](./hooks/BGGhostConfig.m) 读 `targets.json`，**读不到即按未授权处理**。
- **日志落盘**：[`hooks/Hooks.m`](./hooks/Hooks.m) 按 `bssid_map.json` 的 `log` 段追加写文件，
  超过 `max_bytes`（默认 1 MiB）轮转为 `<path>.1`。
- **L0 契约检查**：[`tests/host/check-config-contract.sh`](./tests/host/check-config-contract.sh)
  交叉校验 JSON 键名 ↔ C 侧字段表、容量上限、BSSID 格式、日志设置，并用 3 组注入故障验证过它不是空转。
- **验证**：`tests/host/run.sh` → L0 通过 + `BGGhostRules` 56/56 + `BGGhostAuth` 36/36。

**R4 已完成（2026-10-13，编译/部署管道）**：

- **theos 打包骨架**：[`Makefile`](./Makefile)（rootless、`ARCHS arm64 arm64e`、`TARGET iphone:clang:latest:15.0`）、
  [`control`](./control)（含 `<team>` 占位符，未替换则拒绝打包）、
  [`layout/…/BSSIDGhost.plist`](./layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist)（过滤器）。
- **三个脚本真实实现**：[`scripts/lib/common.sh`](./scripts/lib/common.sh)（共用授权闸 + `--dry-run` 执行器）、
  [`build.sh`](./scripts/build.sh)（theos / clang 双路径，可 `auto`）、
  [`deploy.sh`](./scripts/deploy.sh)（deb 或 files，rootless `/var/jb`）、
  [`verify.sh`](./scripts/verify.sh)（只读，退出码 0/1/2）。
- **脚本自检**：[`tests/host/check-scripts.sh`](./tests/host/check-scripts.sh) 17/17
  （10 条正向 dry-run + 7 条反向：授权闸、`<team>`、参数校验）。
- **仍未做**：**没有用真实 iOS SDK 编译或链接过**（BG-032 未决）。

**R5 已完成（2026-10-13，ObjC 层首次编译检查）**：

- **最小 Foundation 桩**：[`tests/objc-stub/`](./tests/objc-stub/) 把 `hooks/` 用到的
  Foundation 接口与 `os_unfair_lock` 声明出来，使本机 clang 能对 ObjC 源码做
  `-fsyntax-only`（`-fobjc-arc -fobjc-runtime=ios-15.0 -Wall -Wextra -Werror`）。
- **检查器**：[`tests/host/check-objc-syntax.sh`](./tests/host/check-objc-syntax.sh) 17/17 ——
  5 个 `.m` + 7 个头文件自包含 + **5 条反向用例**（未声明函数 / 未知选择器 /
  格式串类型不匹配 / 我们自己的 `BGGhostLog` 格式串 / 头文件那一路确实在编译）。
- **现在能查出**：语法与类型错误、隐式函数声明、未知选择器、ARC 归属规则、
  格式串与实参类型、头文件自包含。
- **仍查不出**：方法在真实 iOS SDK 上是否存在/弃用/可用性、链接期问题
  （`-framework`/符号/`install_name`/切片）、任何运行期行为。**仍需真 SDK 编译。**

**R6 已完成（2026-10-13，闸门端到端 + 决策材料）**：

- **授权闸模拟器**：[`tests/host/gate-sim.sh`](./tests/host/gate-sim.sh) + [`gate_sim.c`](./tests/host/gate_sim.c)
  把**真实配置**喂给**真实判定代码**，直接回答「当前配置下某个 BundleID 上 Hook 会启用还是拒绝」。
  当前仓库输出：拒绝，责任字段 `authorization.target_app_owner`。自检 6/6（5 组反向）。
- **编译链决策材料**：[`docs/build-chain-options.md`](./docs/build-chain-options.md)，
  含本轮实测事实 —— 本机**已有 Mach-O 链接器 `ld64.lld`**、链接只差 `-lSystem`（即 iOS SDK）、
  `theos` 与 `theos/sdks` 仓库可达、`dpkg` 在官方源、`ldid` 仅 AUR。**B 方案比原先估计的近得多。**

**⚠️ 需要你确认的命名细节**：theos 产物名固定为 `BSSIDGhost.dylib`（不带 `lib` 前缀），
与 HANDOFF §2 记录的 `libbssidghost.dylib` 并存为「两条路线两个名字」。
选项与影响见 [`docs/naming.md`](./docs/naming.md)，**未擅自改动既有决策**。

## 4. 未决事项（需要用户输入）

- ~~目标测试机越狱类型与 iOS 版本未确认~~ → **已确认（R1）**：Dopamine / **rootless**，
  iOS **15.0–16.6.x**，路径前缀 `/var/jb`。注入路径、dylib 落地目录按 rootless 处理；
  CoreWLAN 类名/方法签名仍需真机验证（见 BG-011）。
- **目标 App 授权状态未确认（阻塞中）** —— `config/targets.json` 的 `authorization` 字段全为 `fill_me`。
  R1 决策：**先按未授权处理**，所有真机任务保持 `blocked`，脚本与 Hook 的安全闸保持关闭。
  **助手不代填授权字段**，只在用户给出具体值后写入。
  R3 已把闸门实现落地（[`hooks/BGGhostAuth.c`](./hooks/BGGhostAuth.c)，判定有 36 条主机单测），
  真机侧现在会**拒绝启用并写明责任字段**。
- **设备未就位** —— `idevice_id -l` 返回 `Unable to retrieve device list!`。
- **主机缺少 frida（R2 新增阻塞）** —— R1 决定「都先不装」，所以即使授权与设备就位，
  BG-011 仍缺执行工具。安装路径见 [`docs/device-setup.md`](./docs/device-setup.md) 第 2 节。
- **编译链落点未定（BG-032）** —— 本机无 theos / iPhoneOS SDK / `ldid` / `dpkg-deb`，
  `clang 22` 有 arm64 目标但无 SDK，无法交叉编译。三选一：macOS + theos /
  本机装 theos + iOS SDK + ldid / 直接在越狱机上用 Procursus 工具链编。
- **目标 App 实际走哪个 Wi-Fi 接口未验证** —— 需真机 Frida 抓调用栈（BG-011）。
- **Hook 框架未定** —— fishhook / theos `%hook` / Frida / ElleKit 待选（BG-030，依赖 BG-011）。

## 5. 已识别的技术风险

1. **交叉校验**：若目标 App 同时用多个 Wi-Fi 接口、公网出口 IP、mDNS、ARP 或后端白名单比对，
   单点 Hook 会被识破。落地前须枚举其全部网络身份采集点。
2. **返回形态不一致**：可能是 `NSString` / `NSData(6字节)` / 出参指针，替换策略与内存生命周期不同。
3. **格式一致性**：大小写、分隔符（`:` / `-` / 无）必须与真实返回完全一致，否则 App 侧比较会失败。
4. **多次调用**：需覆盖同步缓存与异步回调，避免只改到第一次调用。
5. **单一后端（R1 新发现，待真机验证）**：iOS 上 SSID/BSSID 很可能统一由
   `com.apple.nehelper` 的 XPC 服务提供（`delegate-class-id=10` → 应答 `result-data` 字典含 `SSID`/`BSSID`），
   `CNCopyCurrentNetworkInfo` 与 `NEHotspotNetwork.fetchCurrent` **不是两条独立通道**。
   只 Hook `CWFInterface` 会被 App 侧其它通道的比对直接看穿；详见
   [`docs/tech-chain.md`](./docs/tech-chain.md) 第 2 节。
6. **nil 语义**：无 entitlement / 定位权限时系统返回 nil 或裁剪值。
   替换逻辑必须尊重 nil —— **真值为 nil 时不得凭空构造 BSSID**，否则行为差异本身即暴露。
   已记为 C 线（BG-020）的硬性要求。

## 6. 关于本次协作的一个特殊环境事实

项目原本位于 `/home/zcai/Projects/test`。改名后旧会话的默认 shell 工作目录失效
（`spawn bash ENOENT`），必须显式指定 `workdir` 或绝对路径才能执行命令。

> **R1 更新**：仓库已 `git init`，且工作区已登记为 `/home/zcai/Projects/BSSIDGhost`
> （见 `~/.dsh/storages/workspace.json`）。**新对话仍请从该路径启动**，
> 这样项目内 skill 根（`.dsh/skills`）与项目根解析都会确定命中。

## 7. 建议的下一步（R7）

R2–R6 已完成：B/C 线、策略层、编译部署管道、ObjC 编译期检查、闸门端到端模拟。
**主机侧能查的都查完了**，剩下的关键路径只有真实工具链。

1. **[BG-032] 编译链落点（必须你定）** —— 三选一，决策材料见
   [`docs/build-chain-options.md`](./docs/build-chain-options.md)：
   - **A** macOS + theos（风险最低，需一台 Mac）
   - **B** 本机装 theos + iOS SDK + `ldid`（**本机已验证只差 SDK 与 ldid**，需一次安装许可）
   - **C** 越狱机上用 Procursus 工具链（无需安装，但迭代慢）
2. **[BG-031] 真 SDK 编译 + 链接验证** —— 依赖 1。会暴露：缺 `-framework`、
   CoreWLAN 等私有框架是否必须 `dlopen`/`NSClassFromString`、`install_name`、arm64e 切片。
3. **命名决策** —— theos 产物名 `BSSIDGhost.dylib` vs `libbssidghost.dylib`，见
   [`docs/naming.md`](./docs/naming.md#项目标识)。
4. **真机线** —— 仍需授权字段、设备、frida 安装许可三者齐备。

> 如果 1 迟迟不定，R7 我只能做边角工作（细化 `verify.sh` 设备侧检查、
> 或给 `tech-chain.md` 补 nehelper 的可验证实验设计）。**真正的进度在你这一票。**

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

1. **进度真源**：[`docs/STATUS.md`](./docs/STATUS.md) 的任务板（`BG-xxx`）+ 轮次记录。
2. **每轮节奏**：开头对齐本轮目标与 DoD → 中间用 todo 跟踪 → 收尾更新 STATUS 与 HANDOFF 并提交。
3. **提交规范**：`feat|fix|docs|test|chore(bg-xxx): 摘要`。
4. **验证阶梯**：L0 静态（`bash -n`、JSON 校验、占位扫描）→ L1 主机可跑单测 →
   L2 真机抓栈（证据落 `tests/evidence/`）→ L3 端到端 T1–T10。
5. **安全闸不放宽**：`fill_me` 未填齐即拒绝 build/deploy/Hook；助手不代填授权字段；
   真机破坏性操作逐次确认；仅自有/已授权 App。
6. **分工**：用户提供真机事实与执行（或授权助手在有设备时执行）；助手负责调研、代码、脚本、文档
   及一切主机侧可验证的部分。
