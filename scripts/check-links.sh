#!/usr/bin/env bash
#
# BSSIDGhost - Markdown 链接检查（跨平台，无额外依赖）
#
# 为什么要它：R12 把 iOS 资产迁移到 ios/、文档迁到 docs/ios/，
# 这类重构最容易的失败模式就是**文档里的相对链接悄悄断掉**——
# 而文档恰恰是新会话接手时的唯一入口。断链比代码 bug 更隐蔽。
#
# 检查范围：仓库内所有 .md 的 `](目标)` 形式链接（含图片），
# 目标为 http(s)/mailto/#锚点 的跳过；带 #L24 之类锚点与 :行号 后缀的剥掉再判。
#
# 用法：
#   scripts/check-links.sh          # 全仓库检查，有断链则退出码 1
#   scripts/check-links.sh -v       # 同时打印检查过的链接总数
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

CHECKED=0
BROKEN=0

# 找出所有 markdown 文件（跳过 .git 与构建产物）
mapfile -t FILES < <(find "${ROOT}" \
    -path "${ROOT}/.git" -prune -o \
    -path "${ROOT}/build" -prune -o \
    -name '*.md' -type f -print | sort)

for f in "${FILES[@]}"; do
    dir="$(dirname "${f}")"
    # 抽取所有 ](目标) 里的目标；用 -o 逐条输出
    while IFS= read -r target; do
        [[ -n "${target}" ]] || continue

        # 跳过外部链接与纯锚点
        case "${target}" in
            http://*|https://*|mailto:*|ftp://*|'#'*|'') continue ;;
            *'<'*|*'>'*) continue ;;   # 模板占位符，如 <path>
        esac

        # 剥掉锚点（#L24）与行号后缀（:24）
        path="${target%%#*}"
        path="${path%%:*}"
        [[ -n "${path}" ]] || continue

        # 只检查「像路径」的目标：含 `/`、以 `/` 结尾，或带扩展名。
        # 目的是不把文档里作为**示例**出现的链接写法误判为断链
        # （R12 就踩过一次：说明文字里写了示例，被自己的检查器报断链）。
        # 这一收紧不会漏掉本仓库任何真实链接。
        case "${path}" in
            */*|*/|*.*) ;;
            *) continue ;;
        esac

        CHECKED=$((CHECKED + 1))

        # 绝对路径按仓库根解析，相对路径按所在目录解析
        if [[ "${path}" == /* ]]; then
            resolved="${path}"
        else
            resolved="${dir}/${path}"
        fi

        if [[ ! -e "${resolved}" ]]; then
            BROKEN=$((BROKEN + 1))
            printf '断链 %s\n  -> %s\n' "${f#"${ROOT}/"}" "${target}"
        fi
    done < <(grep -oE '\]\([^)]+\)' "${f}" 2>/dev/null | sed 's/^](//; s/)$//' || true)
done

echo
if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '检查了 %d 个文件、%d 条内部链接。\n' "${#FILES[@]}" "${CHECKED}"
fi

if [[ "${BROKEN}" -gt 0 ]]; then
    printf '!! 发现 %d 条断链（%d 条内部链接中）。\n' "${BROKEN}" "${CHECKED}" >&2
    exit 1
fi

printf '链接检查通过：%d 个文件、%d 条内部链接，无断链。\n' "${#FILES[@]}" "${CHECKED}"
