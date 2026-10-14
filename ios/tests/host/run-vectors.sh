#!/usr/bin/env bash
#
# BSSIDGhost - 语言中立向量的执行器（L1）
#
# 把 shared/vectors/*.json 用 jq 转成 USV（0x1f 分隔）流，喂给两个 C 驱动，
# 由它们调用**真实的核心代码**并与向量里写死的期望值比对。
#
# 为什么要绕这一层：C 端没有 JSON 解析器，而向量必须是**两端可读的数据**。
# jq 是本仓库既有的依赖（构建脚本一直在用），所以转换放在这里最省事。
#
# 运行：ios/tests/host/run-vectors.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CC="${CC:-clang}"
OUT_DIR="${ROOT}/build/host-tests"
VEC_DIR="${ROOT}/shared/vectors"
HOST_DIR="${ROOT}/ios/tests/host"
CFLAGS=(-std=c11 -Wall -Wextra -Werror -O1 -g -I"${ROOT}/ios/hooks")

if ! command -v jq >/dev/null 2>&1; then
    echo "!! 向量执行需要 jq（把 JSON 转成驱动可读的流）。" >&2
    exit 1
fi
if [[ ! -f "${VEC_DIR}/bssid-map.json" || ! -f "${VEC_DIR}/auth-gate.json" ]]; then
    echo "!! 找不到向量文件：${VEC_DIR}/{bssid-map.json,auth-gate.json}" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

echo "==> 向量执行器（shared/vectors/）"
echo "    编译器: ${CC}"

echo
echo "==> [vector_rules] 编译"
"${CC}" "${CFLAGS[@]}" \
    "${ROOT}/ios/hooks/BGGhostRules.c" \
    "${HOST_DIR}/vector_rules.c" \
    -o "${OUT_DIR}/vector_rules"

echo "==> [vector_auth] 编译"
"${CC}" "${CFLAGS[@]}" \
    "${ROOT}/ios/hooks/BGGhostAuth.c" \
    "${HOST_DIR}/vector_auth.c" \
    -o "${OUT_DIR}/vector_auth"

FAILED=0

# --- 映射侧 ------------------------------------------------------------------
echo
echo "==> [vector_rules] 运行"
jq -r '
  def j: join("\u001f");
  def s(v): if v == null then "@null@" else v end;
  ( .normalize[] | ["N", .name, s(.in), (if .ok then "1" else "0" end), (.out // "-")] | j ),
  ( .render[]    | ["R", .name, s(.real), s(.fake), (if .ok then "1" else "0" end), (.out // "-")] | j ),
  ( .map[] |
      ( ["SET", (if .set.enabled then "1" else "0" end),
                (if .set.default.enabled then "1" else "0" end),
                (.set.default.fake_bssid // "-")] | j ),
      ( .rules[] | ["RULE", s(.ssid), s(.real_bssid), s(.fake_bssid),
                     (if .enabled then "1" else "0" end)] | j ),
      ( .queries[] | ["Q", .name, s(.ssid), s(.real_bssid),
                       (if .hit then "1" else "0" end), (.out // "-")] | j )
  ),
  ( .add[] |
      if .op == "add" then
        ["A", .name, s(.ssid), s(.real_bssid), s(.fake_bssid),
         (if .enabled then "1" else "0" end), (if .ok then "1" else "0" end),
         ((.count_after // "-") | tostring)] | j
      elif .op == "fill" then
        ["FILL", .name, (.count | tostring), .fake_bssid,
         (.expect_added | tostring), ((.count_after // "-") | tostring)] | j
      else
        ["FILL_OVERFLOW", .name, (.count | tostring), .fake_bssid,
         (if .ok then "1" else "0" end), ((.count_after // "-") | tostring)] | j
      end
  )
' "${VEC_DIR}/bssid-map.json" | "${OUT_DIR}/vector_rules" || FAILED=1

# --- 授权闸侧 ----------------------------------------------------------------
echo
echo "==> [vector_auth] 运行"
jq -r '
  def j: join("\u001f");
  def s(v): if v == null then "@null@" else v end;
  def raw(v): if v == null then "@null@"
              elif (v | type) == "object" then (v.repeat * v.times)
              else v end;
  (.contract.auth_keys) as $keys |
  ( .contract.field_names | to_entries[] |
      ["CT", (.key | tostring), .value, $keys[.key]] | j ),
  ( .contract.result_codes[] | ["CR", .] | j ),
  ( .field_set[] | ["FS", .name,
      (if .key == "" then "@empty@" else .key end),
      raw(.value),
      (if .ok then "1" else "0" end)] | j ),
  ( .bundle_add[] |
      if .op == "add" then
        ["BA", .name,
         (if .bundle_id == "" then "@empty@" else raw(.bundle_id) end),
         (if .ok then "1" else "0" end)] | j
      elif .op == "fill" then
        ["BZ", .name, (.count | tostring), (.expect_added | tostring),
         (.count_after | tostring)] | j
      else
        ["BO", .name, (.count | tostring), (if .ok then "1" else "0" end),
         (.count_after | tostring)] | j
      end
  ),
  ( .cases[] |
      ( ["CASE", .name, (if .config == null then "1" else "0" end)] | j ),
      ( if .config == null then empty else
          ( (.config.authorization // {}) | to_entries[] |
              ["CF", .key, s(.value)] | j ),
          ( ["CM", (if .config.scope.mode == "" then "@empty@" else .config.scope.mode end)] | j ),
          ( (.config.scope.bundle_ids // [])[] | ["CB", .] | j ),
          ( ["CC",
              (if .config.constraints.only_test_devices then "1" else "0" end),
              (if .config.constraints.only_test_network then "1" else "0" end),
              (if .config.constraints.no_production_targets then "1" else "0" end)] | j )
        end ),
      ( (.extra_writes // [])[] | ["CW", .key, s(.value)] | j ),
      ( ["CP", (if .process == null then "@null@"
                elif .process == "" then "@empty@"
                else .process end)] | j ),
      ( ["CX", .expect.result,
         (if .expect.field == null then "@null@" else .expect.field end)] | j )
  )
' "${VEC_DIR}/auth-gate.json" | "${OUT_DIR}/vector_auth" || FAILED=1

echo
if [[ "${FAILED}" -ne 0 ]]; then
    echo "!! 向量存在失败项。" >&2
    exit 1
fi
echo "==> 向量全部通过"
