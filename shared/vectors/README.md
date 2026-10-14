# shared/vectors — 语言中立测试向量（R13 填充）

本目录为空壳，R13 落地。规划内容：

| 文件 | 内容 |
|---|---|
| `bssid-map.json` | 映射用例：`(ssid, real_bssid) -> 期望返回值`，含归一化、格式跟随、规则优先级、nil 语义、非法值拒绝 |
| `auth-gate.json` | 授权闸用例：`(配置快照, 进程 bundle id) -> 期望判定 + 责任字段` |

**用途**：iOS 的纯 C 核心（`ios/hooks/BGGhostRules.c`、`BGGhostAuth.c`）与 Android 的 Java 核心
（R14）必须**跑同一份向量并得到相同结论**。这是本次双端化里防止「两端行为漂移」的核心机制。

现阶段这些用例以硬编码断言的形式存在于 `ios/tests/host/test_bgg_rules.c`（56 条）
与 `test_bgg_auth.c`（36 条）中——R13 的任务就是把它们**抽取**成数据，
再让两端都从数据驱动执行，且**不减少覆盖**。
