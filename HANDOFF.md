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

## 4. 未决事项（需要用户输入）

- ~~目标测试机越狱类型与 iOS 版本未确认~~ → **已确认（R1）**：Dopamine / **rootless**，
  iOS **15.0–16.6.x**，路径前缀 `/var/jb`。注入路径、dylib 落地目录按 rootless 处理；
  CoreWLAN 类名/方法签名仍需真机验证（见 BG-011）。
- **目标 App 授权状态未确认（阻塞中）** —— `config/targets.json` 的 `authorization` 字段全为 `fill_me`。
  R1 决策：**先按未授权处理**，所有真机任务保持 `blocked`，脚本与 Hook 的安全闸保持关闭。
  **助手不代填授权字段**，只在用户给出具体值后写入。
- **设备未就位** —— `idevice_id -l` 返回 `Unable to retrieve device list!`。
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

## 7. 建议的下一步（R2：B、C 并行）

R1 已决策「先 A，然后 B、C 并行」。A 的最小集已完成，R2 按下面两条线同时推进
（完整任务板见 [`docs/STATUS.md`](./docs/STATUS.md)）：

**B 线 —— 真机抓链路方案（无设备也能先交付脚本与清单，BG-011 前置）**

1. `tests/frida/capture-wifi-api.js`：一次性 Hook `CoreWLAN` / `NEHotspotNetwork` /
   `CNCopyCurrentNetworkInfo` / `com.apple.nehelper` XPC 应答，打印调用栈与返回形态。
2. 设备准备 SOP：越狱确认、frida-server 与主机版本严格匹配、rootless 安装路径、
   `iproxy`/SSH 通道、验证命令。
3. `tests/evidence/` 证据记录模板（设备型号 / iOS 版本 / 越狱类型 / App 版本 / 真实 BSSID / 时间）。

**C 线 —— 主机侧可验证实现（完全不依赖真机）**

4. 实现 `BGGhostMapBSSID()`：规则匹配、格式一致性（大小写 / 分隔符）、
   **nil 透传**、无规则时返回原值。
5. 主机侧单测：把映射逻辑抽成不依赖 ObjC 运行时的纯逻辑，覆盖 T5/T7 边界。

> 仍需用户补齐才能解锁真机线：`config/targets.json` 授权字段、设备就位、编译链落点（BG-032）。

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
