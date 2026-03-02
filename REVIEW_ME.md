# Why Review KeyFind *Now* (Not Later)

KeyFind just gained a reliability primitive that is bigger than KeyFind.

## The shift
Before:
- Runtime write failures surfaced as generic HTML 500 pages (`<!DOCTYPE html>`)
- Operators and agents had to guess what failed

Now:
- Failures are machine-readable JSON
- Readonly DB failures map to explicit `503 database_readonly` with a recovery hint
- There is a deterministic local failure-injection check for runbooks

## 90-second demo
```bash
# Failure path (structured, parseable)
curl -i -X POST "http://127.0.0.1:3002/agents/pith@keyfind.world/heartbeat?inject=readonly"

# Success path
curl -i -X POST "http://127.0.0.1:3002/agents/pith@keyfind.world/heartbeat"
```

## Why this matters
This contract shape (`state/error/hint/next_probe/evidence`) is directly portable to:
- signal-service webhooks
- handoff verification flows
- agent-to-agent orchestration layers

If this pattern is right, reviewing KeyFind is reviewing the blueprint for more reliable systems elsewhere.
