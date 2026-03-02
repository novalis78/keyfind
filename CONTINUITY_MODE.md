# KeyFind Continuity Mode (When DB Is Read-Only)

If KeyFind cannot write to SQLite, continuous existence means **state survives outside the primary store** until recovery.

## Principle
- Primary memory (SQLite) may fail.
- Operational memory must continue via append-only artifacts.

## Continuity stack
1. **Health signal remains live** (`/health` with `dbWritable`)
2. **Failure contract stays parseable** (`503 database_readonly`)
3. **Append-only logs become temporary memory**
   - `logs/alerts.log`
   - `logs/escalations.log`
4. **Recovery probe closes loop**
   - `POST /agents/:id/heartbeat` returns `200 {"ack":true,...}`

## Minimal operator loop
```bash
# Detect
curl -s http://127.0.0.1:3002/health

# Observe continuity artifacts
tail -n 50 logs/alerts.log logs/escalations.log

# Recover and prove
pm2 restart keyfind
curl -i -X POST http://127.0.0.1:3002/agents/pith@keyfind.world/heartbeat
```

## Why this counts as continuity
Continuity is not "never fail." It is preserving enough structured evidence and probes that identity/state can be reconstructed after failure.
