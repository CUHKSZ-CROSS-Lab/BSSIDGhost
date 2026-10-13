#!/usr/bin/env bash
#
# BSSIDGhost - 构建脚本
#
# ⚠️ 占位实现：真实构建需在 macOS + theos 环境执行，Linux 下仅做前置检查。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/build"
DYLIB="libbssidghost.dylib"

echo "==> BSSIDGhost build"
echo "    项目根目录: ${ROOT}"

# --- 环境检查 ---------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "!! 当前非 macOS，无法编译 iOS dylib。" >&2
    echo "   请在 macOS + theos 环境执行本脚本。" >&2
    exit 1
fi

if [[ -z "${THEOS:-}" ]]; then
    echo "!! 未检测到 \$THEOS，请先安装并配置 theos。" >&2
    exit 1
fi

# --- 配置校验 ---------------------------------------------------------------
for f in "${ROOT}/config/bssid_map.json" "${ROOT}/config/targets.json"; do
    [[ -f "$f" ]] || { echo "!! 缺少配置文件: $f" >&2; exit 1; }
done

if grep -q 'fill_me' "${ROOT}/config/targets.json"; then
    echo "!! config/targets.json 中仍存在 fill_me 字段。" >&2
    echo "   请先填齐测试授权信息，再构建（见 README 的用途与授权要求）。" >&2
    exit 1
fi

# --- 编译 -------------------------------------------------------------------
mkdir -p "${OUT}"
echo "==> 编译 ${DYLIB}"

# TODO(BG-031/BG-032): 接入 theos Makefile 或 clang 交叉编译
#   注意 hooks/ 下同时有 .m（ObjC 胶水/Hook 点）与 .c（纯 C 映射核心，见 BGGhostRules.c），
#   两者都要编译进去；映射核心不依赖 Foundation，主机侧单测见 tests/host/run.sh
#   clang -dynamiclib -arch arm64 -arch arm64e \
#         -I"${THEOS}/include" -I"${ROOT}/hooks" \
#         -framework Foundation -framework CoreWLAN \
#         "${ROOT}"/hooks/*.m "${ROOT}"/hooks/*.c -o "${OUT}/${DYLIB}"

echo "!! 编译步骤待实现（BG-032 需先决定编译链落点）。" >&2
exit 1
