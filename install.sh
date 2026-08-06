#!/usr/bin/env bash
# Linux developer environment bootstrap
# Supports Debian/Ubuntu (apt) and RHEL/CentOS/Fedora (yum/dnf)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

# shellcheck source=scripts/common.sh
source "${SCRIPTS_DIR}/common.sh"
# shellcheck source=scripts/install_base.sh
source "${SCRIPTS_DIR}/install_base.sh"
# shellcheck source=scripts/install_git.sh
source "${SCRIPTS_DIR}/install_git.sh"
# shellcheck source=scripts/install_java.sh
source "${SCRIPTS_DIR}/install_java.sh"
# shellcheck source=scripts/install_docker.sh
source "${SCRIPTS_DIR}/install_docker.sh"
# shellcheck source=scripts/install_uv.sh
source "${SCRIPTS_DIR}/install_uv.sh"
# shellcheck source=scripts/install_nodejs.sh
source "${SCRIPTS_DIR}/install_nodejs.sh"
# shellcheck source=scripts/install_go.sh
source "${SCRIPTS_DIR}/install_go.sh"
# shellcheck source=scripts/install_rust.sh
source "${SCRIPTS_DIR}/install_rust.sh"
# shellcheck source=scripts/install_kubectl.sh
source "${SCRIPTS_DIR}/install_kubectl.sh"
# shellcheck source=scripts/install_maven.sh
source "${SCRIPTS_DIR}/install_maven.sh"

ALL_COMPONENTS=(base git java docker uv nodejs go rust kubectl maven)

# Components that support non-root install
NON_ROOT_COMPONENTS=(uv rust)

usage() {
  cat <<EOF
Usage: sudo $0 [OPTIONS] [COMPONENTS...]

Install common developer tools on Linux (apt / yum / dnf).

Components:
  base      curl wget build tools vim jq htop ...
  git       Git
  java      OpenJDK (JAVA_VERSION=${JAVA_VERSION:-17})
  docker    Docker Engine + Compose plugin
  uv        Astral uv (Python package/tooling)
  nodejs    Node.js LTS (NODE_MAJOR=${NODE_MAJOR:-20})
  go        Go toolchain (GO_VERSION=latest if unset)
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
  sudo $0                      # install all
  sudo $0 git java go maven    # install selected
  sudo JAVA_VERSION=21 $0 java
  sudo GO_VERSION=1.24.5 $0 go
  sudo MAVEN_VERSION=3.9.9 $0 maven
  $0 --check

EOF
}

list_components() {
  printf '%s\n' "${ALL_COMPONENTS[@]}"
}

check_versions() {
  log_info "Package manager: ${PKG_MANAGER}"
  log_info "Architecture:    $(uname -m)"
  echo
  print_version "git" git --version
  print_version "java" java -version
  print_version "docker" docker --version
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    print_version "compose" docker compose version
  fi
  print_version "uv" uv --version
  print_version "node" node --version
  print_version "npm" npm --version
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
    docker)  install_docker ;;
    uv)      install_uv ;;
    nodejs)  install_nodejs ;;
    go)      install_go ;;
    rust)    install_rust ;;
    kubectl) install_kubectl ;;
    maven)   install_maven ;;
    *)
      log_error "Unknown component: $1"
      usage
      exit 1
      ;;
  esac
}

main() {
  local components=()
  local check_only=0
  local include_base=1

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

  # uv / rust may be installed without root; others need root.
  local needs_root=0
  for c in "${components[@]}"; do
    local allowed=0
    for nr in "${NON_ROOT_COMPONENTS[@]}"; do
      [[ "${c}" == "${nr}" ]] && allowed=1 && break
    done
    if [[ "${allowed}" -eq 0 ]]; then
      needs_root=1
      break
    fi
  done
  if [[ "${needs_root}" -eq 1 ]]; then
    require_root
  fi

  if [[ "${include_base}" -eq 0 ]]; then
    local filtered=()
    for c in "${components[@]}"; do
      [[ "${c}" == "base" ]] && continue
      filtered+=("${c}")
    done
    components=("${filtered[@]}")
  fi

  log_info "Target OS: $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" || echo unknown)"
  log_info "Package manager: ${PKG_MANAGER}"
  log_info "Components: ${components[*]}"
  echo

  for c in "${components[@]}"; do
    echo "======== ${c} ========"
    run_component "${c}"
    echo
  done

  log_ok "Done."
  echo
  check_versions
}

main "$@"
