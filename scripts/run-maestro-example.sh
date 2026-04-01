#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EXAMPLE_APP_DIR="$ROOT_DIR/example-app"
HOST="${MAESTRO_HOST:-127.0.0.1}"
PORT="${MAESTRO_PORT:-4173}"
URL="http://$HOST:$PORT"
LOG_FILE="${TMPDIR:-/tmp}/capgo-widget-kit-maestro-preview.log"

cleanup() {
  if [ "${SERVER_PID:-}" != "" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "$EXAMPLE_APP_DIR"
bun run build >/dev/null
bun run preview -- --host "$HOST" --port "$PORT" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

attempt=0
until curl -fsS "$URL" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "Preview server did not become ready at $URL" >&2
    echo "Preview server log:" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
  sleep 1
done

cd "$ROOT_DIR"
maestro test --headless .maestro/example-app-web.yaml
