#!/usr/bin/env bash
# Install Node.js via Volta (NODE_MAJOR, default 20)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_volta.sh
source "${SCRIPT_DIR}/install_volta.sh"

install_nodejs() {
  install_volta
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_nodejs
fi
