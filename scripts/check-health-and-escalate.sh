#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${1:-http://127.0.0.1:3002/health}"
WINDOW_MIN="${WINDOW_MIN:-10}"
THRESHOLD="${THRESHOLD:-2}"
LOG_DIR="${LOG_DIR:-$(cd "$(dirname "$0")/.." && pwd)/logs}"
ALERT_LOG="$LOG_DIR/alerts.log"
ESC_LOG="$LOG_DIR/escalations.log"
STATE_DIR="${STATE_DIR:-$(cd "$(dirname "$0")/.." && pwd)/state}"
COOLDOWN_SEC="${COOLDOWN_SEC:-1800}"   # 30m default
QUIET_HOURS="${QUIET_HOURS:-22-07}"    # local time, inclusive start
LAST_NOTIFY_FILE="$STATE_DIR/last-escalation-notify.epoch"

mkdir -p "$LOG_DIR" "$STATE_DIR"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
NOW_EPOCH="$(date +%s)"
NOW_HOUR="$(date +%H)"
WINDOW_SEC=$(( WINDOW_MIN * 60 ))

in_quiet_hours() {
  local range="$1"
  local start end
  start="${range%-*}"
  end="${range#*-}"
  # normalize possible leading zeros
  start=$((10#$start))
  end=$((10#$end))
  local h=$((10#$NOW_HOUR))
  if (( start <= end )); then
    (( h >= start && h <= end ))
  else
    # overnight range like 22-07
    (( h >= start || h <= end ))
  fi
}

payload="$(curl -sS "$HEALTH_URL")"
status="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","unknown"))')"
dbw="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dbWritable","unknown"))')"
write_probe="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dbWriteProbe","unknown"))')"

if [[ "$status" != "healthy" || "$dbw" != "True" || "$write_probe" != "True" ]]; then
  echo "[$STAMP] ALERT keyfind_health status=$status dbWritable=$dbw dbWriteProbe=$write_probe url=$HEALTH_URL payload=$payload" | tee -a "$ALERT_LOG"
else
  echo "[$STAMP] OK keyfind_health status=$status dbWritable=$dbw dbWriteProbe=$write_probe url=$HEALTH_URL" | tee -a "$ALERT_LOG"
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

  notify_allowed=1
  notify_reason="allowed"

  if in_quiet_hours "$QUIET_HOURS"; then
    notify_allowed=0
    notify_reason="quiet_hours($QUIET_HOURS)"
  fi

  if [[ -f "$LAST_NOTIFY_FILE" ]]; then
    last_epoch="$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || echo 0)"
    last_epoch=$((last_epoch))
    age=$(( NOW_EPOCH - last_epoch ))
    if (( age >= 0 && age < COOLDOWN_SEC )); then
      notify_allowed=0
      notify_reason="cooldown(${age}s<${COOLDOWN_SEC}s)"
    fi
  fi

  if (( notify_allowed == 1 )); then
    echo "$NOW_EPOCH" > "$LAST_NOTIFY_FILE"
    echo "[$STAMP] NOTIFY keyfind_escalation channel=call reason=$notify_reason" | tee -a "$ESC_LOG"
  else
    echo "[$STAMP] SUPPRESS keyfind_escalation reason=$notify_reason" | tee -a "$ESC_LOG"
  fi

  exit 2
fi

echo "[$STAMP] OK keyfind_escalation alerts=$count window_min=$WINDOW_MIN threshold=$THRESHOLD" | tee -a "$ESC_LOG"
