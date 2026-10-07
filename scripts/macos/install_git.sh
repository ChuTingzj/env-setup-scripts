#!/usr/bin/env bash
# Install Git. Skip when a usable git is already on PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"

_git_ready() {
  local bin=""
  bin="$(command -v git 2>/dev/null || true)"
  if [[ -z "${bin}" ]]; then
    return 1
  fi
  # /usr/bin/git without Command Line Tools is a stub that opens a dialog.
  if [[ "${bin}" == "/usr/bin/git" ]] && ! xcode-select -p >/dev/null 2>&1; then
    return 1
  fi
  "${bin}" --version >/dev/null 2>&1
}

install_git() {
  if _git_ready; then
    log_ok "Git already installed: $(git --version)"
    return 0
  fi

  log_info "Installing Git..."
  brew_install_formula git
  hash -r || true
  if ! _git_ready; then
    log_error "Git installation failed."
    exit 1
  fi
  log_ok "Git installed: $(git --version)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_git
fi
