#!/usr/bin/env bash
# Install common CLI utilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

install_base() {
  log_info "Installing base packages..."
  pkg_update

  case "${PKG_MANAGER}" in
    apt)
      pkg_install \
        ca-certificates curl wget gnupg lsb-release \
        build-essential gcc g++ make \
        vim unzip zip tar gzip bzip2 \
        jq tree htop net-tools \
        software-properties-common apt-transport-https \
        python3
      ;;
    dnf|yum)
      # Development tools group (best-effort)
      if [[ "${PKG_MANAGER}" == "yum" ]]; then
        yum groupinstall -y "Development Tools" || true
      else
        dnf groupinstall -y "Development Tools" || true
      fi
      pkg_install \
        ca-certificates curl wget gnupg2 \
        gcc gcc-c++ make \
        vim unzip zip tar gzip bzip2 \
        jq tree htop net-tools which \
        python3 || true
      ;;
  esac

  log_ok "Base packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_base
fi
