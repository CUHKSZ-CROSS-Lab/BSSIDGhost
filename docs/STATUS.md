# 项目状态（单一进度真源）

> **规则**：所有进行中的工作都必须有 `BG-` 编号；每轮结束更新本文件 **与** [`HANDOFF.md`](../HANDOFF.md)。
> 状态取值：`todo` / `doing` / `blocked` / `done`。证据一律写仓库内相对路径。

## 当前轮次

| 轮次 | 主题 | 状态 |
|---|---|---|
| R1 | 工程化与流程最小集（决策 A 的先做部分） | ✅ 完成 |
| R2 | B 线（真机抓链路方案）与 C 线（映射逻辑 + 主机侧单测）并行 | ✅ 完成（真机执行仍阻塞） |
| R3 | 待定：编译链落点（BG-032）+ 授权闸与日志落盘（BG-022） | ⏳ 计划中 |

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
| BG-021 | 主机侧可跑单测（不依赖真机） | **done** | BG-020 | [`tests/host/run.sh`](../tests/host/run.sh)（56/56 通过） |
| BG-022 | 映射表读取 / 日志落盘 / 授权闸的配置读取实现 | **doing** | — | 映射表读取已完成（`BGGhostMap.m`）；日志落盘与授权闸待做 |
| BG-030 | 选定 Hook 框架并跑通最小 PoC | blocked | BG-011、设备 | — |
| BG-031 | 补全 `build.sh` / `deploy.sh` / `verify.sh` 真实实现 | todo | BG-030、BG-032 | — |
| BG-032 | 决定编译链落点（macOS+theos / Linux 补 SDK / 越狱机上编） | todo | — | 见「阻塞项 3」 |
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
| 编译链 | 未确定，见 BG-032 | 待办 |

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
3. **编译链落点（BG-032）** —— 三选一：macOS + theos / 本机装 theos + iOS SDK + `ldid` /
   直接在越狱机上用 Procursus 工具链编译。**尚未决策**。
4. **主机 frida** —— R1 决定「都先不装」，因此 BG-011 即便设备与授权就位也还缺执行工具
   （安装路径见 [`docs/device-setup.md`](device-setup.md) 第 2 节）。

## 下一轮（R3）候选

真机线（BG-011/012/013/030/031/040）在没有授权、设备与 frida 的情况下无法推进，
因此 R3 的候选都落在**主机侧可完成**的工作上：

1. **[BG-032] 编译链落点决策** —— 需要用户三选一，之后 BG-031 才可动。
2. **[BG-022] 授权闸实现** —— `BGGhostValidateAuthorization()` 读取 `config/targets.json`，
   校验 6 个授权字段非 `fill_me`、`scope.bundle_ids` 非空，并给出明确拒绝原因（对应 T9）。
3. **[BG-022] 日志落盘** —— 按 `bssid_map.json` 的 `log.path` 写文件，带轮转与大小上限。
4. **扩展 L1 覆盖** —— 为「配置 JSON → BGRuleSet」的解析路径补主机侧测试。
   当前 `BGGhostMap.m` 依赖 Foundation、在 Linux 上无法编译；需先决策：条件编译，
   还是把 JSON 读取也做成可注入的纯 C 接口（推荐后者，`BGGhostRuleSetAdd` 已经是纯 C 的注入点）。
5. **范围收窄评估** —— 若目标 App 只走 nehelper XPC（待 BG-011 结论），
   则 Hook 点应从 ObjC 方法改为 XPC 边界，`BGGhostCoreWLAN.m` / `BGGhostHotspot.m` 需要重构。

## 轮次记录

> 最新轮次在最前。

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
