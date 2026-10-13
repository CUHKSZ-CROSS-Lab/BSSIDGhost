# 编译链落点（BG-032）—— 决策说明

> 这是**唯一卡住整个项目**的事项（见 [`STATUS.md`](STATUS.md) 的阻塞项 3）。
> 本文件把三个选项的前置条件、成本、能验证到什么都摊开，并附上**已在本机实测**的证据。

## 1. 为什么需要你决策

编译链落点涉及**在你的机器上安装/下载东西**（theos、iOS SDK ~1–3 GB、`ldid`），
或需要另一台机器（Mac）。R1 已明确「外部能力都先不装，保持环境干净」，
所以我不能自行安装或下载；这属于你拥有的资源与许可决策。

**代码层面已经准备好了**：`scripts/build.sh` 同时支持 `--toolchain theos` 与 `--toolchain clang`
（`auto` 自动选择），选定后不需要改代码，只需要环境就位 + 真正跑一次编译。

## 2. 已在本机实测的环境事实（证据）

| 事实 | 证据 | 结论 |
|---|---|---|
| clang 接受 iOS 目标三元组 | `clang -target arm64-apple-ios15.0 -fsyntax-only` 与 `arm64e-…` 均通过 | 交叉编译的**前端**已具备 |
| **Mach-O 链接器已存在** | `/usr/bin/ld64.lld`（LLD 22.1.6）；`-fuse-ld=lld` 对 Darwin 目标会自动选它 | 链接器不用另外装 |
| 缺的只有 SDK | 上述链接报错**只剩** `ld64.lld: error: library not found for -lSystem` | 装上 iOS SDK 即可继续 |
| host libc 头**不能**替代 SDK | 直接 `-c` 编到 arm64 Mach-O：`BGGhostMap.m`/`BGGhostCoreWLAN.m`/`BGGhostHotspot.m` 成功产出 arm64 目标文件；`Hooks.m`/`BGGhostConfig.m` 因 `<stdio.h>`/`<stdlib.h>` 的 glibc 头在 Darwin 目标下报错而失败 | 无法用"主机头文件 + 桩"跳过 SDK |
| theos 仓库可达 | `git ls-remote https://github.com/theos/theos HEAD` → `304e0799…` | 可 `git clone` |
| **theos SDK 仓库可达** | `git ls-remote https://github.com/theos/sdks HEAD` → `0222fd54…` | SDK 有现成来源（可 `--depth 1` 并只保留需要的版本） |
| 打包工具 | `dpkg` 在官方 `extra` 源（1.23.7-1）；`fakeroot` **已装**；`ldid` **不在官方源**（需 AUR，本机有 `yay`） | 装 `dpkg` + `ldid` 即可 |
| 磁盘 | `/home` 可用 80 GB | 放得下 theos + SDK |

> ⚠️ `theos/sdks` 里的 SDK 提取自 Xcode，**许可归属你自己确认**；本仓库不代为下载。

## 3. 三个选项

### A. macOS + theos（最省事，前提是你有 Mac）

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
export THEOS=~/theos
# 把仓库同步到 Mac 后：
scripts/build.sh --toolchain theos      # 打包 deb
scripts/build.sh --toolchain clang      # 或只出 dylib
```

- **能验证**：真 SDK 编译、链接、arm64/arm64e 切片、deb 打包、私有 API 可用性（CoreWLAN 是否需 `dlopen`）、`install_name`。
- **成本**：需要一台 Mac；代码要在两台机器间同步（git push/pull 或 rsync）。
- **风险**：最低（Apple 官方工具链）。

### B. 本机 Linux：theos + iOS SDK + ldid（一台机器闭环）

```sh
git clone --recursive https://github.com/theos/theos.git ~/theos
git clone --depth 1 https://github.com/theos/sdks.git /tmp/sdks
mkdir -p ~/theos/sdks && cp -r /tmp/sdks/iPhoneOS15.*.sdk /tmp/sdks/iPhoneOS16.*.sdk ~/theos/sdks/   # 只留需要的
sudo pacman -S dpkg            # extra 源；提供 dpkg-deb
yay -S ldid                    # 仅 AUR 有；打包/签名需要
export THEOS=~/theos
scripts/build.sh --toolchain theos
```

- **能验证**：与 A 基本一致（本机 `ld64.lld` 已在位；theos 在 Linux 上支持交叉编译）。`ldid` 只在打包/签名阶段需要。
- **成本**：下载 ~1–3 GB；磁盘占用；镜像里的 SDK 版本要与你目标 iOS 15.0–16.6.x 匹配。
- **风险**：中等 —— Linux 上偶发工具链差异；**并且需要破例安装**（R1 说"先不装"）。

### C. 越狱机上用 Procursus 工具链编译

```sh
rsync -a --exclude build --exclude .git ./ mobile@127.0.0.1:~/BSSIDGhost/   # 需 iproxy 2222 22
ssh -p 2222 mobile@127.0.0.1 'cd ~/BSSIDGhost && make package'               # 或用 clang 直接编
```

- **能验证**：设备自带 SDK 头、链接、**真实可加载性**（编译产物直接进 `/var/jb`）。
- **成本**：设备上编译慢；Procursus 的工具链未必完整（`make`/`clang`/`dpkg-deb` 需确认）；SSH 通道不稳定时很难迭代。
- **风险**：最高 —— 排障链条长，且失败原因可能来自越狱环境而非代码。

## 4. 对比

| | A macOS | B Linux + SDK | C 设备上编 |
|---|---|---|---|
| 前置成本 | 一台 Mac | ~1–3 GB 下载 + `dpkg`/`ldid` | 越狱 + SSH + Procursus 工具链 |
| 真 SDK 编译 + 链接 | ✅ | ✅ | ✅ |
| arm64 + arm64e 切片 | ✅ | ✅（`ld64.lld` 已在位） | 取决于设备工具链 |
| deb 打包 | ✅ | ✅（需 `dpkg-deb`） | ✅（需 `dpkg-deb`） |
| 迭代速度 | 快 | 快 | 慢 |
| 与 R1「先不装」的冲突 | 无 | **有**（需安装/下载） | 无（但需设备） |
| 依赖设备 | 否 | 否 | **是** |

## 5. 选定之后我会做什么（BG-031）

1. `scripts/build.sh --toolchain …` 真编译，逐个处理会暴露的问题：
   缺 `-framework`、CoreWLAN 等私有框架是否必须走 `dlopen`/`NSClassFromString`、
   `install_name`、arm64e 切片、`-fobjc-arc` 与 theos 的 CFLAGS 冲突。
2. 用 `llvm-objdump` / `otool` 检查产物：架构切片、依赖库、`install_name`、`LC_LOAD_DYLIB`。
3. 把命令与输出存 [`tests/evidence/`](../tests/evidence/)，结论回写 `STATUS.md`。
4. 通过后再谈真机（那时才轮到授权闸、设备与 frida）。

## 6. 与「命名」决策的关系

theos 产物名固定为 `BSSIDGhost.dylib`（不带 `lib` 前缀），与 HANDOFF §2 记录的
`libbssidghost.dylib` 并存为「两条路线两个名字」。三个选项见
[`naming.md`](naming.md#项目标识) —— **与本节是两件独立的事**，但如果你选 A/B
（走 theos/deb 路线），统一产物名的动机就更强。

## 7. 建议

- **手上有 Mac** → 选 **A**：风险最低，一次到位。
- **没有 Mac，且接受一次安装** → 选 **B**：本机已验证 `ld64.lld` 在位、
  theos 与 SDK 仓库可达、`dpkg` 在官方源，**只差 SDK 与 `ldid`**；
  说一声我可以在 B 路径上把安装、编译、链接检查一次做完。
- **暂时不想装任何东西、但设备在手** → 选 **C**，代价是迭代慢。
