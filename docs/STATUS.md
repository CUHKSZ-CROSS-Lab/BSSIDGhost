# 项目状态（单一进度真源）

> **规则**：所有进行中的工作都必须有 `BG-` 编号；每轮结束更新本文件 **与** [`HANDOFF.md`](../HANDOFF.md)。
> 状态取值：`todo` / `doing` / `blocked` / `done`。证据一律写仓库内相对路径。

## 当前轮次

| 轮次 | 主题 | 状态 |
|---|---|---|
| R1 | 工程化与流程最小集（决策 A 的先做部分） | ✅ 完成 |
| R2 | B 线（真机抓链路方案）与 C 线（映射逻辑 + 主机侧单测）并行 | ⏳ 计划中 |

## 任务板

| ID | 任务 | 状态 | 依赖 | 证据 |
|---|---|---|---|---|
| BG-001 | 建立 git 仓库与 `.gitignore` | done | — | [`.gitignore`](../.gitignore) |
| BG-002 | 建立 STATUS/HANDOFF 轮次节奏（单一进度真源） | done | BG-001 | 本文件、[`HANDOFF.md`](../HANDOFF.md) |
| BG-010 | 确认测试机越狱类型与 iOS 版本 | done | — | 见下「已确认环境事实」 |
| BG-011 | 真机 Frida 抓取 Wi-Fi 信息接口真实调用栈 | blocked | BG-010、授权闸、设备就位 | — |
| BG-012 | 确认返回形态与格式（NSString / NSData / 结构体） | blocked | BG-011 | — |
| BG-013 | 枚举交叉校验通道（多接口 / 公网出口 IP / mDNS / ARP） | todo | BG-011 | — |
| BG-020 | 实现 `BGGhostMapBSSID()` 映射逻辑（含 nil 语义与格式一致性） | todo | — | — |
| BG-021 | 主机侧可跑单测（不依赖真机） | todo | BG-020 | — |
| BG-022 | 映射表读取 / 日志落盘 / 授权闸的配置读取实现 | todo | — | — |
| BG-030 | 选定 Hook 框架并跑通最小 PoC | blocked | BG-011、设备 | — |
| BG-031 | 补全 `build.sh` / `deploy.sh` / `verify.sh` 真实实现 | todo | BG-030、BG-032 | — |
| BG-032 | 决定编译链落点（macOS+theos / Linux 补 SDK / 越狱机上编） | todo | — | 见下「阻塞项 3」 |
| BG-040 | 测试矩阵 T1–T10 执行与取证 | blocked | BG-030、授权闸 | [`tests/README.md`](../tests/README.md) |

## 轮次记录

### R1（2026-10-13）工程化与流程最小集

用户决策（本轮）：

1. 测试机：**Dopamine / rootless，iOS 15.0–16.6.x，路径前缀 `/var/jb`**。
2. 授权：**暂不确定，先按未授权处理** —— 所有真机相关任务保持 blocked，脚本与 Hook 的安全闸保持关闭，**不代填授权字段**。
3. 主线：**先 A，然后 B、C 并行**。
4. 流程范围：**最小集**（git + STATUS + HANDOFF 节奏）；`process.md` / `decisions.md` 等跑完一轮再补。
5. 外部能力：**都先不装，保持环境干净**（不装 frida、不接 MCP、不启用 `plugin_manager` 工具、不装社区插件市场）。

交付物：

- `git init -b main`，首次提交覆盖现有 16 个骨架文件 + `.gitignore`。
- 本文件（任务板 + 轮次记录 + 环境事实 + 阻塞项）。

## 已确认环境事实（不要重复探测）

### 决策与环境

| 项 | 结论 | 来源 |
|---|---|---|
| 测试机越狱 | Dopamine / rootless | 用户（R1） |
| 目标 iOS | 15.0–16.6.x | 用户（R1） |
| 注入路径前缀 | `/var/jb`（`/var/jb/usr/lib`、`/var/jb/Library/MobileSubstrate/DynamicLibraries`） | 由 rootless 推导 |
| 授权状态 | 未登记（`fill_me`），全部闸门关闭 | [`config/targets.json`](../config/targets.json) |
| Hook 框架 | 未选定，待 BG-011 结论 | 待办 |
| 编译链 | 未确定，见 BG-032 | 待办 |

### 本机（Linux）能力审计

| 能力 | 状态 |
|---|---|
| 真机连接 | ❌ `idevice_id -l` → `Unable to retrieve device list!`（当前无设备） |
| libimobiledevice | ✅ `idevice_id` / `iproxy` / `idevicesyslog` / `idevicedebug` / `idevicescreenshot` / `ideviceinfo` |
| 基础工具 | ✅ `ssh` / `scp` / `jq` / `git`（身份已配）/ `pacman` + `yay` |
| Frida | ❌ 无 CLI；Python 无 `pip`，故 `frida-tools` 不可装；npm `frida@17.23.3`（npmmirror 有）可行但**本轮决定不装** |
| theos / iPhoneOS SDK / `ldid` / `dpkg-deb` | ❌ 全无；`clang 22` 支持 arm64 目标但**无 SDK，无法在本机交叉编译** |
| 网络 | ⚠️ `registry.npmjs.org` **不可达**（DNS 仅 IPv6、连接超时）；`registry.npmmirror.com` 200；`github.com` 200 |

## 阻塞项（需要用户输入）

1. **授权闸** —— `config/targets.json` 的 6 个授权字段仍为 `fill_me`。按 R1 决策先按未授权处理；真机任务（BG-011/012/013/030/031/040）全部 blocked。**助手不代填授权字段**，只在用户提供具体值后写入。
2. **设备就位** —— 当前无 iOS 设备连接，`idevice_id -l` 失败。
3. **编译链落点（BG-032）** —— 三选一：macOS + theos / 本机装 theos + iOS SDK + `ldid` / 直接在越狱机上用 Procursus 工具链编译。**尚未决策**。

## 下一轮（R2）计划：B、C 并行

**B 线（BG-011 前置，无设备也能交付）**

- `tests/frida/capture-wifi-api.js`：一次性 Hook `CoreWLAN` / `NEHotspotNetwork` / `CNCopyCurrentNetworkInfo` / `com.apple.nehelper` XPC 应答，打印调用栈与返回形态。
- `docs/device-setup.md`（或 `tests/` 下 SOP）：设备准备清单（越狱、frida-server 版本匹配 rootless 安装、`iproxy`/SSH 通道、验证命令）。
- `tests/evidence/README.md`：证据命名与记录模板（设备型号 / iOS 版本 / 越狱类型 / App 版本 / 真实 BSSID / 抓取时间）。

**C 线（完全不依赖真机）**

- 实现 `BGGhostMapBSSID()`：规则匹配、格式一致性（大小写 / 分隔符）、**真值为 nil 时不得凭空构造**、无规则时原值透传。
- 主机侧单测：把映射逻辑抽成不依赖 ObjC 运行时的纯逻辑（或加一个可用 clang 直接编译的测试入口），覆盖 T5/T7 对应的边界。
