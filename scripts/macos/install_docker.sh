#!/usr/bin/env bash
# Docker Engine on macOS: CLI, Compose, buildx, and colima.
# Homebrew bottles match the prefix for this chip. colima starts the daemon
# without a Docker Desktop license dialog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"

_link_docker_plugin() {
  local name="$1"
  local bin=""
  bin="$(command -v "${name}" 2>/dev/null || true)"
  if [[ -z "${bin}" ]]; then
    return 0
  fi
  mkdir -p "${HOME}/.docker/cli-plugins"
  ln -sfn "${bin}" "${HOME}/.docker/cli-plugins/${name}"
}

_ensure_colima() {
  if ! command_exists colima; then
    return 0
  fi
  if colima status >/dev/null 2>&1; then
    log_ok "colima already running"
    return 0
  fi
  log_info "Starting colima..."
  if ! colima start; then
    log_warn "colima did not start. Run 'colima start' when a hypervisor is available."
  fi
}

install_docker() {
  if command_exists docker && docker --version >/dev/null 2>&1; then
    log_ok "Docker already installed: $(docker --version)"
    if command_exists colima; then
      _ensure_colima
    fi
    return 0
  fi

  log_info "Installing Docker CLI, Compose, buildx, and colima ($(macos_arch_label))..."
  brew_install_formula docker docker-compose docker-buildx colima
  _link_docker_plugin docker-compose
  _link_docker_plugin docker-buildx

  if ! command_exists docker; then
    log_error "Docker installation failed."
    exit 1
  fi

  _ensure_colima
  log_ok "Docker installed: $(docker --version)"
  if docker compose version >/dev/null 2>&1; then
    log_ok "Docker Compose: $(docker compose version)"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_docker
fi
