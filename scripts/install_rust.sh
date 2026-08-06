#!/usr/bin/env bash
# Install Rust via rustup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

install_rust() {
  if command_exists rustc && command_exists cargo; then
    log_ok "Rust already installed: $(rustc --version)"
    log_ok "Cargo: $(cargo --version)"
    return 0
  fi

  log_info "Installing Rust (rustup)..."
  ensure_curl

  if [[ "${EUID}" -eq 0 ]]; then
    export RUSTUP_HOME="${RUSTUP_HOME:-/usr/local/rustup}"
    export CARGO_HOME="${CARGO_HOME:-/usr/local/cargo}"
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --default-toolchain stable
    append_once "export RUSTUP_HOME=${RUSTUP_HOME}" /etc/profile.d/rust.sh
    append_once "export CARGO_HOME=${CARGO_HOME}" /etc/profile.d/rust.sh
    append_once "export PATH=${CARGO_HOME}/bin:\$PATH" /etc/profile.d/rust.sh
    export PATH="${CARGO_HOME}/bin:${PATH}"
  else
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1091
    [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
    export PATH="${HOME}/.cargo/bin:${PATH}"
  fi

  if ! command_exists rustc || ! command_exists cargo; then
    log_error "Rust installation failed."
    exit 1
  fi

  log_ok "Rust installed: $(rustc --version)"
  log_ok "Cargo: $(cargo --version)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # rustup supports non-root user installs into ~/.cargo
  install_rust
fi
