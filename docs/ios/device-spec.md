# iPhone 8 采购规格与验机清单（iOS 主线）

> 用途：**照着买、照着验**。本文档同时是 [`docs/adr/0002-return-to-ios.md`](../adr/0002-return-to-ios.md)
> 「主线切回 iOS」决策的依据留档。
>
> **性质标注约定**：✅ 官方明示 / 我第一手取到　🟡 权威社区文档　⚠️ 推断或**必须真机实测**。
> 价格一律是 ⚠️ 推断。

## 0. 一句话结论

| 项 | 结论 |
|---|---|
| 机型 | **iPhone 8（A11）**；8 Plus / iPhone X 同芯片同结论 |
| **iOS 版本** | **优先买已在 ≤16.6.1 的机器**；16.7.16 为备案 |
| 越狱工具 | **Dopamine**（rootless，semi-untethered） |
| 是否可行 | ✅ **可行**，且 iOS 侧**代码一行都不用改** |
| 最大风险 | **从 16.7.16 退不回 ≤16.6.1**（除非有该机 ECID 的 SHSH2 blobs）→ 版本必须买的时候就对 |

## 1. 为什么 iPhone 8 可行（这是 R14 推翻的旧结论）

R10 那轮曾用「palera1n 明确排除 arm64e」把 iPhone 8 / X 一并否定。**那个推论是错的**，
详见 [`handoff-device-jailbreak.md`](handoff-device-jailbreak.md) §2.1。事实是：

| 事实 | 来源 | 性质 |
|---|---|---|
| **Dopamine 支持 A8–A11**（原文 `A jailbreak for arm64 (A8 - A11) and arm64e (A12 - A17, M1 - M2)`）、**rootless**、A8–A13 覆盖 iOS 15.0–18.7.1 | [ellekit.space/dopamine](https://ellekit.space/dopamine/) | ✅ 官方明示 |
| palera1n 支持 **A8 through A11**，README 机型表明确列出 iPhone 8 / 8 Plus | [palera1n](https://github.com/palera1n/palera1n) 仓库描述 + README + man page | ✅ 官方明示 |
| man page 的 `arm64e devices will NEVER be supported` 指 **A12+**，且同页有 `On A11 devices, that is, iPhone 8, iPhone 8 Plus and iPhone X, the passcode cannot be used.` | palera1n man page | ✅ 官方明示 |

**结论**：iPhone 8（A11）被 **Dopamine 与 palera1n 双重支持**。

> **为什么"现在才"可行**：Dopamine **3.0（2026-08）** 新增 DarkSword / ClearSword 利用并修补
> A8 iPad 兼容性，**A10/A11 这类老设备因此才进入 16.7–16.7.16** 🟡。
> 这也解释了为什么 R10 那轮（更早）查到的矩阵里没有它们——**矩阵本身在变**，
> 这也是本次必须重新核实的第二个理由。

> ⚠️ **引用陷阱**：Dopamine 的 **GitHub README 是过期文本**（仍写「Rootless arm64e jailbreak for
> iOS 15.0 - 15.4.1」），与官网矩阵冲突。**判断支持范围必须看官网**
> <https://ellekit.space/dopamine/>，不要引用那个 README。

## 2. 机型与固件边界

| 型号标识 | 机型 | 固件区间 | 当前 Apple 签名 |
|---|---|---|---|
| `iPhone10,1` / `10,4` | iPhone 8 | **11.0 → 16.7.16** | **16.7.16** |
| `iPhone10,2` / `10,5` | iPhone 8 Plus | 11.0 → 16.7.16 | 16.7.16 |
| `iPhone10,3` / `10,6` | iPhone X | 11.1 → 16.7.16 | 16.7.16 |

来源：ipsw.me 实测查询（R14，6 个型号一致）✅。

> **对测试机是优点**：16.7.16 至今仍在签名 → 任何一台 iPhone 8 都能恢复到 16.7.16，
> **系统版本可复现**，实验室不会出现"每台机器版本都不一样"的问题。

**价位档**：⚠️ 推断（二手行情波动大，以闲鱼/淘宝实际为准）：

| 档位 | 机型 | 内存 | 推断价位 ⚠️ |
|---|---|---|---|
| 最低 | iPhone 8 | **2 GB** | ¥200–400 |
| **推荐** | **iPhone 8 Plus** | **3 GB** | **¥300–500** |
| 略高 | iPhone X | 3 GB | ¥400–700 |

> ⚠️ 价位是**推断**，本次**未取得可靠成交价数据**，请以实际行情为准。

### 2.1 为什么把 8 Plus 排在 8 前面（一个实质差异）

三者越狱能力**完全相同**（都是 A11），差别在**内存**与屏幕：

- **iPhone 8 只有 2 GB RAM**。cfw.guide 明确写：*2GB 内存的设备在 **iOS 15.8.7–15.8.8
  或 16.7 及以后**，Dopamine App 可能需要先 respring 一次才能越狱*。对一个要往里注入
  tweak、还要跑飞书（包体 ≈900 MB）的测试机，2 GB 是实打实的压力。
- **iPhone 8 Plus / X 是 3 GB**，且 8 Plus 屏幕更大（调试时可读性更好）。

**建议**：预算允许就买 **8 Plus**；坚持要 iPhone 8 也可以（尤其在 **≤16.6.1** 上，
上面那条 2GB 的额外步骤不适用）。

## 3. iOS 版本：优先 ≤16.6.1（TrollStore 是分水岭）

TrollStore 官方 README 原文：

> Supported versions: 14.0 beta 2 - **16.6.1**, 16.7 RC (20H18), 17.0
> **16.7.x (excluding 16.7 RC) and 17.0.1+ will NEVER be supported**

cfw.guide 的 Dopamine 安装页原文：

> If you are on iOS/iPadOS **16.7 or later** (excluding iOS/iPadOS 17.0), due to how
> semi-untethered jailbreaks work, the app will need to be **re-signed once every 7 days**.

| 目标版本 | Dopamine | TrollStore | 代价 |
|---|---|---|---|
| **≤16.6.1** 🟢 **选定** | ✅ | ✅ | 无。免重签；与仓库原假设（推荐 15.0–16.6.1）一致 |
| 16.7 RC (20H18) | ✅ | ✅ | 极罕见，实际买不到 |
| 16.7.16 🟡 备案 | ✅ | ❌ 官方明示永不支持 | **每 7 天用电脑重签 Dopamine**，或上付费开发者账号 |

> ⚠️ **采购硬约束**：Apple 只签 16.7.16，**从它无法退回 ≤16.6.1**。
> 所以 ≤16.6.1 **只能在成交时就在那个版本**——验机时**第一项**就查版本。

## 4. 越狱工具：选 Dopamine（不选 palera1n）

| | **Dopamine** 🟢 选定 | palera1n |
|---|---|---|
| 越狱类型 | **semi-untethered**：重启后点 App 图标即可，**不需要电脑** 🟡 | **semi-tethered**：**每次重启都要连电脑**跑一遍 ✅ 官方明示 |
| A11 密码限制 | 文档**未提**（⚠️ 待实测） | **官方明示不能设密码**；iOS 16 还需"自恢复出厂起就不能设" ✅ |
| 与仓库假设 | 完全一致：rootless `/var/jb`、Sileo、**ElleKit** | 也是 rootless `/var/jb`，但装机步骤不同 |
| 签名 | ≤16.6.1 用 TrollStore 免签（推荐路径） | 无签名问题（bootrom 漏洞） |
| **SSH** | Sileo 装 `openssh` → **局域网 22 端口**，部署脚本可直连 ✅ | 内置 SSH 在 **44 端口且只监听 loopback** → 脚本必须走 `iproxy` 隧道 ⚠️ |
| 无密码的根因 | — | **A11 的 SEP 无法 pwn**（这就是 A11 不能设锁屏密码的原因） |

> "不能设密码"的准确含义（palera1n man page）：iOS 15 上**越狱态必须无密码**；
> iOS 16 上**自恢复出厂起就不能有密码**（设置里的「抹掉所有内容和设置」也算一次恢复）。
> 另注意别混淆：palera1n 初始化时让你设的是 **SSH/命令行密码**，不是锁屏密码。

### 4.1 其他工具为什么不用（避免后来者重新踩）

| 工具 | 状态 | 判定 |
|---|---|---|
| **checkra1n** | 最新 0.12.4 beta，页脚 ©2019–2021，**事实停更**；A11 在 iOS 14+ 还需去密码 + Skip A11 BPR check | ❌ 覆盖不到 iOS 16 |
| unc0ver / Taurine / XinaA15 | **未查到可靠的一手现役矩阵**；可确定其版本上限均 < 16.7.16 | ❌ 目标版本上不可用 |
| **meowbrek2** | ElleKit README 列出，A8–A11 **iOS 15.0–15.8.1** 的 semi-untethered 工具 | 🟡 仅当最终停在 15.x 时的备选 |
| **palera1n** | 现役，但 A11 不能设密码 + 每次重启连电脑 | 🟡 备选（见上表） |

### 4.2 一个对 Hook 实现有利的发现

**ElleKit 官方 README 写明「Used by: palera1n (A8-A11, iOS 15.0+)」**，
且 ElleKit 实现了 **Substrate + libhooker API 兼容层** → **旧的 `MSHook*` 写法可以继续用** 🟡。

这对 `BG-030`（Hook 框架选型）是正面信息：Dopamine 与 palera1n 都落在 ElleKit 上，
所以框架层面**不需要为工具差异分叉**。

> ⚠️ 但 palera1n **自身文档未点名默认注入库**，且社区有"正从 Substitute 迁移到 ElleKit"的报道
> （低可信）。真机上用 `dpkg -l | grep -Ei 'ellekit|substitute'` 确认。

**Dopamine 安装 SOP（概要）**，依据 cfw.guide：

1. 电脑上用 **PlumeImpactor**（或 Sideloadly）把 Dopamine `.ipa` 侧载进设备；
2. 设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID；**iOS 16+ 还需开启开发者模式**
   （设置 → 隐私与安全性 → 开发者模式）；
3. 打开 Dopamine → 点 **Jailbreak**；Sileo 会装到桌面；
4. 在 Sileo 里装 **ElleKit** 与 **PreferenceLoader**；
5. **≤16.6.1 额外（强烈建议）**：Sileo 装 **TrollStore Helper** → 打开 TrollHelper →
   安装 TrollStore → 在 TrollStore 设置里装 **Persistence Helper**（选「提示」App）→
   重启后打开「提示」App 点 **Refresh App Registrations** → 用 TrollStore 永久安装 Dopamine
   （此后不用再担心 7 天过期）。

## 5. 目标 App 事实（⚠️ 发现一处**疑似真实缺陷**）

用 Apple 官方 lookup/search API 查得（R14，`country=cn`）：

| 产品 | BundleID | 最低系统 | 当前版本 |
|---|---|---|---|
| **国内版飞书**（App Store id `1401729613`） | **`com.bytedance.ee.lark`** | **iOS 13.0** | **8.2.18**（2026-10-13） |
| 国际版 Lark | `com.larksuite.lark` | iOS 13.0 | 8.1.25 |

> 取数说明：用 Apple `lookup?id=1401729613&country=cn`（权威记录）得 8.2.18；
> 同期用 `search?term=飞书` 得到的是 8.1.15 —— **以 lookup 为准**。
> 包体 **≈865 MiB**（907,027,456 B）——这个数字对 iPhone 8 的 2GB 内存有意义，见 §2.1。

**两个直接结论**：

1. ✅ **iPhone 8 装得上**，而且证据很硬：飞书元数据的 `minimumOsVersion = 13.0`，
   且 **`supportedDevices` 明确包含 `iPhone8` / `iPhone8Plus` / `iPhoneX`**。
   （R10 遗留的「目标 App 最低系统要求」疑问，就此关闭。）
2. ⚠️ **`shared/config/targets.json` 里的 `scope.bundle_ids` 是 `com.ss.iphone.ugc.Lark`，
   与实际不符**。若真机确认如此，**theos 过滤器会写错 BundleID → 插件根本不注入**，
   而且不会报错，属于"静默失效"。

**处置建议（未擅自改，等你确认）**：过滤器先**同时包含两个 ID**（`com.bytedance.ee.lark` 与
`com.ss.iphone.ugc.Lark`），等真机 `idevicesyslog` / `frida` 确认后再收敛。
已记为 **BG-061**。

> 参考：`com.ss.iphone.ugc.*` 是字节早期 iOS 命名（如抖音 `com.ss.iphone.ugc.Aweme`），
> 飞书已改用 `com.bytedance.ee.lark`——所以旧值可能是历史遗留。

## 6. 为什么 iOS 侧代码不用改

| 仓库假设 | iPhone 8 + Dopamine 的实际 | 是否一致 |
|---|---|---|
| `THEOS_PACKAGE_SCHEME = rootless` | Dopamine 是 rootless | ✅ |
| `/var/jb` 前缀（`layout/`、`deploy.sh`） | rootless 前缀就是 `/var/jb` | ✅ |
| `control` 的 `Depends: ellekit \| mobilesubstrate` | Dopamine 自带 Sileo，ElleKit 可装 | ✅ |
| `ARCHS = arm64 arm64e` | A11 = arm64e 设备，**需要 arm64e 切片** | ✅ 已具备 |
| `TARGET … :15.0`（部署目标） | 设备 16.x | ✅ |

## 7. 验机命令清单

### Step 0：本机准备（Arch）

```sh
sudo pacman -S libimobiledevice usbmuxd     # ideviceinfo / idevice_id / iproxy
idevice_id -l                               # 列出已连接设备
```

### Step 1：买之前（卖家截图或当面，**第一项就是版本**）

| 顺序 | 检查 | 路径 | 期望 |
|---|---|---|---|
| **1** | **iOS 版本** | 设置 → 通用 → 关于本机 | **≤ 16.6.1**（决定 TrollStore 与免重签） |
| 2 | 机型 | 同上 → 型号名称 | iPhone 8 / 8 Plus / X |
| 3 | 激活锁 / ID 锁 | 设置顶部是否还登着别人的 Apple ID；或问能否抹掉重激活 | **无锁**（有锁的机器等于砖） |
| 4 | 是否改版机 | 型号号码以 `M` 开头（`N`/`F` 开头为官换/翻新） | 知悉即可 |
| 5 | 电池健康 | 设置 → 电池 → 电池健康 | 建议 ≥80% |

### Step 2：到手后（连电脑）

```sh
ideviceinfo -k ProductType        # 期望 iPhone10,1（8）/ 10,4（8 GSM）/ 10,2（8P）...
ideviceinfo -k ProductVersion     # iOS 版本 —— 必须 ≤16.6.1（首选）或 16.7.16（备案）
ideviceinfo -k BuildVersion       # 构建号；应与你看到的版本对应（16.7 RC 是 20H18，16.7.16 是 20H392）
ideviceinfo -k SerialNumber
ideviceinfo -k UniqueDeviceID     # UDID
ideviceinfo -k UniqueChipID       # ECID —— 记下来，将来要 SHSH2 blobs 就靠它
ideviceinfo -k IMEI
ideviceinfo -k ActivationState    # 期望 Activated
ideviceinfo -k RegionInfo         # 销售地区，如 CH/A
ideviceinfo -k ModelNumber        # M=零售 N=官换 F=官翻 P=定制
ideviceinfo                       # 整机全量信息（不带 -k），留档用
```

**防改版**：`ProductVersion` + `BuildVersion` 必须与屏幕上显示的一致——不一致即为改版机或刷过机。

**屏幕原装性**（换屏机是实质风险，cfw.guide 明示越狱后触控可能失灵）：
检查**原彩显示（True Tone）能否开关**（换屏常丢失）、3D Touch 全区域可用。

**激活锁的终极验证**：`设置 → 通用 → 传输或还原 iPhone → 抹掉所有内容和设置`，
然后联网激活；若停在 Activation Lock 要求输入**前任** Apple ID = ID 锁，**直接拒收**。

**电池**：`设置 → 电池 → 电池健康`（iPhone 8 不显示循环次数，那是 iPhone 15 及以后的功能）。
命令侧可试 `idevicediagnostics ioregentry AppleSmartBattery`（参数名随版本，先看 `--help`）。

> ⚠️ 诚实标注：`ModelNumber` 前缀含义、屏幕原装性判据、`idevicediagnostics` 的可用性
> 属**社区经验/推断，未实测**；以「能正常激活 + 能登录自己的 Apple ID + 触摸正常」为准。

### Step 3：越狱完成后

**Dopamine 路线**（我们选定的）：在 Sileo 里装 `openssh` → **局域网 22 端口直连**，
部署脚本（`ios/scripts/deploy.sh`）可直接用：

```sh
ssh root@<设备IP> 'id; ls -d /var/jb; echo $PATH'
ssh root@<设备IP> '/var/jb/usr/bin/dpkg -l | grep -iE "ellekit|preferenceloader|openssh"'
ssh root@<设备IP> 'ls /var/jb/Library/MobileSubstrate/DynamicLibraries/'
```

**若改走 palera1n 路线**（备选）：内置 SSH 在 **44 端口且只监听 loopback**，
必须走 USB 转发，且**每次重启后隧道消失**：

```sh
iproxy 2222 44 &                     # 隧道
ssh -p 2222 root@127.0.0.1 'id'      # 之后同上
```

> ⚠️ 这条差异会影响"能否无人值守自动部署"：**palera1n 做不到**（重启即需人工介入），
> 这也是选 Dopamine 的工程理由之一。

**越狱可行性预检（可选）**：进 DFU 后 `palera1n -I` 打印设备信息，
或直接试跑一次看能否进入越狱态（同时验证 USB 线材——建议用 USB-A to Lightning）。

## 8. 风险与红线

| # | 风险 | 性质 | 应对 |
|---|---|---|---|
| 1 | **买到的机器已在 16.7.x** → 用不了 TrollStore，需每 7 天重签 | ✅ TrollStore/cfw.guide 官方明示 | 验机第一项查版本；已买错则改走 palera1n（但代价是不能设密码 + 每次重启连电脑） |
| 2 | **激活锁/iCloud 锁**的二手 iPhone 8 无法使用 | ⚠️ 推断（常识） | 到手当面抹掉重激活再付款 |
| 3 | **Dopamine 是否要求关闭密码**未明示 | ⚠️ **待实测** | 装完先设密码试越狱；失败则关闭密码 |
| 4 | A11 是 arm64e，palera1n 文档 "arm64e excluded" 的措辞是否影响注入行为 | ⚠️ **待实测** | 我们选 Dopamine，避开了这个不确定性；但 tweak 的 arm64e 切片必须保留 |
| 5 | **过滤器 BundleID 可能写错**（§5） | ⚠️ **待真机确认** | 先同时包含两个 ID |
| 6 | 目标 App 有越狱检测 | ⚠️ **待实测** | 真遇到用 Dopamine 的隐藏选项 / 换 iOS 15 试 |
| 7 | 二手 iPhone 8 屏幕/电池老化 | ⚠️ 推断 | 买前问电池健康；屏幕是否原装（有第三方屏会导致越狱后触摸失灵，cfw.guide 明示） |

## 9. 来源与性质汇总

| 事实 | 来源 | 性质 |
|---|---|---|
| Dopamine 支持 A8–A11、rootless、A8–A13 覆盖 15.0–18.7.1 | [官方站点](https://ellekit.space/dopamine/) | ✅ 官方明示（第一手） |
| Dopamine 是 semi-untethered；16.7+ 需每 7 天重签；≤16.6.1 可装 TrollStore | [cfw.guide](https://ios.cfw.guide/installing-dopamine/) | 🟡 权威社区文档 |
| Dopamine 安装步骤（PlumeImpactor / 开发者模式 / ElleKit + PreferenceLoader） | 同上 | 🟡 权威社区文档 |
| TrollStore 支持 14.0b2–16.6.1 / 16.7 RC / 17.0；16.7.x 正式版永不支持 | [opa334/TrollStore README](https://github.com/opa334/TrollStore) | ✅ 官方明示 |
| palera1n 支持 A8–A11，机型表含 iPhone 8；A11 不能设密码；semi-tethered | [palera1n](https://github.com/palera1n/palera1n) 描述/README/[man page](https://raw.githubusercontent.com/palera1n/palera1n/main/docs/palera1n.1) | ✅ 官方明示 |
| iPhone 8/8P/X 固件 11.0/11.1 → 16.7.16，当前签名 16.7.16 | ipsw.me 实测 | ✅ 实测（我查的） |
| 飞书 iOS = `com.bytedance.ee.lark`，最低 iOS 13.0，版本 8.1.15 | Apple lookup/search API（`country=cn`） | ✅ 官方 API |
| Lark 国际版 = `com.larksuite.lark`，最低 iOS 13.0 | 同上 | ✅ 官方 API |
| 各档位价格 | — | ⚠️ **推断**，无可靠来源 |

## 10. 必须真机实测才能确认的项

1. Dopamine 越狱后**能否保留密码**；
2. 目标 App 的真实 BundleID（决定过滤器必须包含哪些值）与**越狱检测**情况；
3. 飞书在 iOS 16.x + Dopamine 下能否正常启动、能否触发 Wi-Fi 信息读取（BG-011 抓栈）；
4. A11（arm64e）上 tweak 的注入与切片行为；
5. 设备端 Procursus 工具链在 iOS 16.x 上的可用包版本（方案 C 的前提，见
   [`ondevice-build-setup.md`](ondevice-build-setup.md)）。
