#!/usr/bin/env bash
#
# BSSIDGhost - 构建脚本
#
# 两条编译链（BG-032 决策前两者都已就绪，用 --toolchain 选择）：
#   theos  使用 ios/Makefile 打包成 rootless deb（推荐：过滤器与布局交给 theos）
#   clang  直接用 clang + iOS SDK 交叉编译出 libbssidghost.dylib（手工注入用）
#
# 任何一条路径都会先过授权闸：shared/config/targets.json 未填齐授权字段 -> 拒绝构建。
#
# 用法：
#   ios/scripts/build.sh [--toolchain auto|theos|clang] [--dry-run]
#                    [--archs arm64[,arm64e]] [--out DIR] [--sdk PATH]
#
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DYLIB_NAME="libbssidghost.dylib"
TOOLCHAIN="auto"
ARCHS="arm64"
OUT_DIR="${BG_ROOT}/build"
SDK_PATH="${BGGHOST_IOS_SDK:-}"
CC="${CC:-clang}"

usage() {
    cat <<EOF
用法: ios/scripts/build.sh [选项]

  --toolchain auto|theos|clang  选择编译链（默认 auto：有 theos 用 theos，否则用 clang）
  --archs LIST                  clang 路线的架构列表，默认 arm64（可 "arm64,arm64e"）
  --out DIR                     clang 路线的产物目录，默认 build/
  --sdk PATH                    clang 路线的 iPhoneOS SDK 路径（也可用 BGGHOST_IOS_SDK）
  --dry-run                     只打印将要执行的命令与产物路径，不做任何编译
  -h, --help                    显示本帮助

环境变量:
  THEOS               theos 根目录（theos 路线必需）
  BGGHOST_IOS_SDK     iPhoneOS SDK 路径（clang 路线，优先于自动探测）
  CC                  编译器，默认 clang
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --toolchain) TOOLCHAIN="${2:?--toolchain 需要一个值}"; shift 2 ;;
        --archs)     ARCHS="${2:?--archs 需要一个值}"; shift 2 ;;
        --out)       OUT_DIR="${2:?--out 需要一个值}"; shift 2 ;;
        --sdk)       SDK_PATH="${2:?--sdk 需要一个值}"; shift 2 ;;
        --dry-run)   BG_DRY_RUN=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           bg_die "未知参数：$1（用 --help 查看用法）" ;;
    esac
done

case "${TOOLCHAIN}" in
    auto|theos|clang) ;;
    *) bg_die "--toolchain 只能是 auto / theos / clang，收到 '${TOOLCHAIN}'" ;;
esac

bg_step "BSSIDGhost build"
bg_info "项目根目录: ${BG_ROOT}"
bg_info "编译链:     ${TOOLCHAIN}$([[ "${BG_DRY_RUN}" -eq 1 ]] && echo '（dry-run）')"

# --- 1. 授权闸 ---------------------------------------------------------------
bg_gate_check

# --- 2. 工具链探测 -----------------------------------------------------------
theos_available() {
    [[ -n "${THEOS:-}" && -d "${THEOS}/makefiles" ]]
}

detect_sdk() {
    if [[ -n "${SDK_PATH}" ]]; then
        printf '%s\n' "${SDK_PATH}"
        return 0
    fi
    # macOS：交给 xcrun
    if command -v xcrun >/dev/null 2>&1; then
        local p
        if p="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)" && [[ -n "${p}" ]]; then
            printf '%s\n' "${p}"
            return 0
        fi
    fi
    # Linux + theos：SDK 通常放在 $THEOS/sdks 下
    if [[ -n "${THEOS:-}" ]]; then
        local candidate
        for candidate in "${THEOS}"/sdks/iPhoneOS*.sdk; do
            [[ -d "${candidate}" ]] && { printf '%s\n' "${candidate}"; return 0; }
        done
    fi
    return 1
}

if [[ "${TOOLCHAIN}" == "auto" ]]; then
    if theos_available; then
        TOOLCHAIN="theos"
    else
        TOOLCHAIN="clang"
    fi
    bg_info "自动选择编译链: ${TOOLCHAIN}"
fi

# --- 3. theos 路线 -----------------------------------------------------------
build_with_theos() {
    if ! theos_available; then
        if [[ "${BG_DRY_RUN}" -eq 1 ]]; then
            bg_warn "未检测到 \$THEOS（dry-run 仅打印计划，不检查工具链）"
        else
            bg_die "theos 路线需要 \$THEOS 指向 theos 根目录（当前：'${THEOS:-未设置}'）"
        fi
    fi

    bg_check_control_placeholders "${BG_ROOT}/ios/control"

    # 过滤器与随包配置都由 build.sh 生成，避免与 shared/config/ 漂移。
    local filter="${BG_ROOT}/ios/layout/Library/MobileSubstrate/DynamicLibraries/BSSIDGhost.plist"
    local layout_share="${BG_ROOT}/ios/layout/usr/share/bssidghost"

    bg_step "生成过滤器与随包配置"
    bg_generate_filter_plist "${filter}"
    bg_run mkdir -p "${layout_share}"
    bg_run cp "$(bg_map_json)" "${layout_share}/bssid_map.json"
    bg_run cp "$(bg_targets_json)" "${layout_share}/targets.json"
    bg_info "随包配置 -> ${BG_SHARE_DIR}/{bssid_map.json,targets.json}"

    bg_step "make package（theos，rootless）"
    bg_run env \
        THEOS_PACKAGE_SCHEME=rootless \
        FINALPACKAGE=1 \
        ARCHS="${ARCHS//,/ }" \
        make -C "${BG_ROOT}/ios" package

    bg_step "产物"
    bg_info "deb:      ${BG_ROOT}/ios/packages/*.deb$([[ "${BG_DRY_RUN}" -eq 1 ]] && echo '（dry-run，未生成）')"
    bg_info "dylib:    ${BG_ROOT}/ios/.theos/obj/**/BSSIDGhost.dylib"
    bg_info "注意:     theos 约定产物名为 BSSIDGhost.dylib；手工注入路线才是 ${DYLIB_NAME}"
}

# --- 4. clang 路线 -----------------------------------------------------------
build_with_clang() {
    local sdk=""
    if sdk="$(detect_sdk)"; then
        bg_info "iOS SDK:    ${sdk}"
    else
        if [[ "${BG_DRY_RUN}" -eq 1 ]]; then
            bg_warn "未找到 iPhoneOS SDK（dry-run 仅打印计划，不检查工具链）；可设 BGGHOST_IOS_SDK"
            sdk="<iPhoneOS.sdk>"
        else
            bg_die "未找到 iPhoneOS SDK。请设置 BGGHOST_IOS_SDK，或安装 theos 并下载 SDK 到 \$THEOS/sdks/，或在 macOS 上运行。"
        fi
    fi

    command -v "${CC}" >/dev/null 2>&1 || {
        [[ "${BG_DRY_RUN}" -eq 1 ]] || bg_die "未找到编译器 ${CC}"
    }

    local sources=()
    local f
    for f in "${BG_ROOT}"/ios/hooks/*.m "${BG_ROOT}"/ios/hooks/*.c; do
        sources+=("${f}")
    done
    [[ "${#sources[@]}" -gt 0 ]] || bg_die "ios/hooks/ 下没有找到源文件"

    bg_run mkdir -p "${OUT_DIR}"

    local -a arch_list
    IFS=',' read -r -a arch_list <<<"${ARCHS}"
    [[ "${#arch_list[@]}" -ge 1 ]] || bg_die "--archs 为空"

    # 私有框架（CoreWLAN 等）不参与链接，运行时用 NSClassFromString / dlopen 获取，
    # 以免依赖 SDK 里是否存在对应的 stub。
    local frameworks=(-framework Foundation)
    local -a outputs=()

    bg_step "编译（clang，${#arch_list[@]} 个架构）"
    local arch slice
    for arch in "${arch_list[@]}"; do
        [[ -n "${arch}" ]] || continue
        slice="${OUT_DIR}/${DYLIB_NAME}.${arch}"
        outputs+=("${slice}")
        bg_run "${CC}" -dynamiclib \
            -target "${arch}-apple-ios${BG_MIN_IOS}" \
            -isysroot "${sdk}" \
            -fobjc-arc -fmodules \
            -Wall -Wextra \
            -I"${BG_ROOT}/hooks" \
            -install_name "${BG_INSTALL_DYLIB_DIR}/${DYLIB_NAME}" \
            "${frameworks[@]}" \
            "${sources[@]}" \
            -o "${slice}"
    done

    local final="${OUT_DIR}/${DYLIB_NAME}"
    if [[ "${#outputs[@]}" -gt 1 ]]; then
        local lipo
        lipo="$(command -v llvm-lipo || command -v lipo || true)"
        if [[ -z "${lipo}" ]]; then
            if [[ "${BG_DRY_RUN}" -eq 1 ]]; then
                bg_warn "多架构需要 lipo/llvm-lipo（dry-run 不检查）"
                lipo="<lipo>"
            else
                bg_die "多架构打包需要 lipo 或 llvm-lipo，未找到"
            fi
        fi
        bg_step "合并架构"
        bg_run "${lipo}" -create "${outputs[@]}" -output "${final}"
    else
        final="${outputs[0]}"
    fi

    bg_step "产物"
    bg_info "dylib:    ${final}$([[ "${BG_DRY_RUN}" -eq 1 ]] && echo '（dry-run，未生成）')"
    bg_info "落地路径: ${BG_INSTALL_DYLIB_DIR}/${DYLIB_NAME}"
    bg_info "下一步:   ios/scripts/deploy.sh（部署与注入）"
}

case "${TOOLCHAIN}" in
    theos) build_with_theos ;;
    clang) build_with_clang ;;
esac
