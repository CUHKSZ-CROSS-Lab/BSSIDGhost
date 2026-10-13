#!/usr/bin/env bash
#
# BSSIDGhost - 主机侧检查（L0 + L1）
#
# L0 配置契约检查：config/*.json 与 hooks/*.c 的键名/类型/容量契约
# L1 单元测试（纯 C，不依赖真机与 ObjC）：
#   - BGGhostRules.c : BSSID 映射（T5 格式一致 / T7 无规则透传 / nil 语义）
#   - BGGhostAuth.c  : 授权闸与作用域（T8 作用域 / T9 授权闸）
#
# 不依赖真机、不依赖 ObjC 运行时，macOS / Linux 均可执行。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CC="${CC:-clang}"
OUT_DIR="${ROOT}/build/host-tests"

CFLAGS=(-std=c11 -Wall -Wextra -Werror -O1 -g -I"${ROOT}/hooks")

echo "==> BSSIDGhost 主机侧检查"
echo "    编译器: ${CC}"

if ! command -v "${CC}" >/dev/null 2>&1; then
    echo "!! 未找到编译器 ${CC}，请安装 clang 或设置 CC 环境变量。" >&2
    exit 1
fi

echo
echo "==> [L0] 配置契约检查"
bash "${ROOT}/tests/host/check-config-contract.sh"

mkdir -p "${OUT_DIR}"

# 测试目标格式：<可执行名>:<被测核心>:<测试文件>
TARGETS=(
    "test_bgg_rules:BGGhostRules.c:test_bgg_rules.c"
    "test_bgg_auth:BGGhostAuth.c:test_bgg_auth.c"
)

FAILED=0

for target in "${TARGETS[@]}"; do
    IFS=':' read -r name core test <<<"${target}"
    echo
    echo "==> [${name}] 编译"
    "${CC}" "${CFLAGS[@]}" \
        "${ROOT}/hooks/${core}" \
        "${ROOT}/tests/host/${test}" \
        -o "${OUT_DIR}/${name}"

    echo "==> [${name}] 运行"
    if ! "${OUT_DIR}/${name}"; then
        FAILED=1
    fi
done

echo
if [[ "${FAILED}" -ne 0 ]]; then
    echo "!! 存在失败的测试目标。" >&2
    exit 1
fi
echo "==> 全部测试目标通过"
