#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME="$ROOT/data/home"

CONFIG_DIR="$ROOT/config"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

DATA_DIR="$ROOT/data"
PROJECTS_DIR="$ROOT/projects"

make_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 18
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_hex(18))
PY
  else
    echo "change-this-password"
  fi
}

mkdir -p \
  "$HOME" \
  "$CONFIG_DIR" \
  "$DATA_DIR/user-data" \
  "$DATA_DIR/extensions" \
  "$DATA_DIR/xdg-config" \
  "$DATA_DIR/xdg-data" \
  "$DATA_DIR/xdg-cache" \
  "$DATA_DIR/tmp" \
  "$PROJECTS_DIR"

chmod 700 "$CONFIG_DIR" "$DATA_DIR" || true

if [ ! -f "$CONFIG_FILE" ]; then
  PASSWORD="$(make_password)"

  cat > "$CONFIG_FILE" <<EOF_CONFIG
# For Docker, bind to 0.0.0.0 so Docker port publishing can reach it.
# Example:
# docker run -p 127.0.0.1:8080:8080 ...
bind-addr: 0.0.0.0:8080
auth: password
password: $PASSWORD
cert: false
disable-telemetry: true
EOF_CONFIG

  chmod 600 "$CONFIG_FILE"

  echo "Created config: $CONFIG_FILE"
  echo "Generated password: $PASSWORD"
else
  echo "Config already exists: $CONFIG_FILE"
fi

echo "Portable folders are ready under: $ROOT"
