#!/usr/bin/env bash
# Install the Homebrew that matches uname -m.
#   x86_64 -> /usr/local
#   arm64  -> /opt/homebrew

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

_ensure_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log_ok "Xcode Command Line Tools already installed."
    return 0
  fi

  log_info "Installing Xcode Command Line Tools..."
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  local label="" list=""
  set +e
  list="$(softwareupdate -l 2>&1)"
  set -e
  label="$(printf '%s\n' "${list}" | sed -n 's/^.*Label: //p' | grep 'Command Line Tools' | tail -n 1 || true)"
  if [[ -z "${label}" ]]; then
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    log_warn "Command Line Tools package was not listed. Run xcode-select --install if compilers are missing."
    return 0
  fi
  if ! softwareupdate -i "${label}" --verbose; then
    log_warn "Command Line Tools install failed."
  fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  if xcode-select -p >/dev/null 2>&1; then
    log_ok "Xcode Command Line Tools installed."
  fi
}

ensure_homebrew() {
  require_macos
  export NONINTERACTIVE=1
  export HOMEBREW_NO_ANALYTICS=1

  macos_warn_rosetta

  local prefix brew_bin
  prefix="$(macos_homebrew_prefix)"
  brew_bin="${prefix}/bin/brew"

  if [[ -x "${brew_bin}" ]]; then
    activate_homebrew "${brew_bin}"
    log_ok "Homebrew already installed: $(brew --version | head -n 1) (${prefix}, $(macos_arch_label))"
  else
    if ! command_exists curl; then
      log_error "curl is required to install Homebrew."
      exit 1
    fi
    log_info "Installing Homebrew for $(uname -m) ($(macos_arch_label)) into ${prefix}..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ ! -x "${brew_bin}" ]]; then
      log_error "Homebrew installation failed. Expected ${brew_bin} for $(uname -m)."
      exit 1
    fi
    activate_homebrew "${brew_bin}"
    log_ok "Homebrew installed: $(brew --version | head -n 1) (${prefix})"
  fi

  if ! brew update; then
    log_warn "brew update failed; continuing with the current formulae."
  fi
  export HOMEBREW_NO_AUTO_UPDATE=1

  macos_persist_brew_shellenv
  macos_link_shell_profiles
  _ensure_clt
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
fi
