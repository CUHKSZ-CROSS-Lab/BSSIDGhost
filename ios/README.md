# ios — iOS 实现（**已冻结**）

> ⚠️ **这一层不是当前主线。** 项目已在 R12 转向 Android，
> 原因与两版关系见 [`docs/adr/0001-pivot-to-android.md`](../docs/adr/0001-pivot-to-android.md)。

## 状态：frozen（冻结）

- **冻结点**：git tag **`ios-r11-host-verified`**
- 冻结时状态：主机侧 **141 项断言全部通过**（L0 配置契约 / 脚本自检 17 / ObjC 语法 18 /
  授权闸模拟器 6 / 映射模拟器 8 / 纯 C 单测 56+36）
- 冻结含义：**保留、可回看、可复现，但不再投入开发**
- 冻结原因（一句话）：iOS 路线被**设备可得性**卡死——必须先有一台能越狱的特定机型，
  而用户手上的 iPhone 12（A14 / iOS 26）既不支持越狱、也无法降级

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
