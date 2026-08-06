#!/usr/bin/env bash
# Install uv (https://github.com/astral-sh/uv)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

install_uv() {
  # Prefer system-wide install under /usr/local/bin when running as root.
  local uv_bin=""
  if command_exists uv; then
    uv_bin="$(command -v uv)"
    log_ok "uv already installed: $(uv --version) (${uv_bin})"
    return 0
  fi

  log_info "Installing uv..."
  ensure_curl

  # Official installer; install to /usr/local when root.
  if [[ "${EUID}" -eq 0 ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --install-dir /usr/local/bin --no-modify-path
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Ensure cargo/uv path is available in profile for non-root installs.
    local home_bin="${HOME}/.local/bin"
    if [[ -d "${home_bin}" ]]; then
      append_once "export PATH=\"${home_bin}:\$PATH\"" "${HOME}/.bashrc"
    fi
  fi

  # Refresh PATH for current shell
  export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"

  if ! command_exists uv; then
    log_error "uv installation failed. Check network or https://docs.astral.sh/uv/"
    exit 1
  fi

  log_ok "uv installed: $(uv --version)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # uv can be installed as non-root into ~/.local/bin
  install_uv
fi
