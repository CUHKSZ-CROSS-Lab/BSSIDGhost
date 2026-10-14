//
//  test_bgg_rules.c
//  BSSIDGhost - 主机侧单测（L1：不依赖真机、不依赖 ObjC）
//
//  覆盖 tests/README.md 中的：
//    T5 格式一致（大小写 / 分隔符）
//    T7 无规则透传（默认不改变行为）
//    以及 nil 语义、畸形输入、全局开关、规则优先级、表容量等边界。
//
//  运行：ios/tests/host/run.sh
//

#include "../../hooks/BGGhostRules.h"

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

/// 期望命中：out 必须等于 want。
static void expect_hit(const char *name,
                       const BGRuleSet *set,
                       const char *ssid,
                       const char *real,
                       const char *want) {
    char out[BG_BSSID_STR_MAX];
    memset(out, 0x7F, sizeof(out));
    int hit = BGGhostMapBSSIDC(set, ssid, real, out);
    char detail[192];
    if (!hit) {
        snprintf(detail, sizeof(detail), "期望命中但返回未命中 (want=%s)", want);
        report(0, name, detail);
        return;
    }
    if (strcmp(out, want) != 0) {
        snprintf(detail, sizeof(detail), "got=%s want=%s", out, want);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

/// 期望透传（返回未命中），且 out 缓冲必须保持未被写入。
static void expect_pass(const char *name,
                        const BGRuleSet *set,
                        const char *ssid,
                        const char *real) {
    char out[BG_BSSID_STR_MAX];
    memset(out, 0x7F, sizeof(out));
    char before[BG_BSSID_STR_MAX];
    memcpy(before, out, sizeof(out));

    int hit = BGGhostMapBSSIDC(set, ssid, real, out);
    if (hit) {
        char detail[192];
        snprintf(detail, sizeof(detail), "期望透传但命中了 (out=%s)", out);
        report(0, name, detail);
        return;
    }
    if (memcmp(before, out, sizeof(out)) != 0) {
        report(0, name, "透传时不应写入 out 缓冲");
        return;
    }
    report(1, name, NULL);
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

static void expect_str(const char *name, const char *got, const char *want) {
    char detail[192];
    if (got == NULL || strcmp(got, want) != 0) {
        snprintf(detail, sizeof(detail), "got=%s want=%s", got ? got : "(null)", want);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

#pragma mark - 用例

static void test_normalize(void) {
    printf("\n[归一化 BGGhostNormalizeBSSID]\n");
    char out[BG_BSSID_STR_MAX];

    int ok = BGGhostNormalizeBSSID("aabbccddeeff", out);
    expect_int("无分隔符小写 -> 解析成功", ok, 1);
    if (ok) expect_str("无分隔符小写 -> 大写冒号", out, "AA:BB:CC:DD:EE:FF");

    ok = BGGhostNormalizeBSSID(" aa:bb:cc:dd:ee:ff ", out);
    expect_int("前后空白 -> 解析成功", ok, 1);
    if (ok) expect_str("前后空白 -> 大写冒号", out, "AA:BB:CC:DD:EE:FF");

    ok = BGGhostNormalizeBSSID("11-22-33-44-55-66", out);
    expect_int("连字符 -> 解析成功", ok, 1);
    if (ok) expect_str("连字符 -> 大写冒号", out, "11:22:33:44:55:66");

    expect_int("长度不足 -> 拒绝", BGGhostNormalizeBSSID("AA:BB:CC", out), 0);
    expect_int("长度超出 -> 拒绝", BGGhostNormalizeBSSID("AA:BB:CC:DD:EE:FF:00", out), 0);
    expect_int("非十六进制 -> 拒绝", BGGhostNormalizeBSSID("AA:BB:CC:DD:EE:GG", out), 0);
    expect_int("空串 -> 拒绝", BGGhostNormalizeBSSID("", out), 0);
    expect_int("NULL -> 拒绝", BGGhostNormalizeBSSID(NULL, out), 0);
}

static void test_render_like_real(void) {
    printf("\n[格式跟随真实值 BGGhostRenderLikeReal]\n");
    char out[BG_BSSID_STR_MAX];
    const char *fake = "A1:B2:C3:D4:E5:F6";

    expect_int("大写冒号真实值 -> 成功",
               BGGhostRenderLikeReal("AA:BB:CC:DD:EE:FF", fake, out), 1);
    expect_str("大写冒号真实值 -> 大写冒号输出", out, "A1:B2:C3:D4:E5:F6");

    expect_int("小写冒号真实值 -> 成功",
               BGGhostRenderLikeReal("aa:bb:cc:dd:ee:ff", fake, out), 1);
    expect_str("小写冒号真实值 -> 小写冒号输出", out, "a1:b2:c3:d4:e5:f6");

    expect_int("大写连字符真实值 -> 成功",
               BGGhostRenderLikeReal("AA-BB-CC-DD-EE-FF", fake, out), 1);
    expect_str("大写连字符真实值 -> 大写连字符输出", out, "A1-B2-C3-D4-E5-F6");

    expect_int("无分隔符真实值 -> 成功",
               BGGhostRenderLikeReal("AABBCCDDEEFF", fake, out), 1);
    expect_str("无分隔符真实值 -> 无分隔符输出", out, "A1B2C3D4E5F6");

    // 纯数字真实值（无小写字母）应保持大写。
    expect_int("全数字真实值 -> 成功",
               BGGhostRenderLikeReal("11:22:33:44:55:66", fake, out), 1);
    expect_str("全数字真实值 -> 大写输出", out, "A1:B2:C3:D4:E5:F6");

    expect_int("畸形真实值 -> 拒绝",
               BGGhostRenderLikeReal("AA:BB:CC", fake, out), 0);
    expect_int("畸形伪造值 -> 拒绝",
               BGGhostRenderLikeReal("AA:BB:CC:DD:EE:FF", "not-a-bssid", out), 0);
    expect_int("NULL 真实值 -> 拒绝",
               BGGhostRenderLikeReal(NULL, fake, out), 0);
}

static void test_global_switch_and_nil(void) {
    printf("\n[全局开关 与 nil 语义]\n");

    BGRuleSet set;
    BGGhostRuleSetInit(&set);
    set.enabled = 1;
    expect_int("添加规则成功",
               BGGhostRuleSetAdd(&set, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66", 1), 1);

    expect_hit("命中并替换", &set, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66");
    expect_pass("nil 真实值 -> 不得凭空构造", &set, "Office_WiFi", NULL);
    expect_pass("空串真实值 -> 透传", &set, "Office_WiFi", "");
    expect_pass("畸形真实值 -> 透传", &set, "Office_WiFi", "AA:BB:CC");
    expect_pass("SSID 不匹配 -> 透传", &set, "Other_WiFi", "AA:BB:CC:DD:EE:FF");
    expect_pass("SSID 大小写不同 -> 透传（802.11 语义为大小写敏感）",
                &set, "office_wifi", "AA:BB:CC:DD:EE:FF");

    set.enabled = 0;
    expect_pass("全局关闭 -> 即使规则命中也不替换", &set, "Office_WiFi", "AA:BB:CC:DD:EE:FF");
}

static void test_format_follows_real(void) {
    printf("\n[格式一致性：输出跟随入参格式]\n");

    BGRuleSet set;
    BGGhostRuleSetInit(&set);
    set.enabled = 1;
    BGGhostRuleSetAdd(&set, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "A1:B2:C3:D4:E5:F6", 1);

    expect_hit("大写冒号入参 -> 大写冒号输出",
               &set, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "A1:B2:C3:D4:E5:F6");
    expect_hit("小写冒号入参 -> 小写冒号输出",
               &set, "Office_WiFi", "aa:bb:cc:dd:ee:ff", "a1:b2:c3:d4:e5:f6");
    expect_hit("连字符入参 -> 连字符输出",
               &set, "Office_WiFi", "AA-BB-CC-DD-EE-FF", "A1-B2-C3-D4-E5-F6");
    expect_hit("无分隔符入参 -> 无分隔符输出",
               &set, "Office_WiFi", "AABBCCDDEEFF", "A1B2C3D4E5F6");
    expect_hit("真实值用连字符且小写 -> 小写连字符输出",
               &set, "Office_WiFi", "aa-bb-cc-dd-ee-ff", "a1-b2-c3-d4-e5-f6");
}

static void test_rule_matching(void) {
    printf("\n[规则匹配：SSID / BSSID 限制与优先级]\n");

    BGRuleSet set;
    BGGhostRuleSetInit(&set);
    set.enabled = 1;

    // 只限 SSID：任何真实 BSSID 都命中（多 AP 漫游同 SSID 场景）。
    BGGhostRuleSetAdd(&set, "Roam_SSID", "", "11:22:33:44:55:66", 1);
    expect_hit("规则只填 SSID -> 任意真实 BSSID 命中",
               &set, "Roam_SSID", "DE:AD:BE:EF:00:01", "11:22:33:44:55:66");

    BGRuleSet set2;
    BGGhostRuleSetInit(&set2);
    set2.enabled = 1;

    // 只限真实 BSSID：SSID 为空/不提供也命中。
    BGGhostRuleSetAdd(&set2, "", "AA:BB:CC:DD:EE:FF", "22:33:44:55:66:77", 1);
    expect_hit("规则只填真实 BSSID -> 命中", &set2, "Whatever", "AA:BB:CC:DD:EE:FF", "22:33:44:55:66:77");
    expect_hit("规则只填真实 BSSID -> SSID 为 NULL 也命中",
               &set2, NULL, "AA:BB:CC:DD:EE:FF", "22:33:44:55:66:77");
    expect_pass("规则只填真实 BSSID -> 其它 BSSID 透传",
                &set2, "Whatever", "AA:BB:CC:DD:EE:00");

    // 禁用规则必须被跳过。
    BGRuleSet set3;
    BGGhostRuleSetInit(&set3);
    set3.enabled = 1;
    BGGhostRuleSetAdd(&set3, "Office_WiFi", "", "11:22:33:44:55:66", 0);
    expect_pass("规则 enabled=0 -> 跳过", &set3, "Office_WiFi", "AA:BB:CC:DD:EE:FF");

    // 先命中者胜出。
    BGRuleSet set4;
    BGGhostRuleSetInit(&set4);
    set4.enabled = 1;
    BGGhostRuleSetAdd(&set4, "Office_WiFi", "", "11:22:33:44:55:66", 1);
    BGGhostRuleSetAdd(&set4, "Office_WiFi", "", "99:99:99:99:99:99", 1);
    expect_hit("多条规则命中 -> 取第一条", &set4, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66");
}

static void test_default_and_passthrough(void) {
    printf("\n[T7 透传 与 default 显式启用]\n");

    BGRuleSet set;
    BGGhostRuleSetInit(&set);
    set.enabled = 1;
    BGGhostRuleSetAdd(&set, "Office_WiFi", "", "11:22:33:44:55:66", 1);

    // default 未启用（has_default = 0）-> 未配置的网络必须透传。
    expect_pass("未配置网络 -> 透传（T7）", &set, "Cafe_Free", "AA:BB:CC:DD:EE:FF");

    // default 显式启用 -> 未配置网络使用默认伪造值，格式仍跟随真实值。
    set.has_default = 1;
    BGGhostNormalizeBSSID("A1:B2:C3:D4:E5:F6", set.default_fake_bssid);
    expect_hit("default 启用 -> 未配置网络使用默认值",
               &set, "Cafe_Free", "AA:BB:CC:DD:EE:FF", "A1:B2:C3:D4:E5:F6");
    expect_hit("default 启用 -> 输出格式仍跟随真实值（小写连字符）",
               &set, "Cafe_Free", "aa-bb-cc-dd-ee-ff", "a1-b2-c3-d4-e5-f6");
    expect_hit("default 启用 -> 已配置网络仍走规则",
               &set, "Office_WiFi", "AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66");

    BGRuleSet disabled;
    BGGhostRuleSetInit(&disabled);
    disabled.enabled = 0;
    disabled.has_default = 1;
    BGGhostNormalizeBSSID("A1:B2:C3:D4:E5:F6", disabled.default_fake_bssid);
    expect_pass("全局关闭 -> default 也不生效", &disabled, "Cafe_Free", "AA:BB:CC:DD:EE:FF");
}

static void test_add_validation(void) {
    printf("\n[规则表校验与容量]\n");

    BGRuleSet set;
    BGGhostRuleSetInit(&set);
    set.enabled = 1;

    expect_int("伪造值非法 -> 添加失败",
               BGGhostRuleSetAdd(&set, "S", "", "zz:zz:zz:zz:zz:zz", 1), 0);
    expect_int("真实值非法 -> 添加失败",
               BGGhostRuleSetAdd(&set, "S", "AA:BB:CC", "11:22:33:44:55:66", 1), 0);
    expect_int("SSID 超长(32+) -> 添加失败",
               BGGhostRuleSetAdd(&set,
                                 "0123456789012345678901234567890123",
                                 "", "11:22:33:44:55:66", 1), 0);
    expect_int("SSID 恰好 32 字节 -> 添加成功",
               BGGhostRuleSetAdd(&set,
                                 "01234567890123456789012345678901",
                                 "", "11:22:33:44:55:66", 1), 1);
    expect_int("伪造值为 NULL -> 添加失败",
               BGGhostRuleSetAdd(&set, "S", "", NULL, 1), 0);

    BGRuleSet full;
    BGGhostRuleSetInit(&full);
    int added = 0;
    for (int i = 0; i < BG_RULE_MAX_COUNT; i++) {
        char ssid[16];
        snprintf(ssid, sizeof(ssid), "net-%d", i);
        added += BGGhostRuleSetAdd(&full, ssid, "", "11:22:33:44:55:66", 1);
    }
    expect_int("表容量内全部添加成功", added, BG_RULE_MAX_COUNT);
    expect_int("超出容量 -> 拒绝且不覆盖",
               BGGhostRuleSetAdd(&full, "overflow", "", "11:22:33:44:55:66", 1), 0);
    expect_int("count 未越界", full.count, BG_RULE_MAX_COUNT);
}

int main(void) {
    printf("BSSIDGhost 主机侧单测（BGGhostRules）\n");

    test_normalize();
    test_render_like_real();
    test_global_switch_and_nil();
    test_format_follows_real();
    test_rule_matching();
    test_default_and_passthrough();
    test_add_validation();

    printf("\n结果：%d 通过, %d 失败\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
