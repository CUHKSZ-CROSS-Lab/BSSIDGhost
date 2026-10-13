# 项目状态（单一进度真源）

> **规则**：所有进行中的工作都必须有 `BG-` 编号；每轮结束更新本文件 **与** [`HANDOFF.md`](../HANDOFF.md)。
> 状态取值：`todo` / `doing` / `blocked` / `done`。证据一律写仓库内相对路径。

## 当前轮次

| 轮次 | 主题 | 状态 |
|---|---|---|
| R1 | 工程化与流程最小集（决策 A 的先做部分） | ✅ 完成 |
| R2 | B 线（真机抓链路方案）与 C 线（映射逻辑 + 主机侧单测）并行 | ✅ 完成（真机执行仍阻塞） |
| R3 | 授权闸与日志落盘（BG-022）+ L0 配置契约检查 | ✅ 完成 |
| R4 | 待定：编译链落点（BG-032，需用户决策）→ 之后解锁 BG-031 | ⏳ 计划中 |

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

## 下一轮（R4）候选

真机线（BG-011/012/013/030/031/040）仍被授权、设备与 frida 三重阻塞。
R3 已把主机侧「策略层」做完，R4 的可选项：

1. **[BG-032] 编译链落点决策** —— 需要用户三选一，之后 BG-031 才能动。
   这是**当前唯一会卡住整个项目**的事项。
2. **[BG-031] 三个脚本的真实实现** —— 依赖 BG-032；可先把 `build.sh` 的 clang / theos
   两条路径写成可切换的形式，决策前先做骨架。
3. **ObjC 层的编译验证（风险最高）** —— `hooks/*.m` 至今**没有经过任何编译器**
   （本机无 Foundation / iOS SDK）。可选：装 theos + iOS SDK 后 `clang -fsyntax-only`，
   或写一层最小 Foundation 桩在 Linux 上做语法检查。
4. **把 JSON → 结构体的解析纳入 L1** —— 目前只有「键名/容量/格式」的 L0 契约检查，
   解析行为本身仍靠人工复核。可选：给 `BGGhostConfig.m` 抽一个可注入的纯 C 接口
   （`BGGhostAuthConfigSetField` 已是现成注入点），或引入极小的 JSON 子集解析器。
5. **范围收窄评估** —— 若 BG-011 结论是「目标 App 只走 nehelper XPC」，
   则 Hook 点要从 ObjC 方法改为 XPC 边界，`BGGhostCoreWLAN.m` / `BGGhostHotspot.m` 需要重构。

## 轮次记录

> 最新轮次在最前。

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
