#!/usr/bin/env bash
#
# BSSIDGhost - 配置契约检查（L0）
#
# 校验 shared/config/*.json 与 ios/hooks/*.c 之间的**接口契约**：
#   - 授权字段键名是否与 BGGhostAuth.c 的 kBGAuthFieldKeys 完全一致（拼错 = 闸门静默失效）
#   - scope.mode / constraints / bundle_ids 的取值与容量是否落在 C 侧接受范围内
#   - 规则表的 BSSID 格式与条数上限是否会被 BGGhostRules.c 接受
#   - 日志设置是否完整
#
# 这里**不重复实现判定逻辑**（那在 BGGhostAuth.c，由 ios/tests/host 单测覆盖），
# 只检查「配置的写法能不能被代码认出来」。
#
# 依赖：bash + jq。运行：ios/tests/host/run.sh（会先跑本脚本）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGETS_JSON="${ROOT}/shared/config/targets.json"
MAP_JSON="${ROOT}/shared/config/bssid_map.json"
AUTH_C="${ROOT}/ios/hooks/BGGhostAuth.c"
RULES_H="${ROOT}/ios/hooks/BGGhostRules.h"

FAILED=0

ok()   { echo "  ok   $*"; }
bad()  { echo "  FAIL $*" >&2; FAILED=1; }
note() { echo "  注意 $*"; }

if ! command -v jq >/dev/null 2>&1; then
    echo "!! 本脚本需要 jq。" >&2
    exit 1
fi

for f in "${TARGETS_JSON}" "${MAP_JSON}" "${AUTH_C}" "${RULES_H}"; do
    [[ -f "$f" ]] || { echo "!! 缺少文件: $f" >&2; exit 1; }
done

echo "==> 配置契约检查"

# --- 1. JSON 可解析 ---------------------------------------------------------
if jq empty "${TARGETS_JSON}" 2>/dev/null; then ok "targets.json 可解析"; else bad "targets.json 解析失败"; fi
if jq empty "${MAP_JSON}" 2>/dev/null; then ok "bssid_map.json 可解析"; else bad "bssid_map.json 解析失败"; fi

# --- 2. scope -----------------------------------------------------------------
MODE="$(jq -r '.scope.mode // ""' "${TARGETS_JSON}")"
case "${MODE}" in
    allowlist|all) ok "scope.mode = ${MODE}" ;;
    *) bad "scope.mode 非法或缺失：'${MODE}'（C 侧只接受 allowlist / all）" ;;
esac

TOTAL_IDS="$(jq -r '[.scope.bundle_ids[]?] | length' "${TARGETS_JSON}")"
VALID_IDS="$(jq -r '[.scope.bundle_ids[]? | select(type == "string" and length > 0)] | length' "${TARGETS_JSON}")"
if [[ "${TOTAL_IDS}" != "${VALID_IDS}" ]]; then
    bad "scope.bundle_ids 含非字符串或空字符串项（C 侧会忽略它们）"
else
    ok "scope.bundle_ids 共 ${TOTAL_IDS} 项且均为非空字符串"
fi

MAX_BUNDLES="$(sed -n 's/^#define BG_AUTH_MAX_BUNDLES \([0-9]*\)$/\1/p' "${ROOT}/ios/hooks/BGGhostAuth.h")"
MAX_BUNDLES="${MAX_BUNDLES:-8}"
if [[ "${TOTAL_IDS}" -gt "${MAX_BUNDLES}" ]]; then
    bad "scope.bundle_ids 有 ${TOTAL_IDS} 项，超过 C 侧上限 ${MAX_BUNDLES}（多余项会被静默忽略）"
else
    ok "bundle_ids 数量在 C 侧上限 ${MAX_BUNDLES} 之内"
fi

if [[ "${MODE}" == "allowlist" && "${VALID_IDS}" -lt 1 ]]; then
    bad "scope.mode=allowlist 但没有任何有效 bundle_ids（C 侧会判定 BG_AUTH_ERR_SCOPE_EMPTY）"
fi

# --- 3. authorization 键名必须与 C 侧表一致 ----------------------------------
# 只取第一处声明块：anchored 起始行 + 到第一个 `};` 为止。
mapfile -t C_AUTH_KEYS < <(
    awk '/^static const char \*const kBGAuthFieldKeys\[/{flag=1} flag{print} flag && /};/{exit}' "${AUTH_C}" \
        | grep -oE '"[a-z_]+"' | tr -d '"'
)
mapfile -t JSON_AUTH_KEYS < <(
    jq -r '.authorization | keys[] | select(startswith("_") | not)' "${TARGETS_JSON}"
)

if [[ "${#C_AUTH_KEYS[@]}" -eq 0 ]]; then
    bad "无法从 BGGhostAuth.c 提取 kBGAuthFieldKeys（脚本需同步更新？）"
fi

for key in "${C_AUTH_KEYS[@]}"; do
    if ! printf '%s\n' "${JSON_AUTH_KEYS[@]}" | grep -qx "${key}"; then
        bad "targets.json 的 authorization 缺少 C 侧要求的字段：${key}"
    fi
done
for key in "${JSON_AUTH_KEYS[@]}"; do
    if ! printf '%s\n' "${C_AUTH_KEYS[@]}" | grep -qx "${key}"; then
        bad "targets.json 的 authorization 含 C 侧不认识的字段：${key}（会被忽略 -> 该授权信息实际未登记）"
    fi
done

NON_STRING="$(jq -r '[.authorization | to_entries[] | select(.key | startswith("_") | not) | select(.value | type != "string")] | length' "${TARGETS_JSON}")"
if [[ "${NON_STRING}" -ne 0 ]]; then
    bad "authorization 下有 ${NON_STRING} 个非字符串值（C 侧会忽略）"
else
    ok "authorization 字段类型均为字符串"
fi

# 授权是否已填（只报告，不失败 —— 未填是当前仓库的合法状态）
PLACEHOLDERS="$(jq -r '[.authorization | to_entries[] | select(.key | startswith("_") | not) | select((.value | type == "string") and ((.value | ascii_downcase | gsub("^\\s+|\\s+$"; "")) == "fill_me" or (.value | gsub("^\\s+|\\s+$"; "")) == ""))] | length' "${TARGETS_JSON}")"
if [[ "${PLACEHOLDERS}" -eq 0 ]]; then
    ok "授权字段已填齐（授权闸可能放行）"
else
    note "授权字段仍有 ${PLACEHOLDERS} 个为空或 fill_me -> 真机侧 Hook 会拒绝启用（这是预期行为）"
fi

# --- 4. constraints ----------------------------------------------------------
for key in only_test_devices only_test_network no_production_targets; do
    VALUE="$(jq -r --arg k "${key}" '.constraints[$k] | if type == "boolean" then tostring else "MISSING" end' "${TARGETS_JSON}")"
    case "${VALUE}" in
        true)  ok "constraints.${key} = true" ;;
        false) note "constraints.${key} = false -> 授权闸会拒绝启用" ;;
        *)     bad "constraints.${key} 缺失或不是布尔值（C 侧按 false 处理 -> 拒绝启用）" ;;
    esac
done

# --- 5. 规则表 ---------------------------------------------------------------
# 与 BGGhostRules.c 的宽松解析保持一致：允许 : / - / 无分隔符，忽略前后空白。
is_bssid() {
    [[ "$1" =~ ^[[:space:]]*[0-9a-fA-F]{2}([:-]?[0-9a-fA-F]{2}){5}[[:space:]]*$ ]]
}

MAX_RULES="$(sed -n 's/^#define BG_RULE_MAX_COUNT \([0-9]*\)$/\1/p' "${RULES_H}")"
MAX_RULES="${MAX_RULES:-16}"

mapfile -t RULES < <(jq -c '.rules[]?' "${MAP_JSON}")
if [[ "${#RULES[@]}" -gt "${MAX_RULES}" ]]; then
    bad "rules 有 ${#RULES[@]} 条，超过 C 侧上限 ${MAX_RULES}（超出部分会被拒绝加载）"
else
    ok "rules 共 ${#RULES[@]} 条，在上限 ${MAX_RULES} 之内"
fi

INDEX=0
for rule in "${RULES[@]}"; do
    NAME="$(jq -r '.name // "(未命名)"' <<<"${rule}")"
    FAKE="$(jq -r '.replace.bssid // ""' <<<"${rule}")"
    REAL="$(jq -r '.match.bssid // ""' <<<"${rule}")"
    ENABLED="$(jq -r '.enabled // false' <<<"${rule}")"

    if is_bssid "${FAKE}"; then
        ok "rules[${INDEX}] ${NAME}: replace.bssid 格式合法 (${FAKE}${ENABLED:+, enabled=${ENABLED}})"
    else
        bad "rules[${INDEX}] ${NAME}: replace.bssid 无法被 C 侧解析：'${FAKE}'"
    fi

    if [[ -n "${REAL}" ]] && ! is_bssid "${REAL}"; then
        bad "rules[${INDEX}] ${NAME}: match.bssid 无法被 C 侧解析：'${REAL}'"
    fi
    INDEX=$((INDEX + 1))
done

# default 段：只有显式 enabled 才生效。
DEFAULT_ENABLED="$(jq -r '.default.enabled // false' "${MAP_JSON}")"
DEFAULT_FAKE="$(jq -r '.default.fake_bssid // ""' "${MAP_JSON}")"
if [[ "${DEFAULT_ENABLED}" == "true" ]]; then
    if is_bssid "${DEFAULT_FAKE}"; then
        ok "default.enabled=true，default.fake_bssid 格式合法"
    else
        bad "default.enabled=true 但 default.fake_bssid 无法解析：'${DEFAULT_FAKE}'"
    fi
else
    ok "default.enabled=false -> 未命中规则的网络一律透传（T7）"
fi

# --- 6. 日志设置 -------------------------------------------------------------
# R13 起路径**按平台取值**：log.paths.{ios,android}。iOS 必须有绝对路径；
# android 允许为 null（主通道是 logcat；Android 已暂停冻结，文件路径随解冻再定），
# 但一旦给出就必须是绝对路径。
LOG_ENABLED="$(jq -r '.log.enabled // false' "${MAP_JSON}")"
LOG_PATH_IOS="$(jq -r '.log.paths.ios // ""' "${MAP_JSON}")"
LOG_PATH_ANDROID="$(jq -r '.log.paths.android // ""' "${MAP_JSON}")"
LOG_PATH_LEGACY="$(jq -r '.log.path // ""' "${MAP_JSON}")"
LOG_MAX="$(jq -r '.log.max_bytes // 0' "${MAP_JSON}")"

if [[ -n "${LOG_PATH_LEGACY}" ]]; then
    # 同名旧键若还在，解析方会静默走错分支 —— 必须显式拦住，而不是容忍两份并存。
    bad "log.path 是 R12 之前的旧键（单平台），已改为 log.paths.{ios,android}：请删除 log.path"
fi

if [[ "${LOG_ENABLED}" == "true" ]]; then
    if [[ -z "${LOG_PATH_IOS}" ]]; then
        bad "log.enabled=true 但 log.paths.ios 为空 -> iOS 会退化为仅 NSLog"
    elif [[ "${LOG_PATH_IOS}" != /* ]]; then
        bad "log.paths.ios 不是绝对路径：'${LOG_PATH_IOS}'"
    else
        ok "log.paths.ios=${LOG_PATH_IOS}"
    fi

    if [[ -z "${LOG_PATH_ANDROID}" || "${LOG_PATH_ANDROID}" == "null" ]]; then
        note "log.paths.android 未定（Android 主通道为 logcat；Android 已冻结，解冻后再定）"
    elif [[ "${LOG_PATH_ANDROID}" != /* ]]; then
        bad "log.paths.android 不是绝对路径：'${LOG_PATH_ANDROID}'"
    else
        ok "log.paths.android=${LOG_PATH_ANDROID}"
    fi
fi
if ! [[ "${LOG_MAX}" =~ ^[0-9]+$ ]]; then
    bad "log.max_bytes 不是非负整数：'${LOG_MAX}'"
elif [[ "${LOG_MAX}" -eq 0 ]]; then
    note "log.max_bytes=0 -> 使用代码内默认值 1 MiB"
else
    ok "log.max_bytes=${LOG_MAX}"
fi

# --- 7. 提交在仓库里的过滤器 plist 必须与 targets.json 一致 ------------------
# 它由 ios/scripts/build.sh 重新生成，但仓库里留一份「安全默认」以免直接 make package
# 时插件在所有进程加载。这里防止两份内容漂移。
PLIST="${ROOT}/ios/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist"
if [[ -f "${PLIST}" ]]; then
    mapfile -t PLIST_BUNDLES < <(grep -oE '"[^"]+"' "${PLIST}" | tr -d '"' | sort)
    mapfile -t CFG_BUNDLES < <(jq -r '.scope.bundle_ids[]? | select(type == "string" and length > 0)' "${TARGETS_JSON}" | sort)
    if [[ "${#PLIST_BUNDLES[@]}" -eq 0 ]]; then
        bad "${PLIST##*/} 里没有解析到任何 Bundle，会在所有进程加载"
    elif [[ "$(printf '%s\n' "${PLIST_BUNDLES[@]}")" == "$(printf '%s\n' "${CFG_BUNDLES[@]}")" ]]; then
        ok "过滤器 plist 与 targets.json 的 bundle_ids 一致（${#CFG_BUNDLES[@]} 项）"
    else
        bad "过滤器 plist 与 targets.json 的 bundle_ids 不一致：plist=[${PLIST_BUNDLES[*]}] / config=[${CFG_BUNDLES[*]}]（重新生成：ios/scripts/build.sh --dry-run --toolchain theos）"
    fi
else
    note "未找到 ${PLIST##*/}；只走 clang 手工注入路线时可以不提交它"
fi

# --- 汇总 --------------------------------------------------------------------
echo
if [[ "${FAILED}" -ne 0 ]]; then
    echo "!! 配置契约检查未通过。" >&2
    exit 1
fi
echo "==> 配置契约检查通过"
