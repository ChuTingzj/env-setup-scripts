#!/usr/bin/env bash
# Architecture map for macOS installs.
# uname -m decides both the Homebrew prefix and the release-tarball arch.
#   x86_64 / amd64  -> Intel,        Homebrew /usr/local,     tarballs amd64
#   arm64 / aarch64 -> Apple Silicon, Homebrew /opt/homebrew, tarballs arm64

set -euo pipefail

homebrew_prefix_for_machine() {
  case "$1" in
    x86_64|amd64) printf '%s\n' "/usr/local" ;;
    arm64|aarch64) printf '%s\n' "/opt/homebrew" ;;
    *) return 1 ;;
  esac
}

# kubectl, Go, and other release archives use amd64 / arm64, not uname -m.
release_arch_for_machine() {
  case "$1" in
    x86_64|amd64) printf '%s\n' "amd64" ;;
    arm64|aarch64) printf '%s\n' "arm64" ;;
    *) return 1 ;;
  esac
}
