# 测试矩阵

> **平台切分（R12 起，见 [ADR-0001](../docs/adr/0001-pivot-to-android.md)）**：
> 本文的 T1–T10 矩阵与 [`evidence/`](evidence/) 的证据规范是**跨端**的；
> 具体测试实现按平台放在 `ios/tests/`（**当前主线**）与 `android/tests/`（随 Android 冻结，待解冻）。
> 下表中的路径指向 iOS 侧实现——**它们是当前主线，且必须保持全绿**。

## 验证目标

确认 Hook 生效，且**只**改变了 BSSID 返回值 —— 不影响真实网络连接。

## 目录

| 路径 | 层级 | 说明 |
|---|---|---|
| [`host/check-config-contract.sh`](../ios/tests/host/check-config-contract.sh) | **L0**（主机） | 校验 `shared/config/*.json` 与 `ios/hooks/*.c` 的键名/类型/容量契约，以及过滤器 plist 与 `bundle_ids` 是否一致 |
| [`host/check-scripts.sh`](../ios/tests/host/check-scripts.sh) | **L0**（主机） | 用 `--dry-run` 正向验证三个脚本的命令拼装；反向验证授权闸与 `<team>` 占位符会拦住执行 |
| [`host/check-objc-syntax.sh`](../ios/tests/host/check-objc-syntax.sh) | **L0**（主机） | 用 [`objc-stub/`](../ios/tests/objc-stub/) 的最小 Foundation 桩，对 `ios/hooks/*.m` 做 `clang -fsyntax-only`（含 ARC 与格式串检查）+ 头文件自包含检查 |
| [`host/gate-sim.sh`](../ios/tests/host/gate-sim.sh) | **L1**（主机） | 授权闸模拟器：把**真实配置**喂给**真实判定代码**（`BGGhostAuth.c`），回答「某个 BundleID 上 Hook 会启用还是拒绝」；`--self-test` 含 5 组反向用例 |
| [`host/map-sim.sh`](../ios/tests/host/map-sim.sh) | **L1**（主机） | BSSID 映射模拟器：把**真实映射表**喂给**真实映射代码**（`BGGhostRules.c`），回答「给定 (SSID, 真实 BSSID)，App 会读到什么」；`--self-test` 含 8 组断言 |
| [`host/`](../ios/tests/host/) 的单测 | **L1**（主机，不依赖真机） | `run.sh` 编译并运行 `BGGhostRules.c` 与 `BGGhostAuth.c` 的纯 C 单测 |
| [`frida/`](../ios/tests/frida/) | **L2**（真机只读抓栈） | `capture-wifi-api.js` + 用法（App 与 nehelper 两步 attach），落实 BG-011 |
| [`evidence/`](evidence/) | 证据 | 原始输出与结论摘要的命名/模板/纪律 |

```sh
# L0 + L1：本机即可跑（推荐入口；也是换机器后的第一条命令）
bash scripts/bootstrap.sh      # 环境自检 + 全套检查 + 下一步提示
ios/tests/host/run.sh              # 只跑检查，不打印环境报告

# 单项运行
ios/tests/host/check-config-contract.sh
ios/tests/host/check-scripts.sh
ios/tests/host/check-objc-syntax.sh
ios/tests/host/gate-sim.sh                 # 对配置里的第一个 BundleID 判定
ios/tests/host/gate-sim.sh --bundle com.x  # 指定 BundleID
ios/tests/host/map-sim.sh                                  # 按配置里的规则自动生成查询
ios/tests/host/map-sim.sh --ssid Office_WiFi --bssid AA:BB:CC:DD:EE:FF
```

## 用例矩阵

| # | 用例 | 操作 | 期望结果 | 覆盖情况 |
|---|---|---|---|---|
| T1 | Hook 加载 | 启动目标 App，查日志 | 出现 `[BSSIDGhost] 启用` | 待测（需真机，BG-030） |
| T2 | BSSID 替换 | App 内查看 Wi-Fi 信息 | 读到 `11:22:33:44:55:66` | 待测（需真机） |
| T3 | SSID 不变 | 同上 | 仍为 `Office_WiFi` | 待测（需真机） |
| T4 | 真实链路 | 断开/重连、访问网络 | 网络功能完全正常 | 待测（需真机） |
| T5 | 格式一致 | 对比伪造值与真实值格式 | 大小写、分隔符一致 | ✅ L1（`[格式一致性]` 段） |
| T6 | 多次调用 | 反复触发读取（前台/后台切换） | 每次返回均为伪造值 | 待测（需真机） |
| T7 | 无规则透传 | 切到未配置的网络 | 返回真实 BSSID，行为不变 | ✅ L1（`[T7 透传]` 段） |
| T8 | 作用域 | 在非目标 App 中检查 | Hook 不生效 | ✅ 判定逻辑由 L1 覆盖（含 gate-sim），端到端待真机 |
| T9 | 授权闸 | 清空 targets.json 授权字段 | Hook 拒绝启用并记录原因 | ✅ 判定逻辑由 L1 覆盖（含 gate-sim 真实配置端到端），端到端待真机 |
| T10 | 交叉校验 | 观察 App 是否有异常上报 | 无风控拦截 / 无异常提示 | 待测（需真机） |

> T5 / T7 / T8 / T9 的**判定逻辑**已在 L1 由 106 条断言覆盖（56 条映射单测 + 36 条授权闸单测
> + 6 条 gate-sim + 8 条 map-sim，后两者是「真实配置取值 + 真实代码」的端到端），
> 另有 L0 检查（脚本自检 17 + ObjC 语法与头文件自包含 18，另加配置契约检查的逐项校验）。
> 真机侧仍需按上表复核「端到端」行为
> （尤其是日志落盘与真实 nil 返回值），两者不可互相替代。

## 关键对照组

- **真实设备实测值**：设置 → 无线局域网 → 当前网络详情，记录真实 BSSID。
- **Hook 后 App 读取值**：通过 Frida 或 App 界面读取。
- **接口 MAC**：`ios/tests/frida/capture-wifi-api.js` 的 `interface-macs` 事件给出 en0 MAC，
  用于证明它与 AP 的 BSSID 不是同一个值。
- 三者必须符合配置映射，且 T3 的 SSID 两侧一致。

## 反面用例（必须验证）

- **伪造值格式错误**（小写/换分隔符）→ App 应无法识别或直接失败，用于确认 App 是否做格式校验。
  L1 已断言「输出格式跟随入参」，真机侧需用格式异常值验证 App 的反应。
- **只 Hook 单通道** → 若 App 同时调用多个接口，观察是否触发不一致告警（对应 tech-chain.md 第 6 节）。
  先用 `ios/tests/frida/capture-wifi-api.js` 确认实际通道数量，再设计该用例。
- **nil 场景** → 在无定位权限 / 无 entitlement 的情况下，真实值为 nil 时不得凭空构造 BSSID
  （L1 已断言，真机需复验系统是否真的返回 nil）。

## 记录要求

每次测试记录：设备型号、iOS 版本、越狱类型、目标 App 版本、真实 BSSID、伪造 BSSID、
主机 frida 与设备 frida-server 版本。模板与命名规则见 [`evidence/README.md`](evidence/README.md)。
