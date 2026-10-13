//
//  gate_sim.c
//  BSSIDGhost - 授权闸模拟器（主机侧）
//
//  把「真实配置」喂给**真实的判定代码**（hooks/BGGhostAuth.c），在不接触设备的情况下
//  回答：以当前 config/targets.json 为准，Hook 会对某个 BundleID 启用还是拒绝？
//
//  输入（stdin，每行一条，制表符分隔，值里可以有空格）：
//      auth<TAB><字段名><TAB><值>            -> BGGhostAuthConfigSetField
//      mode<TAB>-<TAB>allowlist|all          -> BGGhostAuthConfigSetScopeMode
//      bundle<TAB>-<TAB>com.example.app      -> BGGhostAuthConfigAddBundleID
//      constraints<TAB>-<TAB>1,1,1           -> BGGhostAuthConfigSetConstraints
//      # 开头的行为注释
//
//  用法：gate-sim <bundle-id|->        （- 表示 NULL，模拟非 App 进程）
//  退出码：0 = 判定通过；1 = 判定拒绝；2 = 用法/输入错误
//
//  由 tests/host/gate-sim.sh 负责用 jq 从 JSON 抽取输入并调用本程序。
//  注意：JSON → 结构体这一步由 jq 完成（不是 NSJSONSerialization），
//  所以本工具验证的是「判定代码 + 配置取值」的端到端结果，
//  不覆盖 BGGhostConfig.m 的解析实现（那需要真 SDK 编译，见 docs/STATUS.md）。
//

#include "../../hooks/BGGhostAuth.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/// 把一行拆成 3 段（KIND / KEY / VALUE），VALUE 允许含制表符以外的任意字符。
static int split_tsv(char *line, char **kind, char **key, char **value) {
    char *first = strchr(line, '\t');
    if (first == NULL) {
        return 0;
    }
    *first = '\0';
    char *second = strchr(first + 1, '\t');
    if (second == NULL) {
        return 0;
    }
    *second = '\0';
    *kind = line;
    *key = first + 1;
    *value = second + 1;
    return 1;
}

static void strip_eol(char *line) {
    size_t n = strlen(line);
    while (n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r')) {
        line[--n] = '\0';
    }
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "用法: gate-sim <bundle-id|->\n");
        return 2;
    }
    const char *bundle_id = (strcmp(argv[1], "-") == 0) ? NULL : argv[1];

    BGAuthConfig cfg;
    BGGhostAuthConfigInit(&cfg);

    int auth_seen = 0;
    int bundle_seen = 0;
    int mode_seen = 0;
    int constraints_seen = 0;
    int problems = 0;

    char line[4096];
    while (fgets(line, sizeof(line), stdin) != NULL) {
        strip_eol(line);
        if (line[0] == '\0' || line[0] == '#') {
            continue;
        }

        char *kind = NULL;
        char *key = NULL;
        char *value = NULL;
        if (!split_tsv(line, &kind, &key, &value)) {
            fprintf(stderr, "!! 无法解析输入行（需要 KIND<TAB>KEY<TAB>VALUE）：%s\n", line);
            problems++;
            continue;
        }

        if (strcmp(kind, "auth") == 0) {
            if (BGGhostAuthConfigSetField(&cfg, key, value)) {
                auth_seen++;
            } else {
                fprintf(stderr, "!! 授权字段被拒（未知键名或超长）：%s\n", key);
                problems++;
            }
        } else if (strcmp(kind, "mode") == 0) {
            BGGhostAuthConfigSetScopeMode(&cfg, value);
            mode_seen++;
        } else if (strcmp(kind, "bundle") == 0) {
            if (BGGhostAuthConfigAddBundleID(&cfg, value)) {
                bundle_seen++;
            } else {
                fprintf(stderr, "!! BundleID 被拒（空值/超长/超出容量）：%s\n", value);
                problems++;
            }
        } else if (strcmp(kind, "constraints") == 0) {
            int a = 0;
            int b = 0;
            int c = 0;
            if (sscanf(value, "%d,%d,%d", &a, &b, &c) != 3) {
                fprintf(stderr, "!! constraints 值格式应为 a,b,c（0/1）：%s\n", value);
                problems++;
            } else {
                BGGhostAuthConfigSetConstraints(&cfg, a, b, c);
                constraints_seen++;
            }
        } else {
            fprintf(stderr, "!! 未知输入类型：%s\n", kind);
            problems++;
        }
    }

    if (auth_seen != BG_AUTH_FIELD_COUNT) {
        fprintf(stderr, "!! 只收到 %d/%d 个授权字段（配置缺少字段时判定必然拒绝）\n",
                auth_seen, BG_AUTH_FIELD_COUNT);
    }
    if (mode_seen == 0) {
        fprintf(stderr, "!! 没有收到 scope.mode\n");
    }
    if (constraints_seen == 0) {
        fprintf(stderr, "!! 没有收到 constraints（缺失按全 false 处理 -> 拒绝）\n");
    }

    BGAuthDecision decision = BGGhostAuthCheckProcess(&cfg, bundle_id);

    printf("输入：授权字段 %d/%d，scope.mode=%s，bundle=%d，constraints=%s%s\n",
           auth_seen, BG_AUTH_FIELD_COUNT,
           cfg.scope_mode[0] ? cfg.scope_mode : "(空)",
           bundle_seen,
           constraints_seen ? "有" : "缺失",
           problems ? "，且存在解析问题" : "");
    printf("目标进程：%s\n", bundle_id ? bundle_id : "(NULL / 非 App 进程)");
    printf("判定：%s\n", decision.result == BG_AUTH_OK ? "通过 —— Hook 会启用"
                                                      : "拒绝 —— Hook 不会启用");
    printf("原因：%s\n", BGGhostAuthResultDescription(decision.result));
    if (decision.field != NULL) {
        printf("责任字段：%s\n", decision.field);
    }

    return decision.result == BG_AUTH_OK ? 0 : 1;
}
