#!/usr/bin/env bash
# Install jenv and register an existing JDK. jenv does not download JDKs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

_jenv_root() {
  if [[ -n "${JENV_ROOT:-}" ]]; then
    printf '%s\n' "${JENV_ROOT}"
    return 0
  fi
  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "/usr/local/jenv"
  else
    printf '%s\n' "${HOME}/.jenv"
  fi
}

activate_jenv() {
  local root=""
  if [[ -n "${JENV_ROOT:-}" && -x "${JENV_ROOT}/bin/jenv" ]]; then
    root="${JENV_ROOT}"
  elif [[ -x /usr/local/jenv/bin/jenv ]]; then
    root="/usr/local/jenv"
  elif [[ -x "${HOME}/.jenv/bin/jenv" ]]; then
    root="${HOME}/.jenv"
  elif command_exists jenv; then
    root="$(dirname "$(dirname "$(command -v jenv)")")"
  else
    return 0
  fi
  export JENV_ROOT="${root}"
  export PATH="${JENV_ROOT}/bin:${JENV_ROOT}/shims:${PATH}"
}

_write_jenv_path() {
  local root="$1"
  if [[ "${EUID}" -eq 0 ]]; then
    append_once "export JENV_ROOT=${root}" /etc/profile.d/jenv.sh
    append_once 'export PATH="$JENV_ROOT/shims:$JENV_ROOT/bin:$PATH"' /etc/profile.d/jenv.sh
  else
    append_once "export JENV_ROOT=\"${root}\"" "${HOME}/.bashrc"
    append_once 'export PATH="$JENV_ROOT/shims:$JENV_ROOT/bin:$PATH"' "${HOME}/.bashrc"
    append_once 'eval "$(jenv init -)"' "${HOME}/.bashrc"
  fi
}

# readlink -f is missing on older macOS. Fall back to walking symlinks.
_resolve_link() {
  local path="$1"
  local resolved=""
  resolved="$(readlink -f "${path}" 2>/dev/null || true)"
  if [[ -n "${resolved}" ]]; then
    printf '%s\n' "${resolved}"
    return 0
  fi
  local dir base
  while [[ -L "${path}" ]]; do
    dir="$(cd "$(dirname "${path}")" && pwd)" || return 1
    base="$(readlink "${path}")"
    if [[ "${base}" == /* ]]; then
      path="${base}"
    else
      path="${dir}/${base}"
    fi
  done
  dir="$(cd "$(dirname "${path}")" && pwd)" || return 1
  printf '%s/%s\n' "${dir}" "$(basename "${path}")"
}

# Print the JDK home for a java binary. jenv shims are not a JDK.
_java_home_from_bin() {
  local java_bin="$1"
  [[ -n "${java_bin}" && -x "${java_bin}" ]] || return 0
  # macOS /usr/bin/java is an install stub. Running it opens a dialog.
  if [[ "$(uname -s)" == "Darwin" && "${java_bin}" == "/usr/bin/java" ]]; then
    return 0
  fi
  local resolved home
  resolved="$(_resolve_link "${java_bin}")"
  [[ -n "${resolved}" && -x "${resolved}" ]] || return 0
  if [[ -n "${JENV_ROOT:-}" && "${resolved}" == "${JENV_ROOT}/"* ]]; then
    return 0
  fi
  home="$(dirname "$(dirname "${resolved}")")"
  if [[ "$(uname -s)" == "Darwin" && "${home}" == "/usr" ]]; then
    return 0
  fi
  if [[ -x "${home}/bin/java" ]]; then
    printf '%s\n' "${home}"
  fi
}

_detect_java_home() {
  local candidate=""
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    candidate="$(_java_home_from_bin "${JAVA_HOME}/bin/java")"
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi
  if command_exists java; then
    candidate="$(_java_home_from_bin "$(command -v java)")"
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi
  # Shims precede /usr/bin once jenv is on PATH. The distro JDK is still there.
  # On macOS, /usr/bin/java is a stub and is ignored above.
  if [[ "$(uname -s)" != "Darwin" && -x /usr/bin/java ]]; then
    _java_home_from_bin /usr/bin/java
  fi
}

_register_jdk_with_jenv() {
  local java_home
  java_home="$(_detect_java_home)"
  if [[ -z "${java_home}" ]]; then
    log_warn "No JDK found for jenv to register. Install Java first (JAVA_VERSION=${JAVA_VERSION:-17})."
    return 0
  fi

  local add_out version
  set +e
  add_out="$(jenv add "${java_home}" 2>&1)"
  set -e
  # jenv colors its "added" lines when stdout is a terminal, and sometimes when it is not.
  # -E works on both GNU sed and the macOS BSD sed.
  add_out="$(printf '%s\n' "${add_out}" | sed -E 's/\x1b\[[0-9;]*m//g')"
  if printf '%s\n' "${add_out}" | grep -q 'added'; then
    log_ok "Registered JDK with jenv: ${java_home}"
  elif printf '%s\n' "${add_out}" | grep -qi 'already'; then
    log_ok "JDK already registered with jenv: ${java_home}"
  else
    log_info "jenv add: ${add_out}"
  fi

  version="$(printf '%s\n' "${add_out}" | awk '/added/ { print $1; exit }')"
  if [[ -z "${version}" ]]; then
    version="$(jenv versions --bare 2>/dev/null | grep -E '^[0-9]' | head -n 1 || true)"
  fi
  if [[ -z "${version}" ]]; then
    log_warn "jenv has no JDK version to set as global."
    return 0
  fi

  jenv global "${version}"
  jenv rehash >/dev/null 2>&1 || true
  log_ok "jenv global ${version}"
}

install_jenv() {
  local root
  root="$(_jenv_root)"

  if [[ -x "${root}/bin/jenv" ]] || command_exists jenv; then
    activate_jenv
    log_ok "jenv already installed: $(jenv --version)"
  else
    log_info "Installing jenv to ${root}..."
    if ! command_exists git; then
      if [[ "${EUID}" -ne 0 && "$(uname -s)" != "Darwin" ]]; then
        log_error "git is required to install jenv."
        exit 1
      fi
      ensure_git
    fi
    git clone --depth 1 https://github.com/jenv/jenv.git "${root}"
    _write_jenv_path "${root}"
    activate_jenv
  fi

  if ! command_exists jenv; then
    log_error "jenv installation failed."
    exit 1
  fi

  # Keep JAVA_HOME aligned with the version selected by jenv.
  jenv enable-plugin export >/dev/null 2>&1 || true
  _register_jdk_with_jenv
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # jenv installs into JENV_ROOT (system path as root, ~/.jenv otherwise).
  install_jenv
fi
