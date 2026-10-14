# ObjC 语法检查桩

本目录是给 **`ios/hooks/*.m` 做编译期检查**用的最小声明桩：本机（Linux）没有 iOS SDK、
也没有真实的 Foundation 头文件，于是用 `Foundation/Foundation.h` 与 `os/lock.h`
把 `ios/hooks/` 用到的那部分接口声明出来，让 `clang -fsyntax-only` 能真正编译这些源码。

运行入口：[`../host/check-objc-syntax.sh`](../host/check-objc-syntax.sh)（已串进 `ios/tests/host/run.sh`）。

> **两种模式，脚本自动二选一**：[`../host/check-objc-syntax.sh`](../host/check-objc-syntax.sh)
> 优先用**真 SDK**（`BGGHOST_IOS_SDK`，或 macOS 上的 `xcrun --sdk iphoneos`），
> 拿不到才退回本目录的桩，并**打印当前模式**。
> 两者**绝不能混用**：桩的 `-I` 若与真 SDK 同时生效会把真 `Foundation.h` 顶掉，
> 让「通过」变成假通过。脚本里有一条反向用例专门守这个
> （拿假 SDK 重跑必须失败）。强制桩模式：`BGGHOST_FORCE_STUB=1`。

> **安全属性**：桩目录**只**被检查脚本通过 `-I` 引入；`ios/scripts/build.sh` 的编译命令
> 只带 `-I hooks`，**永远不会**把桩带进真实构建 —— 否则会用假 Foundation 掩盖真错误。
> 新增检查项时请保持这一点。

## 能查出来的东西

| 类别 | 说明 |
|---|---|
| 语法 / 类型错误 | 编译不过就是编译不过 |
| 隐式函数声明 | C99+ 下未声明就调用会直接报错（`Hooks.h` 曾漏 `BGGhostLog` 声明，就是这类问题） |
| 未知选择器 / 未知类 | 例：`[str stringWithUTF8StringX:]` 会被 `-Werror` 拦下 |
| ARC 归属规则 | `-fobjc-arc` 下的 retain/release 违规、非拥有指针写法 |
| **格式串与实参类型** | `NS_FORMAT_FUNCTION` 照真实 Foundation 定义，`BGGhostLog(@"%@", cString)` 会报错 |
| 头文件自包含 | 每个 `.h` 都会被单独包含编译一次，捕捉漏 import |

## **查不出来**的东西（必须靠真 SDK 编译，见 `docs/STATUS.md` 的 BG-031/BG-032）

- 方法在真实 iOS SDK 上**是否存在**、是否已弃用、可用性标注（`@available`）、私有 API 限制；
- **链接期**问题：缺 `-framework`、缺符号、`install_name`、架构切片；
- 任何**运行期**行为（真实 `nil` 语义、`NSJSONSerialization` 的实际返回类型等）；
- 桩与真头文件之间的**签名差异**：如果桩把某个方法写错了类型，检查结果可能被"骗过"。

> 因此这项检查的定位是：**把「编译期错误」提前暴露，降低 BG-032 决策后一次性撞墙的概率**，
> 而不是替代真机编译。桩里的签名照 Apple 文档书写，但仍有出错可能。

## 维护

`ios/hooks/` 用到新的 Foundation 接口时，在此补声明即可。原则：

1. 只声明，不实现 —— 需要实现就说明用法超出了语法检查的范围；
2. 签名照 Apple 文档写，别写"能过就行"的宽签名（会掩盖真实错误）；
3. `NS_FORMAT_FUNCTION` 等属性要与真实 Foundation 保持一致，否则会漏掉一整类检查；
4. 改动后跑 `ios/tests/host/run.sh`：**5 条反向用例**会验证检查器本身没有空转。
