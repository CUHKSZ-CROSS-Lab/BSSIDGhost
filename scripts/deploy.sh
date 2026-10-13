#!/usr/bin/env bash
#
# BSSIDGhost - 部署脚本
#
# 将 libbssidghost.dylib 注入到越狱测试设备上的目标 App。
#
# ⚠️ 仅用于自有 / 已授权的测试设备与 App。见 README 的用途与授权要求。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DYLIB="${ROOT}/build/libbssidghost.dylib"

# 目标设备与 App（可通过环境变量覆盖）
DEVICE_UDID="${BGGHOST_UDID:-}"
TARGET_BUNDLE_ID="${BGGHOST_BUNDLE_ID:-com.ss.iphone.ugc.Lark}"
# 越狱形态已确认（R1）：Dopamine / rootless，iOS 15.0-16.6.x -> 路径前缀 /var/jb
REMOTE_LIB_DIR="${BGGHOST_LIB_DIR:-/var/jb/usr/lib}"

echo "==> BSSIDGhost deploy"

# --- 前置检查 ---------------------------------------------------------------
[[ -f "${DYLIB}" ]] || { echo "!! 未找到 ${DYLIB}，请先执行 scripts/build.sh" >&2; exit 1; }

[[ -n "${DEVICE_UDID}" ]] || {
    echo "!! 未设置 BGGHOST_UDID。" >&2
    echo "   使用 'idevice_id -l' 列出设备后导出：export BGGHOST_UDID=<udid>" >&2
    exit 1
}

if grep -q 'fill_me' "${ROOT}/config/targets.json"; then
    echo "!! config/targets.json 授权信息未填齐，拒绝部署。" >&2
    exit 1
fi

echo "    设备:   ${DEVICE_UDID}"
echo "    目标:   ${TARGET_BUNDLE_ID}"
echo "    落地:   ${REMOTE_LIB_DIR}"

# --- 推送 -------------------------------------------------------------------
echo "==> 推送 dylib"
# TODO: scp -P 2222 "${DYLIB}" root@localhost:"${REMOTE_LIB_DIR}/"

# --- 注入 -------------------------------------------------------------------
# 越狱形态已确认（R1）：Dopamine / rootless -> 一律使用 /var/jb 前缀。
#   - 越狱插件方式：封装为 deb，写入 /var/jb/Library/MobileSubstrate/DynamicLibraries/
#                  并附 BSSIDGhost.plist 指定 Filter -> Bundles（ElleKit 亦读该目录）
#   - 单次调试：    frida -U -f <bundleid> -l tests/frida/inject.js
# 注意：不要写入 rootful 的 /usr/lib 或 /Library/MobileSubstrate/...，本机不适用。
echo "==> 注入"
echo "!! 注入步骤待实现：需先完成 BG-030（选定 Hook 框架）与 BG-032（编译链落点）。" >&2

# --- 提示 -------------------------------------------------------------------
cat <<'EOF'

后续手动步骤：
  1. 重启目标 App（或 respring）使 dylib 加载
  2. 执行 scripts/verify.sh 验证 Hook 是否生效
  3. 查看日志：/var/mobile/Library/Logs/BSSIDGhost/ghost.log
EOF
