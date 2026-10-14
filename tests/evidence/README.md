# 证据目录

真机抓栈与测试矩阵（T1–T10）的原始输出与结论摘要放这里。
**结论必须能追溯到原始输出**，不接受只有文字描述的"实测通过"。

## 命名

| 类型 | 文件名 |
|---|---|
| 抓栈原始输出 | `<YYYYMMDD-HHMMSS>-capture.jsonl`（冷启动）<br>`<YYYYMMDD-HHMMSS>-attach-<进程名>.jsonl`（附加） |
| 抓栈结论摘要 | `<YYYYMMDD-HHMMSS>-capture.md`（与上面同名，扩展名不同） |
| 测试矩阵执行记录 | `T<n>-<简述>.md`，例如 `T2-bssid-replaced.md` |
| 日志片段 | `T<n>-ghost.log`（`*.log` 已被 `.gitignore` 忽略，需脱敏后手动 `git add -f`） |

## 每条证据摘要必须包含

```markdown
# <标题>

- 日期：YYYY-MM-DD
- 设备型号：<ideviceinfo -k ProductType>
- iOS 版本：<ideviceinfo -k ProductVersion>
- 越狱类型：Dopamine / rootless (/var/jb)
- 目标 App 与版本：<bundle id> / <版本号>
- 授权引用：<shared/config/targets.json 的 authorization_ref>
- 主机 frida 版本 / 设备 frida-server 版本：<必须一致>
- 原始输出：<同目录 jsonl 文件名>

## 期望

<本次要验证什么，对应 tests/README.md 的哪条 T 用例>

## 实测

<关键 JSONL 行摘录（脱敏后的原文），以及调用栈要点>

## 结论

- [ ] 与期望一致
- [ ] 与期望不一致 —— 差异说明：

## 对文档的更新

<本结论改动了 tech-chain.md / STATUS.md 的哪些行；「实测」还是「外部资料待复验」>
```

## 纪律

1. **实测与外部资料严格分开**：来自博客/仓库的结论（如 nehelper XPC）一律标注
   「外部资料，待真机验证」，只有本目录下的证据才能写成「实测」。
2. **脱敏**：真实 SSID / BSSID / UDID / 账号信息按需打码，但**打码规则要写进摘要**，
   否则后续无法复现。
3. **失败也要留痕**：设备连不上、版本不匹配、类不存在的输出同样入库 —— 这些是
   排除候选 Hook 点的有效证据。
