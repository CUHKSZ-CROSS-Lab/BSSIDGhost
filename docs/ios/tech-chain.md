# 技术链路拆解与 Hook 点调研

## 1. 链路拆解

链路拆解为六个环节（原 `技术链路流程图.jpeg` 已从仓库移除，
需要时从历史取回：`git show b9f00cd:技术链路流程图.jpeg`）：

| # | 环节 | 实现关注点 |
|---|---|---|
| 1 | App 调用 Wi-Fi 信息接口 | 确定目标 App 到底走哪个接口（公开 / 私有） |
| 2 | 系统返回真实信息 | 拿到真实 BSSID 的调用栈与返回形态（NSString / NSData / 结构体） |
| 3 | 运行时拦截层 | 越狱环境下的注入方式与 Hook 框架选型 |
| 4 | 替换 BSSID 返回值 | 只改 BSSID，保留 SSID 与其他字段 |
| 5 | 返回伪造信息 | 处理多次调用、缓存、异步回调 |
| 6 | App 接收到伪造信息 | 验证生效，并排查交叉校验通道 |

## 2. 候选接口（按优先级）

> 待办：用 Frida / lldb 在真机抓调用栈，确认飞书实际命中的是哪一个。
> 以下为按经验排序的候选，**尚未验证**。

| 优先级 | 接口 | 类型 | 说明 |
|---|---|---|---|
| P0 | `com.apple.nehelper` XPC 应答（`delegate-class-id=10` → `result-data` 字典的 `BSSID`/`SSIDDATA`） | 私有 XPC | **R1 新增**。很可能是 SSID/BSSID 的**统一后端**；堵住这里可一次覆盖所有 App 侧消费者 |
| P0 | `CoreWLAN` → `CWFInterface.currentInterface` 的 `bssid` / `-interfaceState` | 私有框架 | 读取 BSSID 最常见的私有通道 |
| P0 | `CoreWLAN` → `CWInterface.bssid` | 私有框架 | 旧版 API，仍可能被调用 |
| P1 | `NetworkExtension` → `NEHotspotNetwork`（`SSID` / `BSSID`） | 公开 | 需定位权限，值可能被裁剪 |
| P1 | `SystemConfiguration` → `CNCopyCurrentNetworkInfo` | 公开（已废弃） | 返回字典内含 `BSSID` 键 |
| P2 | `CWFNetworkProfile` / `CWWiFiClient` | 私有框架 | macOS 侧常见，iOS 视版本而定 |
| P2 | `getifaddrs` / `SIOCGIFHWADDR` | POSIX | 拿到的是接口 MAC，不是 AP BSSID，需区分 |

**关键区分**：设备接口 MAC（`en0`）≠ AP 的 BSSID。若 App 用前者做判断，
Hook 点完全不同，不要混淆。

### 2.1 R1 调研增量：nehelper 统一后端（⚠️ 外部资料，待真机验证）

来源：[illusionofchaos/ios-nehelper-wifi-info-0day](https://github.com/illusionofchaos/ios-nehelper-wifi-info-0day)
（iOS 15.0 0day）。要点：

```
XPC 服务: com.apple.nehelper
请求字段: delegate-class-id=10, interface-name=en0, (sdk-version)
应答:     result-data → { SSID, BSSID, SSIDDATA }
权限闸:   -[NEHelperWiFiInfoManager checkIfEntitled:]   (/usr/libexec/nehelper)
          需要 entitlement com.apple.developer.networking.wifi-info
```

对 Hook 点选择的三点影响：

1. **P1 的两条很可能不是独立通道** —— `CNCopyCurrentNetworkInfo` 与
   `NEHotspotNetwork.fetchCurrent` 都可能汇入 nehelper。真正独立的另一条是
   **XPC 应答边界 / App 侧解析**；只改 `CWFInterface` 而漏掉 nehelper，
   差异会被 App 侧比对直接看到（对应第 6 节交叉校验）。
2. **nil 语义** —— 无 entitlement / 定位权限时系统返回 nil 或裁剪值。
   替换逻辑必须尊重 nil：**真值为 nil 时不得凭空构造 BSSID**。
3. **需真机确认版本差异** —— `sdk-version` 阈值、字段名、是否已被后续 iOS 收紧，
   必须在目标版本（iOS 15.0–16.6.x，rootless）上用 Frida 实测（BG-011）。

### 2.2 可证伪实验设计：nehelper 到底是不是统一后端（BG-011 的执行脚本）

§2.1 是**外部资料**。为避免"抓一次栈、看到什么都往结论上套"，先把假设与判别标准写死。

**假设 H1**：目标 App 读到的 SSID/BSSID 来自 `com.apple.nehelper` 的 XPC 应答，
因此 `CNCopyCurrentNetworkInfo` 与 `NEHotspotNetwork.fetchCurrent` 不是独立通道。

**若 H1 成立，抓栈输出里应当同时出现**（事件名对应
[`ios/tests/frida/capture-wifi-api.js`../../ios/tests/frida/capture-wifi-api.js 的输出）：

| 期望事件 | 说明 |
|---|---|
| `{"src":"xpc","kind":"request-set","key":"interface-name","value":"en0"}` | 有人在构造 nehelper 请求 |
| `{"src":"xpc","kind":"request-set","key":"delegate-class-id"}` | 且用的是 wifi-info 的 delegate class |
| `{"src":"xpc","kind":"reply-result-data","reply":{"ssid":…,"bssid":…}}` | 有人解析了 `result-data` 拿到 BSSID |

**判别表（观测 → 结论 → Hook 落点）**

| 观测 | 结论 | 落点选择 |
|---|---|---|
| 只有 `src:"objc"`（`CWFInterface -bssid`），无 `src:"xpc"` | App 走私有 CoreWLAN 通道，**H1 在本 App 上不成立** | Hook `CWFInterface`；nehelper 可忽略 |
| 只有 `src:"xpc"`（`reply-result-data`） | 直接走 nehelper | Hook XPC 应答边界；只 Hook ObjC 方法无效 |
| 两者都有、**值不同** | 交叉校验风险高（§6） | 必须同时覆盖且保证一致 |
| 两者都有、**值相同** | objc 通道内部可能也经 nehelper | 优先堵 XPC（一次覆盖所有消费者） |

**证伪条件（写下来，避免事后合理化）**：若整个冷启动 + 多次读取过程中
**一次 `src:"xpc"` 事件都没出现**，而 App 确实读到了 BSSID，
则 H1 在该 App + 该 iOS 版本上被证伪 —— 此时 §2.1 必须改写，而不是硬套。

**执行步骤（两步 attach，缺一不可）**

```sh
# 第 1 步：App 进程 —— 看它调用哪些通道、返回值形态与调用栈
frida -U -f com.ss.iphone.ugc.Lark -l ios/tests/frida/capture-wifi-api.js \
      -o tests/evidence/$(date +%Y%m%d-%H%M%S)-capture.jsonl

# 第 2 步：nehelper 进程 —— 看 entitlement 闸与应答构造
#   （NEHelperWiFiInfoManager 在 /usr/libexec/nehelper 里，不在 App 进程）
frida -U -n nehelper -l ios/tests/frida/capture-wifi-api.js \
      -o tests/evidence/$(date +%Y%m%d-%H%M%S)-nehelper.jsonl
```

第 2 步预期能看到 `{"src":"objc","kind":"method","cls":"NEHelperWiFiInfoManager","sel":"- checkIfEntitled:"}`
以及应答字典的构造（`xpc_dictionary_set_string` 的 `SSID`/`BSSID`/`result-data` 键）。

**记录要求**：原始 JSONL 与结论摘要按 [`tests/evidence/README.md`](../../tests/evidence/README.md)
入库；结论回写第 2 节表格，并明确区分「实测」与「外部资料」。
**在拿到真机输出之前，§2.1 的一切都只能写「待真机验证」。**

## 3. 返回形态与替换策略

| 返回形态 | 替换难度 | 备注 |
|---|---|---|
| `NSString`（`AA:BB:CC:DD:EE:FF`） | 低 | 直接替换字符串，注意大小写与分隔符格式 |
| `NSData`（6 字节） | 中 | 需构造等长字节串 |
| C 结构体 / 出参指针 | 高 | 需保证内存生命周期，避免悬垂指针 |

格式一致性是常见坑：App 可能做 `AA-BB-CC-...`、小写、或去分隔符比较，
替换值格式必须与真实返回完全一致。

## 4. Hook 框架选型

| 方案 | 适用 | 取舍 |
|---|---|---|
| `fishhook` | C 函数（`CNCopyCurrentNetworkInfo` 等） | 轻量，只能 Hook 符号表里的 C 函数 |
| `MSHookMessageEx` / `theos` `%hook` | Objective-C 方法 | 生态成熟，需 theos 工具链 |
| `Frida` | 调研与动态验证 | 最适合前期抓调用栈，生产注入不一定用 |
| `ElleKit` / `Substrate` | 越狱注入运行时 | 取决于越狱类型（rootful / rootless / 无根） |

> **已确认（R1）**：目标测试机为 **Dopamine / rootless，iOS 15.0–16.6.x**，
> 注入路径前缀 `/var/jb`（dylib 落地 `/var/jb/usr/lib`，越狱插件目录
> `/var/jb/Library/MobileSubstrate/DynamicLibraries`），运行时用 ElleKit。
> rootful 路径（`/usr/lib`、`/Library/MobileSubstrate/...`）在本项目**不适用**。

## 5. 待办清单

> 编号对应 [`STATUS.md`](../STATUS.md) 的任务板（单一进度真源）。

- [x] 确认目标测试机越狱类型与 iOS 版本 → **Dopamine / rootless，iOS 15.0–16.6.x**（BG-010）
- [ ] 用 Frida 抓取目标 App 读取 Wi-Fi 信息的真实调用栈（BG-011，阻塞：授权闸 + 设备）
- [ ] 按 §2.2 的可证伪实验验证 nehelper 是否为统一后端（第 1、2 步 attach 都要做）（新，随 BG-011）
- [ ] 确认返回形态与格式（字符串 / 字节 / 结构体）（BG-012）
- [ ] 确认是否存在交叉校验通道（见第 6 节）（BG-013）
- [ ] 选定 Hook 框架并跑通最小 PoC（BG-030）
- [ ] 建立测试矩阵（见 `tests/README.md`）（BG-040）

## 6. 交叉校验风险

单点 Hook 是理想链路。若目标 App 同时使用下列任一通道交叉比对，单点改写会被识破：

- 同时调用多个 Wi-Fi 接口，比对结果差异
- 上报公网出口 IP / 网关 MAC，与后端记录比对
- mDNS / Bonjour 探测、ARP 表读取
- 后端下发期望 BSSID 白名单

**结论**：落地前先枚举 App 的全部网络身份采集点，再决定需要覆盖几个 Hook 点。
