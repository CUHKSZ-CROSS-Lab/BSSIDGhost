# 命名规范

## 项目标识

| 用途 | 名称 | 备注 |
|---|---|---|
| 项目名 | `BSSIDGhost` | 对外中文名：**幻影 BSSID** |
| 仓库名 | `BSSIDGhost` | 与项目名一致 |
| 注入库（手工注入） | `libbssidghost.dylib` | 全小写，符合 dylib 惯例；由 `build.sh --toolchain clang` 产出 |
| 注入库（theos/deb） | `BSSIDGhost.dylib` | **theos 约定**：产物名 = `TWEAK_NAME`，无法加 `lib` 前缀，见下 |
| 过滤器 | `BSSIDGhost.plist` | 与 theos 产物同名，由 `build.sh` 按 `scope.bundle_ids` 生成 |
| BundleID | `com.<team>.bssidghost` | 替换 `<team>` 为实际团队标识；`control` 中留有 `<team>` 占位符，未替换时打包会被拒绝 |
| deb 包名 | `com.<team>.bssidghost` | theos 打包用 |

> ⚠️ **待你确认的命名细节**：theos 的产物名固定是 `<TWEAK_NAME>.dylib`，不带 `lib` 前缀，
> 因此 deb 路线无法产出 `libbssidghost.dylib`。当前处理是**两条路线两个名字**：
> clang 手工注入用 `libbssidghost.dylib`，theos/deb 用 `BSSIDGhost.dylib` + `BSSIDGhost.plist`。
> 若你希望统一，可选：(a) 保持现状；(b) 把 `TWEAK_NAME` 改成 `libbssidghost`
> （文件名统一为 `libbssidghost.dylib`/`.plist`，但与 `BG` 代码前缀不一致）；
> (c) 放弃 deb 路线只用 clang。此项涉及 HANDOFF §2 的既有决策，**未擅自改动**。

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
