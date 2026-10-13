# 真机准备与抓栈 SOP（B 线 / BG-011）

> **前置约束**：本项目只用于**自有或已获书面授权**的测试 App 与受控测试机（见
> [`README.md`](../README.md) 的「用途与授权要求」）。当前 `config/targets.json` 的授权字段
> 仍为 `fill_me`，按 R1 决策**先按未授权处理** —— 本文件是**准备清单**，
> **授权填齐前不要对目标 App 执行抓栈**。

## 1. 目标形态（已确认）

| 项 | 值 |
|---|---|
| 越狱 | Dopamine（**rootless**） |
| iOS | 15.0 – 16.6.x |
| 路径前缀 | `/var/jb` |
| 运行时 | ElleKit |

## 2. 主机侧前置

| 需要 | 本机状态 | 说明 |
|---|---|---|
| `frida` CLI | ❌ **未安装** | R1 决定「都先不装」。执行抓栈前必须先装，见下 |
| `frida` 与 `frida-server` 版本 | — | **必须完全一致**，否则连接会失败或行为异常 |
| `usbmuxd` | 需确认 | `frida -U` 走 USB 时需要；`idevice_id -l` 能列设备即说明可用 |
| `iproxy`（libimobiledevice） | ✅ 已装 | 走 USB 转发 SSH：`iproxy 2222 22` |

安装 frida 的两条路径（**需用户批准后执行**，本仓库不自动安装）：

- Python：`pip3 install frida-tools` —— 本机 **无 pip**，需要先装 pip/pipx。
- Node：`npm i -g frida`（本机 npm 可用；`registry.npmjs.org` 不可达，
  需走 npmmirror：`npm i -g frida --registry=https://registry.npmmirror.com`）。
  Node 路径只提供绑定库；CLI 抓栈仍推荐 Python 版 `frida-tools`。

## 3. 设备侧：部署 frida-server

```sh
# 1) 确认设备可见
idevice_id -l

# 2) 设备型号 / iOS 版本（记录到 tests/evidence/）
ideviceinfo -k ProductType
ideviceinfo -k ProductVersion

# 3) USB 转发 SSH（另开一个终端保持）
iproxy 2222 22

# 4) 登录设备（Dopamine 通常为 mobile + sudo 提权，口令按你机器实际设置）
ssh -p 2222 mobile@127.0.0.1
```

在设备上：

```sh
# 版本必须与主机 frida --version 完全一致
# 下载 frida-server-<VER>-ios-arm64.xz 后解压
# rootless 布局：放进 /var/jb 前缀下
sudo mkdir -p /var/jb/usr/sbin
sudo cp frida-server-<VER>-ios-arm64 /var/jb/usr/sbin/frida-server
sudo chmod 755 /var/jb/usr/sbin/frida-server

# 后台启动（-D 让 frida-server 自身 daemon 化）
sudo /var/jb/usr/sbin/frida-server -D

# 确认在跑
ps aux | grep frida-server
```

> ⚠️ 不要写入 rootful 的 `/usr/sbin` 或 `/usr/lib` —— 本项目的越狱形态不适用。

## 4. 主机侧验证

```sh
frida --version            # 必须等于设备上 frida-server 的版本
frida-ps -U                # 能列出进程 = 通道打通
frida -U -f com.ss.iphone.ugc.Lark -l tests/frida/capture-wifi-api.js -o tests/evidence/<时间戳>-capture.jsonl
```

`-f` 是冷启动（能抓到启动阶段的调用），`-n <进程名>` 是附加到已运行进程。
抓栈期间在被测 App 内触发 Wi-Fi 信息读取（进入「网络诊断」类页面、下拉刷新等）。

## 5. 验证清单

- [ ] `idevice_id -l` 能列出测试机 UDID
- [ ] `ideviceinfo -k ProductVersion` 落在 15.0–16.6.x
- [ ] 主机 `frida --version` == 设备 `frida-server` 版本
- [ ] `frida-ps -U` 能列出进程
- [ ] 抓栈输出中出现 `{"src":"meta","kind":"start"}` 与 `{"kind":"ready"}`
- [ ] 至少出现一个 `{"src":"objc"}` 或 `{"src":"xpc"}` 事件
- [ ] `{"src":"cfunc","kind":"interface-macs"}` 中的 en0 MAC **不等于** 抓到的 BSSID
      （证明「接口 MAC ≠ AP BSSID」这一关键区分）

## 6. 常见故障

| 现象 | 原因 / 处理 |
|---|---|
| `unable to connect to remote frida-server` | 版本不匹配，或 frida-server 未启动，或端口/USB 通道未建立 |
| `frida-ps -U` 报 `Unable to retrieve device list` | usbmuxd 未运行 / 数据线未解锁配对；先 `idevice_id -l` 排查 |
| ObjC 事件全无 `class-missing` | 目标 iOS 版本没有该类；把日志作为「该通道不存在」的证据记录 |
| 只有 `xpc` 事件、没有 `objc` 事件 | 说明该 App 直接走 nehelper XPC，映射逻辑的 Hook 落点应选 XPC 边界（见 `docs/tech-chain.md` §2.1） |
| 什么都没有 | 触发时机不对（Wi-Fi 信息可能只在冷启动读取一次），改用 `-f` 冷启动并记录启动全流程 |
| 输出过大 | 调小脚本顶部 `CONFIG.maxBacktrace`，或关闭 `hookXpcStringReads` |

## 7. 结果处理

1. 原始输出存 `tests/evidence/<YYYYMMDD-HHMMSS>-capture.jsonl`（`.gitignore` 只忽略大文件，
   JSONL 证据应入库；若含敏感信息则脱敏后再提交）。
2. 按 [`tests/evidence/README.md`](../tests/evidence/README.md) 补一份同名 `.md` 摘要。
3. 把结论回写到 [`docs/tech-chain.md`](tech-chain.md) §2 表格与
   [`docs/STATUS.md`](STATUS.md) 的 BG-011/BG-012 行，并明确区分「实测」与「外部资料」。
