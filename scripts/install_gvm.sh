#!/usr/bin/env bash
# Install gvm, then Go from the official binary (-B).
# Version: GO_VERSION if set, otherwise the latest stable from go.dev,
# otherwise 1.24.5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

GO_VERSION="${GO_VERSION:-}"

_gvm_root_default() {
  if [[ -n "${GVM_ROOT:-}" ]]; then
    printf '%s\n' "${GVM_ROOT}"
    return 0
  fi
  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "/usr/local/gvm"
  else
    printf '%s\n' "${HOME}/.gvm"
  fi
}

_resolve_go_version() {
  if [[ -n "${GO_VERSION}" ]]; then
    printf '%s\n' "${GO_VERSION#go}"
    return 0
  fi
  ensure_curl
  local latest
  latest="$(curl -fsSL 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n 1 | tr -d '\r' || true)"
  if [[ -n "${latest}" ]]; then
    printf '%s\n' "${latest#go}"
  else
    printf '%s\n' "1.24.5"
  fi
}

activate_gvm() {
  local root=""
  if [[ -n "${GVM_ROOT:-}" && -s "${GVM_ROOT}/scripts/gvm" ]]; then
    root="${GVM_ROOT}"
  elif [[ -s /usr/local/gvm/scripts/gvm ]]; then
    root="/usr/local/gvm"
  elif [[ -s "${HOME}/.gvm/scripts/gvm" ]]; then
    root="${HOME}/.gvm"
  else
    return 0
  fi
  export GVM_ROOT="${root}"
  # gvm's scripts return non-zero while probing the environment, and they read
  # variables they also unset. Ignore both while loading the shell function.
  set +e
  set +u
  # shellcheck disable=SC1091
  source "${GVM_ROOT}/scripts/gvm"
  set -e
  set -u
  # gvm reads this even when unset, which fails under `set -u`.
  export GVM_NO_GIT_BAK="${GVM_NO_GIT_BAK:-}"
  export PATH="${GVM_ROOT}/bin:${PATH}"
}

_write_gvm_path() {
  local version="$1"
  local file
  if [[ "${EUID}" -eq 0 ]]; then
    file="/etc/profile.d/gvm.sh"
    append_once "export GVM_ROOT=${GVM_ROOT}" "${file}"
  else
    file="${HOME}/.bashrc"
    append_once 'export GVM_ROOT="$HOME/.gvm"' "${file}"
  fi
  if [[ -n "${version}" ]]; then
    append_once "export GOROOT=\"\$GVM_ROOT/gos/go${version}\"" "${file}"
    append_once 'export GOPATH="${GOPATH:-$HOME/go}"' "${file}"
    append_once 'export PATH="$GOROOT/bin:$GVM_ROOT/bin:$GOPATH/bin:$PATH"' "${file}"
  fi
  # gvm itself is a bash function. Source it only from bash so dash login shells
  # still keep the Go bin directory on PATH from the lines above.
  append_once 'if [ -n "${BASH_VERSION:-}" ] && [ -s "$GVM_ROOT/scripts/gvm" ]; then . "$GVM_ROOT/scripts/gvm"; fi' "${file}"
}

_go_ready() {
  command_exists go && go version >/dev/null 2>&1
}

# gvm's command wrapper checks these even for `gvm install -B`.
_ensure_gvm_deps() {
  local missing=()
  local tool pkgs=()
  for tool in git curl gcc make bison ar; do
    if ! command_exists "${tool}"; then
      missing+=("${tool}")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "gvm requires ${missing[*]}. Install them, or re-run as root."
    exit 1
  fi
  log_info "Installing gvm requirements: ${missing[*]}"
  for tool in "${missing[@]}"; do
    case "${tool}" in
      ar) pkgs+=(binutils) ;;
      *) pkgs+=("${tool}") ;;
    esac
  done
  pkg_install "${pkgs[@]}"
  hash -r || true
}

install_gvm() {
  local root had_go version
  root="$(_gvm_root_default)"
  if _go_ready; then
    had_go=1
  else
    had_go=0
  fi

  # Sourcing gvm runs `gvm list`, which refuses to start until these exist.
  _ensure_gvm_deps

  if [[ -s "${root}/scripts/gvm" ]]; then
    export GVM_ROOT="${root}"
    log_ok "gvm already installed (${GVM_ROOT})"
  else
    log_info "Installing gvm to ${root}..."
    ensure_curl
    if ! command_exists git; then
      if [[ "${EUID}" -ne 0 ]]; then
        log_error "git is required to install gvm."
        exit 1
      fi
      ensure_git
    fi
    if ! command_exists which && [[ "${EUID}" -eq 0 ]]; then
      pkg_install which || pkg_install debianutils
    fi

    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer -o "${tmp}/gvm-installer"
    # The installer writes shell rc files unless this is set. Profile updates
    # below match the other toolchain scripts.
    export GVM_NO_UPDATE_PROFILE=1
    if [[ "${EUID}" -eq 0 ]]; then
      bash "${tmp}/gvm-installer" master /usr/local
      root="/usr/local/gvm"
    else
      bash "${tmp}/gvm-installer" master "${HOME}"
      root="${HOME}/.gvm"
    fi
    rm -rf "${tmp}"
    export GVM_ROOT="${root}"
    if [[ ! -s "${GVM_ROOT}/scripts/gvm" ]]; then
      log_error "gvm installation failed."
      exit 1
    fi
    log_ok "gvm installed (${GVM_ROOT})"
  fi

  activate_gvm

  if [[ "${had_go}" -eq 1 ]]; then
    log_ok "Go already installed: $(go version)"
    _write_gvm_path ""
    return 0
  fi

  version="$(_resolve_go_version)"
  if [[ -x "${GVM_ROOT}/gos/go${version}/bin/go" ]]; then
    log_ok "Go ${version} already installed via gvm"
    export GOROOT="${GVM_ROOT}/gos/go${version}"
    export PATH="${GOROOT}/bin:${PATH}"
    set +e
    set +u
    gvm use "go${version}" --default
    set -e
    set -u
    hash -r || true
    _write_gvm_path "${version}"
    if ! _go_ready; then
      log_error "Go ${version} is installed but not usable."
      exit 1
    fi
    log_ok "Go already installed: $(go version)"
    return 0
  fi

  log_info "Installing Go ${version} via gvm (binary)..."

  local rc
  set +e
  set +u
  gvm install "go${version}" -B
  rc=$?
  set -e
  set -u
  if [[ "${rc}" -ne 0 ]]; then
    log_error "gvm install go${version} -B failed."
    exit 1
  fi

  set +e
  set +u
  gvm use "go${version}" --default
  rc=$?
  set -e
  set -u
  if [[ "${rc}" -ne 0 ]]; then
    log_error "gvm use go${version} --default failed."
    exit 1
  fi

  export GOROOT="${GVM_ROOT}/gos/go${version}"
  export PATH="${GOROOT}/bin:${GVM_ROOT}/bin:${PATH}"
  hash -r || true

  if ! _go_ready; then
    log_error "Go installation failed."
    exit 1
  fi

  _write_gvm_path "${version}"
  log_ok "Go installed: $(go version)"
  log_info "GOROOT=${GOROOT} (source the gvm profile or re-login)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # gvm installs into GVM_ROOT (system path as root, ~/.gvm otherwise).
  install_gvm
fi
