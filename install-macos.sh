#!/usr/bin/env bash
# macOS developer environment bootstrap (Intel and Apple Silicon).
# Homebrew prefix follows uname -m:
#   x86_64 -> /usr/local
#   arm64  -> /opt/homebrew

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS (Intel x86_64 or Apple Silicon arm64)." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
MACOS_DIR="${SCRIPTS_DIR}/macos"

# shellcheck source=scripts/common.sh
source "${SCRIPTS_DIR}/common.sh"
# shellcheck source=scripts/macos/common.sh
source "${MACOS_DIR}/common.sh"
# shellcheck source=scripts/macos/install_homebrew.sh
source "${MACOS_DIR}/install_homebrew.sh"
# shellcheck source=scripts/macos/install_base.sh
source "${MACOS_DIR}/install_base.sh"
# shellcheck source=scripts/macos/install_git.sh
source "${MACOS_DIR}/install_git.sh"
# shellcheck source=scripts/install_jenv.sh
source "${SCRIPTS_DIR}/install_jenv.sh"
# shellcheck source=scripts/macos/install_java.sh
source "${MACOS_DIR}/install_java.sh"
# shellcheck source=scripts/macos/install_docker.sh
source "${MACOS_DIR}/install_docker.sh"
# shellcheck source=scripts/install_uv.sh
source "${SCRIPTS_DIR}/install_uv.sh"
# shellcheck source=scripts/install_volta.sh
source "${SCRIPTS_DIR}/install_volta.sh"
# shellcheck source=scripts/install_nodejs.sh
source "${SCRIPTS_DIR}/install_nodejs.sh"
# shellcheck source=scripts/install_gvm.sh
source "${SCRIPTS_DIR}/install_gvm.sh"
# shellcheck source=scripts/install_go.sh
source "${SCRIPTS_DIR}/install_go.sh"
# shellcheck source=scripts/install_rust.sh
source "${SCRIPTS_DIR}/install_rust.sh"
# shellcheck source=scripts/macos/install_kubectl.sh
source "${MACOS_DIR}/install_kubectl.sh"
# shellcheck source=scripts/macos/install_maven.sh
source "${MACOS_DIR}/install_maven.sh"

ALL_COMPONENTS=(base git java jenv docker uv volta nodejs gvm go rust kubectl maven)

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [COMPONENTS...]

Install common developer tools on macOS with Homebrew.
Intel (uname -m x86_64) uses /usr/local. Apple Silicon (uname -m arm64) uses /opt/homebrew.
Run the same command on either chip. sudo is not required.

Components:
  base      curl-compatible CLI tools, compilers (Command Line Tools), python3
  git       Git
  java      OpenJDK (JAVA_VERSION=${JAVA_VERSION:-17}) and jenv
  jenv      jenv (registers an installed JDK; does not download one)
  docker    Docker CLI, Compose, buildx, and colima
  uv        Astral uv (Python package/tooling)
  volta     Volta and Node.js (NODE_MAJOR=${NODE_MAJOR:-20})
  nodejs    Node.js via Volta (NODE_MAJOR=${NODE_MAJOR:-20})
  gvm       gvm and Go (GO_VERSION, else latest stable, else 1.24.5)
  go        Go via gvm binary install (-B)
  rust      Rust via rustup (stable)
  kubectl   Kubernetes CLI (KUBECTL_VERSION=stable if unset)
  maven     Apache Maven (MAVEN_VERSION=${MAVEN_VERSION:-3.9.9})
  all       Everything above (default)

Options:
  -h, --help     Show this help
  -l, --list     List available components
  -c, --check    Only print installed versions (no install)
  --no-base      Skip base packages when installing all

Examples:
  $0
  $0 git java go maven
  JAVA_VERSION=21 $0 java
  NODE_MAJOR=22 $0 nodejs
  GO_VERSION=1.24.5 $0 go
  MAVEN_VERSION=3.9.9 $0 maven
  $0 --check

EOF
}

list_components() {
  printf '%s\n' "${ALL_COMPONENTS[@]}"
}

_rerun_as_user_if_sudo() {
  [[ "${EUID}" -eq 0 ]] || return 0
  local arg
  for arg in "$@"; do
    case "${arg}" in
      -h|--help|-l|--list) return 0 ;;
    esac
  done
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    log_info "Continuing as ${SUDO_USER}; Homebrew does not run as root."
    exec sudo -u "${SUDO_USER}" -H env \
      "NODE_MAJOR=${NODE_MAJOR:-}" \
      "JAVA_VERSION=${JAVA_VERSION:-}" \
      "GO_VERSION=${GO_VERSION:-}" \
      "KUBECTL_VERSION=${KUBECTL_VERSION:-}" \
      "MAVEN_VERSION=${MAVEN_VERSION:-}" \
      NONINTERACTIVE=1 \
      /bin/bash "${BASH_SOURCE[0]}" "$@"
  fi
  for arg in "$@"; do
    case "${arg}" in
      -c|--check) return 0 ;;
    esac
  done
  log_error "Run as a normal macOS user. Homebrew does not install as root."
  exit 1
}

check_versions() {
  log_info "Operating system: macOS $(sw_vers -productVersion 2>/dev/null || true)"
  log_info "Architecture:     $(uname -m) ($(macos_arch_label))"
  if macos_activate_homebrew_if_present; then
    log_info "Homebrew prefix:  $(brew --prefix)"
  else
    log_warn "Homebrew: not installed at $(macos_homebrew_prefix)"
  fi
  echo
  print_version "git" git --version
  print_version "java" java -version
  print_version "docker" docker --version
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    print_version "compose" docker compose version
  fi
  print_version "uv" uv --version
  activate_volta || true
  print_version "volta" volta --version
  print_version "node" node --version
  print_version "npm" npm --version
  activate_jenv || true
  print_version "jenv" jenv --version
  activate_gvm || true
  print_version "gvm" gvm version
  print_version "go" go version
  print_version "rustc" rustc --version
  print_version "cargo" cargo --version
  print_version "kubectl" kubectl version --client
  print_version "mvn" mvn -version
  print_version "curl" curl --version
  print_version "python3" python3 --version
}

run_component() {
  case "$1" in
    base)    install_base ;;
    git)     install_git ;;
    java)    install_java ;;
    jenv)    install_jenv ;;
    docker)  install_docker ;;
    uv)      install_uv ;;
    volta)   install_volta ;;
    nodejs)  install_nodejs ;;
    gvm)     install_gvm ;;
    go)      install_go ;;
    rust)    install_rust_macos ;;
    kubectl) install_kubectl ;;
    maven)   install_maven ;;
    *)
      log_error "Unknown component: $1"
      usage
      exit 1
      ;;
  esac
}

install_rust_macos() {
  install_rust
  if [[ -f "${HOME}/.cargo/env" ]]; then
    append_once '. "$HOME/.cargo/env"' "${HOME}/.bashrc"
    append_once '. "$HOME/.cargo/env"' "${HOME}/.zshrc"
    append_once '. "$HOME/.cargo/env"' "${HOME}/.zprofile"
  fi
}

main() {
  local components filtered c
  local check_only=0
  local include_base=1
  components=()
  filtered=()

  _rerun_as_user_if_sudo "$@"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -l|--list)
        list_components
        exit 0
        ;;
      -c|--check)
        check_only=1
        shift
        ;;
      --no-base)
        include_base=0
        shift
        ;;
      all)
        components=("${ALL_COMPONENTS[@]}")
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        components+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${check_only}" -eq 1 ]]; then
    check_versions
    exit 0
  fi

  if [[ ${#components[@]} -eq 0 ]]; then
    components=("${ALL_COMPONENTS[@]}")
  fi

  if [[ "${include_base}" -eq 0 ]]; then
    filtered=()
    for c in "${components[@]}"; do
      [[ "${c}" == "base" ]] && continue
      filtered+=("${c}")
    done
    if [[ ${#filtered[@]} -eq 0 ]]; then
      components=()
    else
      components=("${filtered[@]}")
    fi
  fi

  ensure_homebrew

  log_info "Architecture: $(uname -m) ($(macos_arch_label)); Homebrew $(macos_homebrew_prefix); release arch $(macos_release_arch)"
  if [[ ${#components[@]} -eq 0 ]]; then
    log_info "Components: none"
  else
    log_info "Components: ${components[*]}"
  fi
  echo

  if [[ ${#components[@]} -gt 0 ]]; then
    for c in "${components[@]}"; do
      echo "======== ${c} ========"
      run_component "${c}"
      echo
    done
  fi

  macos_link_shell_profiles
  log_ok "Done."
  echo
  check_versions
}

main "$@"
