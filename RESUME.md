# 快速恢复（RESUME）

> **换机器 / 换会话后的第一条入口。** 目标：5 分钟内回答「我现在能做什么、缺什么、下一步是什么」。
> 本文只做**索引与操作步骤**，进度真源始终是 [`docs/STATUS.md`](docs/STATUS.md)。

## 项目一句话

**BSSIDGhost（幻影 BSSID）**：在已越狱的 iOS 设备上 Hook Wi-Fi 信息接口，
**只替换 App 读取到的 BSSID 返回值**（SSID 与真实链路不变）。
准确表述是「返回值的伪装 / spoofing」，**不是**「切换 Wi-Fi 连接」。

## 1. 5 分钟恢复（三步）

```sh
# ① 取代码
git clone https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git
cd BSSIDGhost

# ② 一条命令：环境自检 + 跑全套主机检查（不需要设备）
bash scripts/bootstrap.sh

# ③ 按输出的「接下来做什么」执行；本文第 4 节的决策是当前唯一的关键路径
```

`bootstrap.sh` 会依次做三件事：

1. **必需项检查**（`git` / `clang` / `jq`），缺失时按当前平台给出安装命令；
2. **可选项检查**（真机与打包工具、iOS SDK、`THEOS`、`lipo`）；
3. **跑 `tests/host/run.sh`** —— 6 个主机检查目标、141 项断言，全部不需要设备。

健康的仓库应当输出：

```
✅ 必需工具齐全
✅ 主机检查通过（配置契约 / 脚本自检 / ObjC 语法 / 两个模拟器 / 纯 C 单测）
```

任一项红，先按提示装工具，再重跑。**缺工具也算交付物的一部分**：不要跳过这一步去改代码。

## 2. 新机器要装什么

| 层级 | 工具 | Linux（Arch） | macOS |
|---|---|---|---|
| **必需**（跑主机检查） | `git` / `clang` / `jq` | `pacman -S git clang jq` | `xcode-select --install` + `brew install jq` |
| 建议 | `node`（校验 Frida 脚本语法） | `pacman -S nodejs npm` | `brew install node` |
| 真机 | `libimobiledevice`（`idevice_id`/`iproxy`） | `pacman -S libimobiledevice` | `brew install libimobiledevice` |
| 真机 | `frida`（抓栈，BG-011 必需） | `pip3 install frida-tools` 或 npm 走 npmmirror | `pip3 install frida-tools` |
| 打包 | `theos` + iOS SDK | `git clone` theos + `theos/sdks` | theos 安装脚本一行 |
| 打包 | `ldid`（签名） | 仅 AUR：`yay -S ldid` | `brew install ldid` 或 theos 自带 |
| 打包 | `dpkg-deb` | `pacman -S dpkg` | `brew install dpkg` |

> 网络现实（本机实测）：`registry.npmjs.org` 在本项目当前开发机上**不可达**，
> `registry.npmmirror.com` 与 `github.com` 可达。npm 相关安装请带
> `--registry=https://registry.npmmirror.com`。

## 3. 换到 macOS —— 专门说明

如果你把开发机换成 Mac，**仓库里的东西不用改**，但有四点要知道：

1. **主机检查照样跑**：`bash scripts/bootstrap.sh` 应当同样全绿。
   只需要 `xcode-select --install`（拿 clang）与 `brew install jq`。
2. **ObjC 检查会自动升级为「真 SDK 强检查」**：
   [`tests/host/check-objc-syntax.sh`](tests/host/check-objc-syntax.sh) 会优先用
   `xcrun --sdk iphoneos --show-sdk-path`；只有拿不到 SDK 时才退回
   [`tests/objc-stub/`](tests/objc-stub/) 的声明桩，并**打印当前用的是哪种模式**。
   真 SDK 模式下，方法存在性 / 弃用 / 可用性标注都会参与检查 —— 这比桩强得多。
   > 这一条是刻意做的：桩的 `-I` 若与真 SDK 混用，会把真头文件顶掉，
   > 让 Mac 上的「通过」变成**假通过**。脚本里有一条反向用例专门守住它
   > （用假 SDK 重跑，必须失败）。
3. **`lipo` 不用另装**：macOS 自带；Linux 上用 `llvm-lipo`。
   `scripts/build.sh` 两者都支持，会自动挑。
4. **`BG-032` 的决策材料里 A 方案就是 Mac**：如果你确定用 Mac，
   直接在 [`docs/build-chain-options.md`](docs/build-chain-options.md) 选 A，
   然后可以走真编译（见第 4 节）。

可选：设 `export BGGHOST_IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)` 后，
`bash tests/host/check-objc-syntax.sh` 会明确以 sdk 模式运行。

## 4. 下一步只有一件事：`BG-032` 编译链落点

**这是我（助手）无法自己决定、也无法绕过的唯一障碍。**
三个选项的前置条件、成本、能验证什么，全部在
[`docs/build-chain-options.md`](docs/build-chain-options.md)，含已实测事实。

| 选项 | 一句话 | 前置 |
|---|---|---|
| **A** | macOS + theos | 一台 Mac |
| **B** | 本机装 theos + iOS SDK + `ldid` | 一次安装许可（本机已验证**只差 SDK 与 ldid**） |
| **C** | 越狱机上用 Procursus 工具链 | 设备 + SSH，迭代慢 |

选定后要做的（BG-031）：真编译 → 处理 `-framework` / 私有框架是否必须
`dlopen`+`NSClassFromString` / `install_name` / arm64e 切片 →
用 `llvm-objdump`（或 `otool`）检查产物 → 证据入 [`tests/evidence/`](tests/evidence/)。

## 5. 当前进度与缺口（指针，不复制真源）

| 想看什么 | 去哪 |
|---|---|
| 任务板、轮次记录、阻塞项 | [`docs/STATUS.md`](docs/STATUS.md) |
| 已定决策、风险、未决事项 | [`HANDOFF.md`](HANDOFF.md) |
| 技术链路、Hook 点、可证伪实验 | [`docs/tech-chain.md`](docs/tech-chain.md)（§2.2） |
| 编译链选项与实测成本 | [`docs/build-chain-options.md`](docs/build-chain-options.md) |
| 真机准备 SOP | [`docs/device-setup.md`](docs/device-setup.md) |
| 测试矩阵与证据规范 | [`tests/README.md`](tests/README.md)、[`tests/evidence/README.md`](tests/evidence/README.md) |

**已经能确定的**（有证据、可在本机复现）：主机侧 6 个检查目标、141 项断言全绿 ——
配置契约、脚本自检（含授权闸反向用例）、ObjC 语法与头文件自包含、
授权闸与映射两个模拟器、92 条纯 C 单测。

**明确还没有的**：**没有任何一行代码在真实 iOS SDK 上编译或链接过**。
`hooks/*.m` 只到语法检查；`scripts/build.sh` 只验证过命令拼装（`--dry-run`）。

**真机线的三个前置**（都不由助手代填/代办）：

1. `config/targets.json` 的 6 个授权字段仍是 `fill_me`；
2. 一台已越狱测试机（Dopamine / rootless，iOS 15.0–16.6.x）；
3. 同意安装 `frida`。

## 6. 换 AI 会话怎么最快接上

新开一个助手会话时，用这段开场（可按需删减）：

```
先读 RESUME.md、HANDOFF.md、docs/STATUS.md，再读 docs/tech-chain.md 与
docs/build-chain-options.md。然后：
1) 运行 bash scripts/bootstrap.sh，把结果告诉我；
2) 按 docs/STATUS.md 的阻塞项继续推进；
3) 遵守约定：config/targets.json 的授权字段未填齐前不做真机注入、不代填授权字段；
   外部资料的结论必须标注「待真机验证」；每次改动要有可复现的验证证据。
```

助手必须遵守的三条约定（已写进 [`HANDOFF.md`](HANDOFF.md) §9）：

1. **进度真源**是 `docs/STATUS.md`；每轮结束更新 STATUS 与 HANDOFF。
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
bash scripts/bootstrap.sh              # 环境自检 + 全套主机检查
tests/host/run.sh                      # 只跑主机检查（L0+L1）
tests/host/gate-sim.sh                 # 当前配置下，Hook 会对目标进程启用还是拒绝？
tests/host/map-sim.sh                  # 当前映射表下，App 会读到什么 BSSID？
tests/host/gate-sim.sh --self-test     # 闸门模拟器自检（6 项）
tests/host/map-sim.sh  --self-test     # 映射模拟器自检（8 项）
tests/host/check-objc-syntax.sh        # ObjC 语法（自动选 真SDK / 声明桩 模式）
bash scripts/build.sh --dry-run        # 看会执行什么编译命令（先过授权闸）
bash scripts/build.sh --help           # 两条编译链的用法
bash scripts/deploy.sh --help          # 部署方式（deb / files）
bash scripts/verify.sh --skip-device   # 只做本地检查（设备侧需真机）
bash scripts/publish.sh --help         # 推送到远端并开 PR（见 §9）
```

## 9. 发布到远端（含 PR）

远端：<https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git>

```sh
bash scripts/publish.sh --dry-run      # 先看会推送什么、PR 标题是什么
bash scripts/publish.sh                # 真正执行：推送 main + 推送分支 + 开 PR
```

前提：本机需要 GitHub 凭据（`gh auth login`，或已配置 SSH key）。
脚本会在缺少凭据时**明确报错并给出替代命令**，不会静默失败。
