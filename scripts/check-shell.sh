#!/usr/bin/env bash
#
# BSSIDGhost - shell 脚本静态检查（跨端，无额外依赖）
#
# 检查两件事：
#   1. 每个 .sh 都能通过 `bash -n`（语法）；
#   2. 每个 `source "...pwd)/<相对路径>"` 的目标**真实存在**。
#
# 为什么需要第 2 条：R12 把 iOS 的 lib 从 scripts/lib/ 搬进 ios/scripts/lib/ 后，
# 跨端的 scripts/publish.sh 仍在 source 老路径 —— 结果 publish.sh 一执行就报
# "No such file or directory"。而 ios/tests/host/check-scripts.sh 只覆盖
# build/deploy/verify 三个脚本，**publish.sh 不在任何检查里**，所以这个 bug
# 一直活到 R14 真要开 PR 的时候才暴露。
#
# 教训：重构移动文件时，"谁引用了我"必须由机器查，不能靠记性。
#
# 用法：scripts/check-shell.sh [-v]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

PASS=0
FAIL=0

# 注意：这里必须显式 return 0。写成 `[[ ... ]] && printf` 时，非 -v 模式下
# 该语句返回 1，会被脚本顶部的 set -e 当成失败 —— 表现是**静默退出、什么都不打印**。
ok()  {
    PASS=$((PASS + 1))
    if [[ "${VERBOSE}" -eq 1 ]]; then
        printf '  ok   %s\n' "$1"
    fi
    return 0
}
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s -- %s\n' "$1" "$2"; }

mapfile -t FILES < <(find "${ROOT}" \
    -path "${ROOT}/.git" -prune -o \
    -path "${ROOT}/build" -prune -o \
    -name '*.sh' -type f -print | sort)

for f in "${FILES[@]}"; do
    rel="${f#"${ROOT}/"}"

    # --- 1. 语法 ---
    if err="$(bash -n "${f}" 2>&1)"; then
        ok "语法 ${rel}"
    else
        bad "语法 ${rel}" "$(printf '%s' "${err}" | head -n 1)"
    fi

    # --- 2. source 目标存在性 ---
    # 匹配形如： source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
    # 取 `pwd)` 之后到收尾引号之间的部分，按脚本所在目录解析。
    dir="$(dirname "${f}")"
    # 只看**真正的 source/. 语句行**（行首，前面只允许空白）——
    # 否则注释里的示例、以及本检查器自己的代码都会被误判成引用。
    while IFS= read -r line; do
        # 支持两种写法，都必须解析对（否则会出现"因为撞对了而通过"的假通过）：
        #   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/x.sh"          -> dir=脚本目录,  后缀=/lib/x.sh
        #   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/x.sh"       -> dir=脚本目录/../lib
        mid=""; suffix=""
        mid="$(printf '%s' "${line}" | sed -n 's/.*BASH_SOURCE\[0\]}")\([^"]*\)" && pwd)\([^"]*\)".*/\1/p')"
        suffix="$(printf '%s' "${line}" | sed -n 's/.*BASH_SOURCE\[0\]}")\([^"]*\)" && pwd)\([^"]*\)".*/\2/p')"
        [[ -n "${suffix}" ]] || continue
        target="${dir}${mid}${suffix}"
        if [[ -e "${target}" ]]; then
            ok "source ${rel} -> ${mid}${suffix}"
        else
            bad "source ${rel}" "目标不存在：${target}"
        fi
    done < <(grep -E '^[[:space:]]*(source|\.)[[:space:]]' "${f}" 2>/dev/null || true)
done

echo
printf 'shell 检查：%d 通过, %d 失败（%d 个脚本）\n' "${PASS}" "${FAIL}" "${#FILES[@]}"
[[ "${FAIL}" -eq 0 ]] || exit 1
