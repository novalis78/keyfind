#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${1:-http://127.0.0.1:3002/health}"
WINDOW_MIN="${WINDOW_MIN:-10}"
THRESHOLD="${THRESHOLD:-2}"
LOG_DIR="${LOG_DIR:-$(cd "$(dirname "$0")/.." && pwd)/logs}"
ALERT_LOG="$LOG_DIR/alerts.log"
ESC_LOG="$LOG_DIR/escalations.log"

mkdir -p "$LOG_DIR"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
NOW_EPOCH="$(date +%s)"
WINDOW_SEC=$(( WINDOW_MIN * 60 ))

payload="$(curl -sS "$HEALTH_URL")"
status="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","unknown"))')"
dbw="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dbWritable","unknown"))')"

if [[ "$status" != "healthy" || "$dbw" != "True" ]]; then
  echo "[$STAMP] ALERT keyfind_health status=$status dbWritable=$dbw url=$HEALTH_URL payload=$payload" | tee -a "$ALERT_LOG"
else
  echo "[$STAMP] OK keyfind_health status=$status dbWritable=$dbw url=$HEALTH_URL" | tee -a "$ALERT_LOG"
fi

count=0
while IFS= read -r line; do
  [[ "$line" == *"ALERT keyfind_health"* ]] || continue
  ts="$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
  [[ -n "$ts" ]] || continue
  ts_epoch="$(date -d "$ts" +%s 2>/dev/null || true)"
  [[ -n "$ts_epoch" ]] || continue
  age=$(( NOW_EPOCH - ts_epoch ))
  if (( age >= 0 && age <= WINDOW_SEC )); then
    count=$((count + 1))
  fi
done < "$ALERT_LOG"

if (( count >= THRESHOLD )); then
  echo "[$STAMP] ESCALATE keyfind_escalation alerts=$count window_min=$WINDOW_MIN threshold=$THRESHOLD action=operator_notification_intent" | tee -a "$ESC_LOG"
  exit 2
fi

echo "[$STAMP] OK keyfind_escalation alerts=$count window_min=$WINDOW_MIN threshold=$THRESHOLD" | tee -a "$ESC_LOG"
