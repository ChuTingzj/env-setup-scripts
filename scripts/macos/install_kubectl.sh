#!/usr/bin/env bash
# Install kubectl for darwin/<arch>. KUBECTL_VERSION defaults to the stable release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"

KUBECTL_VERSION="${KUBECTL_VERSION:-}"

_resolve_kubectl_version() {
  if [[ -n "${KUBECTL_VERSION}" ]]; then
    local v="${KUBECTL_VERSION}"
    [[ "${v}" == v* ]] || v="v${v}"
    printf '%s\n' "${v}"
    return 0
  fi
  ensure_curl
  local stable=""
  stable="$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)"
  if [[ -n "${stable}" ]]; then
    printf '%s\n' "${stable}"
  else
    printf '%s\n' "v1.32.0"
  fi
}

install_kubectl() {
  if command_exists kubectl; then
    log_ok "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n 1 || true)"
    return 0
  fi

  local version arch url tmp dest
  version="$(_resolve_kubectl_version)"
  arch="$(macos_release_arch)"
  url="https://dl.k8s.io/release/${version}/bin/darwin/${arch}/kubectl"
  dest="${KUBECTL_INSTALL_DIR:-$(macos_homebrew_prefix)/bin}/kubectl"

  log_info "Installing kubectl ${version} (darwin/${arch})..."
  ensure_curl
  mkdir -p "$(dirname "${dest}")"

  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}'" RETURN

  curl -fsSL "${url}" -o "${tmp}"
  if curl -fsSL "${url}.sha256" -o "${tmp}.sha256" 2>/dev/null; then
    local sum
    sum="$(awk '{ print $1; exit }' "${tmp}.sha256")"
    if command_exists shasum; then
      echo "${sum}  ${tmp}" | shasum -a 256 -c - >/dev/null
      log_ok "kubectl checksum verified"
    elif command_exists sha256sum; then
      echo "${sum}  ${tmp}" | sha256sum -c - >/dev/null
      log_ok "kubectl checksum verified"
    fi
    rm -f "${tmp}.sha256"
  fi

  install -m 0755 "${tmp}" "${dest}"
  assert_macho_arch "${dest}"
  hash -r || true

  if ! command_exists kubectl; then
    log_error "kubectl installation failed."
    exit 1
  fi
  log_ok "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n 1 || true)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_kubectl
fi
