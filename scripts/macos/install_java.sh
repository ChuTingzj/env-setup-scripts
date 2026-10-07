#!/usr/bin/env bash
# Install a JDK with Homebrew, then register it with jenv.
# jenv does not download JDKs. JAVA_VERSION defaults to 17.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=install_homebrew.sh
source "${SCRIPT_DIR}/install_homebrew.sh"
# shellcheck source=../install_jenv.sh
source "${SCRIPT_DIR}/../install_jenv.sh"

JAVA_VERSION="${JAVA_VERSION:-17}"

_brew_java_home() {
  local prefix="" home=""
  prefix="$(brew --prefix "openjdk@${JAVA_VERSION}" 2>/dev/null || true)"
  home="${prefix}/libexec/openjdk.jdk/Contents/Home"
  if [[ -n "${prefix}" && -x "${home}/bin/java" ]]; then
    printf '%s\n' "${home}"
    return 0
  fi
  return 1
}

_existing_java_home() {
  local home="" bin=""
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" && "${JAVA_HOME}" != "/usr" ]]; then
    printf '%s\n' "${JAVA_HOME}"
    return 0
  fi
  if home="$(/usr/libexec/java_home 2>/dev/null)" && [[ -n "${home}" && -x "${home}/bin/java" ]]; then
    printf '%s\n' "${home}"
    return 0
  fi
  bin="$(command -v java 2>/dev/null || true)"
  if [[ -n "${bin}" && "${bin}" != "/usr/bin/java" ]]; then
    home="$(_java_home_from_bin "${bin}")"
    if [[ -n "${home}" ]]; then
      printf '%s\n' "${home}"
      return 0
    fi
  fi
  return 1
}

_symlink_jvm() {
  local home="$1"
  local bundle dest
  bundle="$(cd "${home}/../.." && pwd)"
  dest="/Library/Java/JavaVirtualMachines/openjdk-${JAVA_VERSION}.jdk"
  if sudo -n true >/dev/null 2>&1; then
    sudo mkdir -p /Library/Java/JavaVirtualMachines
    sudo ln -sfn "${bundle}" "${dest}"
    log_ok "Linked ${dest}"
  else
    log_info "No passwordless sudo; JAVA_HOME stays at ${home}."
  fi
}

install_java() {
  local java_home=""
  java_home="$(_brew_java_home || true)"
  if [[ -z "${java_home}" ]]; then
    java_home="$(_existing_java_home || true)"
  fi

  if [[ -n "${java_home}" ]]; then
    log_ok "Java already installed: $("${java_home}/bin/java" -version 2>&1 | head -n 1 || true)"
  else
    log_info "Installing OpenJDK ${JAVA_VERSION} ($(macos_arch_label))..."
    brew_install_formula "openjdk@${JAVA_VERSION}"
    java_home="$(_brew_java_home || true)"
    if [[ -z "${java_home}" ]]; then
      log_error "OpenJDK ${JAVA_VERSION} installation failed."
      exit 1
    fi
    _symlink_jvm "${java_home}"
  fi

  export JAVA_HOME="${java_home}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
  append_once "export JAVA_HOME=\"${java_home}\"" "${HOME}/.bashrc"
  append_once 'export PATH="$JAVA_HOME/bin:$PATH"' "${HOME}/.bashrc"
  log_ok "JAVA_HOME=${JAVA_HOME}"
  install_jenv
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_homebrew
  install_java
fi
