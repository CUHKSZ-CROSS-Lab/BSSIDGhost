//
//  test_bgg_auth.c
//  BSSIDGhost - 主机侧单测（L1：不依赖真机、不依赖 ObjC）
//
//  覆盖 tests/README.md 中的：
//    T8 作用域（非目标 App 中 Hook 不生效）
//    T9 授权闸（授权字段未填齐 -> 拒绝启用并给出原因）
//    以及占位符/空白值绕过、约束开关、作用域声明、字段名映射等边界。
//
//  运行：tests/host/run.sh
//

#include "../../hooks/BGGhostAuth.h"

#include <stdio.h>
#include <string.h>

static int g_pass = 0;
static int g_fail = 0;

static void report(int ok, const char *name, const char *detail) {
    if (ok) {
        g_pass++;
        printf("  ok   %s\n", name);
    } else {
        g_fail++;
        printf("  FAIL %s%s%s\n", name, detail ? "  -- " : "", detail ? detail : "");
    }
}

static void expect_int(const char *name, int got, int want) {
    char detail[128];
    if (got != want) {
        snprintf(detail, sizeof(detail), "got=%d want=%d", got, want);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

/// 断言判定结果与责任字段。
static void expect_decision(const char *name,
                            const BGAuthConfig *cfg,
                            const char *bundle_id,
                            BGAuthResult want_result,
                            const char *want_field) {
    BGAuthDecision d = BGGhostAuthCheckProcess(cfg, bundle_id);
    char detail[256];
    if (d.result != want_result) {
        snprintf(detail, sizeof(detail), "result=%d(%s) want=%d(%s)",
                 (int)d.result, BGGhostAuthResultDescription(d.result),
                 (int)want_result, BGGhostAuthResultDescription(want_result));
        report(0, name, detail);
        return;
    }
    if (want_field == NULL) {
        report(1, name, NULL);
        return;
    }
    if (d.field == NULL || strcmp(d.field, want_field) != 0) {
        snprintf(detail, sizeof(detail), "field=%s want=%s",
                 d.field ? d.field : "(null)", want_field);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

/// 与字段顺序一致的键名助手（仅测试用）。
static const char *keys_of(int index);

/// 构造一份「全部合规」的配置：6 个授权字段填齐 + 约束全开 + allowlist 含目标 App。
static void make_valid_config(BGAuthConfig *cfg, const char *bundle_id) {
    BGGhostAuthConfigInit(cfg);
    BGGhostAuthConfigSetField(cfg, "target_app_owner", "ACME 移动端团队（自有 App）");
    BGGhostAuthConfigSetField(cfg, "authorized_by", "安全负责人 张三 / 工单 SEC-1024");
    BGGhostAuthConfigSetField(cfg, "authorization_ref", "SEC-1024");
    BGGhostAuthConfigSetField(cfg, "purpose", "验证客户端对 AP 身份的判定逻辑");
    BGGhostAuthConfigSetField(cfg, "test_device", "iPhone12,1 / 测试机 SN-0001");
    BGGhostAuthConfigSetField(cfg, "test_ap", "实验室 AP-BG-01");
    BGGhostAuthConfigSetConstraints(cfg, 1, 1, 1);
    BGGhostAuthConfigSetScopeMode(cfg, "allowlist");
    BGGhostAuthConfigAddBundleID(cfg, bundle_id);
}

#pragma mark - 用例

static void test_valid_pass(void) {
    printf("\n[合规配置 -> 通过]\n");

    BGAuthConfig cfg;
    make_valid_config(&cfg, "com.example.bgtest");
    expect_decision("授权齐备 + 进程在作用域 -> 通过",
                    &cfg, "com.example.bgtest", BG_AUTH_OK, NULL);

    // 多 BundleID 时应逐个精确匹配。
    BGGhostAuthConfigAddBundleID(&cfg, "com.example.other");
    expect_decision("多 BundleID -> 命中第二个",
                    &cfg, "com.example.other", BG_AUTH_OK, NULL);
}

static void test_authorization_gate(void) {
    printf("\n[T9 授权闸：字段缺失 / 占位符]\n");

    BGAuthConfig empty;
    BGGhostAuthConfigInit(&empty);
    BGGhostAuthConfigSetConstraints(&empty, 1, 1, 1);
    BGGhostAuthConfigSetScopeMode(&empty, "allowlist");
    BGGhostAuthConfigAddBundleID(&empty, "com.example.bgtest");
    expect_decision("授权全空 -> 缺值，指向第一个字段",
                    &empty, "com.example.bgtest",
                    BG_AUTH_ERR_AUTH_MISSING, "authorization.target_app_owner");

    // 与 config/targets.json 的现状一致：全部是 fill_me。
    BGAuthConfig placeholders;
    BGGhostAuthConfigInit(&placeholders);
    const char *keys[] = {"target_app_owner", "authorized_by", "authorization_ref",
                          "purpose", "test_device", "test_ap"};
    for (int i = 0; i < 6; i++) {
        BGGhostAuthConfigSetField(&placeholders, keys[i], "fill_me");
    }
    BGGhostAuthConfigSetConstraints(&placeholders, 1, 1, 1);
    BGGhostAuthConfigSetScopeMode(&placeholders, "allowlist");
    BGGhostAuthConfigAddBundleID(&placeholders, "com.example.bgtest");
    expect_decision("6 个字段均为 fill_me -> 拒绝（当前仓库的真实状态）",
                    &placeholders, "com.example.bgtest",
                    BG_AUTH_ERR_AUTH_PLACEHOLDER, "authorization.target_app_owner");

    // 只有最后一个字段没填：必须精确指向它。
    BGAuthConfig last;
    make_valid_config(&last, "com.example.bgtest");
    BGGhostAuthConfigSetField(&last, "test_ap", "fill_me");
    expect_decision("仅 test_ap 未填 -> 指向 test_ap",
                    &last, "com.example.bgtest",
                    BG_AUTH_ERR_AUTH_PLACEHOLDER, "authorization.test_ap");

    // 占位符的大小写与空白变体也要拦住。
    BGAuthConfig variants;
    make_valid_config(&variants, "com.example.bgtest");
    BGGhostAuthConfigSetField(&variants, "authorized_by", "  FILL_ME  ");
    expect_decision("占位符变体 '  FILL_ME  ' -> 仍拒绝",
                    &variants, "com.example.bgtest",
                    BG_AUTH_ERR_AUTH_PLACEHOLDER, "authorization.authorized_by");

    // 空白值不能当成"已填写"。
    BGAuthConfig blank;
    make_valid_config(&blank, "com.example.bgtest");
    BGGhostAuthConfigSetField(&blank, "purpose", "   ");
    expect_decision("纯空白值 -> 视为缺值",
                    &blank, "com.example.bgtest",
                    BG_AUTH_ERR_AUTH_MISSING, "authorization.purpose");

    // 授权字段的检查优先于作用域判定：即便进程不在作用域，也应先报授权问题。
    expect_decision("授权未填 + 进程不在作用域 -> 先报授权",
                    &placeholders, "com.other.app",
                    BG_AUTH_ERR_AUTH_PLACEHOLDER, "authorization.target_app_owner");
}

static void test_constraints(void) {
    printf("\n[constraints 必须全部开启]\n");

    BGAuthConfig cfg;
    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetConstraints(&cfg, 0, 1, 1);
    expect_decision("only_test_devices=0 -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_CONSTRAINTS, "constraints");

    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetConstraints(&cfg, 1, 0, 1);
    expect_decision("only_test_network=0 -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_CONSTRAINTS, "constraints");

    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetConstraints(&cfg, 1, 1, 0);
    expect_decision("no_production_targets=0 -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_CONSTRAINTS, "constraints");
}

static void test_scope(void) {
    printf("\n[T8 作用域：声明合法性与进程匹配]\n");

    BGAuthConfig cfg;
    make_valid_config(&cfg, "com.example.bgtest");

    expect_decision("BundleID 不匹配 -> 拒绝",
                    &cfg, "com.other.app", BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");
    expect_decision("BundleID 大小写不同 -> 拒绝",
                    &cfg, "COM.EXAMPLE.BGTEST", BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");
    expect_decision("BundleID 为空（非 App 进程）-> 拒绝",
                    &cfg, "", BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");
    expect_decision("BundleID 为 NULL -> 拒绝",
                    &cfg, NULL, BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");

    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetScopeMode(&cfg, "");
    expect_decision("scope.mode 为空 -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_SCOPE_MODE, "scope.mode");

    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetScopeMode(&cfg, "AllowList");
    expect_decision("scope.mode 大小写不符 -> 拒绝（要求显式合法值）",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_SCOPE_MODE, "scope.mode");

    make_valid_config(&cfg, "com.example.bgtest");
    BGGhostAuthConfigSetScopeMode(&cfg, "whitelist");
    expect_decision("scope.mode 非枚举值 -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_SCOPE_MODE, "scope.mode");

    // allowlist 但没登记任何 BundleID。
    BGGhostAuthConfigInit(&cfg);
    BGGhostAuthConfigSetField(&cfg, "target_app_owner", "ACME");
    BGGhostAuthConfigSetField(&cfg, "authorized_by", "李四");
    BGGhostAuthConfigSetField(&cfg, "authorization_ref", "SEC-1");
    BGGhostAuthConfigSetField(&cfg, "purpose", "测试");
    BGGhostAuthConfigSetField(&cfg, "test_device", "iPhone");
    BGGhostAuthConfigSetField(&cfg, "test_ap", "AP-1");
    BGGhostAuthConfigSetConstraints(&cfg, 1, 1, 1);
    BGGhostAuthConfigSetScopeMode(&cfg, "allowlist");
    expect_decision("allowlist 但无 BundleID -> 拒绝",
                    &cfg, "com.example.bgtest", BG_AUTH_ERR_SCOPE_EMPTY, "scope.bundle_ids");

    // all 模式：任何 App 进程都放行，但仍要求是 App 进程且授权齐备。
    BGGhostAuthConfigSetScopeMode(&cfg, "all");
    expect_decision("all 模式 -> 任意 App 进程放行",
                    &cfg, "com.anything", BG_AUTH_OK, NULL);
    expect_decision("all 模式 -> 非 App 进程仍拒绝",
                    &cfg, NULL, BG_AUTH_ERR_PROCESS_SCOPE, "scope.bundle_ids");

    // all 模式也不豁免授权闸。
    BGAuthConfig allPlaceholder;
    BGGhostAuthConfigInit(&allPlaceholder);
    for (int i = 0; i < 6; i++) {
        BGGhostAuthConfigSetField(&allPlaceholder, keys_of(i), "fill_me");
    }
    BGGhostAuthConfigSetConstraints(&allPlaceholder, 1, 1, 1);
    BGGhostAuthConfigSetScopeMode(&allPlaceholder, "all");
    expect_decision("all 模式 + 授权未填 -> 仍拒绝",
                    &allPlaceholder, "com.anything",
                    BG_AUTH_ERR_AUTH_PLACEHOLDER, "authorization.target_app_owner");
}

/// 与字段顺序一致的键名助手（仅测试用）。
static const char *keys_of(int index) {
    static const char *const kKeys[] = {"target_app_owner", "authorized_by",
                                        "authorization_ref", "purpose",
                                        "test_device", "test_ap"};
    if (index < 0 || index >= 6) {
        return "";
    }
    return kKeys[index];
}

static void test_config_helpers(void) {
    printf("\n[配置写入的校验与容量]\n");

    BGAuthConfig cfg;
    BGGhostAuthConfigInit(&cfg);

    expect_int("未知键名 -> 拒绝（不静默忽略拼错的字段）",
               BGGhostAuthConfigSetField(&cfg, "target_ap_owner", "x"), 0);
    expect_int("键名为空 -> 拒绝", BGGhostAuthConfigSetField(&cfg, "", "x"), 0);
    expect_int("值为 NULL -> 拒绝", BGGhostAuthConfigSetField(&cfg, "purpose", NULL), 0);
    expect_int("未知键名不写入任何字段",
               BGGhostAuthCheckProcess(&cfg, "com.x").result, BG_AUTH_ERR_AUTH_MISSING);

    // 长度边界：恰好放得下 vs 超长。
    char exact[BG_AUTH_FIELD_MAX];
    memset(exact, 'a', sizeof(exact) - 1);
    exact[sizeof(exact) - 1] = '\0';
    expect_int("值长度 = 上限-1 -> 接受",
               BGGhostAuthConfigSetField(&cfg, "target_app_owner", exact), 1);

    char tooLong[BG_AUTH_FIELD_MAX + 1];
    memset(tooLong, 'b', sizeof(tooLong) - 1);
    tooLong[sizeof(tooLong) - 1] = '\0';
    expect_int("值长度 = 上限 -> 拒绝（不截断）",
               BGGhostAuthConfigSetField(&cfg, "target_app_owner", tooLong), 0);

    // BundleID 容量。
    BGAuthConfig scopeCfg;
    BGGhostAuthConfigInit(&scopeCfg);
    char bundle[BG_BUNDLE_ID_MAX + 1];
    memset(bundle, 'c', sizeof(bundle) - 1);
    bundle[sizeof(bundle) - 1] = '\0';
    expect_int("BundleID 超长 -> 拒绝",
               BGGhostAuthConfigAddBundleID(&scopeCfg, bundle), 0);
    expect_int("BundleID 为空 -> 拒绝",
               BGGhostAuthConfigAddBundleID(&scopeCfg, ""), 0);

    int added = 0;
    for (int i = 0; i < BG_AUTH_MAX_BUNDLES; i++) {
        char id[32];
        snprintf(id, sizeof(id), "com.example.app%d", i);
        added += BGGhostAuthConfigAddBundleID(&scopeCfg, id);
    }
    expect_int("容量内全部添加成功", added, BG_AUTH_MAX_BUNDLES);
    expect_int("超出容量 -> 拒绝",
               BGGhostAuthConfigAddBundleID(&scopeCfg, "com.example.overflow"), 0);
    expect_int("count 未越界", scopeCfg.bundle_id_count, BG_AUTH_MAX_BUNDLES);

    // 静态表完整性。
    int namesOk = 1;
    for (int i = 0; i < BG_AUTH_FIELD_COUNT; i++) {
        const char *name = BGGhostAuthFieldName((BGAuthField)i);
        if (name == NULL || strncmp(name, "authorization.", 14) != 0) {
            namesOk = 0;
        }
    }
    expect_int("每个授权字段都有 authorization.* 形式的名称", namesOk, 1);

    int descOk = 1;
    for (int r = 0; r <= (int)BG_AUTH_ERR_PROCESS_SCOPE; r++) {
        const char *desc = BGGhostAuthResultDescription((BGAuthResult)r);
        if (desc == NULL || desc[0] == '\0') {
            descOk = 0;
        }
    }
    expect_int("每个判定结果都有中文说明", descOk, 1);

    // 空指针安全。
    expect_int("cfg 为 NULL -> 不崩溃并拒绝",
               BGGhostAuthCheckProcess(NULL, "com.x").result, BG_AUTH_ERR_AUTH_MISSING);
}

int main(void) {
    printf("BSSIDGhost 主机侧单测（BGGhostAuth）\n");

    test_valid_pass();
    test_authorization_gate();
    test_constraints();
    test_scope();
    test_config_helpers();

    printf("\n结果：%d 通过, %d 失败\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
