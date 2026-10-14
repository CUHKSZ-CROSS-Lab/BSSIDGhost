#!/usr/bin/env bash
#
# BSSIDGhost - **iOS 专属**脚本共用的工具函数（授权闸 / 越狱路径 / 过滤器生成）。
#
# 只应被 source，不要直接执行：
#   source "$(dirname "$0")/lib/common.sh"
#
# 分层（R14 修正）：与平台无关的打印 / dry-run / 依赖检查在 `scripts/lib/common.sh`，
# 本文件会 source 它。**跨端脚本（如 scripts/publish.sh）不应依赖本文件。**
#
# 这里刻意**不重新实现**授权闸与映射的判定逻辑（那在 ios/hooks/BGGhostAuth.c 与
# ios/hooks/BGGhostRules.c，由 ios/tests/host 的 92 条断言覆盖）。本文件里的检查是
# 「明显未授权时不要继续」的脚本侧防线，语义与 C 侧保持一致，并由
# ios/tests/host/check-scripts.sh 做正向/反向验证。
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ios/scripts/lib/common.sh 只应被 source，不要直接执行。" >&2
    exit 1
fi

BG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# 根解析必须可验证：宁可在这里明确失败，也不要用错根目录静默跑偏。
if [[ ! -f "${BG_ROOT}/shared/config/targets.json" ]]; then
    printf '!! 仓库根解析失败：%s 下找不到 shared/config/targets.json\n' "${BG_ROOT}" >&2
    printf '   脚本被移动过？目录约定见 HANDOFF.md 的「目录结构」。\n' >&2
    exit 1
fi
# 跨端通用件：输出 / dry-run 执行器 / 依赖检查
# shellcheck source=../../../scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/lib" && pwd)/common.sh"

# 越狱形态（R1 确认 Dopamine/rootless；R14 复核为 iPhone 8 / A11，前缀 /var/jb）
BG_JB_PREFIX="${BGGHOST_JB_PREFIX:-/var/jb}"
BG_MIN_IOS="${BGGHOST_MIN_IOS:-15.0}"
BG_INSTALL_DYLIB_DIR="${BGGHOST_INSTALL_DYLIB_DIR:-${BG_JB_PREFIX}/usr/lib}"
BG_SHARE_DIR="${BGGHOST_SHARE_DIR:-${BG_JB_PREFIX}/usr/share/bssidghost}"
BG_DEVICE_LOG="${BGGHOST_LOG:-/var/mobile/Library/Logs/BSSIDGhost/ghost.log}"

# iOS 专属的依赖检查（跨端那份不关心 jq）
bg_require_jq() {
    bg_require_cmd jq "配置解析与过滤器生成都依赖它"
}

# --- 配置路径 ---------------------------------------------------------------

bg_targets_json() { printf '%s/shared/config/targets.json\n' "${BG_ROOT}"; }
bg_map_json()     { printf '%s/shared/config/bssid_map.json\n' "${BG_ROOT}"; }

# 授权字段键名必须与 ios/hooks/BGGhostAuth.c 的 kBGAuthFieldKeys 一致；
# ios/tests/host/check-config-contract.sh 会强制这一点。
BG_AUTH_KEYS=(target_app_owner authorized_by authorization_ref purpose test_device test_ap)
BG_CONSTRAINT_KEYS=(only_test_devices only_test_network no_production_targets)

# --- 授权闸（脚本侧防线，语义对齐 ios/hooks/BGGhostAuth.c）----------------------

BG_GATE_REASON=""

# 只报告，不退出：通过返回 0；不通过返回 1，并把原因写进 BG_GATE_REASON。
bg_gate_report() {
    BG_GATE_REASON=""
    local targets
    targets="$(bg_targets_json)"

    if [[ ! -f "${targets}" ]]; then
        BG_GATE_REASON="缺少 ${targets}"
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        BG_GATE_REASON="未安装 jq（无法解析配置）"
        return 1
    fi
    if ! jq empty "${targets}" 2>/dev/null; then
        BG_GATE_REASON="${targets} 不是合法 JSON"
        return 1
    fi

    local mode
    mode="$(jq -r '.scope.mode // ""' "${targets}")"
    case "${mode}" in
        allowlist|all) ;;
        *) BG_GATE_REASON="scope.mode 非法或缺失：'${mode}'（应为 allowlist 或 all）"; return 1 ;;
    esac

    local key
    for key in "${BG_AUTH_KEYS[@]}"; do
        if ! jq -e --arg k "${key}" '.authorization[$k] | type == "string"' "${targets}" >/dev/null; then
            BG_GATE_REASON="缺少 authorization.${key}（或不是字符串）"
            return 1
        fi
    done

    local pending
    pending="$(jq -r '
        [ .authorization
          | to_entries[]
          | select(.key | startswith("_") | not)
          | select(.value | type == "string")
          | select(((.value | gsub("^\\s+|\\s+$"; "")) | length) == 0
                   or ((.value | gsub("^\\s+|\\s+$"; "")) | ascii_downcase) == "fill_me")
        ] | length' "${targets}")"
    if [[ "${pending}" -ne 0 ]]; then
        BG_GATE_REASON="仍有 ${pending} 个授权字段未填写（空 / fill_me）"
        return 1
    fi

    for key in "${BG_CONSTRAINT_KEYS[@]}"; do
        if [[ "$(jq -r --arg k "${key}" '.constraints[$k] // false' "${targets}")" != "true" ]]; then
            BG_GATE_REASON="constraints.${key} 必须为 true"
            return 1
        fi
    done

    if [[ "${mode}" == "allowlist" ]]; then
        local count
        count="$(jq -r '[.scope.bundle_ids[]? | select(type == "string" and length > 0)] | length' "${targets}")"
        if [[ "${count}" -lt 1 ]]; then
            BG_GATE_REASON="scope.mode=allowlist 但 scope.bundle_ids 为空"
            return 1
        fi
    fi

    local valid total
    valid="$(jq -r '[.scope.bundle_ids[]? | select(type == "string" and length > 0)] | length' "${targets}")"
    total="$(jq -r '[.scope.bundle_ids[]?] | length' "${targets}")"
    if [[ "${valid}" != "${total}" ]]; then
        BG_GATE_REASON="scope.bundle_ids 含非字符串或空字符串项"
        return 1
    fi

    BG_GATE_SCOPE_MODE="${mode}"
    BG_GATE_BUNDLE_COUNT="${valid}"
    return 0
}

# 通过则继续，不通过则终止脚本。
bg_gate_check() {
    if ! bg_gate_report; then
        bg_die "授权闸未通过：${BG_GATE_REASON}。未登记授权不得构建或部署 —— 见 README 的用途与授权要求。"
    fi
    bg_info "授权闸：通过（scope.mode=${BG_GATE_SCOPE_MODE}，bundle_ids=${BG_GATE_BUNDLE_COUNT} 项）"
}

# --- theos 过滤器 -----------------------------------------------------------

# 从 shared/config/targets.json 生成 Substrate/ElleKit 过滤器 plist。
# 安全取向：**始终按 bundle_ids 过滤**，不因 scope.mode=all 而放宽注入范围；
# bundle_ids 为空时直接拒绝（否则插件会在所有进程加载）。
bg_generate_filter_plist() {
    local out="$1"
    local targets
    targets="$(bg_targets_json)"
    bg_require_jq

    local bundles
    bundles="$(jq -r '[.scope.bundle_ids[]? | select(type == "string" and length > 0) | @json] | join(", ")' "${targets}")"
    [[ -n "${bundles}" ]] || bg_die "scope.bundle_ids 为空：拒绝生成「无过滤器」的 plist（会让插件在所有进程加载）"

    mkdir -p "$(dirname "${out}")"
    printf '{ Filter = { Bundles = ( %s ); }; }\n' "${bundles}" > "${out}"
    bg_info "过滤器：$(basename "${out}") -> Bundles = ( ${bundles} )"
}

# 打包前检查 control 里是否还有占位符（<team> 等）。
bg_check_control_placeholders() {
    local control="$1"
    [[ -f "${control}" ]] || bg_die "缺少 ${control}"
    if grep -q '<team>' "${control}"; then
        bg_die "theos/control 仍含占位符 <team>：请先填入实际团队标识（命名规范见 docs/naming.md）"
    fi
}
