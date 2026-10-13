#!/usr/bin/env bash
#
# BSSIDGhost - 验证脚本
#
# 确认 Hook 是否生效：目标 App 读到的 BSSID 应为配置中的伪造值。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEVICE_UDID="${BGGHOST_UDID:-}"
TARGET_BUNDLE_ID="${BGGHOST_BUNDLE_ID:-com.ss.iphone.ugc.Lark}"
LOG_PATH="${BGGHOST_LOG:-/var/mobile/Library/Logs/BSSIDGhost/ghost.log}"

echo "==> BSSIDGhost verify"

if [[ -z "${DEVICE_UDID}" ]]; then
    echo "!! 未设置 BGGHOST_UDID，跳过设备侧检查。" >&2
fi

# --- 1. 配置侧:确认预期的伪造值 ---------------------------------------------
echo "--- 期望值（来自 config/bssid_map.json）"
if command -v jq >/dev/null 2>&1; then
    jq -r '.rules[] | select(.enabled) | "  SSID \(.match.ssid)  真实 \(.match.bssid) -> 伪造 \(.replace.bssid)"' \
        "${ROOT}/config/bssid_map.json"
else
    echo "  (未安装 jq，跳过解析)"
fi

# --- 2. 设备侧:确认 dylib 已加载 --------------------------------------------
echo "--- 设备侧检查（待实现）"
# TODO: 通过 ssh 到设备执行：
#   frida-ps -U | grep -i <bundleid>          # 确认进程
#   frida -U -n <app> -e "..."                # 读取 App 实际拿到的 BSSID
#   实际 BSSID 对照：设置 -> 无线局域网 -> 当前网络详情

cat <<'EOF'

验证矩阵（详见 tests/README.md）：
  [ ] Hook 已加载            —— 日志出现 "[BSSIDGhost] 启用"
  [ ] BSSID 已替换           —— App 读到伪造值
  [ ] SSID 保持不变          —— App 读到真实 SSID
  [ ] 真实链路未受影响       —— 仍可正常联网
  [ ] 交叉校验未触发         —— App 无异常上报 / 无风控拦截
EOF

echo "!! 设备侧验证步骤待实现。" >&2
