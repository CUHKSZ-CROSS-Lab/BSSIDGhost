#!/usr/bin/env bash
#
# BSSIDGhost - 部署脚本（rootless / Dopamine）
#
# 把产物推送到测试设备并让越狱运行时加载，两种方式：
#   deb    （默认）推送 packages/*.deb 并 dpkg -i —— 标准越狱安装路径
#   files  只推送 dylib + 过滤器 plist —— 不走包管理，便于快速迭代
#
# ⚠️ 仅用于自有 / 已获书面授权的测试设备与 App（见 README 的用途与授权要求）。
#    授权字段未填齐时本脚本拒绝执行。
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

METHOD="deb"
DEVICE_UDID="${BGGHOST_UDID:-}"
SSH_TARGET="${BGGHOST_SSH:-mobile@127.0.0.1}"
SSH_PORT="${BGGHOST_SSH_PORT:-2222}"
PRIV="${BGGHOST_PRIV-sudo}"        # 设为空串表示已是 root，无需提权
DO_RESPRING=0

DYLIB="${BG_ROOT}/build/libbssidghost.dylib"
REMOTE_LIB_DIR="${BG_INSTALL_DYLIB_DIR}"
REMOTE_PLIST_DIR="${BG_JB_PREFIX}/Library/MobileSubstrate/DynamicLibraries"
FILTER_PLIST="${BG_ROOT}/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist"
REMOTE_TMP="/var/mobile/bssidghost.deb"

usage() {
    cat <<EOF
用法: scripts/deploy.sh [选项]

  --method deb|files   部署方式，默认 deb（推送 deb 并 dpkg -i）
  --udid UDID          目标设备 UDID；缺省时自动用 idevice_id -l 的唯一设备
  --ssh USER@HOST      SSH 目标，默认 mobile@127.0.0.1（可用 BGGHOST_SSH 覆盖）
  --port PORT          SSH 端口，默认 2222（需先用 iproxy 2222 22 建立 USB 转发）
  --no-priv            已是 root，不需要 sudo（等价于 BGGHOST_PRIV=）
  --respring           安装后自动 sbreload/respring
  --dry-run            只打印将要执行的命令
  -h, --help           显示本帮助

环境变量:
  BGGHOST_UDID      目标设备 UDID
  BGGHOST_SSH       SSH 目标（默认 mobile@127.0.0.1）
  BGGHOST_SSH_PORT  SSH 端口（默认 2222）
  BGGHOST_PRIV      提权命令（默认 sudo；设为空串表示 root）
  BGGHOST_JB_PREFIX 越狱前缀（默认 /var/jb）
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --method)   METHOD="${2:?--method 需要一个值}"; shift 2 ;;
        --udid)     DEVICE_UDID="${2:?--udid 需要一个值}"; shift 2 ;;
        --ssh)      SSH_TARGET="${2:?--ssh 需要一个值}"; shift 2 ;;
        --port)     SSH_PORT="${2:?--port 需要一个值}"; shift 2 ;;
        --no-priv)  PRIV=""; shift ;;
        --respring) DO_RESPRING=1; shift ;;
        --dry-run)  BG_DRY_RUN=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          bg_die "未知参数：$1（用 --help 查看用法）" ;;
    esac
done

case "${METHOD}" in
    deb|files) ;;
    *) bg_die "--method 只能是 deb 或 files，收到 '${METHOD}'" ;;
esac

bg_step "BSSIDGhost deploy（${METHOD}）"

# --- 1. 授权闸 ---------------------------------------------------------------
bg_gate_check

# --- 2. 设备 ----------------------------------------------------------------
if [[ -z "${DEVICE_UDID}" ]]; then
    bg_require_cmd idevice_id "libimobiledevice"
    mapfile -t DEVICES < <(idevice_id -l 2>/dev/null || true)
    case "${#DEVICES[@]}" in
        1) DEVICE_UDID="${DEVICES[0]}"; bg_info "自动选择唯一设备: ${DEVICE_UDID}" ;;
        0) bg_die "未检测到 iOS 设备。请连接并解锁测试机，或显式指定 --udid。" ;;
        *) bg_die "检测到 ${#DEVICES[@]} 台设备，请用 --udid 指定其一。" ;;
    esac
fi

bg_info "设备:     ${DEVICE_UDID}"
bg_info "SSH:      ${SSH_TARGET}:${SSH_PORT}$([[ -z "${PRIV}" ]] && echo '（root）' || echo "（提权：${PRIV}）")"
bg_info "落地:     ${REMOTE_LIB_DIR}"

# --- 3. 产物 ----------------------------------------------------------------
artifact=""
case "${METHOD}" in
    deb)
        mapfile -t DEBS < <(ls -1t "${BG_ROOT}"/packages/*.deb 2>/dev/null || true)
        if [[ "${#DEBS[@]}" -eq 0 ]]; then
            [[ "${BG_DRY_RUN}" -eq 1 ]] || bg_die "未找到 packages/*.deb，请先执行 scripts/build.sh --toolchain theos"
            artifact="${BG_ROOT}/packages/BSSIDGhost_<version>_iphoneos-arm64.deb"
        else
            artifact="${DEBS[0]}"
        fi
        ;;
    files)
        artifact="${DYLIB}"
        if [[ ! -f "${artifact}" ]]; then
            [[ "${BG_DRY_RUN}" -eq 1 ]] || bg_die "未找到 ${artifact}，请先执行 scripts/build.sh --toolchain clang"
        fi
        if [[ ! -f "${FILTER_PLIST}" ]]; then
            bg_die "缺少过滤器 ${FILTER_PLIST}（可由 scripts/build.sh 生成）"
        fi
        ;;
esac
bg_info "产物:     ${artifact}"

# --- 4. 建立通道提示 --------------------------------------------------------
if [[ "${BG_DRY_RUN}" -eq 0 ]]; then
    bg_require_cmd ssh
    bg_require_cmd scp
fi

bg_step "推送与安装"
SSH_OPTS=(-p "${SSH_PORT}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
bg_info "提示: USB 转发需在另一个终端保持 'iproxy ${SSH_PORT} 22'"

# 远程提权前缀（空串表示已是 root）
REMOTE_PRIV=""
if [[ -n "${PRIV}" ]]; then
    REMOTE_PRIV="${PRIV} "
fi

if [[ "${METHOD}" == "deb" ]]; then
    bg_run scp -P "${SSH_PORT}" "${artifact}" "${SSH_TARGET}:${REMOTE_TMP}"
    bg_run ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
        "${REMOTE_PRIV}dpkg -i ${REMOTE_TMP} && rm -f ${REMOTE_TMP}"
else
    bg_run ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
        "${REMOTE_PRIV}mkdir -p ${REMOTE_LIB_DIR} ${REMOTE_PLIST_DIR}"
    bg_run scp -P "${SSH_PORT}" "${artifact}" "${SSH_TARGET}:/var/mobile/"
    bg_run scp -P "${SSH_PORT}" "${FILTER_PLIST}" "${SSH_TARGET}:/var/mobile/"
    bg_run ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
        "${REMOTE_PRIV}mv /var/mobile/$(basename "${artifact}") ${REMOTE_LIB_DIR}/ && \
         ${REMOTE_PRIV}mv /var/mobile/$(basename "${FILTER_PLIST}") ${REMOTE_PLIST_DIR}/ && \
         ${REMOTE_PRIV}chmod 755 ${REMOTE_LIB_DIR}/$(basename "${artifact}")"
fi

# --- 5. 让改动生效 ----------------------------------------------------------
bg_info "随包配置路径（deb 方式安装）: ${BG_SHARE_DIR}/{bssid_map.json,targets.json}"
bg_info "现场改配置可用环境变量 BGGHOST_CONFIG_DIR 指向自定义目录"

if [[ "${DO_RESPRING}" -eq 1 ]]; then
    bg_step "sbreload / respring"
    bg_run ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
        "${REMOTE_PRIV}sbreload 2>/dev/null || ${REMOTE_PRIV}killall -9 SpringBoard"
fi

cat <<EOF

后续步骤：
  1. 冷启动目标 App（越狱插件在进程启动时加载）
  2. 执行 scripts/verify.sh --udid ${DEVICE_UDID} --ssh ${SSH_TARGET} --port ${SSH_PORT} 验证
  3. 日志：${BG_DEVICE_LOG}（超过 log.max_bytes 时轮转为 .1）

注意：Hook 只会在授权闸通过时启用；未填齐授权字段时日志里会出现
      「拒绝启用：…」并写明责任字段。
EOF
