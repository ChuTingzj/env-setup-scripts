#!/usr/bin/env bash
# Install Volta, then Node.js (NODE_MAJOR, default 20)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NODE_MAJOR="${NODE_MAJOR:-20}"

_volta_home() {
  if [[ -n "${VOLTA_HOME:-}" ]]; then
    printf '%s\n' "${VOLTA_HOME}"
    return 0
  fi
  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "/usr/local/volta"
  else
    printf '%s\n' "${HOME}/.volta"
  fi
}

activate_volta() {
  local home=""
  if [[ -n "${VOLTA_HOME:-}" && -x "${VOLTA_HOME}/bin/volta" ]]; then
    home="${VOLTA_HOME}"
  elif [[ -x /usr/local/volta/bin/volta ]]; then
    home="/usr/local/volta"
  elif [[ -x "${HOME}/.volta/bin/volta" ]]; then
    home="${HOME}/.volta"
  elif command_exists volta; then
    home="$(dirname "$(dirname "$(command -v volta)")")"
  else
    return 0
  fi
  export VOLTA_HOME="${home}"
  export PATH="${VOLTA_HOME}/bin:${PATH}"
}

_node_ready() {
  command_exists node && node --version >/dev/null 2>&1
}

_write_volta_path() {
  local home="$1"
  if [[ "${EUID}" -eq 0 ]]; then
    append_once "export VOLTA_HOME=${home}" /etc/profile.d/volta.sh
    append_once 'export PATH="$VOLTA_HOME/bin:$PATH"' /etc/profile.d/volta.sh
  else
    append_once "export VOLTA_HOME=\"${home}\"" "${HOME}/.bashrc"
    append_once 'export PATH="$VOLTA_HOME/bin:$PATH"' "${HOME}/.bashrc"
  fi
}

install_volta() {
  local home
  home="$(_volta_home)"

  if [[ -x "${home}/bin/volta" ]] || command_exists volta; then
    activate_volta
    log_ok "Volta already installed: $(volta --version)"
  else
    log_info "Installing Volta to ${home}..."
    ensure_curl
    export VOLTA_HOME="${home}"

    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL https://get.volta.sh -o "${tmp}/volta-install.sh"
    if ! bash "${tmp}/volta-install.sh" --skip-setup; then
      rm -rf "${tmp}"
      if [[ ! -x "${home}/bin/volta" ]]; then
        log_error "Volta installation failed."
        exit 1
      fi
    fi
    rm -rf "${tmp}"
    _write_volta_path "${home}"
    activate_volta
  fi

  if ! command_exists volta; then
    log_error "Volta installation failed."
    exit 1
  fi

  if _node_ready; then
    log_ok "Node.js already installed: $(node --version)"
    if command_exists npm && npm --version >/dev/null 2>&1; then
      log_ok "npm: $(npm --version)"
    fi
    return 0
  fi

  log_info "Installing Node.js ${NODE_MAJOR} via Volta..."
  volta install "node@${NODE_MAJOR}"
  hash -r || true

  if ! _node_ready; then
    log_error "Node.js installation failed."
    exit 1
  fi

  log_ok "Node.js: $(node --version)"
  if command_exists npm; then
    log_ok "npm: $(npm --version)"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Volta installs into VOLTA_HOME (system path as root, ~/.volta otherwise).
  install_volta
fi
