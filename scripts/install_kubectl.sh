#!/usr/bin/env bash
# Install kubectl (Kubernetes CLI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

KUBECTL_VERSION="${KUBECTL_VERSION:-}"
KUBECTL_INSTALL_DIR="${KUBECTL_INSTALL_DIR:-/usr/local/bin}"

_resolve_kubectl_version() {
  if [[ -n "${KUBECTL_VERSION}" ]]; then
    # Accept v1.x.y or 1.x.y
    local v="${KUBECTL_VERSION}"
    [[ "${v}" == v* ]] || v="v${v}"
    echo "${v}"
    return 0
  fi
  ensure_curl
  local stable
  stable="$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)"
  if [[ -n "${stable}" ]]; then
    echo "${stable}"
  else
    echo "v1.32.0"
  fi
}

install_kubectl() {
  if command_exists kubectl; then
    log_ok "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n1)"
    return 0
  fi

  local version arch url tmp
  version="$(_resolve_kubectl_version)"
  arch="$(detect_arch)"
  url="https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl"

  log_info "Installing kubectl ${version} (${arch})..."
  ensure_curl

  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}'" RETURN

  curl -fsSL "${url}" -o "${tmp}"
  # Optional checksum verification when sha256 is available
  if curl -fsSL "${url}.sha256" -o "${tmp}.sha256" 2>/dev/null; then
    if command_exists sha256sum; then
      echo "$(cat "${tmp}.sha256")  ${tmp}" | sha256sum -c - >/dev/null
      log_ok "kubectl checksum verified"
    fi
    rm -f "${tmp}.sha256"
  fi

  install -m 0755 "${tmp}" "${KUBECTL_INSTALL_DIR}/kubectl"

  if ! command_exists kubectl; then
    log_error "kubectl installation failed."
    exit 1
  fi

  log_ok "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n1)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_kubectl
fi
