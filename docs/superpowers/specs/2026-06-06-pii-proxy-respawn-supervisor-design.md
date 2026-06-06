# PII Proxy Respawn Supervisor — Design

**Date:** 2026-06-06
**Status:** Approved (design)
**Topic:** Eliminate `API Error: Unable to connect to API (ConnectionRefused)` caused by the PII proxy process disappearing mid-session.

## Problem

A running Claude Code session bakes `ANTHROPIC_BASE_URL=http://127.0.0.1:<port>` once at launch
(`lib/launcher/launch.sh:1066`) and never updates it. With `PII_PROXY_PORT=0` the proxy binds a
**random** port each start. If the PII proxy process disappears mid-session, there is no recovery:
the baked URL points at a dead port and every subsequent API call fails with
`Unable to connect to API (ConnectionRefused)`. Nothing restarts the proxy on the same port inside
a live session.

The proxy can disappear for several reasons — this is a **class** of failure, not a single bug:

1. **OOM / external kill.** A memory-heavy process the model waits on triggers the OS OOM killer,
   which reaps the lightweight Python proxy (~40 MB in `secrets` mode). Most likely trigger for the
   reported "especially during long waits" symptom.
2. **SID-collision in consumer accounting.** A same-`ICLAUDE_SESSION_ID` sub-invocation of
   `iclaude.sh` (e.g. a Bash tool call inside the session) enters the shared-proxy path, overwrites
   `consumers/${SID}.pid` with its own `$$`, and on exit its `EXIT` trap removes that file and — when
   the consumer count reaches 0 — kills the shared proxy out from under the live session
   (`lib/launcher/launch.sh:1325-1336`). The consumer registry is keyed by SID, but a SID is shared
   by multiple processes.
3. **Crash / connection-handling fault.** Rarer, same outcome.

The recently added upstream timeout work is **not** the cause. `ConnectionRefused` (Errno 111) means
nothing is listening on the target port; a timeout produces `ReadTimeout` → HTTP 502 instead
(`server.py:1023`, `1030`) — a different code path. The timeout change merely coincided in time. The
old 30 s scalar timeout returned 502 on long generations, which the Claude SDK retried and
"self-healed"; the 900 s read timeout correctly holds long requests but is unrelated to refused
connections.

## Goals

- A Claude session survives the PII proxy process dying: the proxy is respawned on the **same port**
  before (or shortly after) the next request, so the baked `ANTHROPIC_BASE_URL` stays valid.
- Same-SID sub-invocations cannot kill the shared proxy a live session depends on.

## Non-goals (YAGNI)

- No HTTP-health-based respawn — only process death is detected.
- No recovery of a hung-but-alive worker.
- No external (bash) watchdog process.
- No change required to the `PII_PROXY_PORT=0` config — port stability comes from the supervisor.

## Design

### Part A — Supervisor mode in `server.py` (fork-respawn, owns the socket)

A self-contained supervisor inside `server.py`. One process, no new state files, no flock
coordination.

```
supervisor  (PID == shared.pid, stable for the proxy's lifetime):
  1. select a free port ONCE and bind() the listening socket
        ← the port-selection logic currently in main() moves here
  2. write the port file ONCE (pii-proxy-<sid>.port)
  3. install SIGTERM/SIGINT handler → forward to worker, then exit (NO respawn)
  loop:
    pid = os.fork()
      child  : ThreadingHTTPServer(addr, Handler, bind_and_activate=False)
               httpd.socket = <inherited bound socket>   # same fd, same port
               serve_forever()
      parent : os.waitpid(pid)
               if SIGTERM was received        -> break          (intentional stop)
               if worker exited (OOM/crash)   -> respawn on the SAME socket
               apply backoff; if > N restarts within T seconds -> log + exit
  cleanup: unlink port file
```

**Why `os.fork` with an inherited bound socket:** the port is guaranteed identical across respawns —
no rebind, no `TIME_WAIT` race, no port change. The supervisor PID is stable, so `launch.sh` tracks a
single PID for the proxy's whole life.

**Worker construction:** build `ThreadingHTTPServer` with `bind_and_activate=False`, assign the
inherited socket to `httpd.socket`, then `serve_forever()`. Presidio (when `standard`) lazy-loads per
worker on respawn — acceptable because respawns are rare; in `secrets` mode no NLP is loaded at all.

**Enable flag:** env `PII_PROXY_SUPERVISE`, default `true`. When `false`, `main()` behaves as today
(single process binds and serves) — preserves the current path for debugging and as a fallback.

**Restart storm guard:** if the worker dies more than `N` times within `T` seconds (e.g. N=5, T=10),
the supervisor logs a clear error and exits rather than busy-looping. This surfaces a genuinely
unrecoverable failure (e.g. a config error that crashes the worker on startup) instead of spinning.

**Monitoring scope:** process death via `waitpid` only. This covers exactly the reported failure
(the process vanishing: OOM / kill / crash). A worker that is alive but wedged is out of scope.

### Part B — Consumer accounting (`lib/launcher/launch.sh`)

Two small changes that stop same-SID processes from cross-deleting each other's consumer
registration.

- **B1 — Early reuse guard on inherited env.** At the top of `start_pii_proxy_server`, if the parent
  already exported `ICLAUDE_PII_ACTIVE=1`, the sub-invocation inherits `ANTHROPIC_BASE_URL`, sets
  `PII_PROXY_SESSION_OWNED=false`, and returns **before** any shared-proxy accounting. The
  sub-invocation never touches the consumer registry, so it cannot trigger a teardown. This fixes the
  SID-collision at the root.

- **B2 — Key consumer files by PID, not SID.** `_register_pii_consumer` writes
  `consumers/$$.pid` (filename = PID) instead of `consumers/${ICLAUDE_SESSION_ID}.pid`.
  `stop_pii_proxy_server` removes only the current process's own file. Defense-in-depth: even if two
  processes share a SID, their consumer files no longer collide, and `_sweep_dead_pii_consumers`
  (which already sweeps by `kill -0`) keeps a live launcher's registration intact.

### Teardown interaction

`stop_pii_proxy_server` for the shared proxy kills `shared.pid` — now the **supervisor** PID. The
supervisor's SIGTERM handler forwards SIGTERM to the current worker, waits, and exits without
respawning. Both processes terminate cleanly; no respawn after an intentional stop.

## Affected files

| File | Change |
|------|--------|
| `lib/pii-proxy/server.py` | Add supervisor mode: move port selection + bind + port-file write + signal handling into the supervisor; worker serves on the inherited socket; backoff + restart-storm cap; `PII_PROXY_SUPERVISE` gate (default true) |
| `lib/launcher/launch.sh` | Start shared proxy via the supervisor (shared.pid = supervisor PID); B1 inherited-env reuse guard; B2 consumer files keyed by PID; teardown sends SIGTERM to supervisor |
| `.nvm-isolated/.claude-isolated/pii-proxy-server.py` | Keep in sync with `lib/pii-proxy/server.py` (deployed copy; currently identical) |
| `tests/` | New tests: respawn keeps same port; sub-invocation does not kill proxy; clean stop on SIGTERM; restart-storm cap |
| `docs/PII_MASKING.md`, `.claude_config.example` | Document `PII_PROXY_SUPERVISE` and respawn behavior |

## Success criteria (verifiable)

1. `kill -9` the serving worker → a new worker is listening on the **same** port within ≈3 s and a
   subsequent request succeeds. → test
2. A same-SID `iclaude.sh` sub-invocation followed by its exit leaves the shared proxy **alive**.
   → test
3. `stop_pii_proxy_server` terminates both supervisor and worker, and **no** respawn occurs.
   → test
4. Worker crashing on startup repeatedly hits the storm cap and the supervisor exits with a clear log
   line (no busy loop). → test
5. `bash -n iclaude.sh` passes and the existing `tests/` PII suite stays green.

## Risks / edge cases

- **`os.fork` + threads:** the worker is forked *before* `serve_forever`, fresh each cycle, so no
  thread state is inherited across forks. Linux-only (the project's target platform).
- **`SO_REUSEADDR`:** not needed for the inherited-socket path (the socket is never closed/rebound),
  but `ThreadingHTTPServer.allow_reuse_address` is already true, which keeps the
  `PII_PROXY_SUPERVISE=false` fallback path working.
- **port-file ownership:** only the supervisor writes/removes the port file, eliminating any
  worker-vs-worker race on it.
- **deployed copy drift:** `server.py` exists in both `lib/` and `.nvm-isolated/`; both must be
  updated together (they are currently byte-identical).
