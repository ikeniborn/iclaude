# Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add OTEL remote endpoint warning in `lib/telemetry/otel.sh` and replace fragile string-interpolated `python3 -c` with a heredoc in `lib/lat/check.sh`.

**Architecture:** Two independent surgical edits, each ~5 lines. No new files, no new dependencies, no behavioral change in default configuration. Both fixes are self-contained in their respective modules.

**Tech Stack:** Bash

---

## File Map

| File | Change |
|------|--------|
| `lib/telemetry/otel.sh` | Add 4-line warning block inside `print_telemetry_status()` after the info print |
| `lib/lat/check.sh` | Replace `python3 -c "...$settings_file..."` (lines 148-153) with heredoc passing path as `sys.argv[1]` |

---

### Task 1: OTEL remote endpoint warning

**Files:**
- Modify: `lib/telemetry/otel.sh:80-86`

Context: `print_telemetry_status()` runs at every startup when telemetry is enabled. It prints endpoint info but gives no indication when prompts are being sent to a non-local host. `log_warn` already has a defensive fallback on line 7 of this file.

- [ ] **Step 1: Open the file and locate the insertion point**

`lib/telemetry/otel.sh` lines 72-87:

```bash
print_telemetry_status() {
    if [[ "${CLAUDE_CODE_ENABLE_TELEMETRY:-0}" != "1" ]]; then
        return 0
    fi
    local endpoint="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
    local project
    project="$(printf '%s' "${OTEL_RESOURCE_ATTRIBUTES:-}" | tr ',' '\n' | awk -F= '/^iclaude\.project=/{print $2; exit}')"
    [[ -z "$project" ]] && project="unknown"
    echo ""
    if command -v print_info >/dev/null 2>&1; then
        print_info "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    else
        echo "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    fi
    echo ""
}
```

Insert the warning block **between** the `fi` on line 85 and the `echo ""` on line 86 (after the info print, before the trailing blank line).

- [ ] **Step 2: Apply the edit**

Replace the closing section of `print_telemetry_status()`:

Old:
```bash
    if command -v print_info >/dev/null 2>&1; then
        print_info "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    else
        echo "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    fi
    echo ""
}
```

New:
```bash
    if command -v print_info >/dev/null 2>&1; then
        print_info "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    else
        echo "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    fi
    if [[ "$endpoint" != *"127.0.0.1"* && "$endpoint" != *"localhost"* \
          && "${OTEL_LOG_USER_PROMPTS:-0}" == "1" ]]; then
        log_warn "Prompt logging ENABLED → remote endpoint: ${endpoint}"
    fi
    echo ""
}
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/telemetry/otel.sh
```

Expected: no output, exit code 0.

- [ ] **Step 4: Smoke test — local endpoint (default), no warning expected**

```bash
bash -c '
source lib/telemetry/otel.sh
print_telemetry_status
' 2>&1
```

Expected: output contains `Telemetry: enabled → http://127.0.0.1:4318` with **no** `warn:` line.

- [ ] **Step 5: Smoke test — remote endpoint, warning expected**

```bash
bash -c '
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.com:4318 \
  source lib/telemetry/otel.sh
print_telemetry_status
' 2>&1
```

Expected: output contains both the info line and a `warn: Prompt logging ENABLED → remote endpoint: https://otel.example.com:4318` line on stderr.

- [ ] **Step 6: Smoke test — no telemetry, no output**

```bash
bash -c '
ICLAUDE_NO_TELEMETRY=1 source lib/telemetry/otel.sh
print_telemetry_status
' 2>&1
```

Expected: no output (function returns early at line 73).

- [ ] **Step 7: Commit**

```bash
git add lib/telemetry/otel.sh
git commit -m "fix(security): warn when OTEL prompt logging targets remote endpoint"
```

---

### Task 2: python3 heredoc in lat/check.sh

**Files:**
- Modify: `lib/lat/check.sh:147-157`

Context: `check_lat_status()` checks whether the `lat` MCP server is configured in `settings.json`. It uses `python3 -c "..."` with `$settings_file` interpolated into the Python source string. The same file already uses the safe heredoc pattern in `remove_lat_precommit()` (lines 94-109) — this task makes `check_lat_status()` consistent.

- [ ] **Step 1: Open the file and locate the target block**

`lib/lat/check.sh` lines 147-157:

```bash
    # MCP config
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"
    if python3 -c "
import json, sys
with open('$settings_file') as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
" 2>/dev/null; then
        print_success "MCP: configured in settings.json"
    else
        print_warning "MCP: not configured (auto-injects on next launch when lat.md/ present)"
    fi
```

- [ ] **Step 2: Apply the edit**

Replace the `python3 -c` block:

Old:
```bash
    # MCP config
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"
    if python3 -c "
import json, sys
with open('$settings_file') as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
" 2>/dev/null; then
```

New:
```bash
    # MCP config
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"
    if python3 - "$settings_file" << 'PYEOF' 2>/dev/null; then
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
PYEOF
```

The rest of the `if` block (`print_success` / `print_warning`) is unchanged.

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/lat/check.sh
```

Expected: no output, exit code 0.

- [ ] **Step 4: Smoke test — settings.json with lat MCP (exit 0)**

```bash
bash -c '
SETTINGS=$(mktemp)
echo '"'"'{"mcpServers":{"lat":{"command":"lat","args":["mcp"]}}}'"'"' > "$SETTINGS"
python3 - "$SETTINGS" << '"'"'PYEOF'"'"' 2>/dev/null
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sys.exit(0 if "lat" in s.get("mcpServers", {}) else 1)
PYEOF
echo "exit: $?"
rm "$SETTINGS"
'
```

Expected: `exit: 0`

- [ ] **Step 5: Smoke test — settings.json without lat MCP (exit 1)**

```bash
bash -c '
SETTINGS=$(mktemp)
echo '"'"'{"mcpServers":{}}'"'"' > "$SETTINGS"
python3 - "$SETTINGS" << '"'"'PYEOF'"'"' 2>/dev/null
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sys.exit(0 if "lat" in s.get("mcpServers", {}) else 1)
PYEOF
echo "exit: $?"
rm "$SETTINGS"
'
```

Expected: `exit: 1`

- [ ] **Step 6: Smoke test — path with single quote (robustness)**

```bash
bash -c '
TMPDIR=$(mktemp -d)
QDIR="$TMPDIR/user'"'"'s config"
mkdir -p "$QDIR"
echo '"'"'{"mcpServers":{"lat":{}}}'"'"' > "$QDIR/settings.json"
python3 - "$QDIR/settings.json" << '"'"'PYEOF'"'"' 2>/dev/null
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sys.exit(0 if "lat" in s.get("mcpServers", {}) else 1)
PYEOF
echo "exit: $?"
rm -rf "$TMPDIR"
'
```

Expected: `exit: 0` (old `python3 -c` pattern would crash here with a SyntaxError)

- [ ] **Step 7: Run lat check end-to-end**

```bash
./iclaude.sh --check-lat
```

Expected: same output as before the change — status lines about lat CLI, lat.md/ project, and MCP config. No Python errors.

- [ ] **Step 8: Commit**

```bash
git add lib/lat/check.sh
git commit -m "fix(security): replace python3 -c string interpolation with heredoc in check_lat_status"
```
