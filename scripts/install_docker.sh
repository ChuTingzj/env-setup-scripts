#!/usr/bin/env bash
# Install Docker Engine + Compose plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

install_docker() {
  if command_exists docker && docker --version >/dev/null 2>&1; then
    log_ok "Docker already installed: $(docker --version)"
    _ensure_docker_running
    return 0
  fi

  log_info "Installing Docker..."
  ensure_curl

  case "${PKG_MANAGER}" in
    apt)
      pkg_update
      pkg_install ca-certificates curl gnupg lsb-release
      install -m 0755 -d /etc/apt/keyrings
      if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "${ID}")/gpg" \
          | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
      fi
      # shellcheck disable=SC1091
      . /etc/os-release
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
      pkg_update
      pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    dnf|yum)
      # Prefer official Docker CE repo; fall back to distro docker if needed.
      pkg_install yum-utils device-mapper-persistent-data lvm2 || true
      if command_exists yum-config-manager; then
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
      elif command_exists dnf; then
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
      fi

      if ! pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null; then
        log_warn "Docker CE install failed; trying distro docker package..."
        pkg_install docker || pkg_install docker-engine
      fi
      ;;
  esac

  if ! command_exists docker; then
    log_error "Docker installation failed."
    exit 1
  fi

  _ensure_docker_running
  log_ok "Docker installed: $(docker --version)"
  if docker compose version >/dev/null 2>&1; then
    log_ok "Docker Compose: $(docker compose version)"
  fi
}

_ensure_docker_running() {
  if command_exists systemctl; then
    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true
  elif command_exists service; then
    service docker start >/dev/null 2>&1 || true
  fi

  # Allow invoking user to use docker without sudo (if SUDO_USER is set).
  if [[ -n "${SUDO_USER:-}" ]] && id "${SUDO_USER}" >/dev/null 2>&1; then
    if getent group docker >/dev/null 2>&1; then
      usermod -aG docker "${SUDO_USER}" || true
      log_info "Added ${SUDO_USER} to docker group (re-login required)."
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_docker
fi
