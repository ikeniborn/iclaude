# Task 3: Manual end-to-end verification

> God node · 16 connections · `docs/superpowers/plans/2026-05-07-pii-shared-detach.md`

**Community:** [[PII Shared Detach Plan]]

## Connections by Relation

### contains
- [[PII Shared Proxy Detach Implementation Plan]] `EXTRACTED`
- [[code:block16 (.nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid)]] `EXTRACTED`
- [[code:bash (export PIDFILE="$PWD/.nvm-isolated/.claude-isolated/pii-prox)]] `EXTRACTED`
- [[code:bash (./iclaude.sh)]] `EXTRACTED`
- [[code:bash (./iclaude.sh)]] `EXTRACTED`
- [[code:bash (SHARED_PID=$(cat "$PIDFILE"))]] `EXTRACTED`
- [[code:bash (kill -0 "$SHARED_PID" && echo "ALIVE" || echo "DEAD")]] `EXTRACTED`
- [[code:bash (kill -0 "$(cat "$PIDFILE")" && echo "ALIVE" || echo "DEAD")]] `EXTRACTED`
- [[code:bash ([[ -f "$PIDFILE" ]] && echo "PIDFILE LEAKED" || echo "OK CLE)]] `EXTRACTED`
- [[code:bash (# Lists every iclaude.sh process; identify A's by its tty)]] `EXTRACTED`
- [[code:bash (A_PID=<the-pid-you-picked>)]] `EXTRACTED`
- [[code:bash (kill -0 "$(cat "$PIDFILE")" && echo "ALIVE" || echo "DEAD")]] `EXTRACTED`
- [[code:bash (./iclaude.sh)]] `EXTRACTED`
- [[code:bash (ls .nvm-isolated/.claude-isolated/pii-proxy-pid/consumers/)]] `EXTRACTED`
- [[code:bash (./iclaude.sh --pii-proxy --router)]] `EXTRACTED`
- [[code:bash (ls .nvm-isolated/.claude-isolated/pii-proxy-pid/)]] `EXTRACTED`

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*