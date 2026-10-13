#!/usr/bin/env bash
#
# BSSIDGhost - 验证脚本（只读，不改动设备）
#
# 三层检查：
#   1. 本地配置：授权闸状态 + 预期映射值（来自 config/）
#   2. 设备侧  ：SSH 抓取日志，判定 Hook 是否真的启用（T1）或是否被授权闸拒绝（T9）
#   3. 后续步骤：打印测试矩阵清单与真机抓栈命令（不自动执行 frida）
#
# 退出码：
#   0  设备侧检查已执行且通过
#   1  有检查明确失败（例如日志显示「拒绝启用」）
#   2  本地检查通过，但设备侧未执行（未提供设备/SSH 不可达）
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DEVICE_UDID="${BGGHOST_UDID:-}"
SSH_TARGET="${BGGHOST_SSH:-mobile@127.0.0.1}"
SSH_PORT="${BGGHOST_SSH_PORT:-2222}"
PRIV="${BGGHOST_PRIV-sudo}"
LOG_PATH="${BG_DEVICE_LOG}"
SKIP_DEVICE=0

usage() {
    cat <<EOF
用法: scripts/verify.sh [选项]

  --udid UDID      目标设备 UDID（缺省时若只有一台设备会自动选择）
  --ssh USER@HOST  SSH 目标，默认 mobile@127.0.0.1
  --port PORT      SSH 端口，默认 2222
  --log PATH       设备上的日志路径，默认 ${BG_DEVICE_LOG}
  --no-priv        已是 root，不需要 sudo
  --skip-device    只做本地配置检查（等价于无设备时的行为）
  --dry-run        只打印将要执行的命令
  -h, --help       显示本帮助

退出码: 0 = 设备侧检查通过；1 = 检查失败；2 = 仅完成本地检查
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid)        DEVICE_UDID="${2:?--udid 需要一个值}"; shift 2 ;;
        --ssh)         SSH_TARGET="${2:?--ssh 需要一个值}"; shift 2 ;;
        --port)        SSH_PORT="${2:?--port 需要一个值}"; shift 2 ;;
        --log)         LOG_PATH="${2:?--log 需要一个值}"; shift 2 ;;
        --no-priv)     PRIV=""; shift ;;
        --skip-device) SKIP_DEVICE=1; shift ;;
        --dry-run)     BG_DRY_RUN=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        *)             bg_die "未知参数：$1（用 --help 查看用法）" ;;
    esac
done

bg_step "BSSIDGhost verify"

FAILED=0
note_fail() { bg_warn "$1"; FAILED=1; }

# --- 1. 本地配置 -------------------------------------------------------------
bg_step "本地配置"

if bg_gate_report; then
    bg_info "授权闸：通过（scope.mode=${BG_GATE_SCOPE_MODE}，bundle_ids=${BG_GATE_BUNDLE_COUNT} 项）"
    bg_info "  -> 真机侧 Hook 应当启用（T1 期望出现「启用」）"
else
    bg_info "授权闸：未通过 —— ${BG_GATE_REASON}"
    bg_info "  -> 真机侧 Hook 会拒绝启用（T9 期望出现「拒绝启用」），这是当前仓库的预期状态"
fi

if ! command -v jq >/dev/null 2>&1; then
    bg_warn "未安装 jq，跳过映射值解析"
else
    bg_step "预期映射值（config/bssid_map.json）"
    map_enabled="$(jq -r '.enabled' "$(bg_map_json)")"
    bg_info "全局开关 enabled=${map_enabled}"
    jq -r '.rules[]? | "  规则 \(.name // "(未命名)"): SSID=\(.match.ssid // "*") 真实=\(.match.bssid // "*") -> 伪造=\(.replace.bssid) [enabled=\(.enabled // false)]"' \
        "$(bg_map_json)"
    jq -r '.default | "  默认值: fake_bssid=\(.fake_bssid) [enabled=\(.enabled // false)]"' "$(bg_map_json)"
    bg_info "随包落地路径: ${BG_SHARE_DIR}/bssid_map.json"
fi

# --- 2. 设备侧 ---------------------------------------------------------------
bg_step "设备侧"

run_device=1
if [[ "${SKIP_DEVICE}" -eq 1 ]]; then
    bg_info "按 --skip-device 跳过"
    run_device=0
fi

if [[ "${run_device}" -eq 1 ]]; then
    if [[ -z "${DEVICE_UDID}" ]] && command -v idevice_id >/dev/null 2>&1; then
        mapfile -t DEVICES < <(idevice_id -l 2>/dev/null || true)
        if [[ "${#DEVICES[@]}" -eq 1 ]]; then
            DEVICE_UDID="${DEVICES[0]}"
            bg_info "自动选择唯一设备: ${DEVICE_UDID}"
        elif [[ "${#DEVICES[@]}" -eq 0 ]]; then
            bg_info "未检测到设备（idevice_id -l 为空）"
            run_device=0
        else
            bg_info "检测到 ${#DEVICES[@]} 台设备，请用 --udid 指定"
            run_device=0
        fi
    fi

    if [[ "${run_device}" -eq 1 && "${BG_DRY_RUN}" -eq 0 ]]; then
        SSH_OPTS=(-p "${SSH_PORT}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)
        REMOTE_PRIV=""
        [[ -n "${PRIV}" ]] && REMOTE_PRIV="${PRIV} "

        if ssh "${SSH_OPTS[@]}" -o BatchMode=yes "${SSH_TARGET}" true 2>/dev/null; then
            bg_info "SSH 可达: ${SSH_TARGET}:${SSH_PORT}"
        else
            bg_info "SSH 不可达: ${SSH_TARGET}:${SSH_PORT}（需要 'iproxy ${SSH_PORT} 22' 与可用凭据）"
            run_device=0
        fi

        if [[ "${run_device}" -eq 1 ]]; then
            log_dump="$(ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
                "${REMOTE_PRIV}sh -c 'test -f ${LOG_PATH} && tail -n 200 ${LOG_PATH}'" 2>/dev/null || true)"
            if [[ -z "${log_dump}" ]]; then
                bg_info "日志为空或不存在: ${LOG_PATH}"
                note_fail "没有日志：Hook 未加载，或 app 尚未冷启动（T1 无法判定）"
            else
                bg_info "日志片段（最后 200 行）："
                printf '%s\n' "${log_dump}" | tail -n 20 | sed 's/^/      /'

                if printf '%s' "${log_dump}" | grep -q '拒绝启用'; then
                    note_fail "日志出现「拒绝启用」—— 授权闸拦住了 Hook（对应 T9）。若这不是预期，请检查设备上的 targets.json"
                fi
                if printf '%s' "${log_dump}" | grep -q '启用'; then
                    bg_info "日志出现「启用」—— Hook 已注册（T1 通过）"
                else
                    note_fail "日志未出现「启用」—— Hook 未生效（T1 未通过）"
                fi
            fi
        fi
    elif [[ "${run_device}" -eq 1 ]]; then
        bg_print_cmd ssh -p "${SSH_PORT}" "${SSH_TARGET}" "tail -n 200 ${LOG_PATH}"
    fi
fi

# --- 3. 后续步骤 -------------------------------------------------------------
bg_step "仍需人工确认的项（真机）"

if command -v frida >/dev/null 2>&1; then
    bg_info "frida: 已安装（$(frida --version 2>/dev/null || echo '版本未知')）"
else
    bg_info "frida: 未安装 —— 真机抓栈（tests/frida/）暂不可执行，安装方式见 docs/device-setup.md"
fi

cat <<EOF

测试矩阵（详见 tests/README.md，证据落 tests/evidence/）：
  [ ] T1  Hook 已加载        —— 日志出现「启用」（本脚本可判定）
  [ ] T2  BSSID 已替换       —— App 读到伪造值（需抓栈/界面确认）
  [ ] T3  SSID 保持不变      —— App 读到真实 SSID
  [ ] T4  真实链路未受影响   —— 仍可正常联网
  [ ] T5  格式一致           —— 伪造值大小写/分隔符与真实值一致（L1 已覆盖逻辑）
  [ ] T6  多次调用           —— 前台/后台切换后仍为伪造值
  [ ] T7  无规则透传         —— 未配置网络返回真实 BSSID（L1 已覆盖逻辑）
  [ ] T8  作用域             —— 非目标 App 内不生效（L1 已覆盖判定）
  [ ] T9  授权闸             —— 未授权时拒绝启用并写明字段（本脚本可判定）
  [ ] T10 交叉校验未触发     —— App 无异常上报 / 无风控拦截

真机抓栈（只读，需先装 frida 且授权已登记）：
  frida -U -f <bundleid> -l tests/frida/capture-wifi-api.js -o tests/evidence/\$(date +%Y%m%d-%H%M%S)-capture.jsonl
EOF

echo
if [[ "${FAILED}" -ne 0 ]]; then
    bg_warn "存在失败的检查项。"
    exit 1
fi
if [[ "${run_device}" -eq 0 ]]; then
    bg_info "本地检查通过；设备侧未执行（退出码 2）。"
    exit 2
fi
bg_info "全部已执行的检查通过。"
