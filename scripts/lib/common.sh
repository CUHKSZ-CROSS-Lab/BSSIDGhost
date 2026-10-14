#!/usr/bin/env bash
#
# BSSIDGhost - **跨端**脚本共用的工具函数（输出 / dry-run / 依赖检查）
#
# 只应被 source，不要直接执行：
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
#
# 分层约定（R14 修正）：
#   本文件 = 与平台无关的东西（打印、dry-run 执行器、命令存在性检查）
#   ios/scripts/lib/common.sh = iOS 专属（授权闸、越狱路径、过滤器生成），它会 source 本文件
#
# 为什么要有这一层：R12 把 ios 的 lib 搬进 ios/ 时，跨端的 publish.sh 还在 source
# 老路径的 scripts/lib/common.sh，于是 publish.sh 一跑就炸 —— 而当时没有任何检查覆盖它。
# 现在跨端脚本依赖跨端 lib，并且有 scripts/check-scripts.sh 守着 source 目标的存在性。
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "scripts/lib/common.sh 只应被 source，不要直接执行。" >&2
    exit 1
fi

BG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# 根解析必须可验证：宁可在这里明确失败，也不要用错根目录静默跑偏。
if [[ ! -f "${BG_ROOT}/shared/config/targets.json" ]]; then
    printf '!! 仓库根解析失败：%s 下找不到 shared/config/targets.json\n' "${BG_ROOT}" >&2
    printf '   脚本被移动过？目录约定见 HANDOFF.md。\n' >&2
    exit 1
fi

BG_DRY_RUN="${BG_DRY_RUN:-0}"

# --- 输出 -------------------------------------------------------------------

bg_step() { printf '==> %s\n' "$*"; }
bg_info() { printf '    %s\n' "$*"; }
bg_warn() { printf '!! %s\n' "$*" >&2; }
bg_die()  { printf '!! %s\n' "$*" >&2; exit 1; }

# --- 依赖 -------------------------------------------------------------------

bg_require_cmd() {
    command -v "$1" >/dev/null 2>&1 || bg_die "未找到命令 $1${2:+（$2）}"
}

# --- 执行（支持 --dry-run）---------------------------------------------------

# 打印一条命令。安全字符集内的参数原样输出，其余用单引号包住，
# 既保留参数边界（可直接复制执行），又比 %q 的 \ 转义更易读。
bg_print_cmd() {
    printf '    [dry-run]'
    local arg quoted
    for arg in "$@"; do
        if [[ "${arg}" =~ ^[A-Za-z0-9_@%+=:,./-]+$ ]]; then
            printf ' %s' "${arg}"
        else
            quoted="${arg//\'/\'\\\'\'}"
            printf " '%s'" "${quoted}"
        fi
    done
    printf '\n'
}

# 非 dry-run 时真正执行；dry-run 只打印。
bg_run() {
    if [[ "${BG_DRY_RUN}" -eq 1 ]]; then
        bg_print_cmd "$@"
        return 0
    fi
    "$@"
}

bg_require_not_dry_run() {
    [[ "${BG_DRY_RUN}" -eq 0 ]] || bg_die "$1 在 --dry-run 下不可用（会真的改动设备/产物）"
}
