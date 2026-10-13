# 设备端编译与验证环境搭建（BG-032 方案 C：Procursus 工具链）

> **适用决策**：`BG-032 = C` —— 在越狱设备上直接用 Procursus 提供的 clang/ld64 编译，
> 并在同一台设备上验证。主机（Linux/Mac）只需要 `git` + `ssh`/`scp`，**不需要 iOS SDK、不需要 theos**。
>
> ⚠️ **本文档的性质**：环境事实（版本号、包名、支持矩阵）来自官方仓库与官方站点，**已逐条核实并标注来源**；
> 但**没有任何步骤在本项目的设备上实跑过**（当前无设备、无授权）。
> 凡未实测的结论一律标 ⏳，执行后请把结果回写到 [`STATUS.md`](STATUS.md) 与 [`tests/evidence/`](../tests/evidence/)。

## 0. 结论摘要：要准备什么

| # | 要准备的东西 | 关键参数 | 核实程度 |
|---|---|---|---|
| 1 | 一台 iPhone/iPad（**已越狱**） | 见 §1 的机型/版本矩阵 | ✅ 官方支持矩阵 |
| 2 | iOS 版本 | **推荐 15.0–16.6.1**（理由见 §1） | ✅ |
| 3 | 越狱工具 | **Dopamine（rootless）**，装完有 Sileo | ✅ 官方站点 + cfw.guide |
| 4 | 设备端编译器 | Sileo 装 **`clang-16`**（LLVM 16.0.0 / Swift 5.9.2 分支） | ✅ 包索引 + 构建配方 |
| 5 | 设备端链接器 | Sileo 装 **`ld64`**（609-3）—— 装 `clang-16` 时会自动带上 | ✅ 包索引（依赖关系） |
| 6 | 签名工具 | Sileo 装 `ldid`（2.1.5-procursus7，220 KB） | ✅ 包索引 |
| 7 | 打包工具 | Sileo 装 `dpkg`（1.22.6，含 dpkg-deb，6.1 MB）、`make`（4.4.1，1.6 MB） | ✅ 包索引 |
| 8 | **iOS SDK 头文件** | `theos/sdks` 的 `iPhoneOS16.5.sdk`（**约 201 MB / 8867 个文件**；仓库里最高就这个版本） | ✅ 仓库 tree 实测 |
| 9 | 顺手的工具 | `git`（2.39.1，29 MB）、`openssh`、`rsync` | ✅ 包索引 |
| 10 | 授权登记 | `config/targets.json` 的 6 个字段（**助手不代填**） | 本项目约定 |

**磁盘预算**：SDK ~200 MB + 工具链 ~600 MB + 包缓存 ≈ **1 GB 出头**；建议设备留 **≥3 GB**。
（不要顺手装 `swift-5.9.2`——它**装完 1.19 GB**，本项目用不到。）

**只有第 10 项不是"装出来的"** —— 它是安全闸：不填齐，Hook 日志会出现「拒绝启用」并写明责任字段。

## 1. 该准备哪台机器、哪个 iOS 版本

### 1.1 Dopamine 官方支持矩阵

来源：<https://ellekit.space/dopamine/>（官方站点，2026 核实）

| 芯片 | 支持的 iOS | 说明 |
|---|---|---|
| **A8 – A13** | **15.0 – 18.7.1**，以及 26.0 – 26.0.1 | 含 arm64（A8–A11）与 arm64e（A12–A13） |
| **A14 – A17 / M1 – M2** | **15.0 – 17.3.1** | 新芯片上限反而更低 |

iOS Guide 的表述（<https://ios.cfw.guide/installing-dopamine-trollstore/>）与之实质一致：
"supports all devices on iOS/iPadOS 15.0 to 17.3.1, and A13 and earlier devices on 17.4 to 18.7.1 and 26.0 to 26.0.1"。

> ⏳ A12/A13 在"17.4 以上"这一点上两份资料的措辞略有差异（官方站点写 A8–A13）。
> 拿不准时用 <https://appledb.dev/device-selection/> 按你的具体机型确认。

### 1.2 本项目的推荐区间：**iOS 15.0 – 16.6.1**

三条理由：

1. **SDK 可得性**：`theos/sdks` 提供的 iPhoneOS SDK 最高只到 **16.5**（已核实仓库目录）。
   用 16.5 SDK 编译、把部署目标设为 15.0 完全没问题；但如果你把设备升到 17/18，
   仍然只能用 16.5 SDK —— 麻烦不在于不能用，而在于**容易误以为需要更高 SDK**。
2. **越狱安装路径最简单**：iOS ≤ 16.6.1 可以走 **TrollStore** 路线（permasigned，7 天不掉签），
   16.7 及以上要换另一套安装流程（见 §2.2）。
3. **与项目假设一致**：`docs/tech-chain.md` 的 nehelper/CoreWLAN 判断就是按这个时代写的，
   换到 17/18 需要重新验证（§2.2 of tech-chain）。

> 结论：**如果你手上这台能停在 15.0–16.6.1，就别升上去。** 已经在 17/18 也能用，只是步骤更多。

### 1.3 机型层面的取舍

| 考虑 | 建议 |
|---|---|
| 架构 | A12 及以上是 **arm64e**；A11 及以下是 arm64。本项目两条都编（`ARCHS = arm64 arm64e`），无需改配置 |
| 存储 | 见 §0 的磁盘预算：**≥3 GB** 比较稳（SDK ~200 MB + 工具链 ~600 MB） |
| 别用主力机 | 越狱会失去保修、影响部分 App（银行/支付类常检测越狱），**用测试机** |
| 屏幕 | 换过屏的机器越狱后触控可能失灵（cfw.guide 明确警告） |

## 2. 越狱准备（Dopamine / rootless）

### 2.1 路线 A：TrollStore（适用于 iOS 15.0–16.6.1、16.7 RC、17.0）

完整步骤见官方指南：<https://ios.cfw.guide/installing-dopamine-trollstore/>。要点与坑：

1. **先装 TrollStore**（这一步用电脑）：
   - 按机型/版本选 TrollRestore / TrollInstallerX / TrollHelperOTA / TrollInstallerMDC；
   - **TrollRestore 那条路要求先关闭「查找」（Find My）** —— 因为它靠还原一份改过的备份注入；
     装完可以再打开；
   - 装完 TrollStore 后进 Settings → **Install Persistence Helper**（选个你不用的系统 App，比如 Tips）。
2. **用 TrollStore 安装 Dopamine**：把 `Dopamine.ipa`（<https://ellekit.space/dopamine>）存到设备，
   在 TrollStore 里 `+` → 选该 ipa → Install。
3. **运行 Dopamine** → 点 `Jailbreak`。A12/A13 在 16.6+ 上屏幕会短暂黑一下再亮，属正常。
   失败就重启重试（半不完美越狱，重启后需重新点一次）。
4. 成功后会看到 **Sileo**。然后按指南在 Sileo 里：
   - Sources → ElleKit 源 → 安装 **ElleKit**（提供 hooking 运行时）；
   - 搜索并安装 **PreferenceLoader**；
   - 点 `Reboot Device`（这是用户态重启，仍在越狱态）。

> ⏳ **我没有核实到的两点**，执行前请自己确认：
> (a) 新版 Dopamine 对**锁屏密码**有没有要求（早期 Fugu15 系工具有"必须关闭密码"的说法，
> 我在官方站点与 cfw.guide 上都**没有**看到这条要求，所以不写进步骤）；
> (b) 某些版本可能需要 iOS 的 **Developer Mode**（sideload 安装 TrollInstallerX 时需要）。
> 这两条以你设备上 Dopamine 的实际提示为准。

### 2.2 路线 B：非 TrollStore（iOS 16.7 及以上）

官方指南：<https://ios.cfw.guide/installing-dopamine>。差别主要在**怎么把 Dopamine 装进设备**
（侧载/签名，需要 Apple ID 与电脑），越狱后的部分与路线 A 相同。

### 2.3 越狱完成的判定

- 桌面出现 **Sileo**；
- 文件系统出现 `/var/jb`（rootless 前缀）——**这是本项目所有路径的基础**；
- `ssh` 可用（见 §5.4，越狱环境自带 SSH 或可用 `openssh` 包装）。

## 3. 设备端编译工具链（Sileo 安装）

Procursus 会随 Dopamine 的 bootstrap 一起提供源（`https://apt.procurs.us`）。
在 Sileo 里**先确认 Sources 中有 Procursus 源**，没有就手动添加。

> ⚠️ **包名要认准**：Procursus 的源码仓库里有 `cctools.mk`，但**iOS 通道上架的链接器包名是 `ld64`**；
> 编译器也不是 `llvm`（那是元包，指向 `llvm-14`），而是按版本上架的 `clang-16` / `clang-14`。
> 下表是我从**当前 iOS 通道的包索引**里逐条核对出来的。

安装这几个（**装 `clang-16` 会自动带上 `ld64`**）：

| 包名 | 版本 | 装完占用 | 用途 |
|---|---|---|---|
| `clang-16` | 16.0.0~5.9.2~RELEASE-1 | 本体 0.9 MB（大头在依赖里） | 编译（LLVM 16） |
| `ld64` | 609-3 | 2.8 MB | 链接（clang-16 的依赖，自动装） |
| `ldid` | 2.1.5-procursus7 | 0.2 MB | 伪签名，让注入的 dylib 能加载 |
| `dpkg` | 1.22.6 | 6.1 MB | `dpkg-deb` 打包 / 装包 |
| `make` | 4.4.1 | 1.6 MB | theos 路线（§5.2） |
| `git`（可选） | 2.39.1 | 29 MB | 在设备上直接 clone 仓库与 SDK |

`clang-16` 的依赖会一并装上（这也是主要体积来源）：
`libclang-common-16-dev` ≈ 287 MB、`libllvm16` ≈ 108 MB、`libclang-cpp16` ≈ 61 MB、
`build-essential` ≈ 41 MB、`libclang1-16` ≈ 38 MB、`libc++-16-dev` ≈ 9 MB、`tapi` ≈ 19 MB。

| 不太需要装的 | 为什么 |
|---|---|
| `swift-5.9.2` / `swift` | 装完 **1.19 GB**，本项目不用 Swift 写 tweak |
| `llvm-16`（整包） | 装完 107 MB，是完整 LLVM 工具集；只编译本项目的话 `clang-16` 够用 |
| 裸 `clang`（元包） | 它指向 **clang-14**（LLVM 14 + Swift 5.7.2）。能用，但建议直接装 `clang-16` |

装完后确认：

```sh
# 设备上执行
clang --version        # 期望 16.0.0（Apple 分支）；若找不到就试 clang-16
ld -v                  # 期望 ld64-609 系
ldid --version         # 期望 2.1.5-procursus7
dpkg-deb --version     # 期望 1.22.6
```

⏳ 如果 `clang` / `clang-16` 都不在 PATH 里，把版本化目录加进去
（Procursus 的 LLVM 常按版本分目录）：

```sh
export PATH="/var/jb/usr/lib/llvm-16/bin:$PATH"
```

> 设备上还有 `tapi` / `libtapi`（Apple 的 TAPI，用 `.tbd` 桩做链接）——SDK 里的
> `System/Library/Frameworks/*.tbd` 就是靠它参与链接的，所以**SDK 和 tapi 缺一不可**。

## 4. 把 iOS SDK 放到设备上

设备端编译同样需要 SDK 头文件与 `.tbd` 桩。`theos/sdks` 提供到 **16.5**，
`iPhoneOS16.5.sdk` 实测约 **201 MB / 8867 个文件**（直接整仓 clone 会拖下所有历史 SDK，别那么干）：

```sh
# 设备上执行（体积大，用 sparse checkout 只取需要的那个）
cd /var/jb/opt
git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git
cd sdks
git sparse-checkout set iPhoneOS16.5.sdk
ls iPhoneOS16.5.sdk   # 期望看到 usr/ System/ SDKSettings.plist
```

> **为什么 16.5 SDK 能在更高 iOS 上跑**：SDK 决定"编译时能用什么 API"，
> 部署目标（`-miphoneos-version-min=15.0` / theos 的 `TARGET ...:15.0`）决定"运行时最低要求"。
> 本项目只用了 Foundation / `os_unfair_lock` / ObjC 运行时这些老 API，16.5 SDK 足够。

如果你要装 theos（§5.2），把 SDK 放到 `$THEOS/sdks/`：

```sh
export THEOS=/var/jb/opt/theos
mkdir -p "$THEOS/sdks"
mv /var/jb/opt/sdks/iPhoneOS16.5.sdk "$THEOS/sdks/"
```

## 5. 在设备上编译本项目

先把代码弄上去（主机侧执行）：

```sh
# 主机
iproxy 2222 22 &                      # USB 转发 SSH
scp -P 2222 -r /home/zcai/Projects/BSSIDGhost mobile@127.0.0.1:/var/jb/opt/
# 或更干净：在设备上直接 git clone 我们的仓库
ssh -p 2222 mobile@127.0.0.1 'cd /var/jb/opt && git clone https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git'
```

### 5.1 路线 1：直接用 clang（不依赖 theos）

```sh
# 设备上执行
cd /var/jb/opt/BSSIDGhost
SDK=/var/jb/opt/sdks/iPhoneOS16.5.sdk

clang -dynamiclib \
      -arch arm64 -arch arm64e \
      -isysroot "$SDK" \
      -miphoneos-version-min=15.0 \
      -fobjc-arc -fmodules -Wall -Wextra \
      -Ihooks \
      -framework Foundation \
      hooks/*.m hooks/*.c \
      -o /var/jb/usr/lib/BSSIDGhost.dylib

ldid -S /var/jb/usr/lib/BSSIDGhost.dylib     # 伪签名，否则可能加载失败
```

> 这与 `scripts/build.sh --toolchain clang` 生成的命令一致，区别只是**本机是设备自身**，
> 所以不需要 `-target`（设备默认就是对的架构）。

### 5.2 路线 2：theos（**推荐**，因为本仓库已经有 Makefile）

```sh
# 设备上执行
export THEOS=/var/jb/opt/theos
git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
# 再把 §4 的 SDK 放进 $THEOS/sdks/

cd /var/jb/opt/BSSIDGhost
bash scripts/build.sh --toolchain theos        # 会先过授权闸，再 make package
```

产物：`packages/com.<team>.bssidghost_*.deb`。

> ⚠️ **`scripts/build.sh` 会先跑授权闸**：`config/targets.json` 里还有 `fill_me` 就会**拒绝构建**
> （这是刻意设计）。两个选择：
> – 填齐授权字段（**你自己的、已获授权的 App**，助手不代填）；
> – 或明确知道自己在做什么，绕过脚本直接 `make package`（跳过闸门，仅建议在纯编译调试时用）。

### 5.3 关于 `BGGHOST_*` 环境变量

设备上同样可用（见 `scripts/lib/common.sh`）：

| 变量 | 默认 | 用途 |
|---|---|---|
| `BGGHOST_JB_PREFIX` | `/var/jb` | 越狱前缀 |
| `BGGHOST_MIN_IOS` | `15.0` | 部署目标 |
| `BGGHOST_IOS_SDK` | — | SDK 路径（覆盖自动探测） |
| `BGGHOST_CONFIG_DIR` | — | 配置目录覆盖（联调时指向临时目录） |

### 5.4 SSH 与通道

Dopamine 环境里可用 `openssh`；主机侧用 libimobiledevice 的 `iproxy` 转发：

```sh
iproxy 2222 22
ssh -p 2222 mobile@127.0.0.1       # 具体用户/口令按你的越狱环境
```

## 6. 装上并验证（T1–T10）

```sh
# 设备上执行
dpkg -i /var/jb/opt/BSSIDGhost/packages/*.deb
# 或手工方式（跳过包管理）
cp BSSIDGhost.dylib /var/jb/usr/lib/
cp layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist \
   /var/jb/Library/MobileSubstrate/DynamicLibraries/
sbreload                     # 或 killall -9 SpringBoard
```

然后按 [`tests/README.md`](../tests/README.md) 跑矩阵，重点是三条：

| 用例 | 怎么做 | 期望 |
|---|---|---|
| T1 Hook 加载 | 冷启动目标 App，看日志 | 出现 `[BSSIDGhost] 启用` |
| T9 授权闸 | 授权字段未填时冷启动 | 出现 `拒绝启用：…（字段 authorization.xxx）` |
| T2 BSSID 替换 | App 内看 Wi-Fi 信息 | 读到配置里的伪造值，SSID 不变 |

日志：`/var/mobile/Library/Logs/BSSIDGhost/ghost.log`（超过 `log.max_bytes` 轮转为 `.1`）。

抓栈（可选但推荐，用来验证 nehelper 假设）：

```sh
# 主机侧（需先装 frida）
frida -U -f <bundleid> -l tests/frida/capture-wifi-api.js -o tests/evidence/$(date +%Y%m%d-%H%M%S)-capture.jsonl
frida -U -n nehelper  -l tests/frida/capture-wifi-api.js -o tests/evidence/$(date +%Y%m%d-%H%M%S)-nehelper.jsonl
```

实验假设与判别表见 [`docs/tech-chain.md`](tech-chain.md) §2.2。

## 7. 安全闸（不要绕过）

1. `config/targets.json` 的 6 个授权字段必须填齐（**助手不代填**）——
   未填齐时设备端会拒绝启用，脚本侧会拒绝构建/部署；
2. 只对**自有或已获书面授权**的 App 使用，只在受控测试设备与测试网络上做；
3. 真机的破坏性操作（装 deb、respring）逐次确认。

## 8. 待真机验证清单（诚实标注）

| 项 | 来源 | 需要实测什么 |
|---|---|---|
| Dopamine 支持矩阵 | 官方站点 + cfw.guide | 你机型的实际可越狱版本 |
| 包名 `clang-16` / `ld64` / `ldid` / `dpkg` / `make` 与版本号 | **当前 iOS 通道包索引**（`dists/2000/main/binary-iphoneos-arm64`，1364 个包，2026-07-27） | Sileo 里实际显示的包名、体积；`clang` 可执行文件是否在 PATH |
| SDK `iPhoneOS16.5.sdk` ≈ 201 MB | GitHub tree 实测（8867 个 blob） | sparse checkout 是否顺利、SDK 在设备端 clang+ld64 下能否正常编译链接本项目 |
| 设备端编译全流程 | 未实测 | 首次编译的报错（缺头文件？`-fmodules` 冲突？arm64e 切片？） |
| 注入后能否加载 | 未实测 | `ldid -S` 是否足够；ElleKit 是否按 plist 过滤生效 |
| nehelper 是否为统一后端 | **外部资料** | 见 tech-chain §2.2 的可证伪实验 |
| ⏳ suite 归属 | 未确认 | Procursus 的 `dists/{1800,1900,2000,3000}` 都是 "Distribution of essential tools for iPhoneOS"，我**无法从 Release 判断哪个对应你的 iOS 版本**。以你设备上 Sileo 已配置的源为准；包找不到时把源地址报回来 |

## 9. 常见坑

| 现象 | 原因 / 处理 |
|---|---|
| `clang: command not found` | 装的是版本化包：试 `clang-16`，或把 `/var/jb/usr/lib/llvm-16/bin` 加进 PATH |
| `ld: library not found for -lSystem` | `-isysroot` 没指向 SDK，或 SDK 路径写错 |
| 编译报缺 `Foundation/Foundation.h` | SDK 没放对位置 / `-isysroot` 未生效 |
| 链接报找不到 framework | SDK 里的 `.tbd` 需要 `tapi` / `libtapi`（装 `ld64` 时会带上） |
| 装完 deb 没生效 | 没冷启动 App（越狱插件在进程启动时加载）；或过滤器 plist 未装 |
| 日志里是「拒绝启用」 | 授权闸拦截，按提示填对应字段（**这是设计，不是 bug**） |
| 越狱重启后失效 | Dopamine 是半不完美越狱，重启后要重新打开 App 点一次 Jailbreak |
| 设备空间不足 | 别装 `swift-5.9.2`（1.19 GB）；或改用主机侧交叉编译（BG-032 的 A/B 方案） |
