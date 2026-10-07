#!/usr/bin/env bash
# Shared helpers for env-setup-scripts

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Please run as root (or via sudo)."
    exit 1
  fi
}

# Detect package manager: apt | dnf | yum
detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    log_error "Unsupported package manager. Need apt, dnf, or yum."
    exit 1
  fi
}

PKG_MANAGER="${PKG_MANAGER:-$(detect_pkg_manager)}"

pkg_update() {
  case "${PKG_MANAGER}" in
    apt) apt-get update -y ;;
    dnf) dnf makecache -y ;;
    yum) yum makecache -y ;;
  esac
}

pkg_install() {
  case "${PKG_MANAGER}" in
    apt) apt-get install -y "$@" ;;
    dnf) dnf install -y "$@" ;;
    yum) yum install -y "$@" ;;
  esac
}

pkg_remove() {
  case "${PKG_MANAGER}" in
    apt) apt-get remove -y "$@" ;;
    dnf) dnf remove -y "$@" ;;
    yum) yum remove -y "$@" ;;
  esac
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_curl() {
  if ! command_exists curl; then
    log_info "Installing curl..."
    pkg_install curl
  fi
}

ensure_git() {
  if ! command_exists git; then
    log_info "Installing git..."
    pkg_install git
  fi
}

ensure_wget() {
  if ! command_exists wget; then
    log_info "Installing wget..."
    pkg_install wget
  fi
}

# Append a line to a file if it is not already present.
append_once() {
  local line="$1"
  local file="$2"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  if ! grep -Fqx "${line}" "${file}" 2>/dev/null; then
    echo "${line}" >> "${file}"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      log_error "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

print_version() {
  local name="$1"
  shift
  if ! command_exists "$1"; then
    log_warn "${name}: not found"
    return 0
  fi
  local out rc
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  out="$(printf '%s\n' "${out}" | head -n1)"
  if [[ "${rc}" -ne 0 ]]; then
    log_warn "${name}: present but not usable (${out})"
    return 0
  fi
  log_ok "${name}: ${out}"
}
