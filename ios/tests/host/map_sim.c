//
//  map_sim.c
//  BSSIDGhost - BSSID 映射模拟器（主机侧）
//
//  用**真实的映射代码**（ios/hooks/BGGhostRules.c）+ **真实的映射表配置**回答：
//  在给定 (SSID, 真实 BSSID) 下，目标 App 最终会读到什么？
//
//  输入（stdin，每行一条，制表符分隔；# 开头为注释）：
//      global<TAB>0|1                                  -> 全局开关
//      rule<TAB><ssid><TAB><real><TAB><fake><TAB>0|1    -> 追加规则（ssid/real 可为空）
//      default<TAB><fake><TAB>0|1                       -> 默认伪造值
//      query<TAB><ssid><TAB><bssid>                     -> 查询（bssid 留空 = 空串）
//      querynil<TAB><ssid>                              -> 查询真实值为 NULL 的情形
//
//  用法：map-sim < map-input.tsv
//  退出码：0 = 全部输入解析成功；1 = 有规则/输入被拒（配置有问题）；2 = 用法错误
//
//  由 ios/tests/host/map-sim.sh 负责用 jq 从 bssid_map.json 抽取输入。
//  注意：JSON → BGRuleSet 这一步由 jq + BGGhostRuleSetAdd 完成（不是 NSJSONSerialization），
//  所以本工具验证的是「映射代码 + 配置取值」的端到端结果，
//  不覆盖 BGGhostMap.m 的解析实现（那需要真 SDK 编译，见 docs/STATUS.md）。
//

#include "../../hooks/BGGhostRules.h"

#include <stdio.h>
#include <string.h>

#define BG_SIM_MAX_FIELDS 8

/// 按制表符就地切分，返回字段数。最后一个字段保留剩余全部内容。
static int split_fields(char *line, char *fields[], int max_fields) {
    int count = 0;
    fields[count++] = line;
    for (char *p = line; *p != '\0' && count < max_fields; p++) {
        if (*p == '\t') {
            *p = '\0';
            fields[count++] = p + 1;
        }
    }
    return count;
}

static void strip_eol(char *line) {
    size_t n = strlen(line);
    while (n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r')) {
        line[--n] = '\0';
    }
}

static const char *show(const char *s) {
    return (s == NULL) ? "(NULL)" : s;
}

int main(void) {
    BGRuleSet set;
    BGGhostRuleSetInit(&set);

    int problems = 0;
    int rule_seen = 0;
    int query_seen = 0;
    int replaced = 0;
    int passthrough = 0;

    char line[4096];
    while (fgets(line, sizeof(line), stdin) != NULL) {
        strip_eol(line);
        if (line[0] == '\0' || line[0] == '#') {
            continue;
        }

        char *f[BG_SIM_MAX_FIELDS];
        const int n = split_fields(line, f, BG_SIM_MAX_FIELDS);
        const char *kind = f[0];

        if (strcmp(kind, "global") == 0) {
            if (n < 2) {
                fprintf(stderr, "!! global 缺少取值\n");
                problems++;
                continue;
            }
            set.enabled = (strcmp(f[1], "1") == 0 || strcmp(f[1], "true") == 0) ? 1 : 0;
            printf("全局开关: %s\n", set.enabled ? "开" : "关（整表不生效）");

        } else if (strcmp(kind, "rule") == 0) {
            if (n < 5) {
                fprintf(stderr, "!! rule 需要 4 个参数（ssid/real/fake/enabled），收到 %d 个\n", n - 1);
                problems++;
                continue;
            }
            const char *ssid = f[1];
            const char *real = f[2];
            const char *fake = f[3];
            const int enabled = (strcmp(f[4], "1") == 0 || strcmp(f[4], "true") == 0) ? 1 : 0;
            if (BGGhostRuleSetAdd(&set, ssid, real, fake, enabled)) {
                printf("规则 #%d: SSID=%s 真实=%s -> 伪造=%s [%s]\n",
                       rule_seen + 1, show(ssid[0] ? ssid : NULL),
                       show(real[0] ? real : NULL), fake,
                       enabled ? "启用" : "禁用");
                rule_seen++;
            } else {
                // 被拒的原因通常是 BSSID 格式非法 / SSID 超长 / 表满
                fprintf(stderr, "!! 规则被拒（BSSID 格式非法 / SSID 超长 / 表已满）：SSID=%s real=%s fake=%s\n",
                        show(ssid), show(real), fake);
                problems++;
            }

        } else if (strcmp(kind, "default") == 0) {
            if (n < 3) {
                fprintf(stderr, "!! default 需要 2 个参数（fake/enabled）\n");
                problems++;
                continue;
            }
            const int enabled = (strcmp(f[2], "1") == 0 || strcmp(f[2], "true") == 0) ? 1 : 0;
            if (!enabled) {
                printf("默认值: 未启用（未命中规则的网络一律透传）\n");
            } else if (BGGhostNormalizeBSSID(f[1], set.default_fake_bssid)) {
                set.has_default = 1;
                printf("默认值: %s [启用]\n", set.default_fake_bssid);
            } else {
                fprintf(stderr, "!! default.fake_bssid 非法，已忽略：%s\n", f[1]);
                problems++;
            }

        } else if (strcmp(kind, "query") == 0 || strcmp(kind, "querynil") == 0) {
            const char *ssid = (n >= 2) ? f[1] : NULL;
            const char *real = NULL;
            if (strcmp(kind, "query") == 0 && n >= 3 && f[2][0] != '\0') {
                real = f[2];
            }

            char out[BG_BSSID_STR_MAX];
            memset(out, 0, sizeof(out));
            const int hit = BGGhostMapBSSIDC(&set, ssid, real, out);

            printf("\n查询: SSID=%s 真实 BSSID=%s\n", show(ssid), show(real));
            if (hit) {
                printf("      返回 \"%s\"  [已替换]\n", out);
                replaced++;
            } else if (real == NULL || real[0] == '\0') {
                printf("      返回 (原值)  [透传 —— 真实值缺失，不得凭空构造]\n");
                passthrough++;
            } else {
                printf("      返回 \"%s\"  [透传 —— 未命中规则 / 全局关闭 / 入参畸形]\n", real);
                passthrough++;
            }
            query_seen++;

        } else {
            fprintf(stderr, "!! 未知输入类型：%s\n", kind);
            problems++;
        }
    }

    printf("\n配置概览: 规则 %d 条，全局=%s，默认值=%s | 查询 %d 次（替换 %d / 透传 %d）%s\n",
           set.count, set.enabled ? "开" : "关",
           set.has_default ? "启用" : "未启用",
           query_seen, replaced, passthrough,
           problems ? "；存在解析问题" : "");

    return problems ? 1 : 0;
}
