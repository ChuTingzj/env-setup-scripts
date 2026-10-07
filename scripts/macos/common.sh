#!/usr/bin/env bash
# macOS helpers. Source scripts/common.sh first so log_* and append_once exist.

set -euo pipefail

_MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=arch.sh
source "${_MACOS_DIR}/arch.sh"

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This installer is for macOS (Intel x86_64 or Apple Silicon arm64)."
    exit 1
  fi
}

macos_arch_label() {
  case "$(uname -m)" in
    x86_64|amd64) printf '%s\n' "Intel" ;;
    arm64|aarch64) printf '%s\n' "Apple Silicon" ;;
    *) printf '%s\n' "$(uname -m)" ;;
  esac
}

macos_homebrew_prefix() {
  local machine prefix
  machine="$(uname -m)"
  if ! prefix="$(homebrew_prefix_for_machine "${machine}")"; then
    log_error "Unsupported macOS architecture: ${machine}"
    exit 1
  fi
  printf '%s\n' "${prefix}"
}

macos_release_arch() {
  local machine arch
  machine="$(uname -m)"
  if ! arch="$(release_arch_for_machine "${machine}")"; then
    log_error "Unsupported macOS architecture: ${machine}"
    exit 1
  fi
  printf '%s\n' "${arch}"
}

macos_warn_rosetta() {
  local translated=""
  translated="$(sysctl -n sysctl.proc_translated 2>/dev/null || true)"
  if [[ "${translated}" == "1" ]]; then
    log_warn "This shell is running under Rosetta (uname -m=$(uname -m)). Installing Intel binaries into /usr/local."
  fi
}

activate_homebrew() {
  local brew_bin="$1"
  local expected actual
  expected="$(macos_homebrew_prefix)"
  if [[ ! -x "${brew_bin}" ]]; then
    log_error "Homebrew is not installed at ${brew_bin}."
    exit 1
  fi
  # shellcheck disable=SC1090
  eval "$("${brew_bin}" shellenv)"
  hash -r || true
  actual="$(brew --prefix)"
  if [[ "${actual}" != "${expected}" ]]; then
    log_error "Homebrew prefix ${actual} does not match ${expected} for $(uname -m) ($(macos_arch_label))."
    exit 1
  fi
}

macos_activate_homebrew_if_present() {
  local brew_bin
  brew_bin="$(macos_homebrew_prefix)/bin/brew"
  if [[ -x "${brew_bin}" ]]; then
    activate_homebrew "${brew_bin}"
    return 0
  fi
  return 1
}

# Future shells: bashrc holds tool exports; login and zsh shells source it.
macos_link_shell_profiles() {
  local line='[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'
  append_once "${line}" "${HOME}/.zprofile"
  append_once "${line}" "${HOME}/.zshrc"
  append_once "${line}" "${HOME}/.bash_profile"
}

macos_persist_brew_shellenv() {
  local brew_bin line
  brew_bin="$(macos_homebrew_prefix)/bin/brew"
  line="eval \"\$(${brew_bin} shellenv)\""
  append_once "${line}" "${HOME}/.bashrc"
  append_once "${line}" "${HOME}/.zprofile"
  append_once "${line}" "${HOME}/.zshrc"
  append_once "${line}" "${HOME}/.bash_profile"
  append_once 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc"
  mkdir -p "${HOME}/.local/bin"
}

brew_install_formula() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing formulae: $*"
  NONINTERACTIVE=1 brew install --formula "$@"
  hash -r || true
}

# True when a JDK is installed and `java` is not the macOS install stub.
java_ready() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" && "${JAVA_HOME}" != "/usr" ]]; then
    return 0
  fi
  if /usr/libexec/java_home >/dev/null 2>&1; then
    return 0
  fi
  local bin=""
  bin="$(command -v java 2>/dev/null || true)"
  if [[ -z "${bin}" || "${bin}" == "/usr/bin/java" ]]; then
    return 1
  fi
  "${bin}" -version >/dev/null 2>&1
}

# /usr/bin/python3 on macOS is often an install stub. A real interpreter lives elsewhere.
python3_ready() {
  local bin=""
  bin="$(command -v python3 2>/dev/null || true)"
  if [[ -z "${bin}" || "${bin}" == "/usr/bin/python3" ]]; then
    return 1
  fi
  "${bin}" --version >/dev/null 2>&1
}

# Fail if a downloaded Mach-O does not match uname -m.
assert_macho_arch() {
  local bin="$1"
  local desc
  if ! command_exists file; then
    return 0
  fi
  desc="$(file -b "${bin}")"
  case "$(uname -m)" in
    x86_64|amd64)
      if [[ "${desc}" != *"x86_64"* ]]; then
        log_error "Expected an x86_64 binary at ${bin}, got: ${desc}"
        exit 1
      fi
      ;;
    arm64|aarch64)
      if [[ "${desc}" != *"arm64"* ]]; then
        log_error "Expected an arm64 binary at ${bin}, got: ${desc}"
        exit 1
      fi
      ;;
  esac
  log_ok "Binary matches $(uname -m): ${desc}"
}
