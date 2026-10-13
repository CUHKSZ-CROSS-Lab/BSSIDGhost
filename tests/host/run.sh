#!/usr/bin/env bash
#
# BSSIDGhost - 主机侧单测（L1）
#
# 编译并运行 hooks/BGGhostRules.c 的纯 C 单测。
# 不依赖真机、不依赖 ObjC 运行时，macOS / Linux 均可执行。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CC="${CC:-clang}"
OUT_DIR="${ROOT}/build/host-tests"

echo "==> BSSIDGhost 主机侧单测"
echo "    编译器: ${CC}"

if ! command -v "${CC}" >/dev/null 2>&1; then
    echo "!! 未找到编译器 ${CC}，请安装 clang 或设置 CC 环境变量。" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

BIN="${OUT_DIR}/test_bgg_rules"
SRC=(
    "${ROOT}/hooks/BGGhostRules.c"
    "${ROOT}/tests/host/test_bgg_rules.c"
)

echo "==> 编译"
"${CC}" -std=c11 -Wall -Wextra -Werror -O1 -g \
    -I"${ROOT}/hooks" \
    "${SRC[@]}" \
    -o "${BIN}"

echo "==> 运行"
"${BIN}"
