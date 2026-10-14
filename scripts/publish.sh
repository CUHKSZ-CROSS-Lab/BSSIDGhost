#!/usr/bin/env bash
#
# BSSIDGhost - 推送到远端并开 PR
#
# 流程（不重写历史、不 force push）：
#   ① 检查工作区干净 + 配置 origin
#   ② 报告本机 GitHub 凭据情况（gh 登录 / SSH key / credential helper）
#   ③ 推送基线分支（默认 main）—— 这一步就是"把进度同步到远端"
#   ④ 若当前分支不是基线分支：推送该分支并用 gh 开 PR
#
# 用法：
#   bash scripts/publish.sh --dry-run            # 只打印会执行的命令、PR 标题与正文
#   bash scripts/publish.sh                      # 真正推送并开 PR
#   bash scripts/publish.sh --no-pr              # 只推送，不开 PR
#   bash scripts/publish.sh --head feat/xxx      # 指定 PR 的来源分支
#
# 凭据：需要 `gh auth login`，或已配置的 SSH key / credential helper。
#       缺少凭据时脚本会明确报错并打印手工命令与 compare URL，不会静默失败。
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REMOTE_NAME="origin"
REMOTE_URL="${BGGHOST_REMOTE_URL:-https://github.com/CUHKSZ-CROSS-Lab/BSSIDGhost.git}"
BASE_BRANCH="main"
HEAD_BRANCH=""
DO_PR=1
PR_TITLE=""

usage() {
    cat <<EOF
用法: scripts/publish.sh [选项]

  --dry-run            只打印将要执行的命令、PR 标题与正文，不做任何推送
  --remote-url URL     远端地址（默认 ${REMOTE_URL}）
  --base BRANCH        基线分支，默认 main
  --head BRANCH        PR 来源分支，默认为当前分支
  --no-pr              只推送，不开 PR
  --title TITLE        PR 标题（默认按分支名生成）
  -h, --help           显示本帮助

说明：脚本从不 force push，也不会改写已有历史。
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    BG_DRY_RUN=1; shift ;;
        --remote-url) REMOTE_URL="${2:?--remote-url 需要一个值}"; shift 2 ;;
        --base)       BASE_BRANCH="${2:?--base 需要一个值}"; shift 2 ;;
        --head)       HEAD_BRANCH="${2:?--head 需要一个值}"; shift 2 ;;
        --no-pr)      DO_PR=0; shift ;;
        --title)      PR_TITLE="${2:?--title 需要一个值}"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            bg_die "未知参数：$1（用 --help 查看用法）" ;;
    esac
done

cd "${BG_ROOT}"

# 非交互场景（CI / 被其它脚本调用）下禁止 git 弹窗要求输入凭据，
# 否则会静默挂住。人工在终端运行时保持默认（可以正常输入凭据）。
if [[ ! -t 0 && "${BGGHOST_ALLOW_PROMPT:-0}" != "1" ]]; then
    export GIT_TERMINAL_PROMPT=0
    export GIT_ASKPASS=/bin/true
fi

bg_step "BSSIDGhost publish$([[ "${BG_DRY_RUN}" -eq 1 ]] && echo '（dry-run）')"
bg_info "远端:     ${REMOTE_URL}"
bg_info "基线分支: ${BASE_BRANCH}"

# --- 1. 前置检查 -------------------------------------------------------------
git rev-parse --git-dir >/dev/null 2>&1 || bg_die "${BG_ROOT} 不是 git 仓库"

if [[ -n "$(git status --porcelain)" ]]; then
    git status --short | sed 's/^/    /' >&2
    bg_die "工作区不干净：请先 git commit 或 git stash，再运行本脚本。"
fi
bg_info "工作区:   干净"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ -z "${HEAD_BRANCH}" ]]; then
    HEAD_BRANCH="${CURRENT_BRANCH}"
fi
bg_info "当前分支: ${CURRENT_BRANCH}"
bg_info "PR 来源:  ${HEAD_BRANCH}"

# --- 2. origin ---------------------------------------------------------------
if git remote get-url "${REMOTE_NAME}" >/dev/null 2>&1; then
    EXISTING="$(git remote get-url "${REMOTE_NAME}")"
    if [[ "${EXISTING}" != "${REMOTE_URL}" ]]; then
        bg_warn "origin 已存在且指向 ${EXISTING}（与预期不同，沿用现有 origin）"
    else
        bg_info "origin:   已配置"
    fi
else
    bg_info "origin:   未配置 -> 将添加"
    bg_run git remote add "${REMOTE_NAME}" "${REMOTE_URL}"
fi

# --- 3. 凭据情况（只报告，不代做认证）----------------------------------------
bg_step "GitHub 凭据情况"
GH_LOGGED_IN=0
if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        GH_LOGGED_IN=1
        bg_info "gh:        已登录（可在推送后自动开 PR）"
    else
        bg_info "gh:        已安装但未登录（开 PR 需要它，或手工点 compare 链接）"
    fi
else
    bg_info "gh:        未安装（推送仍可用，开 PR 需手工或用 compare 链接）"
fi

SSH_KEYS=0
[[ -d "${HOME}/.ssh" ]] && SSH_KEYS="$(find "${HOME}/.ssh" -maxdepth 1 -name 'id_*' ! -name '*.pub' 2>/dev/null | wc -l)"
[[ "${SSH_KEYS}" -gt 0 ]] && bg_info "SSH key:   找到 ${SSH_KEYS} 个私钥" || bg_info "SSH key:   未找到私钥"

CRED_HELPERS="$(git config --get-regexp '^credential\..*helper$' 2>/dev/null || true)"
if [[ -n "${CRED_HELPERS}" ]]; then
    bg_info "凭据助手:  $(printf '%s' "${CRED_HELPERS}" | tr '\n' ' ')"
else
    bg_info "凭据助手:  未配置（HTTPS 推送会要求输入用户名与 token）"
fi

if [[ "${GH_LOGGED_IN}" -eq 0 && "${SSH_KEYS}" -eq 0 ]]; then
    bg_warn "未检测到可用的 GitHub 凭据 —— 推送很可能失败。"
    bg_warn "先用下面任一方式认证，再重跑本脚本："
    bg_warn "  gh auth login                     # 推荐：之后还能自动开 PR"
    bg_warn "  ssh-keygen -t ed25519 && 把公钥加到 GitHub"
fi

# --- 4. PR 标题与正文 --------------------------------------------------------
if [[ -z "${PR_TITLE}" ]]; then
    LAST_SUBJECT="$(git log -1 --pretty=%s "${HEAD_BRANCH}" 2>/dev/null || echo '')"
    # 提交信息本身已带约定式前缀（feat/fix/docs(...)）时直接沿用，避免出现 "docs: docs(...)"
    if [[ "${LAST_SUBJECT}" =~ ^(feat|fix|docs|test|chore|refactor|perf|build|ci)(\(|:) ]]; then
        PR_TITLE="${LAST_SUBJECT}"
    elif [[ -n "${LAST_SUBJECT}" ]]; then
        PR_TITLE="chore: ${LAST_SUBJECT}"
    else
        PR_TITLE="chore: 同步 ${HEAD_BRANCH} -> ${BASE_BRANCH}"
    fi
fi

COMMITS="$(git log --oneline "${BASE_BRANCH}..${HEAD_BRANCH}" 2>/dev/null || true)"
if [[ -z "${COMMITS}" ]]; then
    if [[ "${HEAD_BRANCH}" == "${BASE_BRANCH}" ]]; then
        COMMITS="（PR 来源与基线相同：本次只会同步 ${BASE_BRANCH}，不开 PR）"
    else
        COMMITS="（${HEAD_BRANCH} 相对 ${BASE_BRANCH} 没有新提交）"
    fi
fi

PR_BODY="$(cat <<EOF
## 变更

$(printf '%s\n' "${COMMITS}" | sed 's/^/- /')

## 验证

- \`bash scripts/bootstrap.sh\` 全绿：**251 项断言**（配置契约 / 脚本自检 17 / ObjC 语法与头文件自包含 18 / 授权闸模拟器 6 / 映射模拟器 8 / **语言中立向量 110** / 纯 C 单测 92）
- 以上均**不需要设备**，可在任意 Linux / macOS 上复现

## 已知边界（不要误读为"已完成"）

- **没有任何代码在真实 iOS SDK 上编译或链接过**（BG-032 编译链落点未决）；
  \`ios/hooks/*.m\` 只到语法检查，\`ios/scripts/build.sh\` 只验证过命令拼装（\`--dry-run\`）
- 真机线未解锁：\`shared/config/targets.json\` 的授权字段仍为 \`fill_me\`，
  授权闸会拒绝 build / deploy / Hook（这是刻意设计，见 \`ios/hooks/BGGhostAuth.c\`）
- 来自外部资料的结论（nehelper XPC）一律标注「待真机验证」，
  可证伪实验设计见 \`docs/ios/tech-chain.md\` §2.2
EOF
)"

# --- 5. dry-run 展示 ---------------------------------------------------------
if [[ "${BG_DRY_RUN}" -eq 1 ]]; then
    bg_step "将要执行的命令"
    bg_print_cmd git push -u "${REMOTE_NAME}" "${BASE_BRANCH}"
    if [[ "${HEAD_BRANCH}" != "${BASE_BRANCH}" ]]; then
        bg_print_cmd git push -u "${REMOTE_NAME}" "${HEAD_BRANCH}"
        if [[ "${DO_PR}" -eq 1 ]]; then
            if [[ "${GH_LOGGED_IN}" -eq 1 ]]; then
                bg_print_cmd gh pr create --base "${BASE_BRANCH}" --head "${HEAD_BRANCH}" \
                    --title "${PR_TITLE}" --body-file "(PR 正文见下)"
            else
                bg_info "（gh 未登录：dry-run 下只展示；真实运行时脚本会打印 compare 链接）"
            fi
        else
            bg_info "（--no-pr：跳过 PR）"
        fi
    else
        bg_info "（PR 来源与基线相同：只同步 ${BASE_BRANCH}，不开 PR）"
    fi
    bg_step "PR 标题"
    bg_info "${PR_TITLE}"
    bg_step "PR 正文"
    printf '%s\n' "${PR_BODY}" | sed 's/^/    /'
    exit 0
fi

# --- 6. 真正推送 -------------------------------------------------------------
bg_step "推送"
if ! bg_run git push -u "${REMOTE_NAME}" "${BASE_BRANCH}"; then
    bg_warn "推送 ${BASE_BRANCH} 失败。手工排查："
    bg_info "  git remote -v"
    bg_info "  gh auth login    # 或配置 SSH key"
    bg_info "  git push -u ${REMOTE_NAME} ${BASE_BRANCH}"
    exit 1
fi

if [[ "${HEAD_BRANCH}" != "${BASE_BRANCH}" ]]; then
    if ! bg_run git push -u "${REMOTE_NAME}" "${HEAD_BRANCH}"; then
        bg_warn "推送 ${HEAD_BRANCH} 失败。"
        bg_info "  git push -u ${REMOTE_NAME} ${HEAD_BRANCH}"
        exit 1
    fi
fi

# --- 7. 开 PR ----------------------------------------------------------------
if [[ "${HEAD_BRANCH}" == "${BASE_BRANCH}" || "${DO_PR}" -eq 0 ]]; then
    bg_info "不同步 PR（来源与基线相同，或指定了 --no-pr）。"
    exit 0
fi

bg_step "开 PR"
COMPARE_REL="${REMOTE_URL%.git}/compare/${BASE_BRANCH}...${HEAD_BRANCH}?expand=1"

if [[ "${GH_LOGGED_IN}" -eq 1 ]]; then
    BODY_FILE="$(mktemp)"
    printf '%s\n' "${PR_BODY}" > "${BODY_FILE}"
    if bg_run gh pr create --base "${BASE_BRANCH}" --head "${HEAD_BRANCH}" \
            --title "${PR_TITLE}" --body-file "${BODY_FILE}"; then
        rm -f "${BODY_FILE}"
        bg_info "PR 已创建。"
    else
        rm -f "${BODY_FILE}"
        bg_warn "gh pr create 失败（可能已存在同分支的 PR）。手工创建："
        bg_info "  ${COMPARE_REL}"
        exit 1
    fi
else
    bg_warn "gh 未登录，无法自动开 PR。请在浏览器打开："
    bg_info "  ${COMPARE_REL}"
    bg_info "或先认证：gh auth login，然后重跑本脚本。"
fi
