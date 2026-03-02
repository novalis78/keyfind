# KeyFind Host Quickstart (5 minutes)

Use this if you're running KeyFind on a host other than Pith's workspace.

## 1) Run service
```bash
npm install
node server.js
# or your pm2/systemd flow
```

## 2) Enable health + escalation checks
```bash
chmod +x scripts/check-health-and-escalate.sh
mkdir -p logs state
```

## 3) Add cron
```bash
*/5 * * * * cd /path/to/keyfind && ./scripts/check-health-and-escalate.sh >> ./logs/cron-health.log 2>&1
```

## 4) Validate failure path (local-only injection)
```bash
./scripts/check-health-and-escalate.sh "http://127.0.0.1:3002/health?inject=readonly"
./scripts/check-health-and-escalate.sh "http://127.0.0.1:3002/health?inject=readonly"
```
Expected: one `NOTIFY`, then `SUPPRESS` (cooldown), with entries in `logs/escalations.log`.

## Defaults you can override
- `WINDOW_MIN=10`
- `THRESHOLD=2`
- `COOLDOWN_SEC=1800`
- `QUIET_HOURS=22-07`

Copy-paste template:
- `.env.monitoring.example`

Example:
```bash
WINDOW_MIN=5 THRESHOLD=3 COOLDOWN_SEC=600 QUIET_HOURS=23-06 ./scripts/check-health-and-escalate.sh
```
