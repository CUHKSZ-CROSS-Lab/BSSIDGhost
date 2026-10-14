//
//  vector_rules.c
//  BSSIDGhost - 语言中立向量的**映射侧驱动**（L1）
//
//  从 stdin 读 USV（0x1f 分隔）流，调用真实的 ios/hooks/BGGhostRules.c，
//  逐条与向量里写死的期望值比对。向量文件：shared/vectors/bssid-map.json
//
//  为什么用 USV 而不是 TAB：TAB 属于 IFS 空白类，连续时会被折叠，
//  无法表达空字段；本向量里「空串 = 不限制」是有意义的取值，必须能区分
//  「空串」与「NULL」与「无期望值」。
//
//  运行：ios/tests/host/run-vectors.sh（不要直接跑，需要先生成流）
//

#define _POSIX_C_SOURCE 200809L

#include "BGGhostRules.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define USV '\x1f'
#define MAX_FIELDS 10
#define LINE_MAX 4096

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

/// 向量里的 NULL 记号；其余原样返回（空串就是空串）。
static const char *tok(const char *s) {
    return (s != NULL && strcmp(s, "@null@") == 0) ? NULL : s;
}

static int flag(const char *s) {
    return (s != NULL && s[0] == '1') ? 1 : 0;
}

/// 向量的计数字段；"-" 表示不关心。
static int num(const char *s) {
    return (int)strtol(s, NULL, 10);
}

/// 就地按 USV 切分，返回字段数。
static int split_usv(char *line, char **f, int max) {
    int n = 0;
    char *p = line;
    /* 去掉行尾换行 */
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
        line[--len] = '\0';
    }
    if (len == 0) {
        return 0;
    }
    f[n++] = p;
    for (; *p != '\0'; p++) {
        if (*p == USV) {
            *p = '\0';
            if (n < max) {
                f[n++] = p + 1;
            }
        }
    }
    return n;
}

/// 需要足够字段数，否则报错并返回 0。
static int need(int have, int want, const char *op) {
    if (have < want) {
        char detail[96];
        snprintf(detail, sizeof(detail), "向量行字段数不足（%s: 需要 %d，实得 %d）", op, want, have);
        report(0, "向量解析", detail);
        return 0;
    }
    return 1;
}

static void check_str(const char *name, const char *got, const char *want) {
    char detail[256];
    if (got == NULL || strcmp(got, want) != 0) {
        snprintf(detail, sizeof(detail), "got=%s want=%s", got ? got : "(null)", want);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

static void check_int(const char *name, int got, int want) {
    char detail[128];
    if (got != want) {
        snprintf(detail, sizeof(detail), "got=%d want=%d", got, want);
        report(0, name, detail);
        return;
    }
    report(1, name, NULL);
}

// --- 各操作的执行 -----------------------------------------------------------

static BGRuleSet g_set;

static void op_normalize(char **f) {
    char out[BG_BSSID_STR_MAX];
    memset(out, 0x7F, sizeof(out));
    int ok = BGGhostNormalizeBSSID(tok(f[2]), out);
    if (ok != flag(f[3])) {
        char detail[160];
        snprintf(detail, sizeof(detail), "got ok=%d want ok=%d", ok, flag(f[3]));
        report(0, f[1], detail);
        return;
    }
    if (ok && strcmp(f[4], "-") != 0) {
        check_str(f[1], out, f[4]);
        return;
    }
    report(1, f[1], NULL);
}

static void op_render(char **f) {
    char out[BG_BSSID_STR_MAX];
    memset(out, 0x7F, sizeof(out));
    int ok = BGGhostRenderLikeReal(tok(f[2]), tok(f[3]), out);
    if (ok != flag(f[4])) {
        char detail[160];
        snprintf(detail, sizeof(detail), "got ok=%d want ok=%d", ok, flag(f[4]));
        report(0, f[1], detail);
        return;
    }
    if (ok && strcmp(f[5], "-") != 0) {
        check_str(f[1], out, f[5]);
        return;
    }
    report(1, f[1], NULL);
}

static void op_set(char **f) {
    BGGhostRuleSetInit(&g_set);
    g_set.enabled = flag(f[1]);
    if (flag(f[2])) {
        if (strcmp(f[3], "-") == 0) {
            report(0, "向量解析", "SET 声明了 default 启用但没有给 default 值");
            return;
        }
        if (!BGGhostNormalizeBSSID(f[3], g_set.default_fake_bssid)) {
            report(0, "向量解析", "SET 的 default 伪造值非法（向量数据本身有误）");
            return;
        }
        g_set.has_default = 1;
    }
}

static void op_rule(char **f) {
    if (!BGGhostRuleSetAdd(&g_set, tok(f[1]), tok(f[2]), tok(f[3]), flag(f[4]))) {
        /* 向量里写了一条加不进去的规则 = 向量数据有误，必须显式失败 */
        report(0, "向量解析：规则应能加入", f[1] ? f[1] : "(null)");
        return;
    }
    report(1, "向量装载：规则已加入", NULL);
}

static void op_query(char **f) {
    char out[BG_BSSID_STR_MAX];
    char before[BG_BSSID_STR_MAX];
    memset(out, 0x7F, sizeof(out));
    memcpy(before, out, sizeof(out));

    int hit = BGGhostMapBSSIDC(&g_set, tok(f[2]), tok(f[3]), out);
    if (hit != flag(f[4])) {
        char detail[192];
        snprintf(detail, sizeof(detail), "got hit=%d want hit=%d", hit, flag(f[4]));
        report(0, f[1], detail);
        return;
    }
    if (!hit) {
        /* C 侧额外要求：透传时不得写入输出缓冲（Android 侧对应「返回 null」） */
        if (memcmp(before, out, sizeof(out)) != 0) {
            report(0, f[1], "透传时不应写入 out 缓冲");
            return;
        }
        report(1, f[1], NULL);
        return;
    }
    if (strcmp(f[5], "-") == 0) {
        report(1, f[1], NULL);
        return;
    }
    check_str(f[1], out, f[5]);
}

static void op_add(char **f) {
    BGRuleSet s;
    BGGhostRuleSetInit(&s);
    int ok = BGGhostRuleSetAdd(&s, tok(f[2]), tok(f[3]), tok(f[4]), flag(f[5]));
    if (ok != flag(f[6])) {
        char detail[160];
        snprintf(detail, sizeof(detail), "got add=%d want add=%d", ok, flag(f[6]));
        report(0, f[1], detail);
        return;
    }
    if (strcmp(f[7], "-") != 0) {
        check_int(f[1], s.count, num(f[7]));
        return;
    }
    report(1, f[1], NULL);
}

/// 填充 count 条规则，返回成功加入的条数。
static int fill_set(BGRuleSet *s, int count, const char *fake) {
    int added = 0;
    for (int i = 0; i < count; i++) {
        char ssid[24];
        snprintf(ssid, sizeof(ssid), "net-%d", i);
        added += BGGhostRuleSetAdd(s, ssid, "", fake, 1);
    }
    return added;
}

static void op_fill(char **f) {
    BGRuleSet s;
    BGGhostRuleSetInit(&s);
    int added = fill_set(&s, num(f[2]), f[3]);
    if (added != num(f[4])) {
        char detail[160];
        snprintf(detail, sizeof(detail), "got added=%d want=%d", added, num(f[4]));
        report(0, f[1], detail);
        return;
    }
    if (strcmp(f[5], "-") != 0) {
        check_int(f[1], s.count, num(f[5]));
        return;
    }
    report(1, f[1], NULL);
}

static void op_fill_overflow(char **f) {
    BGRuleSet s;
    BGGhostRuleSetInit(&s);
    (void)fill_set(&s, num(f[2]), f[3]);
    int ok = BGGhostRuleSetAdd(&s, "overflow", "", f[3], 1);
    if (ok != flag(f[4])) {
        char detail[160];
        snprintf(detail, sizeof(detail), "got overflow add=%d want=%d", ok, flag(f[4]));
        report(0, f[1], detail);
        return;
    }
    if (strcmp(f[5], "-") != 0) {
        check_int(f[1], s.count, num(f[5]));
        return;
    }
    report(1, f[1], NULL);
}

int main(void) {
    static char line[LINE_MAX];
    char *f[MAX_FIELDS];

    printf("BSSIDGhost 向量驱动（映射 / shared/vectors/bssid-map.json）\n");

    while (fgets(line, sizeof(line), stdin) != NULL) {
        int n = split_usv(line, f, MAX_FIELDS);
        if (n == 0) {
            continue;
        }
        const char *op = f[0];
        if (strcmp(op, "N") == 0) {
            if (need(n, 5, "N")) op_normalize(f);
        } else if (strcmp(op, "R") == 0) {
            if (need(n, 6, "R")) op_render(f);
        } else if (strcmp(op, "SET") == 0) {
            if (need(n, 3, "SET")) op_set(f);
        } else if (strcmp(op, "RULE") == 0) {
            if (need(n, 5, "RULE")) op_rule(f);
        } else if (strcmp(op, "Q") == 0) {
            if (need(n, 6, "Q")) op_query(f);
        } else if (strcmp(op, "A") == 0) {
            if (need(n, 8, "A")) op_add(f);
        } else if (strcmp(op, "FILL") == 0) {
            if (need(n, 6, "FILL")) op_fill(f);
        } else if (strcmp(op, "FILL_OVERFLOW") == 0) {
            if (need(n, 6, "FILL_OVERFLOW")) op_fill_overflow(f);
        } else {
            char detail[96];
            snprintf(detail, sizeof(detail), "未知操作码 '%s'", op);
            report(0, "向量解析", detail);
        }
    }

    printf("\n结果：%d 通过, %d 失败\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
