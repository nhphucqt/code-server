#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CODE_SERVER_DIR="$ROOT/code-server"
CODE_SERVER_BIN="$CODE_SERVER_DIR/bin/code-server"

DATA_DIR="$ROOT/data"
TMP_DIR="$DATA_DIR/tmp"
LATEST_JSON="$TMP_DIR/code-server-latest.json"

mkdir -p "$TMP_DIR"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      echo "This script expects a Linux code-server standalone release." >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

fetch_latest_json() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/coder/code-server/releases/latest" \
    -o "$LATEST_JSON"
}

latest_version_from_json() {
  python3 - "$LATEST_JSON" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
tag = data["tag_name"]
print(tag[1:] if tag.startswith("v") else tag)
PY
}

asset_url_from_json() {
  local version="$1"
  local os_name="$2"
  local arch="$3"

  python3 - "$LATEST_JSON" "$version" "$os_name" "$arch" <<'PY'
import json, sys

path, version, os_name, arch = sys.argv[1:5]
wanted = f"code-server-{version}-{os_name}-{arch}.tar.gz"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

assets = data.get("assets", [])

for asset in assets:
    if asset.get("name") == wanted:
        print(asset["browser_download_url"])
        raise SystemExit(0)

suffix = f"-{os_name}-{arch}.tar.gz"
for asset in assets:
    name = asset.get("name", "")
    if name.startswith("code-server-") and name.endswith(suffix):
        print(asset["browser_download_url"])
        raise SystemExit(0)

print(f"No matching asset found for {os_name}-{arch}.", file=sys.stderr)
print("Available assets:", file=sys.stderr)
for asset in assets:
    print("  " + asset.get("name", ""), file=sys.stderr)

raise SystemExit(1)
PY
}

current_version() {
  if [ -x "$CODE_SERVER_BIN" ]; then
    "$CODE_SERVER_BIN" --version | head -n 1 | awk '{print $1}' | sed 's/^v//'
  else
    return 1
  fi
}

download_and_install() {
  local version="$1"
  local url="$2"
  local os_name="$3"
  local arch="$4"

  local workdir
  workdir="$(mktemp -d "$TMP_DIR/code-server-install.XXXXXX")"

  local tarball="$workdir/code-server-$version-$os_name-$arch.tar.gz"

  echo "Downloading code-server v$version for $os_name-$arch..."
  curl -fL --progress-bar -o "$tarball" "$url"

  echo "Extracting..."
  tar -xzf "$tarball" -C "$workdir"

  # Remove downloaded archive after extraction.
  rm -f "$tarball"

  local extracted
  extracted="$(find "$workdir" -mindepth 1 -maxdepth 1 -type d -name 'code-server*' | head -n 1)"

  if [ -z "$extracted" ] || [ ! -x "$extracted/bin/code-server" ]; then
    echo "Install failed: extracted code-server binary not found." >&2
    rm -rf "$workdir"
    exit 1
  fi

  local backup=""
  if [ -e "$CODE_SERVER_DIR" ]; then
    backup="$ROOT/code-server.backup.$(date +%s)"
    mv "$CODE_SERVER_DIR" "$backup"
  fi

  if mv "$extracted" "$CODE_SERVER_DIR"; then
    rm -rf "$backup" "$workdir"
    echo "Installed code-server v$version at: $CODE_SERVER_DIR"
  else
    echo "Install failed while moving into place." >&2
    if [ -n "$backup" ] && [ -e "$backup" ]; then
      mv "$backup" "$CODE_SERVER_DIR"
      echo "Restored previous code-server." >&2
    fi
    rm -rf "$workdir"
    exit 1
  fi
}

main() {
  need_cmd curl
  need_cmd tar
  need_cmd python3
  need_cmd uname
  need_cmd awk
  need_cmd sed
  need_cmd find
  need_cmd mktemp

  local os_name
  local arch
  os_name="$(detect_os)"
  arch="$(detect_arch)"

  if ! fetch_latest_json; then
    if [ -x "$CODE_SERVER_BIN" ]; then
      echo "Could not check GitHub for updates; continuing with installed code-server."
      exit 0
    fi

    echo "code-server is missing and GitHub release check failed." >&2
    exit 1
  fi

  local latest
  local url
  latest="$(latest_version_from_json)"
  url="$(asset_url_from_json "$latest" "$os_name" "$arch")"

  if [ ! -x "$CODE_SERVER_BIN" ]; then
    echo "code-server not found at: $CODE_SERVER_BIN"
    download_and_install "$latest" "$url" "$os_name" "$arch"
    exit 0
  fi

  if [ "${CODE_SERVER_SKIP_UPDATE_CHECK:-0}" = "1" ]; then
    exit 0
  fi

  local current
  current="$(current_version || echo unknown)"

  if [ "$current" = "$latest" ]; then
    exit 0
  fi

  echo "Update available: code-server $current -> $latest"

  if [ "${CODE_SERVER_AUTO_UPDATE:-0}" = "1" ]; then
    download_and_install "$latest" "$url" "$os_name" "$arch"
    exit 0
  fi

  if [ -t 0 ]; then
    printf "Update code-server now? [y/N] "
    read -r answer || answer=""

    case "$answer" in
      y | Y | yes | YES)
        download_and_install "$latest" "$url" "$os_name" "$arch"
        ;;
      *)
        echo "Skipping update."
        ;;
    esac
  else
    echo "Non-interactive shell detected; skipping update by default."
  fi
}

main "$@"
