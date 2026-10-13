#!/usr/bin/env bash
#
# BSSIDGhost - ObjC 语法检查（L0）
#
# 对 hooks/*.m 做真正的编译器检查（clang -fsyntax-only）。两种模式：
#
#   sdk 模式（优先）：有 iPhoneOS SDK 时直接用真 SDK 头
#     - 触发条件：设置了 BGGHOST_IOS_SDK，或 `xcrun --sdk iphoneos` 可用（macOS + Xcode）
#     - 这是更强的检查：方法存在性、弃用、可用性标注都会参与
#   stub 模式（兜底）：没有 SDK 时用 tests/objc-stub 的最小声明桩
#     - 触发条件：既无 BGGHOST_IOS_SDK 也无 xcrun
#
# ⚠️ 两种模式**不能混用**：stub 的 `-I` 必须在真 SDK 前生效就会把真头文件顶掉，
#    导致在 Mac 上"通过"其实是拿桩跑的假通过。脚本按上面的规则二选一，并打印所用模式。
#
# 无论哪种模式都查不到：链接期问题（缺 -framework、缺符号、install_name）、任何运行期行为。
#
# 退出码：0 = 全部通过；1 = 有失败；2 = 本机 clang 不支持所需 ObjC 特性（跳过）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STUB="${ROOT}/tests/objc-stub"
CC="${CC:-clang}"
MIN_IOS="${BGGHOST_MIN_IOS:-15.0}"

# --- 模式选择 ----------------------------------------------------------------
MODE="stub"
SDK_PATH="${BGGHOST_IOS_SDK:-}"

if [[ "${BGGHOST_FORCE_STUB:-0}" != "1" ]]; then
    if [[ -z "${SDK_PATH}" ]] && command -v xcrun >/dev/null 2>&1; then
        if probed="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)" && [[ -n "${probed}" ]]; then
            SDK_PATH="${probed}"
        fi
    fi
    if [[ -n "${SDK_PATH}" && -d "${SDK_PATH}" ]]; then
        MODE="sdk"
    else
        SDK_PATH=""
    fi
fi

if [[ "${MODE}" == "sdk" ]]; then
    SYNTAX_FLAGS=(
        -x objective-c
        -fsyntax-only
        -fobjc-arc
        -isysroot "${SDK_PATH}"
        -miphoneos-version-min="${MIN_IOS}"
        -Wall -Wextra -Werror
        -I"${ROOT}/hooks"
    )
else
    # -fobjc-runtime=ios-15.0 既让 ARC 可用，也与 TARGET 的 ios15.0 最低版本对齐
    SYNTAX_FLAGS=(
        -x objective-c
        -fsyntax-only
        -fobjc-arc
        -fobjc-runtime=ios-15.0
        -Wall -Wextra -Werror
        -I"${STUB}"
        -I"${ROOT}/hooks"
    )
fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s -- %s\n' "$1" "$2"; }

if ! command -v "${CC}" >/dev/null 2>&1; then
    echo "!! 未找到编译器 ${CC}" >&2
    exit 2
fi

# 探测本机 clang 是否具备所需能力（ARC + 指定 runtime + ObjC 语言模式）
# 探测本机 clang 是否具备所选模式需要的能力
if [[ "${MODE}" == "sdk" ]]; then
    if ! printf '#import <Foundation/Foundation.h>\n' \
            | "${CC}" "${SYNTAX_FLAGS[@]}" - >/dev/null 2>&1; then
        echo "!! 检测到 iPhoneOS SDK（${SDK_PATH}）但用它编译失败，跳过。" >&2
        echo "   （这不算通过；可设 BGGHOST_FORCE_STUB=1 强制用桩模式）" >&2
        exit 2
    fi
else
    if ! printf 'int main(void){return 0;}\n' \
            | "${CC}" -x objective-c -fsyntax-only -fobjc-arc -fobjc-runtime=ios-15.0 - >/dev/null 2>&1; then
        echo "!! 本机 ${CC} 不支持 '-fobjc-arc -fobjc-runtime=ios-15.0'，跳过 ObjC 语法检查。" >&2
        echo "   （这不算通过：ObjC 层仍未获得编译验证）" >&2
        exit 2
    fi
fi

if [[ "${MODE}" == "sdk" ]]; then
    echo "==> ObjC 语法检查（模式：真 SDK —— ${SDK_PATH}）"
    echo "    这是强检查：方法存在性 / 弃用 / 可用性标注都会参与"
else
    echo "==> ObjC 语法检查（模式：声明桩 tests/objc-stub）"
    echo "    注意：桩模式查不到方法存在性 / 弃用 / 可用性标注；有 iOS SDK 时请用 sdk 模式"
fi
echo "    编译器: $("${CC}" --version | head -1)"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
: > "${TMP}/empty.m"

# --- 1. 逐个检查 hooks/*.m ---------------------------------------------------
for src in "${ROOT}"/hooks/*.m; do
    name="$(basename "${src}")"
    if out="$("${CC}" "${SYNTAX_FLAGS[@]}" "${src}" 2>&1)"; then
        ok "${name}"
    else
        bad "${name}" "$(printf '%s' "${out}" | head -n 3 | tr '\n' ' ')"
    fi
done

# --- 2. 头文件自包含：每个 .h 单独包含也必须通过 ------------------------------
# 防止某个头文件漏了自己需要的 #import，只有在特定包含顺序下才显得正常。
for hdr in "${ROOT}"/hooks/*.h; do
    name="$(basename "${hdr}")"
    if out="$("${CC}" "${SYNTAX_FLAGS[@]}" -include "${hdr}" "${TMP}/empty.m" 2>&1)"; then
        ok "${name}（单独包含）"
    else
        bad "${name}（单独包含）" "$(printf '%s' "${out}" | head -n 3 | tr '\n' ' ')"
    fi
done

# --- 3. 反向验证：注入故障必须被查出来 ---------------------------------------
# 如果一个检查器连明显的错误都放过，它的"通过"就没有意义。

sed '1i #import <Foundation/Foundation.h>' "${ROOT}/hooks/BGGhostCoreWLAN.m" > "${TMP}/undeclared.m"
printf '\nstatic void bg_self_test(void) { BGGhostThisFunctionDoesNotExist(); }\n' >> "${TMP}/undeclared.m"
if "${CC}" "${SYNTAX_FLAGS[@]}" "${TMP}/undeclared.m" >/dev/null 2>&1; then
    bad "反向：未声明的函数必须报错" "竟然通过了（检查器空转）"
else
    ok "反向：未声明的函数被查出"
fi

printf '#import <Foundation/Foundation.h>\nstatic void bg_self_test2(void) { NSString *s = nil; (void)[s bgNoSuchSelector]; }\n' \
    > "${TMP}/badsel.m"
if "${CC}" "${SYNTAX_FLAGS[@]}" "${TMP}/badsel.m" >/dev/null 2>&1; then
    bad "反向：未知选择器必须报错" "竟然通过了（检查器空转）"
else
    ok "反向：未知选择器被查出"
fi

printf '#import <Foundation/Foundation.h>\nstatic void bg_self_test3(void) { NSString *s = nil; NSLog(@"%%@", s.UTF8String); }\n' \
    > "${TMP}/badtype.m"
if "${CC}" "${SYNTAX_FLAGS[@]}" "${TMP}/badtype.m" >/dev/null 2>&1; then
    bad "反向：格式串类型不匹配必须报错" "竟然通过了（桩未启用格式串检查？）"
else
    ok "反向：格式串类型不匹配被查出"
fi

# 针对我们自己的日志函数：BGGhostLog 也带 NS_FORMAT_FUNCTION(1,2)
printf '#import "Hooks.h"\nstatic void bg_self_test4(void) { BGGhostLog(@"%%@", "a c string"); }\n' \
    > "${TMP}/badlog.m"
if "${CC}" "${SYNTAX_FLAGS[@]}" "${TMP}/badlog.m" >/dev/null 2>&1; then
    bad "反向：BGGhostLog 的 %%@ 收到 C 字符串必须报错" "竟然通过了（自己的日志函数未被检查）"
else
    ok "反向：BGGhostLog 的格式串被检查"
fi

# 证明「头文件单独包含」这一路真的在编译头文件，而不是被跳过
printf '#ifndef BG_BAD_HEADER_H\n#define BG_BAD_HEADER_H\nvoid bg_self_test5(BGUnknownType value);\n#endif\n' \
    > "${TMP}/badheader.h"
if "${CC}" "${SYNTAX_FLAGS[@]}" -include "${TMP}/badheader.h" "${TMP}/empty.m" >/dev/null 2>&1; then
    bad "反向：头文件里的未知类型必须报错" "竟然通过了（头文件未被真正编译）"
else
    ok "反向：头文件单独包含这一路确实在编译"
fi

# 反向：sdk 模式必须真的用 SDK 头，而不是偷偷退回桩。
# 用一个「缺方法声明」的假 SDK 重跑本脚本：正确实现应失败（因为桩没被使用）；
# 如果这里通过了，就说明 Mac 上的"通过"是拿桩跑出来的假通过。
FAKE_SDK="${TMP}/fakesdk"
FAKE_BIN="${TMP}/fakebin"
mkdir -p "${FAKE_SDK}/Foundation" "${FAKE_BIN}"
printf '/* 假 SDK：故意不声明 hooks 需要的任何方法 */\n@interface NSString\n@end\n@interface NSObject\n@end\n' \
    > "${FAKE_SDK}/Foundation/Foundation.h"
printf '#!/bin/sh\necho %s\n' "${FAKE_SDK}" > "${FAKE_BIN}/xcrun"
chmod +x "${FAKE_BIN}/xcrun"

set +e
PATH="${FAKE_BIN}:${PATH}" BGGHOST_IOS_SDK="${FAKE_SDK}" BGGHOST_FORCE_STUB=0 \
    bash "$0" >/dev/null 2>&1
FAKE_SDK_STATUS=$?
set -e
if [[ "${FAKE_SDK_STATUS}" -eq 0 ]]; then
    bad "反向：sdk 模式必须使用 SDK 头而非桩" "用假 SDK 竟然通过了（说明桩把真头文件顶掉了）"
else
    ok "反向：sdk 模式确实使用 SDK 头（假 SDK 导致失败，桩未被使用）"
fi

echo
printf '结果：%d 通过, %d 失败\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
