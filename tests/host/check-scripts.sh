#!/usr/bin/env bash
#
# BSSIDGhost - 脚本自检（L0）
#
# 用 --dry-run 正向验证三个脚本能正确组装命令，并反向验证授权闸与打包占位符
# 会真的拦住执行。所有正向用例都在**临时副本**里跑，不触碰仓库本身。
#
# 覆盖：
#   正向：build --toolchain clang / theos 的命令拼装、deploy 两种方式、verify 的本地检查
#   反向：仓库当前 fill_me -> build/deploy 必须拒绝；control 的 <team> -> theos 打包必须拒绝
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s -- %s\n' "$1" "$2"; }

# 在临时副本里准备一份「授权已填、control 已填」的可用工程。
make_filled_copy() {
    local dir="$1"
    mkdir -p "${dir}"
    cp -r "${ROOT}/config" "${ROOT}/hooks" "${ROOT}/scripts" "${ROOT}/tests" \
          "${ROOT}/layout" "${ROOT}/Makefile" "${ROOT}/control" "${dir}/"

    local tmp_json="${dir}/.targets.tmp.json"
    jq '
      .authorization.target_app_owner  = "示例团队（临时副本，仅用于脚本自检）"
      | .authorization.authorized_by    = "示例授权人 / 工单 TEST-0001"
      | .authorization.authorization_ref = "TEST-0001"
      | .authorization.purpose          = "脚本自检"
      | .authorization.test_device      = "示例测试机"
      | .authorization.test_ap          = "示例测试 AP"
    ' "${ROOT}/config/targets.json" > "${tmp_json}"
    mv "${tmp_json}" "${dir}/config/targets.json"

    sed -i 's/com\.<team>\.bssidghost/com.example.bssidghost/g; s/^Maintainer: <team>$/Maintainer: example/; s/^Author: <team>$/Author: example/' \
        "${dir}/control"
}

# 断言：命令以指定退出码结束，且输出包含（或不包含）某段文本。
expect_run() {
    local name="$1" want_code="$2" want_text="$3" forbid_text="$4"
    shift 4
    local out code
    set +e
    out="$("$@" 2>&1)"
    code=$?
    set -e

    if [[ "${code}" -ne "${want_code}" ]]; then
        bad "${name}" "退出码 ${code}，期望 ${want_code}；输出：$(printf '%s' "${out}" | tail -n 2 | tr '\n' ' ')"
        return
    fi
    if [[ -n "${want_text}" ]] && ! printf '%s' "${out}" | grep -qF -- "${want_text}"; then
        bad "${name}" "输出缺少 '${want_text}'"
        return
    fi
    if [[ -n "${forbid_text}" ]] && printf '%s' "${out}" | grep -qF -- "${forbid_text}"; then
        bad "${name}" "输出不应包含 '${forbid_text}'"
        return
    fi
    ok "${name}"
}

echo "==> 脚本自检（tests/host/check-scripts.sh）"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

FILLED="${TMP}/filled"
make_filled_copy "${FILLED}"

echo
echo "[正向] 授权已填的临时副本"
expect_run "build --dry-run --toolchain clang 组装出正确的编译命令" \
    0 "-target arm64-apple-ios15.0" "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain clang

expect_run "build --dry-run --toolchain clang 产出名为 libbssidghost.dylib" \
    0 "libbssidghost.dylib" "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain clang

expect_run "build --dry-run --toolchain theos 会生成过滤器并按 rootless 打包" \
    0 "THEOS_PACKAGE_SCHEME=rootless" "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain theos

expect_run "build --dry-run --toolchain theos 的过滤器按 bundle_ids 生成" \
    0 'Bundles = ( "com.ss.iphone.ugc.Lark" )' "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain theos

expect_run "build --dry-run 支持多架构并调用 lipo" \
    0 "lipo" "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain clang --archs arm64,arm64e

expect_run "deploy --dry-run --method deb 推送并 dpkg -i" \
    0 "dpkg -i" "" \
    bash "${FILLED}/scripts/deploy.sh" --dry-run --method deb --udid FAKE-UDID

expect_run "deploy --dry-run --method files 走 /var/jb 前缀" \
    0 "/var/jb/Library/MobileSubstrate/DynamicLibraries" "" \
    bash "${FILLED}/scripts/deploy.sh" --dry-run --method files --udid FAKE-UDID

expect_run "deploy --dry-run 未显式给 UDID 时不会伪造设备" \
    1 "未检测到 iOS 设备" "" \
    env BGGHOST_UDID= bash "${FILLED}/scripts/deploy.sh" --dry-run --method deb

expect_run "verify --skip-device 只做本地检查并以退出码 2 结束" \
    2 "设备侧未执行" "" \
    bash "${FILLED}/scripts/verify.sh" --skip-device

expect_run "verify --skip-device 在授权已填时报告闸门通过" \
    2 "授权闸：通过" "" \
    bash "${FILLED}/scripts/verify.sh" --skip-device

echo
echo "[反向] 仓库当前状态（授权仍为 fill_me）"
expect_run "build 必须因授权未填而拒绝" \
    1 "授权闸未通过" "" \
    bash "${ROOT}/scripts/build.sh" --dry-run --toolchain clang

expect_run "deploy 必须因授权未填而拒绝" \
    1 "授权闸未通过" "" \
    bash "${ROOT}/scripts/deploy.sh" --dry-run --udid FAKE-UDID

expect_run "verify 在授权未填时如实报告闸门未通过（不拦截）" \
    2 "授权闸：未通过" "" \
    bash "${ROOT}/scripts/verify.sh" --skip-device

echo
echo "[反向] control 仍含 <team> 占位符"
TEAM_COPY="${TMP}/team"
make_filled_copy "${TEAM_COPY}"
sed -i 's/com\.example\.bssidghost/com.<team>.bssidghost/g' "${TEAM_COPY}/control"
expect_run "theos 打包必须因 <team> 未填而拒绝" \
    1 "占位符 <team>" "" \
    bash "${TEAM_COPY}/scripts/build.sh" --dry-run --toolchain theos

echo
echo "[反向] 参数校验"
expect_run "build 拒绝未知 --toolchain 取值" \
    1 "只能是 auto / theos / clang" "" \
    bash "${FILLED}/scripts/build.sh" --dry-run --toolchain cargo

expect_run "deploy 拒绝未知 --method 取值" \
    1 "只能是 deb 或 files" "" \
    bash "${FILLED}/scripts/deploy.sh" --dry-run --method magic --udid FAKE

expect_run "脚本拒绝未知参数" \
    1 "未知参数" "" \
    bash "${FILLED}/scripts/verify.sh" --nonsense

echo
printf '结果：%d 通过, %d 失败\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
