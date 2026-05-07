# PII Proxy Shared Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share one PII proxy Python process across all concurrent clean-PII iclaude sessions instead of starting a separate process per session.

**Architecture:** Consumer-directory pattern — each session registers a file in `pii-proxy-pid/consumers/<SID>.pid`; a flock on `pii-proxy-pid/shared.lock` serializes start/stop decisions; the shared proxy uses `ICLAUDE_SESSION_ID=shared` so server.py writes `pii-proxy-shared.port` and `shared.log`. CCR combined mode and same-SID sub-process reuse are unchanged.

**Tech Stack:** Bash (flock, kill, ps), Python 3 (server.py one-line fix), existing pytest for verification.

**Spec:** `docs/superpowers/specs/2026-05-07-pii-shared-server-design.md`

---

## File Map

| File | Change |
|---|---|
| `lib/pii-proxy/server.py` | Fix `session_id` validation in 2 places to accept `'shared'` |
| `lib/launcher/launch.sh` | Add `sweep_dead_consumers`, `register_consumer` helpers; refactor `start_pii_proxy_server` (non-CCR path); add `shared` branch in `stop_pii_proxy_server` |
| `lib/pii-proxy/status.sh` | Add shared proxy section and consumer list |

---

### Task 1: Fix server.py — accept 'shared' as valid session ID

**Files:**
- Modify: `lib/pii-proxy/server.py:230` (setup_logging)
- Modify: `lib/pii-proxy/server.py:1032` (main session_id validation)

`server.py` validates `ICLAUDE_SESSION_ID` against `[0-9a-f]{12}` in two places. Both must also accept the sentinel `'shared'` to write `pii-proxy-shared.port` and `shared.log` instead of falling back to `default`.

- [ ] **Step 1.1: Fix setup_logging (line 230)**

Current line 230:
```python
    _sid = session_id if re.fullmatch(r'[0-9a-f]{12}', session_id) else 'default'
```

Replace with:
```python
    _sid = session_id if (re.fullmatch(r'[0-9a-f]{12}', session_id) or session_id == 'shared') else 'default'
```

- [ ] **Step 1.2: Fix main() session_id validation (line 1032)**

Current line 1032:
```python
    session_id = _raw_sid if re.fullmatch(r'[0-9a-f]{12}', _raw_sid) else 'default'
```

Replace with:
```python
    session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
```

- [ ] **Step 1.3: Verify server.py starts with ICLAUDE_SESSION_ID=shared**

Run (from project root, requires pii-proxy venv installed):
```bash
LOG_DIR=$(mktemp -d)
ICLAUDE_SESSION_ID=shared \
ANTHROPIC_UPSTREAM_URL=https://api.anthropic.com \
  .nvm-isolated/pii-proxy-venv/bin/python3 lib/pii-proxy/server.py \
  --port 0 --log-dir "$LOG_DIR" &
PROXY_PID=$!
sleep 3
ls "$LOG_DIR"
# Expected: pii-proxy-shared.port  shared.log
cat "$LOG_DIR/pii-proxy-shared.port"
# Expected: a number like 23847
kill "$PROXY_PID"
rm -rf "$LOG_DIR"
```

Expected output: `pii-proxy-shared.port` and `shared.log` both present.

- [ ] **Step 1.4: Run existing test suite — must stay green**

```bash
python3 -m pytest tests/test_patterns_examples.py -v
```

Expected: all 28 tests pass.

- [ ] **Step 1.5: Commit**

```bash
git add lib/pii-proxy/server.py
git commit -m "fix(pii-proxy): accept 'shared' as valid session ID for shared proxy mode"
```

---

### Task 2: Add sweep_dead_consumers and register_consumer helpers to launch.sh

**Files:**
- Modify: `lib/launcher/launch.sh` — insert two new functions before `start_pii_proxy_server`

These helpers are called inside an already-held `flock`, so they must not acquire the lock themselves.

- [ ] **Step 2.1: Insert helpers before start_pii_proxy_server (before line 824)**

Find the line `start_pii_proxy_server() {` (line 824) and insert the two functions immediately before it:

```bash
#######################################
# Sweep dead consumer registrations from pii-proxy-pid/consumers/.
# Must be called while holding flock on shared.lock.
# Removes files whose stored PID is dead (kill -0 fails).
#######################################
_sweep_dead_pii_consumers() {
    local consumers_dir="${PII_PROXY_PID_DIR}/consumers"
    [[ -d "$consumers_dir" ]] || return 0
    local _cf _cpid
    for _cf in "$consumers_dir"/*.pid; do
        [[ -f "$_cf" ]] || continue
        _cpid=$(cat "$_cf" 2>/dev/null)
        if [[ -z "$_cpid" ]] || ! kill -0 "$_cpid" 2>/dev/null; then
            rm -f "$_cf"
        fi
    done
}

#######################################
# Register current session as a consumer of the shared PII proxy.
# Creates pii-proxy-pid/consumers/$ICLAUDE_SESSION_ID.pid with current bash PID.
# Must be called while holding flock on shared.lock.
#######################################
_register_pii_consumer() {
    local consumers_dir="${PII_PROXY_PID_DIR}/consumers"
    mkdir -p "$consumers_dir"
    chmod 700 "$consumers_dir"
    echo "$$" > "$consumers_dir/${ICLAUDE_SESSION_ID}.pid"
}

```

- [ ] **Step 2.2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 2.3: Commit**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(pii-proxy): add _sweep_dead_pii_consumers and _register_pii_consumer helpers"
```

---

### Task 3: Refactor start_pii_proxy_server — add shared proxy path

**Files:**
- Modify: `lib/launcher/launch.sh:892-994` — insert shared proxy block after parent-SID guard, before `cleanup_orphaned_pii_proxies`

The existing function flow after the parent-SID guard (line 892) continues with `cleanup_orphaned_pii_proxies` (line 894). We insert the shared proxy logic between these two points, guarded by `CCR_SESSION_OWNED != true`.

- [ ] **Step 3.1: Insert shared proxy block after line 892 (end of parent-SID guard)**

After the closing `fi` of the parent-SID guard block (the `fi` at line 892), add:

```bash
    # Shared proxy mode (non-CCR only): attach to existing shared proxy or start one.
    # All clean-PII sessions share one Python process to avoid loading Presidio NLP
    # multiple times. A flock on shared.lock serializes start/stop decisions.
    # CCR sessions (CCR_SESSION_OWNED=true) bypass this and start a per-session proxy.
    if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]]; then
        local _shared_lock="${PII_PROXY_PID_DIR}/shared.lock"
        local _shared_pid_file="${PII_PROXY_PID_DIR}/shared.pid"
        local _shared_port_file="${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
        # Capture upstream before subshell (subshells cannot set parent vars)
        local _upstream_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
        # Temp file to pass port out of the flock subshell (subshells cannot set parent vars)
        local _shared_result="${PII_PROXY_PID_DIR}/shared-attach-${ICLAUDE_SESSION_ID}.tmp"
        rm -f "$_shared_result"
        mkdir -p "$PII_PROXY_PID_DIR"
        chmod 700 "$PII_PROXY_PID_DIR"

        (
            flock -x 9
            _sweep_dead_pii_consumers

            # Check if shared proxy is alive
            local _spid _sport _salive=false
            _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
            if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null && \
               ps -p "$_spid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                _sport=$(cat "$_shared_port_file" 2>/dev/null || true)
                [[ "$_sport" =~ ^[0-9]+$ ]] && _salive=true
            fi

            if [[ "$_salive" == "true" ]]; then
                # Attach to existing shared proxy
                _register_pii_consumer
                echo "attach:${_sport}" > "$_shared_result"
            else
                # Start new shared proxy
                rm -f "$_shared_pid_file" "$_shared_port_file"
                local _upstream="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
                mkdir -p "$PII_PROXY_LOG_DIR"
                chmod 700 "$PII_PROXY_LOG_DIR"

                ANTHROPIC_UPSTREAM_URL="$_upstream" \
                ICLAUDE_SESSION_ID="shared" \
                PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
                    "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
                    --port "$PII_PROXY_PORT" \
                    --log-dir "$PII_PROXY_LOG_DIR" \
                    >/dev/null 2>&1 &

                local _proxy_pid=$!
                echo "$_proxy_pid" > "$_shared_pid_file"

                # Poll for port file then HTTP health (max 15s, 0.5s intervals)
                local _max=30 _tick=0 _health=false _port=""
                while [[ $_tick -lt $_max ]]; do
                    if ! kill -0 "$_proxy_pid" 2>/dev/null; then
                        echo "fail:process_exited" > "$_shared_result"
                        rm -f "$_shared_pid_file"
                        exit 1
                    fi
                    if [[ -f "$_shared_port_file" ]]; then
                        _port=$(cat "$_shared_port_file" 2>/dev/null || true)
                        if [[ "$_port" =~ ^[0-9]+$ ]]; then
                            if (: >/dev/tcp/127.0.0.1/"$_port") 2>/dev/null; then
                                if _pii_proxy_http_health "$_port"; then
                                    _health=true
                                    break
                                fi
                            fi
                        fi
                    fi
                    sleep 0.5
                    _tick=$((_tick + 1))
                done

                if [[ "$_health" != "true" ]]; then
                    kill "$_proxy_pid" 2>/dev/null || true
                    rm -f "$_shared_pid_file" "$_shared_port_file"
                    echo "fail:timeout" > "$_shared_result"
                    exit 1
                fi

                _register_pii_consumer
                echo "start:${_port}" > "$_shared_result"
            fi
        ) 9>"$_shared_lock"

        # Process result from flock subshell
        local _result _mode _port
        if [[ -f "$_shared_result" ]]; then
            _result=$(cat "$_shared_result" 2>/dev/null || true)
            rm -f "$_shared_result"
        else
            _result="fail:no_result"
        fi
        _mode="${_result%%:*}"
        _port="${_result#*:}"

        case "$_mode" in
            attach|start)
                if [[ ! "$_port" =~ ^[0-9]+$ ]]; then
                    print_warning "PII proxy: shared proxy returned invalid port"
                    unset -f _pii_proxy_http_health
                    return 1
                fi
                PII_PROXY_ACTIVE_PORT="$_port"
                PII_PROXY_SESSION_OWNED=shared
                export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
                export ICLAUDE_PII_ACTIVE=1
                export ICLAUDE_PII_MASKING_LEVEL="${PII_PROXY_MASKING_LEVEL:-standard}"
                export ICLAUDE_PII_ACTIVE_PORT="$PII_PROXY_ACTIVE_PORT"
                export ICLAUDE_PII_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}"
                export ICLAUDE_PII_LOG_PATH="${PII_PROXY_LOG_DIR}/shared.log"
                if [[ "$_mode" == "attach" ]]; then
                    print_info "PII proxy: attached to shared proxy on :$PII_PROXY_ACTIVE_PORT"
                else
                    print_info "PII proxy: shared proxy started on :$PII_PROXY_ACTIVE_PORT → $_upstream_url [${PII_PROXY_MASKING_LEVEL:-standard}]"
                fi
                unset -f _pii_proxy_http_health
                echo ""
                return 0
                ;;
            *)
                print_warning "PII proxy: shared proxy failed to start (${_result})"
                print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
                unset -f _pii_proxy_http_health
                return 1
                ;;
        esac
    fi

```

- [ ] **Step 3.2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output.

- [ ] **Step 3.3: Smoke-test shared proxy start (manual)**

```bash
# Set up required env vars (replace paths with actual values from your install)
export PII_PROXY_PID_DIR="$(pwd)/.nvm-isolated/.claude-isolated/pii-proxy-pid"
export PII_PROXY_LOG_DIR="/tmp/pii-proxy-logs-test"
export ICLAUDE_SESSION_ID="aabbccddeeff"
export PII_PROXY_PORT=0
export PII_PROXY_MASKING_LEVEL=standard
export PII_PROXY_LOG_LEVEL=info
export PII_PROXY_SERVER_SCRIPT="$(pwd)/lib/pii-proxy/server.py"
export PII_PROXY_VENV="$(pwd)/.nvm-isolated/pii-proxy-venv"

mkdir -p "$PII_PROXY_PID_DIR" "$PII_PROXY_LOG_DIR"

# Source the launcher module
source lib/pii-proxy/detect.sh
source lib/launcher/launch.sh

# Start shared proxy
start_pii_proxy_server false
echo "OWNED=$PII_PROXY_SESSION_OWNED PORT=$PII_PROXY_ACTIVE_PORT"
# Expected: OWNED=shared PORT=<some_number>

ls "$PII_PROXY_PID_DIR/consumers/"
# Expected: aabbccddeeff.pid

ls "$PII_PROXY_LOG_DIR/"
# Expected: pii-proxy-shared.port  shared.log

# Start second session (simulate by changing SID)
export ICLAUDE_SESSION_ID="112233445566"
start_pii_proxy_server false
echo "OWNED=$PII_PROXY_SESSION_OWNED PORT=$PII_PROXY_ACTIVE_PORT"
# Expected: OWNED=shared PORT=<same_number as above> (attached, not new process)

ls "$PII_PROXY_PID_DIR/consumers/"
# Expected: aabbccddeeff.pid  112233445566.pid

pgrep -af pii-proxy-server | wc -l
# Expected: 1 (only one Python process)
```

- [ ] **Step 3.4: Commit**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(pii-proxy): share single proxy across clean-PII sessions via flock + consumer directory"
```

---

### Task 4: Add 'shared' branch to stop_pii_proxy_server

**Files:**
- Modify: `lib/launcher/launch.sh:1113` — add `shared` branch before existing per-session kill logic

Current `stop_pii_proxy_server` starts with:
```bash
stop_pii_proxy_server() {
    # Do not kill proxy started by a parent session (inherited SID reuse path)
    if [[ "${PII_PROXY_SESSION_OWNED:-}" == "false" ]]; then
        return 0
    fi
    if [[ -f "${PII_PROXY_PID_FILE:-}" ]]; then
        ...
```

- [ ] **Step 4.1: Insert 'shared' branch inside stop_pii_proxy_server**

After the `if [[ "${PII_PROXY_SESSION_OWNED:-}" == "false" ]]; then return 0; fi` block, add:

```bash
    # Shared proxy: deregister this session; kill proxy only if no consumers remain
    if [[ "${PII_PROXY_SESSION_OWNED:-}" == "shared" ]]; then
        local _shared_lock="${PII_PROXY_PID_DIR}/shared.lock"
        local _shared_pid_file="${PII_PROXY_PID_DIR}/shared.pid"
        mkdir -p "$PII_PROXY_PID_DIR"
        (
            flock -x 9
            rm -f "${PII_PROXY_PID_DIR}/consumers/${ICLAUDE_SESSION_ID}.pid"
            _sweep_dead_pii_consumers
            local _count
            _count=$(ls "${PII_PROXY_PID_DIR}/consumers/"*.pid 2>/dev/null | wc -l)
            if [[ "$_count" -eq 0 ]]; then
                local _spid
                _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
                if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null; then
                    kill "$_spid" 2>/dev/null || true
                    local _waited=0
                    while kill -0 "$_spid" 2>/dev/null && [[ $_waited -lt 10 ]]; do
                        sleep 0.1
                        _waited=$((_waited + 1))
                    done
                    kill -9 "$_spid" 2>/dev/null || true
                fi
                rm -f "$_shared_pid_file"
                rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
                if [[ "${PII_PROXY_LOG_LEVEL:-info}" != "debug" ]]; then
                    rm -f "${PII_PROXY_LOG_DIR}/shared.log"
                fi
            fi
        ) 9>"$_shared_lock"
        return 0
    fi

```

- [ ] **Step 4.2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output.

- [ ] **Step 4.3: Smoke-test shared proxy stop (manual, continuation of Task 3 test)**

```bash
# Simulate session aabbccddeeff stopping (still have 112233445566 as consumer)
export ICLAUDE_SESSION_ID="aabbccddeeff"
export PII_PROXY_SESSION_OWNED=shared
stop_pii_proxy_server

ls "$PII_PROXY_PID_DIR/consumers/"
# Expected: 112233445566.pid only (aabbccddeeff.pid removed)

pgrep -af pii-proxy-server | wc -l
# Expected: 1 (proxy still running — second consumer exists)

# Now simulate last consumer stopping
export ICLAUDE_SESSION_ID="112233445566"
export PII_PROXY_SESSION_OWNED=shared
stop_pii_proxy_server

ls "$PII_PROXY_PID_DIR/consumers/" 2>/dev/null || echo "(empty)"
# Expected: (empty)

pgrep -af pii-proxy-server | wc -l
# Expected: 0 (proxy killed)

ls "$PII_PROXY_LOG_DIR/pii-proxy-shared.port" 2>/dev/null || echo "(removed)"
# Expected: (removed)
```

- [ ] **Step 4.4: Test SIGKILL recovery (manual)**

```bash
# Start shared proxy
export ICLAUDE_SESSION_ID="aabbccddeeff"
start_pii_proxy_server false

# Simulate kill -9 (no trap fires, consumer file left behind)
# Kill bash PID in consumer file
kill -9 $$ 2>/dev/null || true  # not actually running — simulate by using a dead PID
echo "99999999" > "$PII_PROXY_PID_DIR/consumers/deadbeefcafe.pid"

# On next start, sweep should clean up the orphaned consumer file
export ICLAUDE_SESSION_ID="112233445566"
start_pii_proxy_server false

ls "$PII_PROXY_PID_DIR/consumers/"
# Expected: 112233445566.pid only (deadbeefcafe.pid swept away)
```

- [ ] **Step 4.5: Commit**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(pii-proxy): stop shared proxy only when last consumer deregisters"
```

---

### Task 5: Update status.sh — show shared proxy and consumers

**Files:**
- Modify: `lib/pii-proxy/status.sh` — add shared proxy section after the existing server running processes section

- [ ] **Step 5.1: Add shared proxy section to check_pii_proxy_status**

Find the section starting with `# Running processes (per-session:` (around line 128) and add a new shared proxy block immediately before it:

```bash
    # Shared proxy
    echo ""
    local _shared_pid_file="${PII_PROXY_PID_DIR:-${ISOLATED_CONFIG_DIR}/pii-proxy-pid}/shared.pid"
    local _shared_port_file="${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
    local _consumers_dir="${PII_PROXY_PID_DIR:-${ISOLATED_CONFIG_DIR}/pii-proxy-pid}/consumers"
    local _shared_pid _shared_port _shared_alive=false

    _shared_pid=$(cat "$_shared_pid_file" 2>/dev/null || true)
    if [[ -n "$_shared_pid" ]] && kill -0 "$_shared_pid" 2>/dev/null && \
       ps -p "$_shared_pid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
        _shared_alive=true
        _shared_port=$(cat "$_shared_port_file" 2>/dev/null || echo "?")
    fi

    if [[ "$_shared_alive" == "true" ]]; then
        print_success "Shared proxy: PID $_shared_pid, port $_shared_port"
        if [[ -d "$_consumers_dir" ]]; then
            local _cf _cpid _csid _calive
            for _cf in "$_consumers_dir"/*.pid; do
                [[ -f "$_cf" ]] || continue
                _cpid=$(cat "$_cf" 2>/dev/null || true)
                _csid="${_cf##*/}"; _csid="${_csid%.pid}"
                if [[ -n "$_cpid" ]] && kill -0 "$_cpid" 2>/dev/null; then
                    _calive="alive"
                else
                    _calive="dead (orphan)"
                fi
                echo "    Session ${_csid}: bash PID ${_cpid} (${_calive})"
            done
        fi
    else
        print_info "Shared proxy: not running"
    fi

```

- [ ] **Step 5.2: Verify syntax**

```bash
bash -n lib/pii-proxy/status.sh
```

Expected: no output.

- [ ] **Step 5.3: Commit**

```bash
git add lib/pii-proxy/status.sh
git commit -m "feat(pii-proxy): show shared proxy status and active consumers"
```

---

### Task 6: End-to-end verification

No code changes. Manual verification of all 6 success criteria from the spec.

- [ ] **Step 6.1: Two clean-PII sessions → single Python process**

In terminal 1:
```bash
./iclaude.sh --pii-proxy
# note the PID shown in "PII proxy: shared proxy started on :XXXXX"
```

In terminal 2:
```bash
./iclaude.sh --pii-proxy
# Expected message: "PII proxy: attached to shared proxy on :XXXXX" (same port)
```

```bash
pgrep -af pii-proxy-server
# Expected: exactly 1 line
```

- [ ] **Step 6.2: First session exits, proxy stays alive**

Exit terminal 1 (Ctrl+D or /exit in claude). Then in terminal 2:
```bash
curl -s http://127.0.0.1:XXXXX/api/health
# Expected: {"status": "ready", ...}
```

- [ ] **Step 6.3: Last session exits, proxy terminates**

Exit terminal 2. Then:
```bash
sleep 2
pgrep -af pii-proxy-server
# Expected: no output (proxy dead)
ls .nvm-isolated/.claude-isolated/pii-proxy-pid/consumers/ 2>/dev/null || echo "(empty)"
# Expected: (empty)
```

- [ ] **Step 6.4: CCR combined mode unaffected**

```bash
./iclaude.sh --pii-proxy --router
# Expected: "Launching Claude Code with PII masking → CCR router chain..."
# Expected: per-session proxy message, NOT "attached to shared proxy"
pgrep -af pii-proxy-server
# Expected: one proxy for the CCR session (separate from any shared proxy)
```

- [ ] **Step 6.5: Run existing test suite**

```bash
python3 -m pytest tests/test_patterns_examples.py -v
```

Expected: all 28 tests pass.

- [ ] **Step 6.6: Final commit if any fixups**

```bash
git add -p  # stage any fixups
git commit -m "fix(pii-proxy): <describe fixup if any>"
```
