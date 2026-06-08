#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME="$ROOT/data/home"

CODE_SERVER_BIN="$ROOT/code-server/bin/code-server"

CONFIG_FILE="$ROOT/config/config.yaml"
DATA_DIR="$ROOT/data"
PROJECTS_DIR="$ROOT/projects"

# Prepare folders/config.
bash "$ROOT/setup-folders.sh"

# Download code-server if missing, and check for update.
bash "$ROOT/install-or-update-code-server.sh"

export HOME="$HOME"
export XDG_CONFIG_HOME="$DATA_DIR/xdg-config"
export XDG_DATA_HOME="$DATA_DIR/xdg-data"
export XDG_CACHE_HOME="$DATA_DIR/xdg-cache"
export TMPDIR="$DATA_DIR/tmp"

unset VSCODE_IPC_HOOK_CLI
unset VSCODE_PID
unset VSCODE_CWD

if [ "$#" -eq 0 ]; then
  set -- "$PROJECTS_DIR"
fi

exec "$CODE_SERVER_BIN" \
  --config "$CONFIG_FILE" \
  --user-data-dir "$DATA_DIR/user-data" \
  --extensions-dir "$DATA_DIR/extensions" \
  "$@"
