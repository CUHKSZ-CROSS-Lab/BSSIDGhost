# B 线：真机调用栈抓取

本目录存放**只读**抓栈工具：不修改任何返回值，只记录目标 App 通过哪些接口读到了 Wi-Fi 信息。

| 文件 | 用途 |
|---|---|
| [`capture-wifi-api.js`](capture-wifi-api.js) | Frida 抓栈脚本（ObjC 通道 + C 函数 + nehelper XPC 边界 + 接口 MAC 对照） |
| [`../../docs/device-setup.md`](../../docs/device-setup.md) | 设备与主机准备 SOP（frida-server、iproxy、验证清单、故障排查） |
| [`../evidence/README.md`](../evidence/README.md) | 证据命名与摘要模板 |

## 用法

```sh
# 冷启动（能抓到启动阶段的读取）
frida -U -f com.ss.iphone.ugc.Lark \
      -l tests/frida/capture-wifi-api.js \
      -o tests/evidence/$(date +%Y%m%d-%H%M%S)-capture.jsonl

# 附加到已运行进程
frida -U -n Lark -l tests/frida/capture-wifi-api.js -o tests/evidence/attach-capture.jsonl
```

> ⚠️ 授权闸：`config/targets.json` 的授权字段未填齐前**不要对目标 App 执行**。
> 本机当前也未安装 frida（R1 决定），因此这是**已就绪但未执行**的工具。

## 覆盖的观察点

| 来源 | 观察点 | 回答的问题 |
|---|---|---|
| `objc` | `CWFInterface -bssid` / `-ssid`、`CWInterface -bssid`、`CWNetwork -bssid`、`CWWiFiClient -interface`、`NEHotspotNetwork -BSSID/-SSID`、`+fetchCurrentWithCompletionHandler:` | 目标 App 到底调了哪个接口？返回值是 `NSString` / `NSData` / 其它？ |
| `cfunc` | `CNCopyCurrentNetworkInfo` | 是否走已废弃的 SystemConfiguration 通道？字典里有哪些键？ |
| `xpc` | `xpc_dictionary_set_string/uint64`（请求侧）、`xpc_dictionary_get_value("result-data")`、`xpc_dictionary_get_string("SSID"/"BSSID")`（应答侧） | **是否所有通道都汇入 `com.apple.nehelper`**（对应 tech-chain §2.1） |
| `cfunc` | `getifaddrs` → `AF_LINK` | en0 接口 MAC 是多少（用于证明「接口 MAC ≠ AP BSSID」） |

## 输出格式

每行一个 JSON 对象（JSONL）：

```json
{"src":"objc","kind":"method","cls":"CWFInterface","sel":"- bssid",
 "ret":{"class":"__NSCFString","string":"aa:bb:cc:dd:ee:ff"},
 "selfClass":"CWFInterface","selfPtr":"0x...","bt":["...","..."],"t":1234}
```

关键字段：`src`（来源分类）、`kind`（事件类型）、`ret`（返回值形态与内容）、`bt`（调用栈）。

## 已知限制（务必连同结论一起记录）

1. **嵌套调用被折叠**：为降低噪声，被 hook 实现内部的嵌套调用只记最外层（`gObjcDepth`）。
   因此「App 调 A、A 内部调 B」只会看到 A；B 单独被 App 直接调用时仍会记录。
2. **XPC 异步应答**：异步路径（`xpc_connection_send_message_with_reply`）的应答不经过
   `_sync` 返回；本脚本通过 hook **应答读取函数**（`xpc_dictionary_get_value("result-data")`
   与 `xpc_dictionary_get_string("BSSID")`）来覆盖它，因此只要调用方解析应答就会被记录。
3. **XPC 请求字段**依赖 App 用 `xpc_dictionary_set_string/uint64` 构造请求；
   若用其它构造方式（`xpc_dictionary_create` + 直接写内存），请求侧会缺失，但应答侧不受影响。
4. **`getifaddrs` 结构体偏移**按 64 位 Darwin 布局写死；若解析异常会记录
   `{"kind":"getifaddrs-error"}` 而不会中断脚本。
5. **XPC 写侧 hook 开销**：`xpc_dictionary_set_string` / `set_uint64` 在整个进程内调用极频繁，
   每次都要读 key 字符串做比较。若观察到被测 App 明显变慢或行为异常，
   把 `CONFIG.hookXpcWrites` 置为 `false`（应答侧覆盖不受影响）。
6. **本机未执行过**：脚本仅通过 `node --check` 语法校验，**尚未在任何设备上实跑**。
   首次真机执行后必须把「实测结论」与「脚本预期」的差异回写本文件。

## 相关文档

- [`docs/tech-chain.md`](../../docs/tech-chain.md) §2 / §2.1：候选 Hook 点与 nehelper 增量
- [`docs/STATUS.md`](../../docs/STATUS.md)：BG-011 / BG-012 / BG-013 的状态
- [`tests/README.md`](../README.md)：T1–T10 测试矩阵
