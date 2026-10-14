# shared — 平台中立层

> 这一层的东西**不属于 iOS，也不属于 Android**。两端都必须满足同一份规格。

## 内容

| 路径 | 作用 |
|---|---|
| `config/targets.json` | 目标 App 作用域 + **测试授权登记**（授权闸的输入）。两端共用同一套字段与语义 |
| `config/bssid_map.json` | BSSID 映射表（真实值 → 伪造值）+ 日志设置 |
| `vectors/` | **语言中立测试向量**（R13 已落地，110 条断言）：C 核心与 Java 核心必须跑同一份向量 |

## 为什么要有这一层

本次从 iOS 转向 Android（[ADR-0001](../docs/adr/0001-pivot-to-android.md)）暴露了一件事：
项目真正值钱的不是某端的实现，而是两样东西——

1. **行为规格**：映射的归一化 / 格式跟随 / 规则匹配 / nil 语义；授权闸的判定顺序与短路规则；
2. **可执行的验证**：现有 92 条主机断言就是这套规格的可执行表述。

iOS 端的实现是纯 C（`ios/hooks/BGGhostRules.c`、`ios/hooks/BGGhostAuth.c`），
Android 端将用 Java 重写（R14）。**两份实现必须由同一份测试向量约束**，
否则两端行为会随时间漂移，92 条断言建立的保护就失效了。

## 跨端差异的处理（R13 已落地）

`bssid_map.json` 的日志路径**按平台取值**：

```json
"log": {
  "enabled": true,
  "paths": {
    "ios": "/var/mobile/Library/Logs/BSSIDGhost/ghost.log",
    "android": null
  },
  "max_bytes": 1048576
}
```

| 平台 | 取值 | 说明 |
|---|---|---|
| iOS | `paths.ios` | 越狱机上的绝对路径，`ios/hooks/BGGhostConfig.m` 只读这一项 |
| Android | `paths.android` | **允许为 `null`**：Android 主通道是 **logcat**（tag `BSSIDGhost`），文件日志为可选，路径留待 R14 与 Java 日志实现一起定 |

**不写猜测的路径占位**——Android 的文件落盘位置取决于运行期拿到的应用私有目录，
写一个未经真机验证的绝对路径进配置，比留空更危险。

契约检查（`ios/tests/host/check-config-contract.sh`）强制：

- `paths.ios` 必须存在且为绝对路径；
- `paths.android` 允许缺失/`null`，但一旦给出就必须是绝对路径；
- **旧键 `log.path` 必须不存在**——两份并存会让解析方静默走错分支。

## 纪律

- **授权字段不代填**：`config/targets.json` 的 6 个授权字段保持 `fill_me`，
  直到用户给出具体值。未填齐时，两端的构建与启用都必须拒绝。
- 改动 `config/*.json` 的键名/取值，必须同时通过
  `ios/tests/host/check-config-contract.sh` 的契约检查（它交叉校验 JSON ↔ C 侧字段表）。
