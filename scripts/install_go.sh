#!/usr/bin/env bash
# Install Go toolchain (official tarball)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

GO_VERSION="${GO_VERSION:-}"
GO_INSTALL_DIR="${GO_INSTALL_DIR:-/usr/local}"

_resolve_go_version() {
  if [[ -n "${GO_VERSION}" ]]; then
    echo "${GO_VERSION#go}"
    return 0
  fi
  ensure_curl
  local latest
  latest="$(curl -fsSL 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n1 || true)"
  if [[ -n "${latest}" ]]; then
    echo "${latest#go}"
  else
    echo "1.24.5"
  fi
}

install_go() {
  if command_exists go; then
    log_ok "Go already installed: $(go version)"
    return 0
  fi

  local version arch tarball url tmp
  version="$(_resolve_go_version)"
  arch="$(detect_arch)"
  # Go uses amd64 / arm64
  tarball="go${version}.linux-${arch}.tar.gz"
  url="https://go.dev/dl/${tarball}"

  log_info "Installing Go ${version} (${arch})..."
  ensure_curl

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp}'" RETURN

  curl -fsSL "${url}" -o "${tmp}/${tarball}"
  rm -rf "${GO_INSTALL_DIR}/go"
  tar -C "${GO_INSTALL_DIR}" -xzf "${tmp}/${tarball}"

  append_once "export GOROOT=${GO_INSTALL_DIR}/go" /etc/profile.d/go.sh
  append_once 'export GOPATH=${GOPATH:-$HOME/go}' /etc/profile.d/go.sh
  append_once 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' /etc/profile.d/go.sh

  export GOROOT="${GO_INSTALL_DIR}/go"
  export PATH="${GOROOT}/bin:${PATH}"

  if ! command_exists go; then
    log_error "Go installation failed."
    exit 1
  fi

  log_ok "Go installed: $(go version)"
  log_info "GOROOT=${GOROOT} (source /etc/profile.d/go.sh or re-login)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_go
fi
