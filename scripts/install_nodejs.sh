#!/usr/bin/env bash
# Install Node.js LTS via NodeSource (or distro package as fallback)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NODE_MAJOR="${NODE_MAJOR:-20}"

install_nodejs() {
  if command_exists node; then
    log_ok "Node.js already installed: $(node --version)"
    command_exists npm && log_ok "npm: $(npm --version)"
    return 0
  fi

  log_info "Installing Node.js ${NODE_MAJOR}.x..."
  ensure_curl

  case "${PKG_MANAGER}" in
    apt)
      curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
      pkg_install nodejs
      ;;
    dnf|yum)
      curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | bash - || true
      if ! pkg_install nodejs 2>/dev/null; then
        log_warn "NodeSource failed; trying distro nodejs/npm..."
        pkg_install nodejs npm || pkg_install nodejs
      fi
      ;;
  esac

  if ! command_exists node; then
    log_error "Node.js installation failed."
    exit 1
  fi

  log_ok "Node.js: $(node --version)"
  command_exists npm && log_ok "npm: $(npm --version)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_nodejs
fi
