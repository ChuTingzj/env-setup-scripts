#!/usr/bin/env bash
# Install Go via gvm (official binary release)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_gvm.sh
source "${SCRIPT_DIR}/install_gvm.sh"

install_go() {
  install_gvm
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_go
fi
