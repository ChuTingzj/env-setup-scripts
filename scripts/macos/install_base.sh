#!/usr/bin/env bash
# Common CLI tools via Homebrew, plus a real python3 (no Python version manager).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"

install_base() {
  log_info "Installing base packages with Homebrew ($(macos_arch_label), $(macos_homebrew_prefix))..."
  brew_install_formula \
    ca-certificates wget gnupg \
    vim jq tree htop

  if python3_ready; then
    log_ok "python3 already installed: $(python3 --version)"
  else
    log_info "Installing python3..."
    brew_install_formula python3
    hash -r || true
    if ! python3_ready; then
      log_error "python3 installation failed."
      exit 1
    fi
    log_ok "python3 installed: $(python3 --version)"
  fi

  log_ok "Base packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_base
fi
