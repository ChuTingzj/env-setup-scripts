# env-setup-scripts

One command installs the developer toolchain on Linux or macOS:

```bash
./install.sh
```

On Linux, `install.sh` uses apt, dnf, or yum. On macOS it runs `install-macos.sh` for the chip reported by `uname -m`.

| Chip | `uname -m` | Homebrew | Release binaries |
| --- | --- | --- | --- |
| Intel | `x86_64` | `/usr/local` | `amd64` |
| Apple Silicon | `arm64` | `/opt/homebrew` | `arm64` |

A Rosetta shell reports `x86_64` and gets the Intel Homebrew prefix.

Languages use the same managers on both operating systems:

- Node.js: Volta (`NODE_MAJOR`, default 20)
- Java: a JDK (`JAVA_VERSION`, default 17), then `jenv add` and `jenv global`
- Go: gvm binary install (`GO_VERSION`, otherwise the latest stable release, otherwise 1.24.5)
- Rust: rustup
- Python: `python3` and uv, with no Python version manager

```bash
./install.sh --help
./install.sh git java go maven
JAVA_VERSION=21 ./install.sh java
NODE_MAJOR=22 ./install.sh nodejs
GO_VERSION=1.24.5 ./install.sh go
./install.sh --check
```

Tools that are already on `PATH` are left in place. macOS does not need `sudo`; Homebrew refuses to run as root.
