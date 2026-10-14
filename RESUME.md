# 快速恢复（RESUME）

> **换机器 / 换会话后的第一条入口。** 目标：5 分钟内回答「我现在能做什么、缺什么、下一步是什么」。
> 本文只做**索引与操作步骤**，进度真源始终是 [`docs/STATUS.md`](docs/STATUS.md)。

## 项目一句话

**BSSIDGhost（幻影 BSSID）**：在**已 root / 已越狱的移动设备**上 Hook Wi-Fi 信息接口，
**只替换 App 读取到的 BSSID 返回值**（SSID 与真实链路不变）。
准确表述是「返回值的伪装 / spoofing」，**不是**「切换 Wi-Fi 连接」。

> ⚠️ **平台现状**：**当前主线是 iOS**（R14 切回）；Android 已暂停冻结（代码与文档全保留）。
> 决策发生过两次反转，都留了档：[ADR-0001](docs/adr/0001-pivot-to-android.md)（转向 Android）→
> [ADR-0002](docs/adr/0002-return-to-ios.md)（切回 iOS，**并修正了一个错误的越狱结论**）。

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

### 2.1 当前主线（iOS）

| 层级 | 工具 | Linux（Arch） | 说明 |
|---|---|---|---|
| **必需**（跑主机检查） | `git` / `clang` / `jq` | `pacman -S git clang jq` | clang 跑 C 单测与 ObjC 语法检查 |
| **连设备** | `libimobiledevice` / `usbmuxd` | `pacman -S libimobiledevice usbmuxd` | `ideviceinfo` / `idevice_id` / `iproxy`（抓栈与部署用） |
| **抓栈**（BG-011） | `frida` | npm 走 npmmirror（`frida@17.23.3`），需你给安装许可 | 设备侧需匹配版本的 `frida`（Sileo 安装或推 `frida-server`） |
| **设备端编译**（方案 C） | 装在**设备**上，不是主机 | 见 [`docs/ios/ondevice-build-setup.md`](docs/ios/ondevice-build-setup.md) | `clang-16` / `ld64` / `ldid` / `dpkg` / `make` + `iPhoneOS16.5.sdk` |
| **主机侧可选** | `theos` + iOS SDK + `ldid` | `ldid` 仅在 AUR | **用户已选定不装**；真编译走设备端（方案 C） |

> **主机不需要 iOS SDK、不需要 theos、不需要 Xcode** —— 方案 C 把编译放在越狱设备上。

### 2.2 Android（已暂停冻结，仅当重新解冻时才需要）

| 工具 | Linux（Arch） | 说明 |
|---|---|---|
| JDK（`javac`） | `pacman -S jdk-openjdk` | 构建脚本从镜像自动取 `aapt2` / `d8` / `apksig` / `android.jar` |
| `adb` / `fastboot` | `pacman -S android-tools android-udev` | `android-udev` 提供 USB 权限规则 |

> 网络现实（R12 实测）：`dl.google.com` 与 `repo1.maven.org` 在本开发机上**不可达**
> （DNS 只有 IPv6），Android 构建件必须走镜像（[`android/README.md`](android/README.md)）。

## 3. 换到 macOS —— 专门说明

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

## 4. 下一步（R15，**由设备驱动**）

R14 之后，**iOS 侧能脱离设备做的事已经做完**，下一步必须等机器。

| 步骤 | 谁做 | 内容 |
|---|---|---|
| 1. 采购 | 用户 | **iPhone 8**（**优先已在 ≤16.6.1**；8 Plus 3GB 内存更稳）。**一页清单（可直接发卖家）**：[`docs/ios/purchase-checklist.md`](docs/ios/purchase-checklist.md) |
| 2. 越狱 | 用户 | **Dopamine**（rootless）→ Sileo 装 ElleKit + PreferenceLoader；≤16.6.1 再装 TrollStore 免重签 |
| 3. 确认 BundleID | 双方 | 确认飞书真实 BundleID（**BG-061**）后再打包 |
| 4. 设备端工具链 | 用户 | `clang-16` / `ld64` / `ldid` / `dpkg` / `make` + `iPhoneOS16.5.sdk` |
| 5. 编译 + 验证 | 双方 | `bash ios/scripts/build.sh --toolchain theos` → 装包 → T1–T10 → BG-011 抓栈 |

**用户侧并行待办**：采购 iPhone 8；给出**安装 frida 的一次性许可**。

> ⚠️ **两条不要重新讨论的事**：
> 1. `BG-032` 编译链落点已在 R9 定为**方案 C**；
> 2. **iPhone 8 能不能越狱**已在 R14 核实为**能**（palera1n + Dopamine 双重支持），
>    旧的「arm64e 排除」推论是错的，见 [`docs/ios/device-spec.md`](docs/ios/device-spec.md) §1。

## 5. 当前进度与缺口（指针，不复制真源）

| 想看什么 | 去哪 |
|---|---|
| 任务板、轮次记录、阻塞项、环境事实 | [`docs/STATUS.md`](docs/STATUS.md) |
| 已定决策、风险、未决事项 | [`HANDOFF.md`](HANDOFF.md) |
| **两次反转的原因（含被推翻的旧结论）** | [`docs/adr/0002-return-to-ios.md`](docs/adr/0002-return-to-ios.md)（新）→ [`0001`](docs/adr/0001-pivot-to-android.md) |
| **iPhone 8 采购规格 + 越狱方案 + 验机命令** | [`docs/ios/device-spec.md`](docs/ios/device-spec.md) |
| iOS 实现说明（曾冻结，R14 解冻） | [`ios/README.md`](ios/README.md) |
| iOS 技术链路、Hook 点、可证伪实验 | [`docs/ios/tech-chain.md`](docs/ios/tech-chain.md)（§2.2） |
| 设备端编译 SOP（方案 C） | [`docs/ios/ondevice-build-setup.md`](docs/ios/ondevice-build-setup.md) |
| Android（冻结中，备查） | [`android/README.md`](android/README.md)、[`docs/android-device-spec.md`](docs/android-device-spec.md) |
| 平台中立规格与配置 | [`shared/README.md`](shared/README.md) |
| 测试矩阵与证据规范 | [`tests/README.md`](tests/README.md)、[`tests/evidence/README.md`](tests/evidence/README.md) |

**已经能确定的**（有证据、可在本机复现）：

- 主机侧 **251 项断言全绿**——配置契约、脚本自检（含授权闸反向用例）、
  ObjC 语法与头文件自包含、授权闸与映射两个模拟器、92 条纯 C 单测；
- **iPhone 8 可行性已核实**（R14）：palera1n 与 Dopamine **都支持 A11**，
  Dopamine 是 rootless `/var/jb`，与仓库假设完全一致 → **iOS 代码不用改**；
- 飞书 iOS 元数据：最低 **iOS 13.0**，`supportedDevices` **含 iPhone 8** → 装得上；
- （Android 备查）构建链端到端可用：本机 `javac` + `aapt2` + `d8` + `apksig`
  真实打出并签名验证通过了一个 APK；
- 文档 **265 条内部链接无断链**。

**明确还没有的**：

- **两边都没有任何真机动作**：iPhone 8 未采购，越狱/编译/抓栈都没发生过；
- iOS 侧**没有任何一行代码在真实 iOS SDK 上编译或链接过**（这是最大的空洞）；
- **BG-061**：飞书的真实 BundleID 待真机确认（配置里那个值很可能是错的）；
- Dopamine 是否要求关密码、飞书是否有越狱检测：**均未查到可靠来源 / 待实测**。

**真机线的前置**（都不由助手代填/代办）：

1. `shared/config/targets.json` 的 6 个授权字段仍是 `fill_me`；
2. **一台 iPhone 8，且优先已在 iOS ≤16.6.1**（这决定 TrollStore 能否用）；
3. 同意安装 `frida`（BG-011 抓栈用）。

## 6. 换 AI 会话怎么最快接上（**交接握手**）

### 6.1 当前状态一句话（R14 结束时，2026-10-14）

> **主线 iOS**（iPhone 8 + Dopamine）；Android 暂停冻结但代码全保留。
> 主机侧 **251 项断言全绿、277 条文档链接无断链**，但**没有任何真机动作**——
> iPhone 8 尚未采购。**下一轮 R15 是设备驱动的，卡点只在你手上。**

### 6.2 开场白（复制这一段即可）

```
先读 RESUME.md、HANDOFF.md、docs/STATUS.md、docs/adr/0002-return-to-ios.md，
再读 docs/ios/device-spec.md、docs/ios/purchase-checklist.md、shared/README.md。然后：

1) 运行 bash scripts/bootstrap.sh，把结果告诉我（应报 251 项断言 + 链接无断链）；
2) 主线是 iOS：目标机型 iPhone 8（A11），越狱工具 Dopamine（rootless /var/jb），
   iOS 版本优先 <=16.6.1（决定 TrollStore 能否用，进而决定要不要每 7 天重签）；
3) Android 已暂停冻结，不要再推进 Android；
4) 按 docs/STATUS.md 的阻塞项与下一轮（R15）继续推进；
5) 打包前必须先确认真实 BundleID（BG-061）—— 写错插件不会注入，而且不报错；
6) 遵守约定：shared/config/targets.json 的授权字段未填齐前不做真机注入、不代填授权字段；
   外部资料必须标注「待真机验证」；每次改动要有可复现的验证证据；
   改了文档或目录后跑 bash scripts/check-links.sh。

另外，以下三件事已经核实过了，不要重新讨论：
- iPhone 8 能越狱（palera1n 与 Dopamine 双重支持）—— 项目曾用「palera1n 排除 arm64e」
  错误地否定它，那是个错误推论，已在 docs/ios/handoff-device-jailbreak.md §2.1 修正；
- BG-032 编译链落点已定为方案 C（设备端 Procursus 工具链），不是未决项；
- 单仓双端结构与 shared/vectors/ 的 110 条语言中立向量是跨端资产，与主线在哪一侧无关。
```

### 6.3 助手必须遵守的约定

三条基本约定（已写进 [`HANDOFF.md`](HANDOFF.md) §9）：

1. **进度真源**是 `docs/STATUS.md`；每轮结束更新 STATUS 与 HANDOFF；任务号必须唯一。
2. **安全闸不放宽**：`fill_me` 未填齐即拒绝 build/deploy/Hook；助手不代填授权字段。
3. **实测与外部资料严格分开**：只有 `tests/evidence/` 里的输出才能写「实测」。

> **R14 新增第 4 条纪律**：判断某机型能否越狱，**必须回到官方「支持设备列表」核对**，
> 不能从一句概括性描述外推——项目正是在这里错过一次，差点白白转向 Android。
>
> **第 5 条（R12 起）**：目录或文档改动后跑 `bash scripts/check-links.sh`；
> 根解析有哨兵（找不到 `shared/config/targets.json` 会立即报错），搬迁脚本后先跑测试套件。

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

# —— iOS 侧（当前主线：测试与打包都在这边）——
bash ios/tests/host/run.sh                 # 251 项断言（含语言中立向量）
bash ios/tests/host/run-vectors.sh         # 只跑 shared/vectors/ 的向量驱动（110 条）
bash ios/tests/host/gate-sim.sh            # 当前配置下，Hook 会对目标进程启用还是拒绝？
bash ios/tests/host/map-sim.sh             # 当前映射表下，App 会读到什么 BSSID？
bash ios/tests/host/gate-sim.sh --self-test   # 闸门模拟器自检（6 项）
bash ios/tests/host/map-sim.sh  --self-test   # 映射模拟器自检（8 项）
bash ios/tests/host/check-objc-syntax.sh   # ObjC 语法（自动选 真SDK / 声明桩 模式）
bash ios/scripts/verify.sh --skip-device   # 只做本地检查（设备侧需真机）

# 连设备 / 取信息（iOS）
idevice_id -l                              # 列出已连接设备
ideviceinfo -k ProductVersion              # 版本（采购验机第一项）
iproxy 2222 22                             # SSH 隧道（Dopamine + OpenSSH 时一般可直连局域网）

# —— Android 侧（已暂停冻结，解冻后才需要）——
# bash android/scripts/build.sh            # 构建模块 APK（会先过授权闸）

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
