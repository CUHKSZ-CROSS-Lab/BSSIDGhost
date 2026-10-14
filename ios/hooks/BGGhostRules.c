//
//  BGGhostRules.c
//  BSSIDGhost
//
//  BSSID 映射的纯 C 核心实现。见 BGGhostRules.h 的设计约束。
//
//  本文件刻意不引入任何 Foundation / ObjC 依赖，唯一目的是让映射逻辑
//  能在主机上用 ios/tests/host/run.sh 直接编译并跑单测（不依赖真机）。
//

#include "BGGhostRules.h"

#include <string.h>

#pragma mark - 内部工具

static int bg_hex_val(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int bg_is_space(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

/// 宽松解析：允许 `:` / `-` / 无分隔符，允许大小写混合，忽略前后空白。
/// 严格要求恰好 6 字节且无多余字符。
static int bg_parse_bytes(const char *s, unsigned char out[6]) {
    if (s == NULL) {
        return 0;
    }
    while (bg_is_space(*s)) {
        s++;
    }

    int n = 0;
    while (*s != '\0' && n < 6) {
        if (n > 0 && (*s == ':' || *s == '-')) {
            s++;
        }
        int hi = bg_hex_val(s[0]);
        int lo = (hi >= 0) ? bg_hex_val(s[1]) : -1;
        if (hi < 0 || lo < 0) {
            return 0;
        }
        out[n++] = (unsigned char)((hi << 4) | lo);
        s += 2;
    }

    if (n != 6) {
        return 0;
    }
    while (bg_is_space(*s)) {
        s++;
    }
    return (*s == '\0') ? 1 : 0;
}

/// 检测真实值使用的分隔符：优先 `:`，其次 `-`，都没有则返回 '\0'。
static char bg_detect_sep(const char *s) {
    for (const char *p = s; *p != '\0'; p++) {
        if (*p == ':') return ':';
        if (*p == '-') return '-';
    }
    return '\0';
}

/// 真实值里出现过小写十六进制字母则按小写渲染，否则保持大写。
static int bg_detect_lowercase(const char *s) {
    for (const char *p = s; *p != '\0'; p++) {
        if (*p >= 'a' && *p <= 'f') return 1;
    }
    return 0;
}

static void bg_format_upper_colon(const unsigned char b[6], char out[BG_BSSID_STR_MAX]) {
    static const char kHex[] = "0123456789ABCDEF";
    size_t n = 0;
    for (int i = 0; i < 6; i++) {
        if (i > 0) out[n++] = ':';
        out[n++] = kHex[(b[i] >> 4) & 0x0F];
        out[n++] = kHex[b[i] & 0x0F];
    }
    out[n] = '\0';
}

#pragma mark - 公开 API

void BGGhostRuleSetInit(BGRuleSet *set) {
    if (set == NULL) {
        return;
    }
    memset(set, 0, sizeof(*set));
}

int BGGhostNormalizeBSSID(const char *in, char out[BG_BSSID_STR_MAX]) {
    if (out == NULL) {
        return 0;
    }
    unsigned char bytes[6];
    if (!bg_parse_bytes(in, bytes)) {
        return 0;
    }
    bg_format_upper_colon(bytes, out);
    return 1;
}

int BGGhostRuleSetAdd(BGRuleSet *set,
                      const char *ssid,
                      const char *real_bssid,
                      const char *fake_bssid,
                      int enabled) {
    if (set == NULL || fake_bssid == NULL) {
        return 0;
    }
    if (set->count >= BG_RULE_MAX_COUNT) {
        return 0;
    }
    if (ssid != NULL && strlen(ssid) >= BG_SSID_STR_MAX) {
        return 0;
    }

    BGRule rule;
    memset(&rule, 0, sizeof(rule));

    if (ssid != NULL && ssid[0] != '\0') {
        memcpy(rule.ssid, ssid, strlen(ssid) + 1);
    }

    if (real_bssid != NULL && real_bssid[0] != '\0') {
        if (!BGGhostNormalizeBSSID(real_bssid, rule.real_bssid)) {
            return 0;
        }
    }

    if (!BGGhostNormalizeBSSID(fake_bssid, rule.fake_bssid)) {
        return 0;
    }

    rule.enabled = enabled ? 1 : 0;
    set->rules[set->count] = rule;
    set->count++;
    return 1;
}

int BGGhostRenderLikeReal(const char *real_bssid,
                          const char *fake_bssid_normalized,
                          char out[BG_BSSID_STR_MAX]) {
    if (real_bssid == NULL || fake_bssid_normalized == NULL || out == NULL) {
        return 0;
    }

    unsigned char real_bytes[6];
    unsigned char fake_bytes[6];
    if (!bg_parse_bytes(real_bssid, real_bytes)) {
        return 0;
    }
    if (!bg_parse_bytes(fake_bssid_normalized, fake_bytes)) {
        return 0;
    }

    const char sep = bg_detect_sep(real_bssid);
    const char *hex = bg_detect_lowercase(real_bssid) ? "0123456789abcdef" : "0123456789ABCDEF";

    size_t n = 0;
    for (int i = 0; i < 6; i++) {
        if (i > 0 && sep != '\0') {
            if (n + 1 >= BG_BSSID_STR_MAX) return 0;
            out[n++] = sep;
        }
        if (n + 2 >= BG_BSSID_STR_MAX) return 0;
        out[n++] = hex[(fake_bytes[i] >> 4) & 0x0F];
        out[n++] = hex[fake_bytes[i] & 0x0F];
    }
    out[n] = '\0';
    return 1;
}

int BGGhostMapBSSIDC(const BGRuleSet *set,
                     const char *ssid,
                     const char *real_bssid,
                     char out[BG_BSSID_STR_MAX]) {
    if (set == NULL || out == NULL) {
        return 0;
    }

    // 默认不改变行为：全局关闭即整表失效。
    if (!set->enabled) {
        return 0;
    }

    // nil 语义：真实值缺失时绝不凭空构造（见 HANDOFF §5 风险 6）。
    if (real_bssid == NULL || real_bssid[0] == '\0') {
        return 0;
    }

    // 畸形真实值 → 透传，不做猜测性替换。
    char real_norm[BG_BSSID_STR_MAX];
    if (!BGGhostNormalizeBSSID(real_bssid, real_norm)) {
        return 0;
    }

    for (int i = 0; i < set->count; i++) {
        const BGRule *rule = &set->rules[i];
        if (!rule->enabled) {
            continue;
        }
        // SSID 按 802.11 语义做大小写敏感精确匹配；规则未填 SSID 表示不限制。
        if (rule->ssid[0] != '\0') {
            if (ssid == NULL || strcmp(rule->ssid, ssid) != 0) {
                continue;
            }
        }
        // 规则未填真实 BSSID 表示不限制。
        if (rule->real_bssid[0] != '\0' && strcmp(rule->real_bssid, real_norm) != 0) {
            continue;
        }
        if (BGGhostRenderLikeReal(real_bssid, rule->fake_bssid, out)) {
            return 1;
        }
    }

    // 默认值必须显式启用（default.enabled = true），否则等同「无规则透传」（T7）。
    if (set->has_default) {
        return BGGhostRenderLikeReal(real_bssid, set->default_fake_bssid, out);
    }

    return 0;
}
