# BSSIDGhost

> Ghost BSSID · 在**已 root / 已越狱的移动设备**上 Hook 篡改 Wi-Fi 信息接口，伪造目标 App **读取到的** BSSID 返回值，使 App 误认为当前接入的是另一个 AP。

**当前主线OS平台：iOS**（Android 分支已暂停冻结，见
[ADR-0002](./docs/adr/0002-return-to-ios.md)）。

| | |
|---|---|
| 测试机 | **iPhone 8 或 Plus（A11）**；**iOS ≤16.6.1**  |
| 越狱工具 | **Dopamine**（rootless，`/var/jb`，semi-untethered） |
| 注入运行时 | **ElleKit**（Dopamine/palera1n 都基于且兼容旧 `MSHook*` 写法） |
| 编译链 | 越狱设备上就地编译（Procursus 工具链） |

## 快速开始

```sh
# 环境自检 + 主机检查（251 项断言）+ 文档链接检查
bash scripts/bootstrap.sh
```

- **项目握手与交接**：[`RESUME.md`](./RESUME.md)
- **交接备忘（已定决策 / 风险 / 未决事项）**：[`HANDOFF.md`](./HANDOFF.md)
- **进度真源**：[`docs/STATUS.md`](./docs/STATUS.md)
- **决策留档**：[`docs/adr/`](./docs/adr/)（含「为什么转向 Android」**与**「为什么切回 iOS」）
- **iPhone 8 采购事项清单**：[`docs/ios/purchase-checklist.md`](./docs/ios/purchase-checklist.md)
- **iPhone 8 采购规格与验机命令**：[`docs/ios/device-spec.md`](./docs/ios/device-spec.md)
- **iOS 技术链路与 Hook 点**：[`docs/ios/tech-chain.md`](./docs/ios/tech-chain.md)

## 项目边界

项目要解决的是**返回值的伪装**，不是网络连接的切换：

| 项目 | 是否被改动 |
|---|---|
| 设备实际连接的 AP、物理链路、流量走向 | **否**，完全不变 |
| App 通过系统接口读到的 BSSID 字符串 | **是**，被替换 |
| SSID | **否**，按需求刻意保持不变 |

> SSID 保持原值，意味着目标是构造「同一 SSID 下的不同接入点」这一场景
> （例如多 AP 漫游、按 AP 维度做设备判定的业务逻辑）。

## 用途与授权要求

本项目**仅供内部测试开发**，用于在受控环境下验证客户端对 Wi-Fi 网络身份的判断逻辑。使用前必须满足：

1. **对目标 App 有测试授权** —— 只在授权方自有、或已获得明确书面授权的 App 上使用。
2. **在受控设备与网络中进行** —— 使用专门的测试机与测试 AP，不针对生产环境或他人设备。
3. **遵守目标 App 的服务条款与当地法律** —— 对第三方 App 伪造环境指纹、规避风控属高风险行为，
   root / 越狱与代码注入本身也可能使设备失去保修或违反平台政策。

若用于绕过第三方 App 的安全校验、刷单、薅羊毛或多账号风控规避，**请立即停止使用本项目**。

## 目录结构（单仓双端）

```
BSSIDGhost/
├── README.md                 # 本文件
├── RESUME.md                 # 换机器 / 换会话的 5 分钟恢复指南
├── HANDOFF.md                # 交接备忘（定义 / 已定决策 / 风险 / 下一步）
├── docs/                     # 跨端文档
│   ├── STATUS.md             # 进度真源（任务板 BG-xxx + 轮次记录）
│   ├── android-device-spec.md # Android 测试机采购规格 + root 方案 + 验机命令（含来源与性质标注）
│   ├── naming.md             # 命名规范
│   ├── adr/                  # 决策留档（ADR-0001：转向 Android，双端单仓）
│   └── ios/                  # iOS 专属文档（冻结存档）
│       ├── tech-chain.md             # iOS 链路拆解与 Hook 点调研（§2.2 可证伪实验）
│       ├── device-setup.md           # iOS 真机准备与抓栈 SOP
│       ├── build-chain-options.md    # iOS 编译链落点（BG-032）决策留档
│       ├── ondevice-build-setup.md   # iOS 设备端编译环境搭建 SOP
│       └── handoff-device-jailbreak.md # iPhone 12/A14/iOS 26 可越狱性分析（路线作废的结论）
├── shared/                   # 【平台中立】两端共用
│   ├── config/
│   │   ├── bssid_map.json    # BSSID 映射表（真实值 → 伪造值）+ 日志设置
│   │   └── targets.json      # 目标 App 作用域与测试授权记录（授权闸的输入）
│   └── vectors/              # 语言中立测试向量（110 条断言：两端必须同结论）
├── android/                  # 【已暂停冻结】Android 实现（代码全保留，随时可解冻）
│   └── README.md             # 冻结说明 + 解冻后的路线图
├── ios/                      # 【当前主线】iOS 实现
│   ├── README.md             # 实现说明（曾冻结，R14 解冻）
│   ├── hooks/                # 纯 C 核心（Rules/Auth）+ ObjC 胶水 + Hook 注册
│   ├── layout/               # theos 安装布局（rootless → /var/jb）
│   ├── Makefile, control     # theos 打包与 deb 元信息
│   ├── scripts/              # build.sh / deploy.sh / verify.sh + lib/common.sh
│   └── tests/                # host 单测、objc-stub、frida 抓栈脚本
├── scripts/                  # 【跨端】bootstrap.sh / publish.sh / check-links.sh
└── tests/
    ├── README.md             # 测试矩阵 T1–T10 与校验方法（跨端）
    └── evidence/             # 证据命名、摘要模板与纪律
```

## 命名规范

| 用途 | 名称 |
|---|---|
| 项目 | BSSIDGhost |
| 仓库 | `BSSIDGhost` |
| 代码前缀 | `BG`（如 `BGGhostRules`） |
| Android 目标 App | `com.ss.android.xxxx` |
| iOS 目标 App（冻结） | `com.ss.iphone.ugc.xxxx`；注入库 `libbssidghost.dylib` / theos 产物 `BSSIDGhost.dylib` |

详见 [`docs/naming.md`](./docs/naming.md)。
