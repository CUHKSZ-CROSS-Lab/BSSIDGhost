//
//  vector_auth.c
//  BSSIDGhost - 语言中立向量的**授权闸驱动**（L1）
//
//  从 stdin 读 USV（0x1f 分隔）流，调用真实的 ios/hooks/BGGhostAuth.c，
//  逐条与向量里写死的期望值比对。向量文件：shared/vectors/auth-gate.json
//
//  这是本项目的安全闸：**宁可误拒，不可误放**。因此这里对「责任字段」也逐条断言，
//  避免出现「结论对了但原因是错的」这种看着通过的假象。
//
//  运行：ios/tests/host/run-vectors.sh
//

#define _POSIX_C_SOURCE 200809L

#include "BGGhostAuth.h"

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

static const char *tok(const char *s) {
    if (s == NULL) {
        return NULL;
    }
    if (strcmp(s, "@null@") == 0) {
        return NULL;
    }
    if (strcmp(s, "@empty@") == 0) {
        return "";
    }
    return s;
}

static int flag(const char *s) {
    return (s != NULL && s[0] == '1') ? 1 : 0;
}

static int num(const char *s) {
    return (int)strtol(s, NULL, 10);
}

static int split_usv(char *line, char **f, int max) {
    int n = 0;
    char *p = line;
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

static int need(int have, int want, const char *op) {
    if (have < want) {
        char detail[96];
        snprintf(detail, sizeof(detail), "向量行字段数不足（%s: 需要 %d，实得 %d）", op, want, have);
        report(0, "向量解析", detail);
        return 0;
    }
    return 1;
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

// --- 结果码映射 -------------------------------------------------------------

static int result_from_code(const char *code) {
    if (strcmp(code, "ok") == 0)               return BG_AUTH_OK;
    if (strcmp(code, "auth_missing") == 0)     return BG_AUTH_ERR_AUTH_MISSING;
    if (strcmp(code, "auth_placeholder") == 0) return BG_AUTH_ERR_AUTH_PLACEHOLDER;
    if (strcmp(code, "constraints") == 0)      return BG_AUTH_ERR_CONSTRAINTS;
    if (strcmp(code, "scope_mode") == 0)       return BG_AUTH_ERR_SCOPE_MODE;
    if (strcmp(code, "scope_empty") == 0)      return BG_AUTH_ERR_SCOPE_EMPTY;
    if (strcmp(code, "process_scope") == 0)    return BG_AUTH_ERR_PROCESS_SCOPE;
    return -1;
}

// --- 当前用例状态 -----------------------------------------------------------

static BGAuthConfig g_cfg;
static const BGAuthConfig *g_cfg_ptr = NULL;   /* NULL 用于「配置为 NULL」的用例 */
static char g_case_name[256] = "?";   /* 必须拷贝：f[] 指向的行缓冲下一轮会被覆盖 */
static char g_process[BG_BUNDLE_ID_MAX];
static int g_process_is_null = 0;
static int g_case_ok = 1;                       /* 用例装载阶段是否出错 */

static void case_fail(const char *why) {
    g_case_ok = 0;
    report(0, g_case_name, why);
}

// --- 操作 -------------------------------------------------------------------

static void op_contract_field(char **f) {
    /* CT <index> <field_name> <auth_key> */
    int idx = num(f[1]);
    const char *want_name = f[2];
    const char *key = f[3];
    if (idx < 0 || idx >= BG_AUTH_FIELD_COUNT) {
        report(0, "契约：字段索引越界", want_name);
        return;
    }
    const char *got = BGGhostAuthFieldName((BGAuthField)idx);
    if (got == NULL || strcmp(got, want_name) != 0) {
        char detail[192];
        snprintf(detail, sizeof(detail), "got=%s want=%s", got ? got : "(null)", want_name);
        report(0, "契约：字段名稳定", detail);
        return;
    }
    BGAuthConfig c;
    BGGhostAuthConfigInit(&c);
    if (!BGGhostAuthConfigSetField(&c, key, "probe")) {
        char detail[192];
        snprintf(detail, sizeof(detail), "键名 %s 未被配置写入接受", key);
        report(0, "契约：键名可写入", detail);
        return;
    }
    report(1, "契约：字段名与键名一致", NULL);
}

static void op_contract_result(char **f) {
    /* CR <code> */
    int code = result_from_code(f[1]);
    if (code < 0) {
        char detail[128];
        snprintf(detail, sizeof(detail), "未知结果码 '%s'", f[1]);
        report(0, "契约：结果码可识别", detail);
        return;
    }
    const char *desc = BGGhostAuthResultDescription((BGAuthResult)code);
    if (desc == NULL || desc[0] == '\0') {
        char detail[128];
        snprintf(detail, sizeof(detail), "结果码 %s 没有说明文本", f[1]);
        report(0, "契约：结果码有说明", detail);
        return;
    }
    report(1, "契约：结果码有说明", NULL);
}

static void op_field_set(char **f) {
    /* FS <name> <key> <value> <ok> */
    BGAuthConfig c;
    BGGhostAuthConfigInit(&c);
    int ok = BGGhostAuthConfigSetField(&c, tok(f[2]), tok(f[3]));
    check_int(f[1], ok, flag(f[4]));
}

static void op_bundle_add(char **f) {
    /* BA <name> <bundle_id> <ok> */
    BGAuthConfig c;
    BGGhostAuthConfigInit(&c);
    int ok = BGGhostAuthConfigAddBundleID(&c, tok(f[2]));
    check_int(f[1], ok, flag(f[3]));
}

static void op_bundle_fill(char **f) {
    /* BZ <name> <count> <expect_added> <count_after> */
    BGAuthConfig c;
    BGGhostAuthConfigInit(&c);
    int count = num(f[2]);
    int added = 0;
    for (int i = 0; i < count; i++) {
        char id[32];
        snprintf(id, sizeof(id), "com.example.app%d", i);
        added += BGGhostAuthConfigAddBundleID(&c, id);
    }
    if (added != num(f[3])) {
        char detail[128];
        snprintf(detail, sizeof(detail), "got added=%d want=%d", added, num(f[3]));
        report(0, f[1], detail);
        return;
    }
    check_int(f[1], c.bundle_id_count, num(f[4]));
}

static void op_bundle_overflow(char **f) {
    /* BO <name> <count> <ok> <count_after> */
    BGAuthConfig c;
    BGGhostAuthConfigInit(&c);
    int count = num(f[2]);
    for (int i = 0; i < count; i++) {
        char id[32];
        snprintf(id, sizeof(id), "com.example.app%d", i);
        (void)BGGhostAuthConfigAddBundleID(&c, id);
    }
    int ok = BGGhostAuthConfigAddBundleID(&c, "com.example.overflow");
    if (ok != flag(f[3])) {
        char detail[128];
        snprintf(detail, sizeof(detail), "got overflow add=%d want=%d", ok, flag(f[3]));
        report(0, f[1], detail);
        return;
    }
    check_int(f[1], c.bundle_id_count, num(f[4]));
}

static void op_case(char **f) {
    /* CASE <name> <config_is_null> */
    snprintf(g_case_name, sizeof(g_case_name), "%s", f[1]);
    g_case_ok = 1;
    g_process[0] = '\0';
    g_process_is_null = 0;
    if (flag(f[2])) {
        g_cfg_ptr = NULL;
    } else {
        BGGhostAuthConfigInit(&g_cfg);
        g_cfg_ptr = &g_cfg;
    }
}

static void op_case_expect(char **f) {
    /* CX <result_code> <field|-> */
    if (!g_case_ok) {
        return;   /* 装载阶段已报错，不再重复判 */
    }
    int want_result = result_from_code(f[1]);
    if (want_result < 0) {
        case_fail("期望结果码无法识别（向量数据有误）");
        return;
    }
    int check_field = (strcmp(f[2], "*") != 0);
    const char *want_field = check_field ? tok(f[2]) : NULL;

    BGAuthDecision d = BGGhostAuthCheckProcess(g_cfg_ptr,
                                               g_process_is_null ? NULL : g_process);
    if ((int)d.result != want_result) {
        char detail[320];
        snprintf(detail, sizeof(detail), "result=%d(%s) want=%d(%s)",
                 (int)d.result, BGGhostAuthResultDescription(d.result),
                 want_result, BGGhostAuthResultDescription((BGAuthResult)want_result));
        report(0, g_case_name, detail);
        return;
    }
    if (!check_field) {
        report(1, g_case_name, NULL);
        return;
    }
    if (d.field == NULL && want_field == NULL) {
        report(1, g_case_name, NULL);
        return;
    }
    if (d.field == NULL || want_field == NULL || strcmp(d.field, want_field) != 0) {
        char detail[256];
        snprintf(detail, sizeof(detail), "field=%s want=%s",
                 d.field ? d.field : "(null)", want_field ? want_field : "(null)");
        report(0, g_case_name, detail);
        return;
    }
    report(1, g_case_name, NULL);
}

int main(void) {
    static char line[LINE_MAX];
    char *f[MAX_FIELDS];

    printf("BSSIDGhost 向量驱动（授权闸 / shared/vectors/auth-gate.json）\n");

    while (fgets(line, sizeof(line), stdin) != NULL) {
        int n = split_usv(line, f, MAX_FIELDS);
        if (n == 0) {
            continue;
        }
        const char *op = f[0];

        if (strcmp(op, "CT") == 0) {
            if (need(n, 4, "CT")) op_contract_field(f);
        } else if (strcmp(op, "CR") == 0) {
            if (need(n, 2, "CR")) op_contract_result(f);
        } else if (strcmp(op, "FS") == 0) {
            if (need(n, 5, "FS")) op_field_set(f);
        } else if (strcmp(op, "BA") == 0) {
            if (need(n, 4, "BA")) op_bundle_add(f);
        } else if (strcmp(op, "BZ") == 0) {
            if (need(n, 5, "BZ")) op_bundle_fill(f);
        } else if (strcmp(op, "BO") == 0) {
            if (need(n, 5, "BO")) op_bundle_overflow(f);
        } else if (strcmp(op, "CASE") == 0) {
            if (need(n, 3, "CASE")) op_case(f);
        } else if (strcmp(op, "CF") == 0) {
            if (need(n, 3, "CF")) {
                if (g_cfg_ptr == NULL) {
                    case_fail("向量数据有误：配置为 NULL 的用例不应再写字段");
                } else if (!BGGhostAuthConfigSetField(&g_cfg, f[1], tok(f[2]))) {
                    case_fail("用例装载失败：字段写入被拒（向量数据有误）");
                }
            }
        } else if (strcmp(op, "CM") == 0) {
            if (need(n, 2, "CM")) {
                if (g_cfg_ptr != NULL) {
                    BGGhostAuthConfigSetScopeMode(&g_cfg, tok(f[1]));
                }
            }
        } else if (strcmp(op, "CB") == 0) {
            if (need(n, 2, "CB")) {
                if (g_cfg_ptr != NULL && !BGGhostAuthConfigAddBundleID(&g_cfg, tok(f[1]))) {
                    case_fail("用例装载失败：BundleID 添加被拒（向量数据有误）");
                }
            }
        } else if (strcmp(op, "CC") == 0) {
            if (need(n, 4, "CC")) {
                if (g_cfg_ptr != NULL) {
                    BGGhostAuthConfigSetConstraints(&g_cfg, flag(f[1]), flag(f[2]), flag(f[3]));
                }
            }
        } else if (strcmp(op, "CW") == 0) {
            /* extra_writes：故意写入（可能失败），用于验证「未登记」状态不被污染 */
            if (need(n, 3, "CW")) {
                if (g_cfg_ptr != NULL) {
                    (void)BGGhostAuthConfigSetField(&g_cfg, f[1], tok(f[2]));
                }
            }
        } else if (strcmp(op, "CP") == 0) {
            if (need(n, 2, "CP")) {
                if (strcmp(f[1], "@null@") == 0) {
                    g_process_is_null = 1;
                    g_process[0] = '\0';
                } else {
                    const char *p = tok(f[1]);
                    g_process_is_null = 0;
                    snprintf(g_process, sizeof(g_process), "%s", p ? p : "");
                }
            }
        } else if (strcmp(op, "CX") == 0) {
            if (need(n, 3, "CX")) op_case_expect(f);
        } else {
            char detail[96];
            snprintf(detail, sizeof(detail), "未知操作码 '%s'", op);
            report(0, "向量解析", detail);
        }
    }

    printf("\n结果：%d 通过, %d 失败\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
