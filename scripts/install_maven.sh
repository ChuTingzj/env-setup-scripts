#!/usr/bin/env bash
# Install Apache Maven

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_java.sh
source "${SCRIPT_DIR}/install_java.sh"

MAVEN_VERSION="${MAVEN_VERSION:-3.9.9}"
MAVEN_INSTALL_DIR="${MAVEN_INSTALL_DIR:-/opt/maven}"

install_maven() {
  if command_exists mvn; then
    log_ok "Maven already installed: $(mvn -version 2>/dev/null | head -n1)"
    return 0
  fi

  # Maven requires a JDK
  if ! command_exists java; then
    log_info "Java not found; installing JDK first..."
    install_java
  fi

  log_info "Installing Apache Maven ${MAVEN_VERSION}..."
  ensure_curl

  local tarball url tmp
  tarball="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  url="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${tarball}"
  # Fallback archive URL if current mirror moved the release
  local archive_url="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${tarball}"

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp}'" RETURN

  if ! curl -fsSL "${url}" -o "${tmp}/${tarball}"; then
    log_warn "Primary Maven URL failed; trying archive.apache.org..."
    curl -fsSL "${archive_url}" -o "${tmp}/${tarball}"
  fi

  mkdir -p "$(dirname "${MAVEN_INSTALL_DIR}")"
  rm -rf "${MAVEN_INSTALL_DIR}"
  tar -C "$(dirname "${MAVEN_INSTALL_DIR}")" -xzf "${tmp}/${tarball}"
  mv "$(dirname "${MAVEN_INSTALL_DIR}")/apache-maven-${MAVEN_VERSION}" "${MAVEN_INSTALL_DIR}"

  append_once "export M2_HOME=${MAVEN_INSTALL_DIR}" /etc/profile.d/maven.sh
  append_once 'export PATH=$M2_HOME/bin:$PATH' /etc/profile.d/maven.sh

  export M2_HOME="${MAVEN_INSTALL_DIR}"
  export PATH="${M2_HOME}/bin:${PATH}"

  if ! command_exists mvn; then
    log_error "Maven installation failed."
    exit 1
  fi

  log_ok "Maven installed: $(mvn -version 2>/dev/null | head -n1)"
  log_info "M2_HOME=${M2_HOME} (source /etc/profile.d/maven.sh or re-login)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  require_root
  install_maven
fi
