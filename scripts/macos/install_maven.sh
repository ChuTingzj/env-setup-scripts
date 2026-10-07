#!/usr/bin/env bash
# Install Apache Maven. MAVEN_VERSION defaults to 3.9.9.
# A JDK is installed first when java is missing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"
# shellcheck source=install_java.sh
source "${SCRIPT_DIR}/install_java.sh"

MAVEN_VERSION="${MAVEN_VERSION:-3.9.9}"
MAVEN_INSTALL_DIR="${MAVEN_INSTALL_DIR:-${HOME}/.local/opt/maven}"

install_maven() {
  if command_exists mvn; then
    log_ok "Maven already installed: $(mvn -version 2>/dev/null | head -n 1 || true)"
    return 0
  fi

  if ! java_ready; then
    log_info "Java not found; installing JDK first..."
    install_java
  fi

  log_info "Installing Apache Maven ${MAVEN_VERSION}..."
  ensure_curl

  local tarball url archive_url tmp
  tarball="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  url="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${tarball}"
  archive_url="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${tarball}"

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp}'" RETURN

  if ! curl -fsSL "${url}" -o "${tmp}/${tarball}"; then
    log_warn "Primary Maven URL failed; trying archive.apache.org..."
    curl -fsSL "${archive_url}" -o "${tmp}/${tarball}"
  fi

  mkdir -p "$(dirname "${MAVEN_INSTALL_DIR}")" "${HOME}/.local/bin"
  rm -rf "${MAVEN_INSTALL_DIR}"
  tar -C "$(dirname "${MAVEN_INSTALL_DIR}")" -xzf "${tmp}/${tarball}"
  mv "$(dirname "${MAVEN_INSTALL_DIR}")/apache-maven-${MAVEN_VERSION}" "${MAVEN_INSTALL_DIR}"
  ln -sfn "${MAVEN_INSTALL_DIR}/bin/mvn" "${HOME}/.local/bin/mvn"

  append_once "export M2_HOME=\"${MAVEN_INSTALL_DIR}\"" "${HOME}/.bashrc"
  append_once 'export PATH="$HOME/.local/bin:$M2_HOME/bin:$PATH"' "${HOME}/.bashrc"

  export M2_HOME="${MAVEN_INSTALL_DIR}"
  export PATH="${HOME}/.local/bin:${M2_HOME}/bin:${PATH}"
  hash -r || true

  if ! command_exists mvn; then
    log_error "Maven installation failed."
    exit 1
  fi
  log_ok "Maven installed: $(mvn -version 2>/dev/null | head -n 1 || true)"
  log_info "M2_HOME=${M2_HOME}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_maven
fi
