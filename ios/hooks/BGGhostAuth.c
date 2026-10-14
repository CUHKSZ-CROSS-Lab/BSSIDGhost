//
//  BGGhostAuth.c
//  BSSIDGhost
//
//  授权闸与作用域判定的纯 C 实现。见 BGGhostAuth.h。
//
//  本文件刻意不引入任何 Foundation / ObjC 依赖，唯一目的是让「能不能启用」
//  这个安全决策能在主机上用 ios/tests/host/ 直接编译并跑单测（T8 / T9）。
//

#include "BGGhostAuth.h"

#include <string.h>

#pragma mark - 静态表

static const char *const kBGAuthFieldNames[BG_AUTH_FIELD_COUNT] = {
    "authorization.target_app_owner",
    "authorization.authorized_by",
    "authorization.authorization_ref",
    "authorization.purpose",
    "authorization.test_device",
    "authorization.test_ap"
};

/// 与 kBGAuthFieldNames 一一对应的 JSON 键名。
static const char *const kBGAuthFieldKeys[BG_AUTH_FIELD_COUNT] = {
    "target_app_owner",
    "authorized_by",
    "authorization_ref",
    "purpose",
    "test_device",
    "test_ap"
};

/// 占位符：出现即视为「未登记授权」。
static const char *const kBGAuthPlaceholder = "fill_me";

#pragma mark - 内部工具

static int bg_str_empty(const char *s) {
    return (s == NULL || s[0] == '\0');
}

static int bg_isspace(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

/// 缺值判定：NULL 或**全为空白**都视为未填写 —— 避免用一个空格绕过授权闸。
static int bg_value_missing(const char *s) {
    if (s == NULL) {
        return 1;
    }
    for (const char *p = s; *p != '\0'; p++) {
        if (!bg_isspace(*p)) {
            return 0;
        }
    }
    return 1;
}

/// 长度受限的字符串拷贝；超长返回 0（而不是截断），避免把半截值当合法。
static int bg_copy_bounded(char *dst, size_t cap, const char *src) {
    size_t len = strlen(src);
    if (len + 1 > cap) {
        return 0;
    }
    memcpy(dst, src, len + 1);
    return 1;
}

/// ASCII 小写化，仅用于占位符比较。
static char bg_lower(char c) {
    return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

/// 忽略前后空白、大小写不敏感地判断是否等于占位符 `fill_me`。
static int bg_is_placeholder(const char *s) {
    if (s == NULL) {
        return 0;
    }
    const char *p = s;
    while (bg_isspace(*p)) {
        p++;
    }
    size_t i = 0;
    while (p[i] != '\0' && kBGAuthPlaceholder[i] != '\0') {
        if (bg_lower(p[i]) != kBGAuthPlaceholder[i]) {
            return 0;
        }
        i++;
    }
    if (kBGAuthPlaceholder[i] != '\0') {
        return 0; // 占位符尚未匹配完（值比 fill_me 短）
    }
    while (bg_isspace(p[i])) {
        i++;
    }
    return p[i] == '\0' ? 1 : 0;
}

static int bg_strings_equal(const char *a, const char *b) {
    if (a == NULL || b == NULL) {
        return 0;
    }
    return strcmp(a, b) == 0;
}

static BGAuthDecision bg_make_decision(BGAuthResult result, const char *field) {
    BGAuthDecision decision;
    decision.result = result;
    decision.field = field;
    return decision;
}

#pragma mark - 公开 API

void BGGhostAuthConfigInit(BGAuthConfig *cfg) {
    if (cfg == NULL) {
        return;
    }
    memset(cfg, 0, sizeof(*cfg));
}

const char *BGGhostAuthFieldName(BGAuthField field) {
    if (field < 0 || field >= BG_AUTH_FIELD_COUNT) {
        return "authorization.<unknown>";
    }
    return kBGAuthFieldNames[field];
}

const char *BGGhostAuthResultDescription(BGAuthResult result) {
    switch (result) {
        case BG_AUTH_OK:
            return "通过";
        case BG_AUTH_ERR_AUTH_MISSING:
            return "授权字段为空";
        case BG_AUTH_ERR_AUTH_PLACEHOLDER:
            return "授权字段仍为占位符 fill_me";
        case BG_AUTH_ERR_CONSTRAINTS:
            return "constraints 未全部开启（只测试设备 / 只测试网络 / 不针对生产目标）";
        case BG_AUTH_ERR_SCOPE_MODE:
            return "scope.mode 缺失或非法（应为 allowlist 或 all）";
        case BG_AUTH_ERR_SCOPE_EMPTY:
            return "scope.mode 为 allowlist 但未登记任何 BundleID";
        case BG_AUTH_ERR_PROCESS_SCOPE:
            return "当前进程不在作用域内";
    }
    return "未知原因";
}

int BGGhostAuthConfigSetField(BGAuthConfig *cfg, const char *name, const char *value) {
    if (cfg == NULL || bg_str_empty(name) || value == NULL) {
        return 0;
    }
    for (int i = 0; i < BG_AUTH_FIELD_COUNT; i++) {
        if (bg_strings_equal(name, kBGAuthFieldKeys[i])) {
            return bg_copy_bounded(cfg->fields[i], BG_AUTH_FIELD_MAX, value);
        }
    }
    return 0; // 未知键名：宁可拒绝，也不静默忽略拼错的字段
}

void BGGhostAuthConfigSetScopeMode(BGAuthConfig *cfg, const char *mode) {
    if (cfg == NULL) {
        return;
    }
    cfg->scope_mode[0] = '\0';
    if (mode == NULL) {
        return;
    }
    (void)bg_copy_bounded(cfg->scope_mode, BG_SCOPE_MODE_MAX, mode);
}

int BGGhostAuthConfigAddBundleID(BGAuthConfig *cfg, const char *bundle_id) {
    if (cfg == NULL || bg_str_empty(bundle_id)) {
        return 0;
    }
    if (cfg->bundle_id_count >= BG_AUTH_MAX_BUNDLES) {
        return 0;
    }
    if (!bg_copy_bounded(cfg->bundle_ids[cfg->bundle_id_count], BG_BUNDLE_ID_MAX, bundle_id)) {
        return 0;
    }
    cfg->bundle_id_count++;
    return 1;
}

void BGGhostAuthConfigSetConstraints(BGAuthConfig *cfg,
                                     int only_test_devices,
                                     int only_test_network,
                                     int no_production_targets) {
    if (cfg == NULL) {
        return;
    }
    cfg->only_test_devices = only_test_devices ? 1 : 0;
    cfg->only_test_network = only_test_network ? 1 : 0;
    cfg->no_production_targets = no_production_targets ? 1 : 0;
}

BGAuthDecision BGGhostAuthCheckProcess(const BGAuthConfig *cfg, const char *bundle_id) {
    if (cfg == NULL) {
        return bg_make_decision(BG_AUTH_ERR_AUTH_MISSING, NULL);
    }

    // 1) 授权信息必须填齐：这是最高优先的闸门 —— 未授权时连
    //    「当前进程是否在作用域」都不参与决策，避免给出误导性的放行路径。
    for (int i = 0; i < BG_AUTH_FIELD_COUNT; i++) {
        const char *value = cfg->fields[i];
        if (bg_value_missing(value)) {
            return bg_make_decision(BG_AUTH_ERR_AUTH_MISSING, kBGAuthFieldNames[i]);
        }
        if (bg_is_placeholder(value)) {
            return bg_make_decision(BG_AUTH_ERR_AUTH_PLACEHOLDER, kBGAuthFieldNames[i]);
        }
    }

    // 2) 三项使用约束必须全部开启。
    if (!cfg->only_test_devices || !cfg->only_test_network || !cfg->no_production_targets) {
        return bg_make_decision(BG_AUTH_ERR_CONSTRAINTS, "constraints");
    }

    // 3) 作用域声明必须合法且非空。
    const int is_allowlist = bg_strings_equal(cfg->scope_mode, "allowlist");
    const int is_all = bg_strings_equal(cfg->scope_mode, "all");
    if (!is_allowlist && !is_all) {
        return bg_make_decision(BG_AUTH_ERR_SCOPE_MODE, "scope.mode");
    }
    if (is_allowlist && cfg->bundle_id_count <= 0) {
        return bg_make_decision(BG_AUTH_ERR_SCOPE_EMPTY, "scope.bundle_ids");
    }

    // 4) 当前进程必须落在作用域内。非 App 进程（无 BundleID）一律跳过。
    if (bg_str_empty(bundle_id)) {
        return bg_make_decision(BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");
    }
    if (is_allowlist) {
        int matched = 0;
        for (int i = 0; i < cfg->bundle_id_count; i++) {
            // BundleID 大小写敏感，按字节精确比较。
            if (bg_strings_equal(cfg->bundle_ids[i], bundle_id)) {
                matched = 1;
                break;
            }
        }
        if (!matched) {
            return bg_make_decision(BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");
        }
    }

    return bg_make_decision(BG_AUTH_OK, NULL);
}
