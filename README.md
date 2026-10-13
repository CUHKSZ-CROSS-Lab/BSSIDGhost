# BSSIDGhost

> 幻影 BSSID · iOS 越狱场景下 Hook 篡改 Wi-Fi 信息接口，伪造目标 App 读取到的 BSSID 返回值

## 一句话定义

在 **已越狱的 iOS 设备** 上，通过运行时 Hook 拦截 App 读取 Wi-Fi 信息的系统接口，
**只替换其中的 BSSID 返回值**，使 App 误认为当前接入的是另一个 AP。

```
飞书 App
   │  ❶ 调用 iOS Wi-Fi 信息接口
   ▼
系统返回真实 Wi-Fi 信息        SSID: Office_WiFi   BSSID: AA:BB:CC:DD:EE:FF
   │  ❷ 被运行时拦截层截获
   ▼
运行时拦截层（Hook）
   │  ❸ 替换 BSSID 返回值
   ▼
伪造后的 Wi-Fi 信息           SSID: Office_WiFi   BSSID: 11:22:33:44:55:66
   │
   ▼
飞书接收到修改后的信息
```

原始链路图见 [`技术链路流程图.jpeg`](./技术链路流程图.jpeg)。

## 边界（非常重要，先读这段）

项目要解决的问题是**返回值的伪装**，不是网络连接的切换：

| 项目 | 是否被改动 |
|---|---|
| 设备实际连接的 AP、物理链路、流量走向 | **否**，完全不变 |
| App 通过系统接口读到的 BSSID 字符串 | **是**，被替换 |
| SSID | **否**，按需求刻意保持不变 |

因此本项目的准确描述是「Wi-Fi 信息接口返回值 Hook / BSSID 伪装（spoofing）」，
**不是**「修改 App 连接的 Wi-Fi」。

> 说明：SSID 保持原值，意味着目标是构造「同一 SSID 下的不同接入点」这一场景
> （例如多 AP 漫游、按 AP 维度做设备判定的业务逻辑）。

## 用途与授权要求

本项目是**内部测试工具**，用于在受控环境下验证客户端对 Wi-Fi 网络身份的判断逻辑。使用前必须满足：

1. **对目标 App 有测试授权** —— 只在你方自有、或已获得明确书面授权的 App 上使用。
2. **在受控设备与网络中进行** —— 使用专门的测试机与测试 AP，不针对生产环境或他人设备。
3. **遵守目标 App 的服务条款与当地法律** —— 对第三方 App 伪造环境指纹、规避风控属高风险行为，
   越狱与代码注入本身也可能使设备失去保修或违反平台政策。

若用于绕过第三方 App 的安全校验、刷单、薅羊毛或多账号风控规避，**请立即停止使用本项目**。

## 目录结构

```
BSSIDGhost/
├── README.md                 # 本文件
├── HANDOFF.md                # 交接备忘（定义 / 已定决策 / 风险 / 下一步）
├── Makefile                  # theos 打包（rootless / Dopamine）
├── control                   # deb 元信息（含 <team> 占位符，未替换则拒绝打包）
├── .gitignore
├── docs/
│   ├── STATUS.md             # 进度真源（任务板 BG-xxx + 轮次记录）
│   ├── tech-chain.md         # 技术链路拆解与 Hook 点调研
│   ├── device-setup.md       # 真机准备与抓栈 SOP（B 线）
│   └── naming.md             # 命名规范
├── config/
│   ├── bssid_map.json        # BSSID 映射表（真实值 → 伪造值）+ 日志设置
│   └── targets.json          # 目标 App 作用域与测试授权记录（授权闸的输入）
├── hooks/
│   ├── Hooks.h               # Hook 入口声明 + 日志与授权判定声明
│   ├── Hooks.m               # 统一注册、授权闸、日志落盘与轮转
│   ├── BGGhostRules.h/.c     # BSSID 映射逻辑（纯 C，可在主机上单测）
│   ├── BGGhostAuth.h/.c      # 授权闸与作用域判定（纯 C，可在主机上单测）
│   ├── BGGhostConfig.h/.m    # 读 targets.json / bssid_map.json 的 log 段
│   ├── BGGhostMap.h/.m       # NSString 映射胶水
│   ├── BGGhostCoreWLAN.h/.m  # CoreWLAN / CWFInterface Hook（主通道）
│   └── BGGhostHotspot.h/.m   # NEHotspotNetwork / CNCopy* Hook（补充通道）
├── layout/                   # theos 安装布局（rootless 下映射到 /var/jb）
│   └── Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist   # 过滤器（构建时按 bundle_ids 重新生成）
├── scripts/
│   ├── lib/common.sh         # 三个脚本共用：授权闸、过滤器生成、--dry-run 执行
│   ├── build.sh              # 构建：theos 打包 / clang 交叉编译（均先过授权闸）
│   ├── deploy.sh             # 部署：deb 或 files 方式推送到越狱设备（rootless /var/jb）
│   └── verify.sh             # 验证：本地闸门状态 + 设备日志判定（只读）
└── tests/
    ├── README.md             # 测试矩阵与校验方法
    ├── host/                 # L0 契约/脚本/ObjC 语法检查 + L1 纯 C 单测（不依赖真机）
    ├── objc-stub/            # 给 hooks/*.m 做 -fsyntax-only 的最小 Foundation 声明桩
    ├── frida/                # L2：真机只读抓栈脚本与用法
    └── evidence/             # 证据命名、摘要模板与纪律
```

## 命名规范

| 用途 | 名称 |
|---|---|
| 项目 | BSSIDGhost（中文：幻影 BSSID） |
| 仓库 | `BSSIDGhost` |
| 注入库 | `libbssidghost.dylib` |
| BundleID | `com.<team>.bssidghost` |
| 代码前缀 | `BG`（如 `BGGhostCoreWLAN`） |

详见 [`docs/naming.md`](./docs/naming.md)。

## 当前状态

骨架阶段：目录与配置模板就绪，Hook 实现为占位。

- **进度真源**：[`docs/STATUS.md`](./docs/STATUS.md)（任务板 `BG-xxx` + 轮次记录 + 环境事实 + 阻塞项）
- **交接备忘**：[`HANDOFF.md`](./HANDOFF.md)（项目定义、已定决策、风险、下一步）
- **技术链路与 Hook 点**：[`docs/tech-chain.md`](./docs/tech-chain.md)
- 已确认测试机形态：Dopamine / rootless，iOS 15.0–16.6.x，路径前缀 `/var/jb`

> 真机相关工作仍被**授权闸**阻塞：`config/targets.json` 的授权字段未填齐前，
> build / deploy / Hook 一律拒绝执行。
