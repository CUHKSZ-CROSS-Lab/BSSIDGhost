# ios — iOS 实现（**当前主线**）

> ## ▶️ 已解冻（R14，2026-10-14）
>
> 本项目在 R12 曾转向 Android 并把这一层冻结；R14 用户决定采购 **iPhone 8（A11）**，
> 核实后确认 iOS 路线**可行且成本更低**，主线切回 iOS。
> 原因（含**被推翻的旧结论**：palera1n「arm64e 排除」其实不含 A11）见
> [`docs/adr/0002-return-to-ios.md`](../docs/adr/0002-return-to-ios.md)。
>
> **Android 现在是暂停冻结的一方**：[`android/README.md`](../android/README.md)。

## 状态：**主线（active）** —— 曾于 R12–R13 短暂冻结

- **冻结点存档**：git tag **`ios-r11-host-verified`**（可回看当时状态）
- 冻结时的断言快照：**141 项全通过**；R13 后该套件已扩到 **251 项**并保持全绿
  （配置契约 / 脚本自检 17 / ObjC 语法 18 / 授权闸模拟器 6 / 映射模拟器 8 /
  语言中立向量 110 / 纯 C 单测 56+36）
- 当时冻结的原因（一句话）：iOS 路线被**设备可得性**卡死——用户手上的
  iPhone 12（A14 / iOS 26）既不支持越狱、也无法降级。
  **R14 换成 iPhone 8（A11）后这个前提不再成立。**
- **当前目标设备**：iPhone 8 + **Dopamine**（rootless，前缀 `/var/jb`）
  —— 与本节所有假设一致，**iOS 侧代码一行都不用改**。
  采购与越狱规格见 [`docs/ios/device-spec.md`](../docs/ios/device-spec.md)。

**没有任何 iOS 代码被删除。** 想回到冻结点的完整状态：

```sh
git switch --detach ios-r11-host-verified    # 只读查看
# 或
git switch -c recover-ios ios-r11-host-verified
```

## 目录

| 路径 | 说明 |
|---|---|
| `hooks/` | 实现层。其中 `BGGhostRules.c` / `BGGhostAuth.c` 是**纯 C 核心**（平台中立的规格载体）；`.m` 是 ObjC 胶水与 Hook 注册 |
| `layout/` | theos 安装布局（rootless 映射到 `/var/jb`），含 Substrate/ElleKit 过滤器 |
| `Makefile`、`control` | theos 打包（`BSSIDGhost.dylib` / deb 元信息） |
| `scripts/` | `build.sh` / `deploy.sh` / `verify.sh` + `lib/common.sh`（均先过授权闸） |
| `tests/host/` | 主机侧检查与单测（不需要设备，macOS/Linux 均可跑） |
| `tests/objc-stub/` | 给 `.m` 做 `-fsyntax-only` 的最小 Foundation 声明桩 |
| `tests/frida/` | 真机只读抓栈脚本（**从未在设备上实跑过**） |

iOS 专属文档在 [`docs/ios/`](../docs/ios/)。

## 冻结后仍可用的部分

`ios/tests/host/run.sh` **仍然可以跑，并且仍然全绿**——它是 `shared/` 规格层的参照实现，
Android 端的 Java 核心将以它和 `shared/vectors/` 为对照真值。改 `shared/config/*.json`
之后请仍然跑一次它，确认契约没被破坏：

```sh
bash ios/tests/host/run.sh
```
