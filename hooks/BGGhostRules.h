//
//  BGGhostRules.h
//  BSSIDGhost
//
//  BSSID 映射的纯 C 核心：不依赖 Foundation / ObjC 运行时，
//  因此可以在主机（Linux/macOS）上直接编译并用 tests/host/ 的单测覆盖。
//
//  设计约束（对齐 docs/tech-chain.md 与 tests/README.md）：
//    1. 只决定 BSSID 的替换值与格式，绝不改动 SSID。
//    2. 默认不改变行为：全局关闭、无匹配规则、畸形输入、nil 输入一律“透传”。
//    3. nil 语义：真实值为 NULL / 空串时**不得凭空构造** BSSID，直接返回未命中。
//    4. 格式一致性：输出的大小写与分隔符必须与真实返回值完全一致，
//       否则 App 侧字符串比较会失败（见 tech-chain.md 第 3 节）。
//

#ifndef BG_GHOST_RULES_H
#define BG_GHOST_RULES_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 规则表容量上限。超出后 BGGhostRuleSetAdd 拒绝添加（不覆盖已有规则）。
#define BG_RULE_MAX_COUNT 16

/// BSSID 字符串缓冲长度："AA:BB:CC:DD:EE:FF" + NUL。
#define BG_BSSID_STR_MAX 18

/// SSID 缓冲长度：802.11 上限 32 字节 + NUL。
#define BG_SSID_STR_MAX 33

/// 单条规则。两个 BSSID 字段内部一律以「大写 + 冒号」归一化存储。
typedef struct {
    char ssid[BG_SSID_STR_MAX];        ///< 空串 = 不限制 SSID
    char real_bssid[BG_BSSID_STR_MAX]; ///< 空串 = 不限制真实 BSSID
    char fake_bssid[BG_BSSID_STR_MAX]; ///< 替换值（归一化存储）
    int  enabled;                      ///< 0 = 跳过该规则
} BGRule;

/// 整张映射表 + 全局开关 + 默认值。
typedef struct {
    BGRule rules[BG_RULE_MAX_COUNT];
    int    count;
    int    enabled;                               ///< 全局开关，0 = 整表不生效
    int    has_default;                           ///< default.enabled 为真且值合法
    char   default_fake_bssid[BG_BSSID_STR_MAX];
} BGRuleSet;

/// 归零初始化。任何使用前必须先调用（或 memset 0）。
void BGGhostRuleSetInit(BGRuleSet *set);

/// 追加一条规则，内部做格式归一化校验。
/// @return 1 = 已添加；0 = 参数非法 / 表已满。
int BGGhostRuleSetAdd(BGRuleSet *set,
                      const char *ssid,
                      const char *real_bssid,
                      const char *fake_bssid,
                      int enabled);

/// 归一化 BSSID 为「大写 + 冒号」。
/// 接受 `AA:BB:CC:DD:EE:FF` / `aa-bb-cc-dd-ee-ff` / `aabbccddeeff`（大小写与分隔符宽松），
/// 前后空白忽略；其余一律拒绝。
/// @return 1 = 成功（out 已写入）；0 = 失败（out 内容未定义）。
int BGGhostNormalizeBSSID(const char *in, char out[BG_BSSID_STR_MAX]);

/// 按真实返回值的格式渲染伪造 BSSID：分隔符（`:` / `-` / 无）与大小写跟随 real。
/// @return 1 = 成功；0 = 任一参数非法。
int BGGhostRenderLikeReal(const char *real_bssid,
                          const char *fake_bssid_normalized,
                          char out[BG_BSSID_STR_MAX]);

/// 核心映射。
/// 命中时把「按 real 格式渲染后的伪造值」写入 out 并返回 1；
/// 未命中 / 全局关闭 / nil 或空值 / 畸形值一律返回 0（**不写 out**，调用方沿用原值）。
int BGGhostMapBSSIDC(const BGRuleSet *set,
                     const char *ssid,
                     const char *real_bssid,
                     char out[BG_BSSID_STR_MAX]);

#ifdef __cplusplus
}
#endif

#endif /* BG_GHOST_RULES_H */
