#!/usr/bin/env bash
# Install Git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

install_git() {
  if command_exists git; then
    log_ok "Git already installed: $(git --version)"
    return 0
  fi

  log_info "Installing Git..."
  case "${PKG_MANAGER}" in
    apt)
      pkg_install git
      ;;
    dnf|yum)
      # Prefer newer git from IUS / SCL when available; fall back to distro package.
      pkg_install git || true
      if ! command_exists git; then
        log_error "Failed to install Git."
        exit 1
      fi
      ;;
  esac

  log_ok "Git installed: $(git --version)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_git
fi
