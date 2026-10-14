#!/usr/bin/env bash
#
# BSSIDGhost - 授权闸模拟器（主机侧）
#
# 用真实的判定代码（ios/hooks/BGGhostAuth.c）+ 真实的配置文件回答：
#   「以当前 shared/config/targets.json 为准，Hook 会对某个 BundleID 启用还是拒绝？」
#
# 边界：JSON → 结构体这一步由 jq 完成（不是 NSJSONSerialization），
# 因此本工具覆盖「判定代码 + 配置取值」的端到端结果，
# 不覆盖 BGGhostConfig.m 的解析实现（那需要真 SDK 编译，见 docs/STATUS.md）。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CC="${CC:-clang}"
OUT_DIR="${ROOT}/build/host-tests"
BIN="${OUT_DIR}/gate-sim"
TARGETS="${ROOT}/shared/config/targets.json"
BUNDLE=""
SELF_TEST=0

usage() {
    cat <<'EOF'
用法: ios/tests/host/gate-sim.sh [选项]

  （无选项）                 对配置里的第一个 BundleID 判定
  --bundle BUNDLEID          指定要判定的 BundleID
  --bundle -                 模拟非 App 进程（NULL BundleID）
  --config PATH              使用指定的 targets.json（默认 shared/config/targets.json）
  --self-test                跑 6 组断言（含 5 组反向用例）
  -h, --help                 显示本帮助

退出码：判定通过 0；判定拒绝 1；用法/输入错误 2
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle)    BUNDLE="${2:?--bundle 需要一个值}"; shift 2 ;;
        --config)    TARGETS="${2:?--config 需要一个值}"; shift 2 ;;
        --self-test) SELF_TEST=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "!! 未知参数：$1" >&2; exit 2 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { echo "!! 需要 jq" >&2; exit 2; }

build() {
    mkdir -p "${OUT_DIR}"
    "${CC}" -std=c11 -Wall -Wextra -Werror -O1 -g \
        -I"${ROOT}/hooks" \
        "${ROOT}/ios/hooks/BGGhostAuth.c" \
        "${ROOT}/ios/tests/host/gate_sim.c" \
        -o "${BIN}"
}

# 从 targets.json 抽取出模拟器需要的 TSV 输入（只做机械抽取）。
extract() {
    jq -r '
      "mode\t-\t" + (.scope.mode // ""),
      ( [.scope.bundle_ids[]? | select(type == "string" and length > 0)][]
        | "bundle\t-\t" + . ),
      ( ["target_app_owner","authorized_by","authorization_ref","purpose","test_device","test_ap"][] as $k
        | "auth\t" + $k + "\t" + (.authorization[$k] // "") ),
      ( "constraints\t-\t" + (
          [ .constraints.only_test_devices, .constraints.only_test_network, .constraints.no_production_targets ]
          | map(if . then 1 else 0 end) | map(tostring) | join(",") ) )
    ' "$1"
}

# 判定一次：stdout 为判定报告；退出码 0 通过 / 1 拒绝
judge() {
    extract "$1" | "${BIN}" "$2"
}

first_bundle() {
    jq -r '[.scope.bundle_ids[]? | select(type == "string" and length > 0)][0] // "-"' "$1"
}

# --- 自检 -------------------------------------------------------------------
self_test() {
    local pass=0 fail=0
    local tmp
    tmp="$(mktemp -d)"

    ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
    bad() { fail=$((fail + 1)); printf '  FAIL %s -- %s\n' "$1" "$2"; }

    # 期望：退出码 + 输出中必须出现的片段
    expect() {
        local name="$1" want_code="$2" want_text="$3" config="$4" bundle="$5"
        local out code
        set +e
        out="$(judge "${config}" "${bundle}" 2>&1)"
        code=$?
        set -e
        if [[ "${code}" -ne "${want_code}" ]]; then
            bad "${name}" "退出码 ${code}，期望 ${want_code}；输出：$(printf '%s' "${out}" | tail -n 2 | tr '\n' ' ')"
            return
        fi
        if ! printf '%s' "${out}" | grep -qF -- "${want_text}"; then
            bad "${name}" "输出缺少 '${want_text}'"
            return
        fi
        ok "${name}"
    }

    local filled="${tmp}/filled.json"
    jq '.authorization.target_app_owner="示例团队"
        | .authorization.authorized_by="示例授权人"
        | .authorization.authorization_ref="TEST-1"
        | .authorization.purpose="自检"
        | .authorization.test_device="示例设备"
        | .authorization.test_ap="示例 AP"' "${ROOT}/shared/config/targets.json" > "${filled}"

    echo "==> 授权闸模拟器自检（真实判定代码 + 真实 JSON 取值）"
    echo

    # 1) 仓库当前状态：6 个字段都是 fill_me
    expect "仓库当前配置（fill_me）-> 拒绝，并指向 target_app_owner" \
        1 "authorization.target_app_owner" "${ROOT}/shared/config/targets.json" "com.ss.iphone.ugc.Lark"

    # 2) 授权填齐 + 进程在作用域 -> 通过（端到端验证 jq 抽取 + C 判定）
    expect "授权填齐且在作用域 -> 通过" \
        0 "通过" "${filled}" "com.ss.iphone.ugc.Lark"

    # 3) 只差最后一个字段 -> 精确指向 test_ap
    local last="${tmp}/last.json"
    jq '.authorization.target_app_owner="A" | .authorization.authorized_by="B"
        | .authorization.authorization_ref="C" | .authorization.purpose="D"
        | .authorization.test_device="E" | .authorization.test_ap="fill_me"' \
        "${ROOT}/shared/config/targets.json" > "${last}"
    expect "仅 test_ap 未填 -> 指向 authorization.test_ap" \
        1 "authorization.test_ap" "${last}" "com.ss.iphone.ugc.Lark"

    # 4) constraints 未全开
    local cons="${tmp}/cons.json"
    jq '.authorization.target_app_owner="A" | .authorization.authorized_by="B"
        | .authorization.authorization_ref="C" | .authorization.purpose="D"
        | .authorization.test_device="E" | .authorization.test_ap="F"
        | .constraints.only_test_network=false' "${ROOT}/shared/config/targets.json" > "${cons}"
    expect "constraints.only_test_network=false -> 指向 constraints" \
        1 "constraints" "${cons}" "com.ss.iphone.ugc.Lark"

    # 5) scope.mode 非法
    local mode="${tmp}/mode.json"
    jq '.authorization.target_app_owner="A" | .authorization.authorized_by="B"
        | .authorization.authorization_ref="C" | .authorization.purpose="D"
        | .authorization.test_device="E" | .authorization.test_ap="F"
        | .scope.mode="whitelist"' "${ROOT}/shared/config/targets.json" > "${mode}"
    expect "scope.mode=whitelist -> 指向 scope.mode" \
        1 "scope.mode" "${mode}" "com.ss.iphone.ugc.Lark"

    # 6) 进程不在作用域
    expect "BundleID 不在作用域 -> 指向 scope.bundle_ids" \
        1 "scope.bundle_ids" "${filled}" "com.other.app"

    rm -rf "${tmp}"

    echo
    printf '结果：%d 通过, %d 失败\n' "${pass}" "${fail}"
    [[ "${fail}" -eq 0 ]] || return 1
}

build

if [[ "${SELF_TEST}" -eq 1 ]]; then
    self_test
else
    if [[ -z "${BUNDLE}" ]]; then
        BUNDLE="$(first_bundle "${TARGETS}")"
    fi
    echo "==> 授权闸模拟（判定代码：ios/hooks/BGGhostAuth.c；JSON 抽取：jq）"
    echo "    配置：${TARGETS}"
    echo
    set +e
    judge "${TARGETS}" "${BUNDLE}"
    code=$?
    set -e
    echo
    if [[ "${code}" -eq 0 ]]; then
        echo "结论：通过 —— 该进程上 Hook 会启用"
    elif [[ "${code}" -eq 1 ]]; then
        echo "结论：拒绝 —— 该进程上 Hook 不会启用"
    else
        echo "结论：模拟器执行出错（退出码 ${code}）" >&2
        exit 2
    fi
fi
