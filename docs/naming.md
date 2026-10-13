# 命名规范

## 项目标识

| 用途 | 名称 | 备注 |
|---|---|---|
| 项目名 | `BSSIDGhost` | 对外中文名：**幻影 BSSID** |
| 仓库名 | `BSSIDGhost` | 与项目名一致 |
| 注入库 | `libbssidghost.dylib` | 全小写，符合 dylib 惯例 |
| BundleID | `com.<team>.bssidghost` | 替换 `<team>` 为实际团队标识 |
| deb 包名 | `com.<team>.bssidghost` | theos 打包用 |

## 代码命名

| 类型 | 规则 | 示例 |
|---|---|---|
| 类前缀 | `BG` | `BGGhostCoreWLAN` |
| 文件名 | 前缀 + 模块 | `BGGhostHotspot.m` |
| 常量 | `kBG` + 驼峰 | `kBGGhostEnabled` |
| 配置键 | 小写下划线 | `fake_bssid` |

## 命名理由（备查）

- 选 `Ghost` 而非 `Fake` / `Spoof`：更中性、更像内部工具，
  在对外场合不易触发安全扫描与商店策略针对；同时在技术上精确 ——
  被替换的值是一个**只存在于返回值里的幽灵 AP**，真实链路并未改变。
- 保留 `BSSID` 而非简写成 `AP`：避免被误读成「伪造热点」。

## 备选名（未采用）

`WifiHand`（意象软）、`APMirage`（AP 易误读）、`ShadowBSSID`（偏平）、
`FakeBSSID`（太直白、对外不友好）、`幻影AP / MirageAP`（英文仓名仍需另取）。
