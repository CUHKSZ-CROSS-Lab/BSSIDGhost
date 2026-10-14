#!/usr/bin/env bash
#
# BSSIDGhost - 主机侧检查（L0 + L1）
#
# L0 配置契约检查：shared/config/*.json 与 ios/hooks/*.c 的键名/类型/容量契约
# L1 单元测试（纯 C，不依赖真机与 ObjC）：
#   - shared/vectors/*.json ：**语言中立行为向量**，两端（C 核心 / Java 核心）必须同结论
#   - BGGhostRules.c : BSSID 映射（T5 格式一致 / T7 无规则透传 / nil 语义）
#   - BGGhostAuth.c  : 授权闸与作用域（T8 作用域 / T9 授权闸）
#
# 不依赖真机、不依赖 ObjC 运行时，macOS / Linux 均可执行。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
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
bash "${ROOT}/ios/tests/host/check-config-contract.sh"

echo
echo "==> [L0] 脚本自检（--dry-run 正向 + 授权闸反向）"
bash "${ROOT}/ios/tests/host/check-scripts.sh"

echo
echo "==> [L0] ObjC 语法检查（ios/tests/objc-stub 最小 Foundation 桩）"
set +e
bash "${ROOT}/ios/tests/host/check-objc-syntax.sh"
OBJC_STATUS=$?
set -e
if [[ "${OBJC_STATUS}" -eq 2 ]]; then
    echo "!! 本机 clang 不支持所需 ObjC 特性，已跳过（ObjC 层仍无编译验证）" >&2
elif [[ "${OBJC_STATUS}" -ne 0 ]]; then
    echo "!! ObjC 语法检查未通过。" >&2
    exit 1
fi

echo
echo "==> [L1] 授权闸模拟器自检（真实判定代码 + 真实 JSON 取值）"
bash "${ROOT}/ios/tests/host/gate-sim.sh" --self-test

echo
echo "==> [L1] BSSID 映射模拟器自检（真实映射代码 + 真实 JSON 取值）"
bash "${ROOT}/ios/tests/host/map-sim.sh" --self-test

# 语言中立向量：这是**跨端行为规范**的可执行形式，Android 的 Java 核心（R14）必须跑同一份。
# 与下面两个 C 单测的关系：向量管「两端必须一致的行为」，C 单测还额外管 C API 机制细节。
echo
echo "==> [L1] 语言中立向量驱动（shared/vectors/，两端共用）"
bash "${ROOT}/ios/tests/host/run-vectors.sh"

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
        "${ROOT}/ios/hooks/${core}" \
        "${ROOT}/ios/tests/host/${test}" \
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
