//
//  BGGhostAuth.h
//  BSSIDGhost
//
//  授权闸与作用域判定的**纯 C 核心**：不依赖 Foundation / ObjC 运行时，
//  因此可以在主机上用 ios/tests/host/ 的单测覆盖（对应测试矩阵 T8 / T9）。
//
//  这是本项目刻意设计的「安全闸」：未登记授权的环境**不会静默生效**。
//  约定：
//    - authorization 下 6 个字段必须全部填齐且不等于占位符 `fill_me`；
//    - constraints 三项必须全部开启（只测试设备 / 只测试网络 / 不针对生产目标）；
//    - scope.mode 必须显式声明且合法；allowlist 模式下必须有 bundle id；
//    - 当前进程必须落在作用域内（非 App 进程一律跳过）。
//  任一条不满足 -> 拒绝启用，并给出**可定位的字段名与原因**。
//

#ifndef BG_GHOST_AUTH_H
#define BG_GHOST_AUTH_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 单个授权字段的最大长度（含 NUL）。
#define BG_AUTH_FIELD_MAX 128
/// allowlist 允许登记的 BundleID 数量上限。
#define BG_AUTH_MAX_BUNDLES 8
/// BundleID 字符串最大长度（含 NUL）。
#define BG_BUNDLE_ID_MAX 128
/// scope.mode 字符串最大长度（含 NUL）。
#define BG_SCOPE_MODE_MAX 16

/// 授权字段的稳定索引。新增字段时同步更新 kBGAuthFieldNames。
typedef enum {
    BG_AUTH_FIELD_TARGET_APP_OWNER = 0,
    BG_AUTH_FIELD_AUTHORIZED_BY,
    BG_AUTH_FIELD_AUTHORIZATION_REF,
    BG_AUTH_FIELD_PURPOSE,
    BG_AUTH_FIELD_TEST_DEVICE,
    BG_AUTH_FIELD_TEST_AP,
    BG_AUTH_FIELD_COUNT
} BGAuthField;

/// 判定结果。0 即通过，便于 `if (decision.result)` 直接判断。
typedef enum {
    BG_AUTH_OK = 0,
    BG_AUTH_ERR_AUTH_MISSING,     ///< 授权字段为空
    BG_AUTH_ERR_AUTH_PLACEHOLDER, ///< 授权字段仍是 fill_me
    BG_AUTH_ERR_CONSTRAINTS,      ///< constraints 未全部开启
    BG_AUTH_ERR_SCOPE_MODE,       ///< scope.mode 缺失或非法
    BG_AUTH_ERR_SCOPE_EMPTY,      ///< allowlist 模式下没有任何 BundleID
    BG_AUTH_ERR_PROCESS_SCOPE     ///< 当前进程不在作用域内
} BGAuthResult;

/// 判定结果 + 责任字段。field 为静态字符串（形如 `authorization.test_ap`），
/// 不适用时可为 NULL；调用方不得释放。
typedef struct {
    BGAuthResult result;
    const char *field;
} BGAuthDecision;

/// 授权与作用域配置（由 ObjC 侧从 targets.json 填充）。
typedef struct {
    char scope_mode[BG_SCOPE_MODE_MAX];
    char bundle_ids[BG_AUTH_MAX_BUNDLES][BG_BUNDLE_ID_MAX];
    int  bundle_id_count;

    char fields[BG_AUTH_FIELD_COUNT][BG_AUTH_FIELD_MAX];

    int only_test_devices;
    int only_test_network;
    int no_production_targets;
} BGAuthConfig;

/// 归零初始化。使用前必须调用（或 memset 0）。
void BGGhostAuthConfigInit(BGAuthConfig *cfg);

/// 按 JSON 键名写入授权字段。
/// @param name  `target_app_owner` / `authorized_by` / `authorization_ref` /
///              `purpose` / `test_device` / `test_ap`
/// @return 1 = 已写入；0 = 键名未知 / 参数非法 / 值超出长度上限。
int BGGhostAuthConfigSetField(BGAuthConfig *cfg, const char *name, const char *value);

/// 设置 scope.mode（"allowlist" / "all"）。
void BGGhostAuthConfigSetScopeMode(BGAuthConfig *cfg, const char *mode);

/// 追加一个作用域 BundleID。
/// @return 1 = 已添加；0 = 参数非法 / 超长 / 已满。
int BGGhostAuthConfigAddBundleID(BGAuthConfig *cfg, const char *bundle_id);

/// 设置 constraints 三项开关（非 0 即视为开启）。
void BGGhostAuthConfigSetConstraints(BGAuthConfig *cfg,
                                     int only_test_devices,
                                     int only_test_network,
                                     int no_production_targets);

/// 字段名（静态字符串），供日志与测试引用。
const char *BGGhostAuthFieldName(BGAuthField field);

/// 判定结果的中文说明（静态字符串）。
const char *BGGhostAuthResultDescription(BGAuthResult result);

/// 完整判定：先查授权信息与约束，再查作用域配置，最后查当前进程。
/// @param bundle_id 当前进程的 BundleID，可为 NULL/空（非 App 进程）。
BGAuthDecision BGGhostAuthCheckProcess(const BGAuthConfig *cfg, const char *bundle_id);

#ifdef __cplusplus
}
#endif

#endif /* BG_GHOST_AUTH_H */
