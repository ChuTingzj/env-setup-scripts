#!/usr/bin/env bash
# Install OpenJDK (default: 17)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_jenv.sh
source "${SCRIPT_DIR}/install_jenv.sh"

JAVA_VERSION="${JAVA_VERSION:-17}"

install_java() {
  if command_exists java; then
    local current
    current="$(java -version 2>&1 | head -n1 || true)"
    log_ok "Java already installed: ${current}"
    # Still ensure JAVA_HOME is set below.
  else
    log_info "Installing OpenJDK ${JAVA_VERSION}..."
    case "${PKG_MANAGER}" in
      apt)
        pkg_update
        pkg_install "openjdk-${JAVA_VERSION}-jdk"
        ;;
      dnf)
        pkg_install "java-${JAVA_VERSION}-openjdk-devel" || \
          pkg_install "java-${JAVA_VERSION}-openjdk"
        ;;
      yum)
        # CentOS 7 often has 1.8 / 11; try requested version then fall back.
        if ! pkg_install "java-${JAVA_VERSION}-openjdk-devel" 2>/dev/null; then
          log_warn "OpenJDK ${JAVA_VERSION} not in repos; trying java-11-openjdk-devel..."
          if ! pkg_install java-11-openjdk-devel 2>/dev/null; then
            log_warn "Falling back to java-1.8.0-openjdk-devel..."
            pkg_install java-1.8.0-openjdk-devel
          fi
        fi
        ;;
    esac
  fi

  if ! command_exists java; then
    log_error "Java installation failed."
    exit 1
  fi

  # Resolve JAVA_HOME
  local java_home=""
  if command_exists readlink; then
    local java_bin
    java_bin="$(readlink -f "$(command -v java)" 2>/dev/null || true)"
    if [[ -n "${java_bin}" ]]; then
      java_home="$(dirname "$(dirname "${java_bin}")")"
    fi
  fi
  if [[ -z "${java_home}" || ! -d "${java_home}" ]]; then
    # Common layouts
    for candidate in \
      "/usr/lib/jvm/java-${JAVA_VERSION}-openjdk" \
      "/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-"* \
      "/usr/lib/jvm/java-11-openjdk"* \
      "/usr/lib/jvm/java-1.8.0-openjdk"* \
      "/etc/alternatives/java_sdk"; do
      # shellcheck disable=SC2086
      for path in ${candidate}; do
        if [[ -d "${path}" ]]; then
          java_home="${path}"
          break 2
        fi
      done
    done
  fi

  if [[ -n "${java_home}" ]]; then
    export JAVA_HOME="${java_home}"
    append_once "export JAVA_HOME=${java_home}" /etc/profile.d/java.sh
    append_once 'export PATH="$JAVA_HOME/bin:$PATH"' /etc/profile.d/java.sh
    log_ok "JAVA_HOME=${java_home}"
  else
    log_warn "Could not determine JAVA_HOME automatically."
  fi

  log_ok "Java: $(java -version 2>&1 | head -n1)"
  install_jenv
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_java
fi
