#!/usr/bin/env bash
#
# BSSIDGhost - BSSID 映射模拟器（主机侧）
#
# 用真实的映射代码（ios/hooks/BGGhostRules.c）+ 真实的映射表（shared/config/bssid_map.json）回答：
#   「在给定 (SSID, 真实 BSSID) 下，目标 App 最终会读到什么？」
#
# 用法：
#   ios/tests/host/map-sim.sh                                  # 按配置里的每条规则自动生成查询
#   ios/tests/host/map-sim.sh --ssid Office_WiFi --bssid AA:BB:CC:DD:EE:FF
#   ios/tests/host/map-sim.sh --config /path/to/bssid_map.json
#   ios/tests/host/map-sim.sh --self-test                       # 8 组断言（含反向用例）
#
# 边界：JSON → BGRuleSet 这一步由 jq + BGGhostRuleSetAdd 完成（不是 NSJSONSerialization），
# 因此覆盖「映射代码 + 配置取值」的端到端结果，不覆盖 BGGhostMap.m 的解析实现。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CC="${CC:-clang}"
OUT_DIR="${ROOT}/build/host-tests"
BIN="${OUT_DIR}/map-sim"
CONFIG="${ROOT}/shared/config/bssid_map.json"
SSID=""
BSSID=""
SELF_TEST=0

usage() {
    cat <<'EOF'
用法: ios/tests/host/map-sim.sh [选项]

  （无选项）                    按配置里的每条规则自动生成查询，外加一条未配置网络的查询
  --ssid SSID                   指定查询的 SSID
  --bssid BSSID                 指定查询的真实 BSSID
  --config PATH                 使用指定的 bssid_map.json（默认 shared/config/bssid_map.json）
  --self-test                   跑 8 组断言（含反向用例）
  -h, --help                    显示本帮助

退出码：0 = 模拟正常完成（含"透传"结果）；1 = 配置有问题；2 = 用法错误
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ssid)      SSID="${2:?--ssid 需要一个值}"; shift 2 ;;
        --bssid)     BSSID="${2:?--bssid 需要一个值}"; shift 2 ;;
        --config)    CONFIG="${2:?--config 需要一个值}"; shift 2 ;;
        --self-test) SELF_TEST=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "!! 未知参数：$1" >&2; exit 2 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { echo "!! 需要 jq" >&2; exit 2; }

build() {
    mkdir -p "${OUT_DIR}"
    "${CC}" -std=c11 -Wall -Wextra -Werror -O1 -g \
        -I"${ROOT}/hooks" \
        "${ROOT}/ios/hooks/BGGhostRules.c" \
        "${ROOT}/ios/tests/host/map_sim.c" \
        -o "${BIN}"
}

# 从 bssid_map.json 抽取模拟器输入（只做机械抽取；格式合法性由 BGGhostRuleSetAdd 把关）。
extract_config() {
    jq -r '
      "global\t" + (if .enabled then "1" else "0" end),
      ( .rules[]?
        | "rule\t" + (.match.ssid // "") + "\t" + (.match.bssid // "")
          + "\t" + (.replace.bssid // "") + "\t" + (if .enabled then "1" else "0" end) ),
      ( "default\t" + (.default.fake_bssid // "") + "\t" + (if .default.enabled then "1" else "0" end) )
    ' "$1"
}

# 按配置里的每条规则生成一条查询（用规则自身的 SSID/真实 BSSID），
# 外加一条「未配置网络」的查询，用来直观看到 T7 的透传行为。
auto_queries() {
    jq -r '
      ( .rules[]? | "query\t" + (.match.ssid // "Any_SSID")
        + "\t" + (if (.match.bssid // "") == "" then "AA:BB:CC:DD:EE:FF" else .match.bssid end) ),
      "query\tUnconfigured_Network\tDE:AD:BE:EF:00:01",
      "querynil\tUnconfigured_Network"
    ' "$1"
}

run_sim() {
    local config="$1"
    { extract_config "${config}"; echo; auto_queries "${config}"; } | "${BIN}"
}

# --- 自检 -------------------------------------------------------------------
self_test() {
    local pass=0 fail=0
    local tmp
    tmp="$(mktemp -d)"

    ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
    bad() { fail=$((fail + 1)); printf '  FAIL %s -- %s\n' "$1" "$2"; }

    # expect: 名称 / 期望退出码 / 输出中必须出现的片段 / 输入 TSV / 禁止出现的片段
    expect() {
        local name="$1" want_code="$2" want_text="$3" input="$4" forbid="${5:-}"
        local out code
        set +e
        out="$(printf '%s' "${input}" | "${BIN}" 2>&1)"
        code=$?
        set -e
        if [[ "${code}" -ne "${want_code}" ]]; then
            bad "${name}" "退出码 ${code}，期望 ${want_code}；输出：$(printf '%s' "${out}" | tail -n 2 | tr '\n' ' ')"
            return
        fi
        if ! printf '%s' "${out}" | grep -qF -- "${want_text}"; then
            bad "${name}" "输出缺少 '${want_text}'"
            return
        fi
        if [[ -n "${forbid}" ]] && printf '%s' "${out}" | grep -qF -- "${forbid}"; then
            bad "${name}" "输出不应包含 '${forbid}'"
            return
        fi
        ok "${name}"
    }

    echo "==> BSSID 映射模拟器自检（真实映射代码 + 真实配置取值）"
    echo

    # 1) 仓库当前配置：全局 enabled=false -> 规则命中也必须透传
    expect "仓库当前配置（全局关闭）-> 规则命中也透传" \
        0 '透传' "$(extract_config "${ROOT}/shared/config/bssid_map.json")
query	Office_WiFi	AA:BB:CC:DD:EE:FF"

    # 2) 规则命中 + 大写冒号 -> 输出大写冒号
    expect "规则命中 -> 返回伪造值（大写冒号）" \
        0 '返回 "11:22:33:44:55:66"  [已替换]' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	1
default		0
query	Office_WiFi	AA:BB:CC:DD:EE:FF'

    # 3) 小写 + 连字符入参 -> 输出跟随
    expect "小写连字符入参 -> 输出小写连字符（格式跟随）" \
        0 '返回 "11-22-33-44-55-66"' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	1
default		0
query	Office_WiFi	aa-bb-cc-dd-ee-ff'

    # 4) 未配置网络 -> 透传（T7）
    expect "未配置网络 -> 透传（T7）" \
        0 '透传' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	1
default		0
query	Cafe_Free	DE:AD:BE:EF:00:01'

    # 5) nil 语义 -> 不得凭空构造
    expect "真实值为 NULL -> 透传，不构造" \
        0 '不得凭空构造' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	1
default		0
querynil	Office_WiFi'

    # 6) default 启用 -> 未配置网络使用默认值
    expect "default 启用 -> 未配置网络使用默认值" \
        0 '返回 "A1:B2:C3:D4:E5:F6"' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	1
default	A1:B2:C3:D4:E5:F6	1
query	Cafe_Free	DE:AD:BE:EF:00:01'

    # 7) 规则禁用 -> 透传
    expect "规则 enabled=0 -> 透传" \
        0 '透传' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	11:22:33:44:55:66	0
default		0
query	Office_WiFi	AA:BB:CC:DD:EE:FF'

    # 8) 伪造值格式非法 -> 规则被拒，模拟器退出码 1（配置有问题必须能被发现）
    expect "伪造值非法 -> 规则被拒且退出码为 1" \
        1 '规则被拒' \
        'global	1
rule	Office_WiFi	AA:BB:CC:DD:EE:FF	zz:zz:zz:zz:zz:zz	1
default		0
query	Office_WiFi	AA:BB:CC:DD:EE:FF'

    rm -rf "${tmp}"
    echo
    printf '结果：%d 通过, %d 失败\n' "${pass}" "${fail}"
    [[ "${fail}" -eq 0 ]] || return 1
}

build

if [[ "${SELF_TEST}" -eq 1 ]]; then
    self_test
else
    echo "==> BSSID 映射模拟（映射代码：ios/hooks/BGGhostRules.c；JSON 抽取：jq）"
    echo "    配置：${CONFIG}"
    echo
    if [[ -n "${SSID}" || -n "${BSSID}" ]]; then
        {
            extract_config "${CONFIG}"
            printf 'query\t%s\t%s\n' "${SSID}" "${BSSID}"
        } | "${BIN}"
    else
        run_sim "${CONFIG}"
    fi
    echo
    echo "提示：全局 enabled=false 时整表不生效，任何查询都会透传（这是安全默认）。"
fi
