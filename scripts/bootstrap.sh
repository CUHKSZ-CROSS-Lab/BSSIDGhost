#!/usr/bin/env bash
#
# BSSIDGhost - 环境自检与快速校验（换机器 / 换会话后的第一条命令）
#
#   bash scripts/bootstrap.sh                 # 自检 + 跑全套主机检查（L0+L1）
#   bash scripts/bootstrap.sh --skip-tests    # 只做环境自检
#
# 设计目标：在一台**全新的机器**上，5 分钟内回答三个问题：
#   1. 我缺什么工具？（必需 / 可选分开列，附本平台安装命令）
#   2. 这个仓库现在是不是健康的？（跑 ios/tests/host/run.sh，不需要设备）
#   3. 我接下来该做什么？（读取顺序 + 当前阻塞项）
#
# Linux 与 macOS 都已适配。退出码：0 = 必需项齐全且检查通过；1 = 有缺失或检查失败。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_TESTS=0

for arg in "$@"; do
    case "${arg}" in
        --skip-tests) SKIP_TESTS=1 ;;
        -h|--help)
            sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "!! 未知参数：${arg}" >&2; exit 2 ;;
    esac
done

case "$(uname -s)" in
    Darwin) PLATFORM="macOS" ;;
    Linux)  PLATFORM="Linux" ;;
    *)      PLATFORM="$(uname -s)" ;;
esac

MISSING_REQUIRED=0

# 按平台给出安装提示
hint_for() {
    local tool="$1"
    if [[ "${PLATFORM}" == "macOS" ]]; then
        case "${tool}" in
            clang)      echo "xcode-select --install" ;;
            jq)         echo "brew install jq" ;;
            node)       echo "brew install node" ;;
            python3)    echo "brew install python" ;;
            idevice_id|iproxy) echo "brew install libimobiledevice" ;;
            ldid)       echo "brew install ldid（或由 theos 自带）" ;;
            dpkg-deb)   echo "brew install dpkg" ;;
            *)          echo "brew install ${tool}" ;;
        esac
    else
        case "${tool}" in
            clang)      echo "sudo pacman -S clang" ;;
            jq)         echo "sudo pacman -S jq" ;;
            node)       echo "sudo pacman -S nodejs npm" ;;
            python3)    echo "sudo pacman -S python" ;;
            idevice_id|iproxy) echo "sudo pacman -S libimobiledevice" ;;
            frida)      echo "pip3 install frida-tools（需先有 pip）；或 npm i -g frida --registry=https://registry.npmmirror.com" ;;
            ldid)       echo "yay -S ldid（仅 AUR）" ;;
            dpkg-deb)   echo "sudo pacman -S dpkg" ;;
            *)          echo "sudo pacman -S ${tool}" ;;
        esac
    fi
}

# 注意：本函数**始终返回 0**，缺失项通过 MISSING_REQUIRED 计数上浮。
# 否则在 set -e 下，一次"探测到缺失"就会把整个脚本打断。
probe() {
    local level="$1" tool="$2" purpose="$3"
    if command -v "${tool}" >/dev/null 2>&1; then
        printf '  %-4s %-12s %-6s %s\n' "${level}" "${tool}" "已装" "${purpose}"
        return 0
    fi
    printf '  %-4s %-12s %-6s %s\n' "${level}" "${tool}" "缺失" "${purpose}"
    printf '                             安装：%s\n' "$(hint_for "${tool}")"
    if [[ "${level}" == "必需" ]]; then
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
    return 0
}

show_value() {
    local level="$1" name="$2" value="$3" purpose="$4"
    if [[ -n "${value}" ]]; then
        printf '  %-4s %-12s %-6s %s\n' "${level}" "${name}" "已配" "${purpose}"
        printf '                             %s\n' "${value}"
    else
        printf '  %-4s %-12s %-6s %s\n' "${level}" "${name}" "未配" "${purpose}"
    fi
}

echo "==> BSSIDGhost 环境自检"
echo "    平台: ${PLATFORM}$( [[ "${PLATFORM}" == "macOS" ]] && echo '（可以走真 SDK 编译）' || echo '（无 iOS SDK 时只能做主机检查）' )"
echo "    仓库: ${ROOT}"
echo

echo "--- 必需（跑主机检查 L0+L1 需要）---"
probe 必需 git "版本控制 / 提交与推送"
probe 必需 clang "编译 C 与 ObjC（主机检查、交叉编译）"
probe 必需 jq "解析 JSON 配置（契约检查、模拟器、过滤器生成）"
echo

echo "--- 可选：主机侧增强 ---"
probe 可选 node "校验 Frida 脚本语法（node --check）"
probe 可选 python3 "部分检查脚本 / 报告生成"
echo

echo "--- 可选：真机与打包 ---"
probe 可选 ssh "向越狱设备部署 / 抓日志"
probe 可选 scp "推送 dylib 或 deb"
probe 可选 idevice_id "列出 iOS 设备"
probe 可选 iproxy "USB 转发 SSH（iproxy 2222 22）"
probe 可选 frida "真机只读抓栈（BG-011 必需）"
probe 可选 ldid "签名（theos 打包时用）"
probe 可选 dpkg-deb "打包 deb（theos 路线）"
echo

echo "--- 可选：iOS SDK / 编译器环境（BG-032 相关）---"
SDK_FOUND=""
if [[ -n "${BGGHOST_IOS_SDK:-}" && -d "${BGGHOST_IOS_SDK}" ]]; then
    SDK_FOUND="${BGGHOST_IOS_SDK}（来自 BGGHOST_IOS_SDK）"
elif command -v xcrun >/dev/null 2>&1; then
    if p="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)" && [[ -n "${p}" ]]; then
        SDK_FOUND="${p}（来自 xcrun）"
    fi
fi
if [[ -z "${SDK_FOUND}" && -n "${THEOS:-}" ]]; then
    for candidate in "${THEOS}"/sdks/iPhoneOS*.sdk; do
        [[ -d "${candidate}" ]] && { SDK_FOUND="${candidate}（来自 \$THEOS/sdks）"; break; }
    done
fi
show_value 可选 "iPhoneOS SDK" "${SDK_FOUND}" "有则 ObjC 检查升级为真 SDK 强检查（方法存在性/弃用/可用性）"
show_value 可选 "THEOS" "${THEOS:-}" "theos 打包（export THEOS=~/theos）"
if command -v lipo >/dev/null 2>&1 || command -v llvm-lipo >/dev/null 2>&1; then
    printf '  %-4s %-12s %-6s %s\n' "可选" "lipo" "已装" "多架构切片合并（macOS 自带 lipo / Linux 用 llvm-lipo）"
else
    printf '  %-4s %-12s %-6s %s\n' "可选" "lipo" "缺失" "多架构切片合并（仅 --archs 多架构时需要）"
fi
echo

# --- 跑全套主机检查 ----------------------------------------------------------
SUITE_STATUS="跳过"
if [[ "${SKIP_TESTS}" -eq 0 ]]; then
    echo "--- 全套主机检查（L0+L1，不需要设备）---"
    set +e
    # 先把输出收进变量再取退出码：管道后的 $? 是 tail 的，会把失败误报成通过。
    set +e
    SUITE_OUTPUT="$(bash "${ROOT}/ios/tests/host/run.sh" 2>&1)"
    code=$?
    set -e
    printf '%s\n' "${SUITE_OUTPUT}" | tail -n 20
    if [[ "${code}" -eq 0 ]]; then
        SUITE_STATUS="通过"
    else
        SUITE_STATUS="失败（退出码 ${code}）"
    fi
    echo
    echo "    主机检查结果：${SUITE_STATUS}"
else
    echo "--- 全套主机检查：按 --skip-tests 跳过 ---"
fi
echo

# --- 文档链接检查（跨平台）---------------------------------------------------
LINK_STATUS="跳过"
if [[ "${SKIP_TESTS}" -eq 0 ]]; then
    echo "--- 文档链接检查（重构后最容易悄悄断掉的东西）---"
    set +e
    LINK_OUTPUT="$(bash "${ROOT}/scripts/check-links.sh" 2>&1)"
    link_code=$?
    set -e
    printf '%s\n' "${LINK_OUTPUT}" | tail -n 12
    if [[ "${link_code}" -eq 0 ]]; then
        LINK_STATUS="通过"
    else
        LINK_STATUS="失败"
    fi
    echo
fi

# --- 总结与下一步 ------------------------------------------------------------
echo "==> 总结"
if [[ "${MISSING_REQUIRED}" -gt 0 ]]; then
    echo "    ❌ 缺少 ${MISSING_REQUIRED} 个必需工具 —— 装上后再跑一次本脚本"
else
    echo "    ✅ 必需工具齐全"
fi
if [[ "${SUITE_STATUS}" == "通过" ]]; then
    echo "    ✅ 主机检查通过（配置契约 / 脚本自检 / ObjC 语法 / 两个模拟器 / 纯 C 单测）"
elif [[ "${SUITE_STATUS}" == "跳过" ]]; then
    echo "    ⚠️  主机检查未执行"
else
    echo "    ❌ 主机检查${SUITE_STATUS}"
fi
case "${LINK_STATUS}" in
    通过) echo "    ✅ 文档链接检查通过（无断链）" ;;
    跳过) echo "    ⚠️  文档链接检查未执行" ;;
    *)    echo "    ❌ 文档链接检查失败" ;;
esac
echo

cat <<'EOF'
==> 接下来做什么

当前主线：**Android 版**（iOS 版已冻结，见 docs/adr/0001-pivot-to-android.md）

读取顺序（新会话 / 新机器都按这个来）：
  1. RESUME.md              5 分钟跑通 + 当前进度与缺口
  2. HANDOFF.md             交接备忘：已定决策、风险、未决事项
  3. docs/STATUS.md         进度真源：任务板 BG-xxx + 阻塞项
  4. docs/adr/              决策留档（含「为什么从 iOS 转向 Android」）
  5. docs/ios/tech-chain.md iOS 链路与 Hook 点（冻结参考）

当前关键路径（Android 侧）：
  设备未就位 —— 采购规格、root 方案与验机命令见 docs/android-device-spec.md
  注入路线已定 —— 先 Frida 只读抓栈，再落 LSPosed 模块（Vector + legacy API 82）
  编译链已实测 —— android.jar + aapt2 + d8/R8 + apksig，本机纯命令行可出签名 APK
                   （构建脚本落在 R14；本轮 bootstrap 尚不检查 Android 工具链）

仍需你提供（助手不代填 / 不代办）：
  1) shared/config/targets.json 的 6 个授权字段（现为 fill_me）—— Android 版沿用同一套闸门
  2) 一台已 root 的 Android 测试机（建议 Android 15 / API 35 + Magisk + Vector）

iOS 版（**冻结**，仅作参考，不再推进）：
  需越狱机 + Dopamine/rootless；设备选型结论见 docs/ios/handoff-device-jailbreak.md。
  注意：BG-032 编译链落点**已定为方案 C**（设备端 Procursus），不要再当未决项讨论。
EOF

if [[ "${MISSING_REQUIRED}" -gt 0 || "${SUITE_STATUS}" == "失败"* || "${LINK_STATUS}" == "失败" ]]; then
    exit 1
fi
