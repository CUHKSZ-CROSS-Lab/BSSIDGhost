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
| R6 | 待定：**BG-032 编译链落点仍需你决策**；之后才是真 SDK 编译与链接验证 | ⏳ 计划中 |

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
| BG-032 | 决定编译链落点（macOS+theos / Linux 补 SDK / 越狱机上编） | **todo（需用户决策）** | — | 见「阻塞项 3」 |
| BG-033 | theos 打包骨架（Makefile / control / layout 过滤器） | **done** | — | [`Makefile`](../Makefile)、[`control`](../control)、[`layout/…/BSSIDGhost.plist`](../layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist) |
| BG-034 | 脚本自检（正向 dry-run + 反向授权闸/占位符） | **done** | — | [`tests/host/check-scripts.sh`](../tests/host/check-scripts.sh)（17/17 通过） |
| BG-035 | ObjC 层编译期检查（最小 Foundation 桩 + `-fsyntax-only`） | **done** | — | [`tests/objc-stub/`](../tests/objc-stub/)、[`tests/host/check-objc-syntax.sh`](../tests/host/check-objc-syntax.sh)（17/17，含 5 条反向用例） |
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

## 下一轮（R6）候选

R5 让 ObjC 层第一次过了编译器（语法层面）。剩下的**只有真 SDK 才能做的**部分，以及一项决策：

1. **[BG-032] 编译链落点决策（必须你定）** —— 三选一。这是**唯一卡住整个项目**的事项：
   没有它就没有链接验证、没有产物、没有真机。
2. **[BG-031] 真 SDK 编译 + 链接验证** —— 依赖 1。到那时才会暴露：缺 `-framework`、
   私有 API 可用性、`install_name`、arm64e 切片等问题。
3. **把 JSON → 结构体的解析纳入 L1** —— 目前只有 L0 键名契约与语法检查，解析行为仍靠人工复核。
4. **`--respring` / 日志抓取的真机验证** —— 需要设备。
5. **范围收窄评估** —— 若 BG-011 结论是「只走 nehelper XPC」，Hook 点需改为 XPC 边界。

## 轮次记录

> 最新轮次在最前。

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
