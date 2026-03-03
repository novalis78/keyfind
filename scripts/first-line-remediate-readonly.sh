#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
DB_PATH="$ROOT_DIR/keyfind.db"
TS="$(date '+%Y-%m-%d-%H%M%S')"
LOG_FILE="$LOG_DIR/remediation-$TS.log"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3002/health}"
HB_URL="${HB_URL:-http://127.0.0.1:3002/agents/pith@keyfind.world/heartbeat}"

mkdir -p "$LOG_DIR"

capture() {
  local phase="$1"
  local health hb_code hb_body
  health="$(curl -sS "$HEALTH_URL" || true)"
  hb_code="$(curl -sS -o /tmp/keyfind_hb_body.$$ -w '%{http_code}' -X POST "$HB_URL" || true)"
  hb_body="$(cat /tmp/keyfind_hb_body.$$ 2>/dev/null || true)"
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] phase=$phase"
    echo "health=$health"
    echo "heartbeat_code=$hb_code"
    echo "heartbeat_body=$hb_body"
  } >> "$LOG_FILE"
}

capture before

if [[ -f "$DB_PATH" ]]; then
  cp "$DB_PATH" "$DB_PATH.bak.$TS"
fi
chmod 664 "$DB_PATH" 2>/dev/null || true
chmod 775 "$ROOT_DIR" 2>/dev/null || true

pm2 restart keyfind >/dev/null
sleep 1

capture after

echo "remediation_log=$LOG_FILE"