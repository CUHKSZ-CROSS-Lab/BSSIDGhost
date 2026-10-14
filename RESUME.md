# 快速恢复（RESUME）

> **换机器 / 换会话后的第一条入口。** 目标：5 分钟内回答「我现在能做什么、缺什么、下一步是什么」。
> 本文只做**索引与操作步骤**，进度真源始终是 [`docs/STATUS.md`](docs/STATUS.md)。

## 项目一句话

**BSSIDGhost（幻影 BSSID）**：在**已 root / 已越狱的移动设备**上 Hook Wi-Fi 信息接口，
**只替换 App 读取到的 BSSID 返回值**（SSID 与真实链路不变）。
准确表述是「返回值的伪装 / spoofing」，**不是**「切换 Wi-Fi 连接」。

> ⚠️ **平台现状**：**当前主线是 Android**；iOS 版已冻结（代码保留、不再投入）。
> 转向原因见 [`docs/adr/0001-pivot-to-android.md`](docs/adr/0001-pivot-to-android.md)。

## 1. 5 分钟恢复（三步）

```sh
# ① 取代码
git clone https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git
cd BSSIDGhost

# ② 一条命令：环境自检 + 主机检查（251 项断言）+ 文档链接检查，都不需要设备
bash scripts/bootstrap.sh

# ③ 按输出的「接下来做什么」执行；本文第 4 节是当前的关键路径
```

`bootstrap.sh` 会依次做：

1. **必需项检查**（`git` / `clang` / `jq`），缺失时按当前平台给出安装命令；
2. **可选项检查**（真机与打包工具、iOS SDK、`THEOS`、`lipo`）；
3. **跑 [`ios/tests/host/run.sh`](ios/tests/host/run.sh)** —— 251 项断言（含 110 条语言中立向量）；
4. **跑 [`scripts/check-links.sh`](scripts/check-links.sh)** —— 全仓库 Markdown 内部链接（210 条）。

健康的仓库应当输出：

```
✅ 必需工具齐全
✅ 主机检查通过（配置契约 / 脚本自检 / ObjC 语法 / 两个模拟器 / 纯 C 单测）
✅ 文档链接检查通过（无断链）
```

任一项红，先按提示装工具，再重跑。**缺工具也算交付物的一部分**：不要跳过这一步去改代码。

> iOS 版虽然冻结，但 `ios/tests/host/run.sh` **仍然会跑且必须全绿**——
> 它是 `shared/` 规格层的参照实现，Android 的 Java 核心要以它为对照真值。

## 2. 新机器要装什么

### 2.1 当前主线（Android）

| 层级 | 工具 | Linux（Arch） | 说明 |
|---|---|---|---|
| **必需**（跑主机检查） | `git` / `clang` / `jq` | `pacman -S git clang jq` | clang 只服务于冻结的 iOS 侧检查 |
| **Android 构建** | JDK（`javac`）+ 构建脚本取件 | `pacman -S jdk-openjdk` | `aapt2` / `d8` / `apksig` / `android.jar` 由 R14 的脚本从镜像自动取，**不需要 Android Studio** |
| **Android 设备** | `adb` / `fastboot` | `pacman -S android-tools android-udev` | `android-udev` 提供 USB 权限规则 |
| **抓栈**（R15） | `frida` | npm 走 npmmirror（`frida@17.23.3`） | 需与设备上的 `frida-server` **版本严格匹配** |

> 网络现实（R12 实测）：`dl.google.com` 与 `repo1.maven.org` 在本开发机上**不可达**
> （DNS 只有 IPv6），因此 Android 构建件必须走镜像：
> `android.jar` → GitHub raw；`aapt2` / `d8` / `apksig` → 阿里云 Google Maven；
> Xposed API → 阿里云 Central。**这些 R12 已端到端验证可用。**

### 2.2 iOS（冻结，仅当你要复现 iOS 侧时才需要）

| 工具 | Linux（Arch） | macOS |
|---|---|---|
| `libimobiledevice`（`idevice_id`/`iproxy`） | `pacman -S libimobiledevice` | `brew install libimobiledevice` |
| `theos` + iOS SDK | `git clone` theos + `theos/sdks` | theos 安装脚本一行 |
| `ldid`（签名） | 仅 AUR：`yay -S ldid` | `brew install ldid` 或 theos 自带 |
| `dpkg-deb` | `pacman -S dpkg` | `brew install dpkg` |

## 3. 换到 macOS —— 专门说明（对 iOS 侧仍然有效）

如果你把开发机换成 Mac，**仓库里的东西不用改**，但有四点要知道：

1. **主机检查照样跑**：`bash scripts/bootstrap.sh` 应当同样全绿。
   只需要 `xcode-select --install`（拿 clang）与 `brew install jq`。
2. **ObjC 检查会自动升级为「真 SDK 强检查」**：
   [`ios/tests/host/check-objc-syntax.sh`](ios/tests/host/check-objc-syntax.sh) 会优先用
   `xcrun --sdk iphoneos --show-sdk-path`；只有拿不到 SDK 时才退回
   [`ios/tests/objc-stub/`](ios/tests/objc-stub/) 的声明桩，并**打印当前用的是哪种模式**。
   真 SDK 模式下，方法存在性 / 弃用 / 可用性标注都会参与检查 —— 这比桩强得多。
   > 这一条是刻意做的：桩的 `-I` 若与真 SDK 混用，会把真头文件顶掉，
   > 让 Mac 上的「通过」变成**假通过**。脚本里有一条反向用例专门守住它
   > （用假 SDK 重跑，必须失败）。
3. **`lipo` 不用另装**：macOS 自带；Linux 上用 `llvm-lipo`。
   `ios/scripts/build.sh` 两者都支持，会自动挑。
4. **对 Android 主线没有帮助**：Android 端不需要 Mac，也不需要 Xcode。

## 4. 下一步（R14，不需要设备）

| 轮次 | 做什么 | 需要设备 |
|---|---|---|
| ~~R13~~ | ~~语言中立测试向量~~ → ✅ **本轮已完成**：110 条向量断言，总断言 251 | — |
| **R14** | Java 核心（映射 + 授权闸）移植 + JVM 主机单测（消费同一份向量）+ `android/scripts/build.sh` | ❌ |
| **R15** | Frida 只读抓栈：确认飞书实际走哪条 Wi-Fi 信息通道 | ✅ |
| **R16** | LSPosed 模块实现 + 部署 + 端到端 T1–T10 | ✅ |

**并行待办（用户侧）**：按 [`docs/android-device-spec.md`](docs/android-device-spec.md)
采购测试机（推荐二手 Pixel 8/8a、固定 Android 15、无锁版），
并在 R15 之前给出**安装 frida 的一次性许可**。

> ⚠️ **不要再把 `BG-032` 编译链落点当未决项**：它在 R9 已定为方案 C（iOS 侧），
> 且 Android 端的编译链在 R12 **已端到端实测通过**——这个纠结在 Android 上不存在。

## 5. 当前进度与缺口（指针，不复制真源）

| 想看什么 | 去哪 |
|---|---|
| 任务板、轮次记录、阻塞项、环境事实 | [`docs/STATUS.md`](docs/STATUS.md) |
| 已定决策、风险、未决事项 | [`HANDOFF.md`](HANDOFF.md) |
| 转向原因与两端关系 | [`docs/adr/0001-pivot-to-android.md`](docs/adr/0001-pivot-to-android.md) |
| **Android 测试机采购规格 + root 方案 + 验机命令** | [`docs/android-device-spec.md`](docs/android-device-spec.md) |
| Android 选型、候选 Hook 点、纪律 | [`android/README.md`](android/README.md) |
| 平台中立规格与配置 | [`shared/README.md`](shared/README.md) |
| iOS 冻结说明与回滚 | [`ios/README.md`](ios/README.md) |
| iOS 技术链路、Hook 点、可证伪实验 | [`docs/ios/tech-chain.md`](docs/ios/tech-chain.md)（§2.2） |
| 测试矩阵与证据规范 | [`tests/README.md`](tests/README.md)、[`tests/evidence/README.md`](tests/evidence/README.md) |

**已经能确定的**（有证据、可在本机复现）：

- 主机侧 **251 项断言全绿**——配置契约、脚本自检（含授权闸反向用例）、
  ObjC 语法与头文件自包含、授权闸与映射两个模拟器、92 条纯 C 单测；
- **Android 构建链端到端可用**：本机用 `javac` + `aapt2` + `d8` + `apksig`
  真实打出并**签名验证通过**了一个 APK（含 `WifiInfo.getBSSID` 的 hook 骨架编译通过）；
- 文档 **210 条内部链接无断链**。

**明确还没有的**：

- **Android 端一个真机动作都没做过**——没有设备、没有抓栈、没有装过模块；
- APK 只在本机签名并验证过，**从未在 Android 上安装运行**（本机无 `/dev/kvm`，跑不了模拟器）；
- 飞书是否有 root/Xposed 检测、`WifiInfo.getBSSID()` 在 Android 15 上要哪个权限：**待实测**；
- iOS 侧**没有任何一行代码在真实 iOS SDK 上编译或链接过**（已随冻结一并归档）。

**真机线的前置**（都不由助手代填/代办）：

1. `shared/config/targets.json` 的 6 个授权字段仍是 `fill_me`（**两端共用**）；
2. 一台已 root 的 Android 测试机（Android 15 / API 35 + Magisk + Vector）；
3. 同意安装 `frida`。

## 6. 换 AI 会话怎么最快接上

新开一个助手会话时，用这段开场（可按需删减）：

```
先读 RESUME.md、HANDOFF.md、docs/STATUS.md、docs/adr/0001-pivot-to-android.md，
再读 docs/android-device-spec.md、android/README.md、shared/README.md。然后：
1) 运行 bash scripts/bootstrap.sh，把结果告诉我；
2) 主线是 Android（iOS 版已冻结，不要再推进 iOS）；
3) 按 docs/STATUS.md 的阻塞项与下一轮（R13/R14）继续推进；
4) 遵守约定：shared/config/targets.json 的授权字段未填齐前不做真机注入、不代填授权字段；
   外部资料的结论必须标注「待真机验证」；每次改动要有可复现的验证证据；
   改了目录或文档后跑 bash scripts/check-links.sh。
```

助手必须遵守的三条约定（已写进 [`HANDOFF.md`](HANDOFF.md) §9）：

1. **进度真源**是 `docs/STATUS.md`；每轮结束更新 STATUS 与 HANDOFF；任务号必须唯一。
2. **安全闸不放宽**：`fill_me` 未填齐即拒绝 build/deploy/Hook；助手不代填授权字段。
3. **实测与外部资料严格分开**：只有 `tests/evidence/` 里的输出才能写「实测」。

## 7. 离线传输兜底

如果新机器暂时上不了网，可以用 git bundle 整包搬：

```sh
# 在旧机器
git bundle create bssidghost.bundle --all
# 在新机器
git clone bssidghost.bundle BSSIDGhost && cd BSSIDGhost
git remote set-url origin https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git
```

## 8. 常用命令速查

```sh
bash scripts/bootstrap.sh                  # 环境自检 + 主机检查 + 链接检查（第一条命令）
bash scripts/check-links.sh                # 只跑文档链接检查（改过文档/目录后必跑）
bash scripts/check-links.sh -v             # 附带统计检查了多少文件/链接

# —— iOS 侧（冻结，但必须保持全绿：它是规格层的参照实现）——
bash ios/tests/host/run.sh                 # 251 项断言（含语言中立向量）
bash ios/tests/host/run-vectors.sh         # 只跑 shared/vectors/ 的向量驱动（110 条）
bash ios/tests/host/gate-sim.sh            # 当前配置下，Hook 会对目标进程启用还是拒绝？
bash ios/tests/host/map-sim.sh             # 当前映射表下，App 会读到什么 BSSID？
bash ios/tests/host/gate-sim.sh --self-test   # 闸门模拟器自检（6 项）
bash ios/tests/host/map-sim.sh  --self-test   # 映射模拟器自检（8 项）
bash ios/tests/host/check-objc-syntax.sh   # ObjC 语法（自动选 真SDK / 声明桩 模式）
bash ios/scripts/verify.sh --skip-device   # 只做本地检查（设备侧需真机）

# —— Android 侧（R14 起提供，当前为空）——
# bash android/scripts/build.sh            # 构建模块 APK（会先过授权闸）
# bash android/scripts/deploy.sh           # adb 安装 / 推送

# —— 发布 ——
bash scripts/publish.sh --help             # 推送到远端并开 PR（见 §9）
```

## 9. 发布到远端（含 PR）

远端：<https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git>

```sh
bash scripts/publish.sh --dry-run      # 先看会推送什么、PR 标题是什么
bash scripts/publish.sh                # 真正执行：推送 main + 推送分支 + 开 PR
```

前提：本机需要 GitHub 凭据（`gh auth login`，或已配置 SSH key）。
脚本会在缺少凭据时**明确报错并给出替代命令**，不会静默失败。
