#!/usr/bin/env bash
# Entry and architecture checks that run on Linux CI.
# Prefixes: x86_64 -> /usr/local, arm64 -> /opt/homebrew.
# Release archives: x86_64 -> amd64, arm64 -> arm64.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/macos/arch.sh
source "${ROOT}/scripts/macos/arch.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ "$(homebrew_prefix_for_machine x86_64)" == "/usr/local" ]] || fail "x86_64 prefix"
[[ "$(homebrew_prefix_for_machine amd64)" == "/usr/local" ]] || fail "amd64 prefix"
[[ "$(homebrew_prefix_for_machine arm64)" == "/opt/homebrew" ]] || fail "arm64 prefix"
[[ "$(homebrew_prefix_for_machine aarch64)" == "/opt/homebrew" ]] || fail "aarch64 prefix"
[[ "$(release_arch_for_machine x86_64)" == "amd64" ]] || fail "x86_64 release arch"
[[ "$(release_arch_for_machine amd64)" == "amd64" ]] || fail "amd64 release arch"
[[ "$(release_arch_for_machine arm64)" == "arm64" ]] || fail "arm64 release arch"
[[ "$(release_arch_for_machine aarch64)" == "arm64" ]] || fail "aarch64 release arch"

if homebrew_prefix_for_machine ppc >/dev/null 2>&1; then
  fail "unknown machine should be rejected"
fi
if release_arch_for_machine ppc >/dev/null 2>&1; then
  fail "unknown release arch should be rejected"
fi

list="$(bash "${ROOT}/install.sh" --list)"
grep -qx base <<<"${list}" || fail "linux --list missing base"
grep -qx volta <<<"${list}" || fail "linux --list missing volta"
grep -qx gvm <<<"${list}" || fail "linux --list missing gvm"
grep -qx jenv <<<"${list}" || fail "linux --list missing jenv"
grep -qx maven <<<"${list}" || fail "linux --list missing maven"

help="$(bash "${ROOT}/install.sh" --help)"
grep -q "apt" <<<"${help}" || fail "linux help lost apt"
grep -q "macOS" <<<"${help}" || fail "linux help should mention the macOS handoff"

bash "${ROOT}/install.sh" --check >/dev/null

set +e
mac_out="$(bash "${ROOT}/install-macos.sh" --help 2>&1)"
mac_rc=$?
set -e
[[ "${mac_rc}" -ne 0 ]] || fail "install-macos.sh should refuse to run on Linux"
grep -q "macOS" <<<"${mac_out}" || fail "macOS refusal message"

pkg="$(bash -c "source '${ROOT}/scripts/common.sh'; printf '%s' \"\${PKG_MANAGER}\"")"
[[ "${pkg}" == "apt" ]] || fail "Linux PKG_MANAGER=${pkg}, expected apt"

while IFS= read -r file; do
  bash -n "${file}"
done < <(find "${ROOT}" -name '*.sh' -type f)

echo "ok"
