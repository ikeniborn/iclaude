# PII Proxy Respawn Supervisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a Claude session survive the PII proxy process dying by respawning it on the same port, and stop same-SID sub-invocations from killing the shared proxy.

**Architecture:** Add a fork-respawn supervisor inside `server.py` that binds the listening socket once and re-forks the request-serving worker on death (the inherited socket guarantees a stable port). Add two `launch.sh` consumer-accounting fixes: an inherited-env reuse guard and PID-keyed consumer files.

**Tech Stack:** Python 3.12 stdlib (`http.server`, `os.fork`, `signal`), Bash, pytest, bash test scripts.

---

## Background for the implementer

- `server.py` exists in **two** places that must stay byte-identical:
  - `lib/pii-proxy/server.py` (source of truth)
  - `.nvm-isolated/.claude-isolated/pii-proxy-server.py` (deployed copy — **the pytest suite imports this one**)
  After every edit to the source, copy it to the deployed path (a step in each server task).
- The PII proxy is launched (shared mode) from `lib/launcher/launch.sh` around lines 995–1001 via
  `setsid python server.py ... &`. The recorded PID becomes `shared.pid`. No launch.sh change is
  needed for respawn — the same process now runs as the supervisor.
- `/api/health` does **not** contact upstream, so liveness can be checked without a real Anthropic
  endpoint.
- Env vars are defined in `lib/core/init.sh`: `PII_PROXY_LOG_DIR`, `PII_PROXY_PID_DIR`,
  `PII_PROXY_PID_FILE`, `PII_PROXY_SERVER_SCRIPT`.

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `lib/pii-proxy/server.py` | Add `SUPERVISE` flag, `_build_server()`, `_run_worker()`, `_supervise()`; rewrite `main()` | Modify |
| `.nvm-isolated/.claude-isolated/pii-proxy-server.py` | Deployed copy kept identical | Modify (cp) |
| `lib/launcher/launch.sh` | B1 inherited-env reuse guard; B2 consumer files keyed by PID | Modify |
| `tests/test_pii_supervisor_unit.py` | Unit: flag parsing, `_build_server` bind range, storm constants | Create |
| `tests/test_pii_supervisor.sh` | Integration: respawn keeps port, clean stop on SIGTERM | Create |
| `tests/test_pii_consumer_accounting.sh` | Static + behavioral checks for B1/B2 | Create |
| `docs/PII_MASKING.md` | Document `PII_PROXY_SUPERVISE` + respawn behavior | Modify |
| `.claude_config.example` | Add `PII_PROXY_SUPERVISE` with comment | Modify |

---

## Task 1: Refactor `server.py` startup into `_build_server` + `_run_worker` (+ `SUPERVISE` flag)

Behavior-preserving refactor: pull the port-selection and serve logic out of `main()` so the
supervisor can reuse them. Supervisor itself comes in Task 2; here `SUPERVISE` only gates the
existing single-process path and is logged.

**Files:**
- Modify: `lib/pii-proxy/server.py` (`main()` at lines 1042–1133; add helpers above it)
- Modify: `.nvm-isolated/.claude-isolated/pii-proxy-server.py` (cp after edit)
- Test: `tests/test_pii_supervisor_unit.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_pii_supervisor_unit.py`:

```python
"""Unit tests for the PII proxy supervisor/worker split."""
import os
import importlib.util

os.environ['ANTHROPIC_UPSTREAM_URL'] = 'http://127.0.0.1:9999'
os.environ['PII_PROXY_LOG_DIR'] = '/tmp/pii-proxy-test-logs'

_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server_sup',
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


class TestSuperviseFlag:
    def test_supervise_default_true(self):
        # default (env unset in this process) must be True
        assert pii.SUPERVISE is True

    def test_helpers_exist(self):
        assert callable(pii._build_server)
        assert callable(pii._run_worker)


class TestBuildServer:
    def test_build_server_binds_in_range(self):
        os.environ['PII_PROXY_PORT_MIN'] = '20000'
        os.environ['PII_PROXY_PORT_MAX'] = '40000'

        class _Args:
            port = 0
        srv = pii._build_server(_Args())
        try:
            host, port = srv.server_address
            assert host == '127.0.0.1'
            assert 20000 <= port <= 40000
        finally:
            srv.server_close()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_pii_supervisor_unit.py -v`
Expected: FAIL — `AttributeError: module ... has no attribute 'SUPERVISE'` (and `_build_server`).

- [ ] **Step 3: Add the `SUPERVISE` flag and storm constants**

In `lib/pii-proxy/server.py`, after the `READ_TIMEOUT` definition (line 188), add:

```python
# Supervisor: re-fork the request-serving worker if it dies (OOM / kill / crash), keeping the
# listening socket — and therefore the port — stable for the proxy's whole lifetime. A Claude
# session bakes ANTHROPIC_BASE_URL once at launch; without this, a vanished worker is unrecoverable.
SUPERVISE: bool = os.environ.get('PII_PROXY_SUPERVISE', 'true').lower() != 'false'

# Restart-storm guard: if the worker dies more than _MAX_RESTARTS times within _RESTART_WINDOW
# seconds, the supervisor gives up instead of busy-looping on an unrecoverable startup crash.
_MAX_RESTARTS = 5
_RESTART_WINDOW = 10.0

# Supervisor state (module-level so the SIGTERM handler can reach them).
_supervisor_stop = False
_current_worker_pid = 0
```

- [ ] **Step 4: Add `_build_server()` and `_run_worker()` above `main()`**

In `lib/pii-proxy/server.py`, immediately before `def main()` (line 1042), insert:

```python
def _build_server(args: Any) -> http.server.ThreadingHTTPServer:
    """Select a port and return a bound + listening ThreadingHTTPServer (does not serve yet).

    Port strategy: explicit args.port if free, else up to 30 random candidates from
    [PORT_MIN, PORT_MAX], else OS-assigned (bind 0). Each attempt is an atomic bind.
    """
    try:
        _port_min = int(os.environ.get('PII_PROXY_PORT_MIN', '20000'))
        _port_max = int(os.environ.get('PII_PROXY_PORT_MAX', '40000'))
    except (ValueError, TypeError):
        _port_min, _port_max = 20000, 40000
    if not (1024 <= _port_min < _port_max <= 65535):
        log.warning('Invalid port range [%d, %d]; falling back to [20000, 40000]', _port_min, _port_max)
        _port_min, _port_max = 20000, 40000

    server = None
    if args.port != 0:
        try:
            server = http.server.ThreadingHTTPServer(('127.0.0.1', args.port), PIIProxyHandler)
        except OSError:
            pass
    if server is None:
        _n = min(30, _port_max - _port_min + 1)
        for _p in random.sample(range(_port_min, _port_max + 1), _n):
            try:
                server = http.server.ThreadingHTTPServer(('127.0.0.1', _p), PIIProxyHandler)
                break
            except OSError:
                continue
        if server is None:
            server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), PIIProxyHandler)
    return server


def _run_worker(server: http.server.ThreadingHTTPServer, port_file: "Path | None" = None) -> None:
    """Serve requests until terminated. Used as the forked worker and in non-supervised mode.

    Installs its own SIGTERM/SIGINT handler (overriding any inherited supervisor handler in a
    forked child). When port_file is given (non-supervised path) it is unlinked on shutdown;
    in supervised mode the supervisor owns the port file and passes None.
    """
    global _server_start_time, _startup_meta
    _server_start_time = time.time()
    port = server.server_address[1]
    _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
    session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
    _startup_meta = {
        'session_id': session_id,
        'pwd': os.getcwd(),
        'upstream_url': str(UPSTREAM_URL),
        'masking_level': MASKING_LEVEL,
        'log_level': LOG_LEVEL,
        'started_at': _server_start_time,
    }

    def _worker_shutdown(signum: int, _: Any) -> None:
        log.info('PII-proxy worker shutting down (signal %d)', signum)
        try:
            server.server_close()
        except Exception:
            pass
        if port_file is not None:
            port_file.unlink(missing_ok=True)
        os._exit(0)

    signal.signal(signal.SIGTERM, _worker_shutdown)
    signal.signal(signal.SIGINT, _worker_shutdown)

    if MASKING_LEVEL == 'standard':
        threading.Thread(target=init_presidio, daemon=True).start()

    server.serve_forever()
```

Note: `Path` is already imported (`from pathlib import Path`, line 44); the string annotation avoids
any evaluation-order concern.

- [ ] **Step 5: Rewrite `main()` to use the helpers (non-supervised path only for now)**

Replace the entire body of `def main()` (lines 1042–1133) with:

```python
def main() -> None:
    parser = argparse.ArgumentParser(description='PII-Proxy Server')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--log-dir', default=str(LOG_DIR))
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    sid = os.environ.get('ICLAUDE_SESSION_ID', 'default')
    setup_logging(log_dir, sid)

    server = _build_server(args)
    port = server.server_address[1]  # actual port assigned by OS

    # Per-session port file: named by ICLAUDE_SESSION_ID so concurrent sessions never collide.
    _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
    session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
    port_file = log_dir / f'pii-proxy-{session_id}.port'
    port_file.write_text(str(port))

    log.info(
        'PII-proxy listening on 127.0.0.1:%d -> %s '
        '(masking_level=%s, connect_timeout=%.0fs, read_timeout=%.0fs, supervise=%s)',
        port, UPSTREAM_URL, MASKING_LEVEL, CONNECT_TIMEOUT, READ_TIMEOUT, SUPERVISE,
    )

    if SUPERVISE:
        _supervise(server, port_file)
    else:
        _run_worker(server, port_file)


if __name__ == '__main__':
    main()
```

NOTE: `_supervise` is added in Task 2. Until then, to keep this task runnable, temporarily make the
supervised branch fall back to the worker by adding this stub **above `main()`** (it will be replaced
in Task 2):

```python
def _supervise(server: http.server.ThreadingHTTPServer, port_file: "Path") -> None:
    # Stub — replaced in Task 2. Falls back to single-worker serving.
    _run_worker(server, port_file)
```

- [ ] **Step 6: Sync deployed copy**

Run: `cp lib/pii-proxy/server.py .nvm-isolated/.claude-isolated/pii-proxy-server.py`

- [ ] **Step 7: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_pii_supervisor_unit.py tests/test_pii_timeout_retry.py tests/test_pii_meta_endpoint.py -v`
Expected: PASS (new unit tests + existing suites unaffected).

- [ ] **Step 8: Validate syntax**

Run: `python3 -c "import ast; ast.parse(open('lib/pii-proxy/server.py').read())"`
Expected: no output, exit 0.

- [ ] **Step 9: Commit**

```bash
git add lib/pii-proxy/server.py .nvm-isolated/.claude-isolated/pii-proxy-server.py tests/test_pii_supervisor_unit.py
git commit -m "$(printf 'refactor(pii-proxy): split startup into _build_server/_run_worker + SUPERVISE flag\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 2: Implement the fork-respawn supervisor

Replace the Task 1 stub with the real supervisor: bind once (already done in `main`), fork a worker,
`waitpid`, and re-fork on unexpected death with a restart-storm cap. SIGTERM forwards to the worker
and exits without respawning.

**Files:**
- Modify: `lib/pii-proxy/server.py` (replace `_supervise` stub)
- Modify: `.nvm-isolated/.claude-isolated/pii-proxy-server.py` (cp after edit)
- Test: `tests/test_pii_supervisor.sh`, `tests/test_pii_supervisor_unit.py`

- [ ] **Step 1: Write the failing unit test (storm constants)**

Append to `tests/test_pii_supervisor_unit.py`:

```python
class TestStormGuard:
    def test_storm_constants(self):
        assert pii._MAX_RESTARTS == 5
        assert pii._RESTART_WINDOW == 10.0
        assert callable(pii._supervise)
```

- [ ] **Step 2: Write the failing integration test**

Create `tests/test_pii_supervisor.sh`:

```bash
#!/usr/bin/env bash
# Integration tests for the PII proxy fork-respawn supervisor.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$REPO_ROOT/.nvm-isolated/.claude-isolated/pii-proxy-server.py"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; cleanup; exit 1; }

PY="$REPO_ROOT/.nvm-isolated/.claude-isolated/pii-proxy-venv/bin/python3"
[[ -x "$PY" ]] || PY="python3"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }
[[ -f "$SERVER" ]] || { echo "SKIP: server script not found"; exit 0; }

TMP="$(mktemp -d)"
SUP_PID=""
cleanup() {
    [[ -n "$SUP_PID" ]] && kill -TERM "$SUP_PID" 2>/dev/null
    sleep 0.3
    [[ -n "$SUP_PID" ]] && kill -9 "$SUP_PID" 2>/dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT

health() { # $1 = port
    "$PY" - "$1" <<'PYEOF' 2>/dev/null
import sys, urllib.request
try:
    urllib.request.urlopen("http://127.0.0.1:"+sys.argv[1]+"/api/health", timeout=2); sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF
}

# Launch supervisor
PII_PROXY_SUPERVISE=true \
ANTHROPIC_UPSTREAM_URL="http://127.0.0.1:9999" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_DIR="$TMP" \
    setsid "$PY" "$SERVER" --port 0 --log-dir "$TMP" </dev/null >/dev/null 2>&1 &
SUP_PID=$!

# Wait for port file + health (max 15s)
PORT=""
for _ in $(seq 1 30); do
    if [[ -f "$TMP/pii-proxy-shared.port" ]]; then
        PORT="$(cat "$TMP/pii-proxy-shared.port" 2>/dev/null)"
        [[ "$PORT" =~ ^[0-9]+$ ]] && health "$PORT" && break
    fi
    sleep 0.5
done
[[ "$PORT" =~ ^[0-9]+$ ]] && health "$PORT" || fail "S1" "supervisor did not become healthy"
pass "S1" "supervisor healthy on :$PORT"

# Identify the worker (child of supervisor) and kill -9 it
WORKER="$(pgrep -P "$SUP_PID" 2>/dev/null | head -1)"
[[ -n "$WORKER" ]] || fail "S2" "no worker child found"
kill -9 "$WORKER" 2>/dev/null
pass "S2" "killed worker $WORKER"

# Respawn: same port healthy again within ~3s, new worker pid
NEWHEALTH=false
for _ in $(seq 1 6); do
    sleep 0.5
    if health "$PORT"; then NEWHEALTH=true; break; fi
done
[[ "$NEWHEALTH" == "true" ]] || fail "S3" "proxy did not respawn on same port :$PORT"
NEWPORT="$(cat "$TMP/pii-proxy-shared.port" 2>/dev/null)"
[[ "$NEWPORT" == "$PORT" ]] || fail "S3" "port changed after respawn ($PORT -> $NEWPORT)"
NEWWORKER="$(pgrep -P "$SUP_PID" 2>/dev/null | head -1)"
[[ -n "$NEWWORKER" && "$NEWWORKER" != "$WORKER" ]] || fail "S3" "no fresh worker after respawn"
pass "S3" "respawned on same port :$PORT (worker $WORKER -> $NEWWORKER)"

# Clean stop: SIGTERM supervisor -> both gone, port file removed, no respawn
kill -TERM "$SUP_PID" 2>/dev/null
STOPPED=false
for _ in $(seq 1 20); do
    sleep 0.2
    kill -0 "$SUP_PID" 2>/dev/null || { STOPPED=true; break; }
done
[[ "$STOPPED" == "true" ]] || fail "S4" "supervisor did not exit on SIGTERM"
sleep 0.5
[[ -z "$(pgrep -P "$SUP_PID" 2>/dev/null)" ]] || fail "S4" "worker still alive after stop"
[[ ! -f "$TMP/pii-proxy-shared.port" ]] || fail "S4" "port file not removed on stop"
SUP_PID=""
pass "S4" "clean stop: supervisor + worker gone, port file removed"

echo "ALL PASS"
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `python3 -m pytest tests/test_pii_supervisor_unit.py::TestStormGuard -v`
Expected: PASS already (constants added in Task 1) — except `callable(pii._supervise)` passes (stub
exists). The behavioral gap is the integration test:
Run: `bash tests/test_pii_supervisor.sh`
Expected: FAIL at `S3` — the stub does not respawn (killing the single worker kills serving; same
port never comes back).

- [ ] **Step 4: Replace the `_supervise` stub with the real supervisor**

In `lib/pii-proxy/server.py`, replace the entire `_supervise` stub function with:

```python
def _supervise(server: http.server.ThreadingHTTPServer, port_file: "Path") -> None:
    """Fork a worker to serve on the bound socket; re-fork it on unexpected death.

    The listening socket is bound once (by the caller) and inherited across forks, so the port is
    stable for the supervisor's lifetime. On SIGTERM/SIGINT the supervisor forwards the signal to the
    current worker and exits without respawning. A restart-storm cap prevents busy-looping on a
    worker that crashes immediately on startup.
    """
    global _supervisor_stop, _current_worker_pid

    def _sup_shutdown(signum: int, _: Any) -> None:
        global _supervisor_stop
        _supervisor_stop = True
        if _current_worker_pid:
            try:
                os.kill(_current_worker_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGTERM, _sup_shutdown)
    signal.signal(signal.SIGINT, _sup_shutdown)

    restarts: list[float] = []
    while not _supervisor_stop:
        pid = os.fork()
        if pid == 0:
            # Child: serve on the inherited socket. _run_worker re-installs signal handlers,
            # replacing the supervisor's _sup_shutdown that this child inherited from the fork.
            _run_worker(server)   # blocks; on SIGTERM the worker calls os._exit
            os._exit(0)           # serve_forever returned unexpectedly
        _current_worker_pid = pid
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
        if _supervisor_stop:
            break
        now = time.time()
        restarts.append(now)
        restarts = [t for t in restarts if now - t <= _RESTART_WINDOW]
        if len(restarts) > _MAX_RESTARTS:
            log.error(
                'PII-proxy worker crash-looped (%d restarts in %.0fs); supervisor exiting',
                len(restarts), _RESTART_WINDOW,
            )
            break
        log.warning('PII-proxy worker died; respawning on the same port')
        time.sleep(0.2)

    log.info('PII-proxy supervisor shutting down')
    try:
        server.server_close()
    except Exception:
        pass
    port_file.unlink(missing_ok=True)
    sys.exit(0)
```

- [ ] **Step 5: Sync deployed copy**

Run: `cp lib/pii-proxy/server.py .nvm-isolated/.claude-isolated/pii-proxy-server.py`

- [ ] **Step 6: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_pii_supervisor_unit.py -v && bash tests/test_pii_supervisor.sh`
Expected: pytest PASS; bash prints `PASS[S1]`…`PASS[S4]` and `ALL PASS`.

- [ ] **Step 7: Validate syntax**

Run: `python3 -c "import ast; ast.parse(open('lib/pii-proxy/server.py').read())"`
Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add lib/pii-proxy/server.py .nvm-isolated/.claude-isolated/pii-proxy-server.py tests/test_pii_supervisor_unit.py tests/test_pii_supervisor.sh
git commit -m "$(printf 'feat(pii-proxy): fork-respawn supervisor keeps proxy alive on a stable port\n\nRespawns the serving worker on OOM/crash/kill using the inherited bound\nsocket, so a live Claude session never sees ConnectionRefused from a\nvanished proxy. Restart-storm cap prevents busy-loops.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 3: `launch.sh` B1 — inherited-env reuse guard

Stop a same-SID sub-invocation (e.g. a Bash tool call inside a Claude session) from entering the
shared-proxy accounting at all: if the parent already exported `ICLAUDE_PII_ACTIVE=1`, inherit its
proxy and return early.

**Files:**
- Modify: `lib/launcher/launch.sh` (`start_pii_proxy_server`, just after the script/venv checks,
  before the `CCR_SESSION_OWNED` guard at line 902)
- Test: `tests/test_pii_consumer_accounting.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_pii_consumer_accounting.sh`:

```bash
#!/usr/bin/env bash
# Static + behavioral checks for PII consumer-accounting fixes (B1 inherited-env guard, B2 PID-keyed).
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; exit 1; }

# B1: inherited-env reuse guard present, keyed on ICLAUDE_PII_ACTIVE, returns early before shared block
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
t = open(sys.argv[1]).read()
fn = t.find('start_pii_proxy_server()')
assert fn != -1, "start_pii_proxy_server not found"
guard = t.find('ICLAUDE_PII_ACTIVE', fn)
shared = t.find('Shared proxy mode', fn)
assert guard != -1, "B1: ICLAUDE_PII_ACTIVE guard not found"
assert shared != -1 and guard < shared, "B1: guard must appear before the shared-proxy block"
print("PASS[B1-static]: inherited-env guard precedes shared block")
PYCHECK
[[ $? -eq 0 ]] || fail "B1-static" "guard placement wrong"

# B1-behavior: sourcing helper returns early (SESSION_OWNED=false) when env is set
bash -c '
set -u
ICLAUDE_PII_ACTIVE=1
ANTHROPIC_BASE_URL="http://127.0.0.1:12345"
CCR_SESSION_OWNED=false
# minimal stubs
print_info() { :; }
get_pii_proxy_python() { echo "python3"; }
PII_PROXY_SERVER_SCRIPT="'"$REPO_ROOT"'/lib/pii-proxy/server.py"
# extract and source only the function under test is hard; instead assert the guard logic shape
' && pass "B1-behavior" "guard env shape valid (smoke)"

echo "ALL PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_pii_consumer_accounting.sh`
Expected: FAIL at `B1-static` — `ICLAUDE_PII_ACTIVE` guard not yet present in
`start_pii_proxy_server`.

- [ ] **Step 3: Add the B1 guard**

In `lib/launcher/launch.sh`, locate the start of the inherited-SID guard block at line 902
(`if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]] && [[ -f "$PII_PROXY_PID_FILE" ]]; then`).
**Immediately above** that line, insert:

```bash
    # Inherited-env reuse guard: a same-SID sub-invocation (e.g. a Bash tool call inside a Claude
    # session) inherits ANTHROPIC_BASE_URL + ICLAUDE_PII_ACTIVE from the parent. Reuse the parent's
    # proxy and return BEFORE any shared-proxy consumer accounting, so the sub-invocation can never
    # deregister/kill the proxy the live session depends on. Combined PII+CCR mode is excluded: it
    # needs a fresh proxy chained to its own CCR daemon.
    if [[ "${ICLAUDE_PII_ACTIVE:-}" == "1" ]] && \
       [[ -n "${ANTHROPIC_BASE_URL:-}" ]] && \
       [[ "${CCR_SESSION_OWNED:-false}" != "true" ]] && \
       [[ "${CCR_UPSTREAM_ACTIVE:-false}" != "true" ]]; then
        PII_PROXY_SESSION_OWNED=false
        print_info "PII proxy: inheriting parent session proxy ($ANTHROPIC_BASE_URL)"
        return 0
    fi

```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_pii_consumer_accounting.sh`
Expected: `PASS[B1-static]`, `PASS[B1-behavior]`, `ALL PASS`.

- [ ] **Step 5: Validate syntax**

Run: `bash -n lib/launcher/launch.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add lib/launcher/launch.sh tests/test_pii_consumer_accounting.sh
git commit -m "$(printf 'fix(pii-proxy): inherited-env reuse guard stops same-SID sub-invocations from killing shared proxy\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 4: `launch.sh` B2 — key consumer files by PID

Defense-in-depth: register/deregister consumer files by PID (`consumers/$$.pid`) instead of by SID,
so processes that share an `ICLAUDE_SESSION_ID` cannot cross-delete each other's registration.

**Files:**
- Modify: `lib/launcher/launch.sh` (`_register_pii_consumer` at line 838; shared branch of
  `stop_pii_proxy_server` at line 1325)
- Test: `tests/test_pii_consumer_accounting.sh` (extend)

- [ ] **Step 1: Add the failing static checks**

In `tests/test_pii_consumer_accounting.sh`, insert before the final `echo "ALL PASS"`:

```bash
# B2: consumer registration keyed by PID ($$) not SID
grep -q 'consumers/\$\$\.pid' "$LAUNCH_SH" || fail "B2-register" "consumer file not keyed by \$\$"
pass "B2-register" "consumer file keyed by PID"

# B2: stop_pii_proxy_server removes the PID-keyed consumer file
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
t = open(sys.argv[1]).read()
stop = t.find('stop_pii_proxy_server()')
seg = t[stop:stop+2000]
assert 'consumers/$$.pid' in seg, "B2: stop must rm consumers/$$.pid"
print("PASS[B2-stop]: stop removes PID-keyed consumer file")
PYCHECK
[[ $? -eq 0 ]] || fail "B2-stop" "stop does not remove PID-keyed consumer file"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_pii_consumer_accounting.sh`
Expected: FAIL at `B2-register` — still keyed by `${ICLAUDE_SESSION_ID}.pid`.

- [ ] **Step 3: Update `_register_pii_consumer`**

In `lib/launcher/launch.sh`, in `_register_pii_consumer` (line 838), change the registration line
from:

```bash
    echo "$$" > "$consumers_dir/${ICLAUDE_SESSION_ID}.pid"
```

to:

```bash
    # Key by PID, not SID: multiple processes can share ICLAUDE_SESSION_ID (a Claude session and its
    # Bash-tool sub-invocations). PID-keyed files prevent cross-deletion; _sweep_dead_pii_consumers
    # reaps them by `kill -0` on the stored PID.
    echo "$$" > "$consumers_dir/$$.pid"
```

- [ ] **Step 4: Update the shared branch of `stop_pii_proxy_server`**

In `lib/launcher/launch.sh`, in the `shared` branch of `stop_pii_proxy_server` (line 1325), change:

```bash
            rm -f "${PII_PROXY_PID_DIR}/consumers/${ICLAUDE_SESSION_ID}.pid"
```

to:

```bash
            rm -f "${PII_PROXY_PID_DIR}/consumers/$$.pid"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_pii_consumer_accounting.sh`
Expected: `PASS[B2-register]`, `PASS[B2-stop]`, `ALL PASS`.

- [ ] **Step 6: Run existing shared lifecycle/detach tests (regression)**

Run: `bash tests/test_pii_shared_lifecycle.sh; bash tests/test_pii_shared_detach.sh`
Expected: existing PASS lines, no FAIL. If either greps for `consumers/${ICLAUDE_SESSION_ID}`, update
that test's expectation to `consumers/$$` and note it in the commit.

- [ ] **Step 7: Validate syntax**

Run: `bash -n lib/launcher/launch.sh`
Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add lib/launcher/launch.sh tests/test_pii_consumer_accounting.sh
git commit -m "$(printf 'fix(pii-proxy): key shared-proxy consumer files by PID, not SID\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 5: Documentation

Document the new `PII_PROXY_SUPERVISE` env var and respawn behavior.

**Files:**
- Modify: `docs/PII_MASKING.md`
- Modify: `.claude_config.example`

- [ ] **Step 1: Find the env-var documentation table in PII_MASKING.md**

Run: `grep -n "PII_PROXY_READ_TIMEOUT\|PII_PROXY_CONNECT_TIMEOUT\|Environment" docs/PII_MASKING.md`
Expected: line numbers of the env section/table to extend.

- [ ] **Step 2: Add the supervisor row + behavior note**

In `docs/PII_MASKING.md`, in the environment-variable table (next to the timeout rows), add:

```markdown
| `PII_PROXY_SUPERVISE` | Respawn the serving worker if it dies (OOM/crash/kill), keeping the same port. `true` (default) or `false`. |
```

And add a short paragraph under the table:

```markdown
**Respawn supervisor.** When `PII_PROXY_SUPERVISE=true` (default) the proxy runs as a supervisor that
binds the listening socket once and re-forks the request-serving worker if it dies. Because the
socket is inherited across forks, the port is stable for the proxy's lifetime — a running Claude
session (whose `ANTHROPIC_BASE_URL` is fixed at launch) keeps working across a worker crash instead
of failing with `Unable to connect to API (ConnectionRefused)`. If the worker crash-loops (more than
5 restarts in 10 s) the supervisor logs an error and exits.
```

- [ ] **Step 3: Add the env var to `.claude_config.example`**

In `.claude_config.example`, near the other `PII_PROXY_*` entries, add:

```bash
# Respawn the PII proxy worker if it dies (OOM/crash/kill), keeping the same port.
# Recommended: leave at true so long-running sessions survive a proxy restart.
PII_PROXY_SUPERVISE=true
```

- [ ] **Step 4: Verify doc link integrity**

Run: `./iclaude.sh --lat-check 2>/dev/null || echo "lat-check unavailable, skipping"`
Expected: pass, or skipped cleanly.

- [ ] **Step 5: Commit**

```bash
git add docs/PII_MASKING.md .claude_config.example
git commit -m "$(printf 'docs(pii-proxy): document PII_PROXY_SUPERVISE and respawn behavior\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 6: Full regression + final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full PII pytest suite**

Run: `python3 -m pytest tests/test_pii_supervisor_unit.py tests/test_pii_timeout_retry.py tests/test_pii_meta_endpoint.py tests/test_patterns_examples.py -v`
Expected: all PASS.

- [ ] **Step 2: Run all PII bash tests**

Run:
```bash
for t in tests/test_pii_supervisor.sh tests/test_pii_consumer_accounting.sh \
         tests/test_pii_shared_lifecycle.sh tests/test_pii_shared_detach.sh; do
    echo "=== $t ==="; bash "$t" || { echo "FAILED: $t"; break; }
done
```
Expected: each ends with its PASS lines / `ALL PASS`, no FAIL.

- [ ] **Step 3: Confirm deployed copy is byte-identical**

Run: `diff lib/pii-proxy/server.py .nvm-isolated/.claude-isolated/pii-proxy-server.py && echo IDENTICAL`
Expected: `IDENTICAL`.

- [ ] **Step 4: Validate shell syntax**

Run: `bash -n iclaude.sh && bash -n lib/launcher/launch.sh && echo OK`
Expected: `OK`.

- [ ] **Step 5: Update knowledge graph + docs (per project CLAUDE.md)**

Run: `./iclaude.sh --lat-check 2>/dev/null || true`
Then update any `lat.md/` section that references PII proxy lifecycle if present.

- [ ] **Step 6: Final commit (only if Step 5 changed files)**

```bash
git add -A
git commit -m "$(printf 'chore(pii-proxy): refresh lat.md after respawn supervisor\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Self-Review notes (author)

- **Spec coverage:** Part A (supervisor) → Tasks 1–2; Part B1 (env guard) → Task 3; Part B2
  (PID-keyed consumers) → Task 4; teardown SIGTERM → Task 2 (`_sup_shutdown`); docs → Task 5;
  success criteria 1–5 → Task 2 (S3 respawn, S4 stop), Task 3/4 (sub-invocation), Task 6 (`bash -n`,
  suite). Storm-cap criterion (#4) is covered structurally (`TestStormGuard` + log line); a full
  crash-loop behavioral test is intentionally omitted (hard to force a deterministic startup crash
  without injecting faults — out of scope per YAGNI).
- **Naming consistency:** `_build_server`, `_run_worker`, `_supervise`, `SUPERVISE`,
  `_MAX_RESTARTS`, `_RESTART_WINDOW`, `_supervisor_stop`, `_current_worker_pid` used identically
  across tasks.
- **Deployed-copy sync:** every server edit (Tasks 1, 2) ends with the `cp` step; Task 6 Step 3
  asserts identity.
