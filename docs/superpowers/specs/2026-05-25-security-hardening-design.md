# Security Hardening: OTEL Remote Warning + python3 Heredoc Fix

**Date:** 2026-05-25
**Scope:** Two surgical fixes identified during security review of `dev` branch.

---

## Background

Security review surfaced two low-severity but concrete improvement opportunities — neither is an exploitable vulnerability in the current deployment model, but both represent defensive hygiene worth addressing.

---

## Fix 1: OTEL Remote Endpoint Warning

### Problem

`lib/telemetry/otel.sh` unconditionally sets `OTEL_LOG_USER_PROMPTS=1` at every launch. The default endpoint is `http://127.0.0.1:4318` (local). However, if `OTEL_EXPORTER_OTLP_ENDPOINT` is set to a remote host, user prompts are silently forwarded to that host with no visible indication at launch time.

### Change

In `print_telemetry_status()`, add a `print_warning` call when both conditions are true:
1. Endpoint does not contain `127.0.0.1` or `localhost`
2. `OTEL_LOG_USER_PROMPTS` equals `1`

```bash
# Inside print_telemetry_status(), after printing the status line:
# Use log_warn (already has defensive fallback in otel.sh line 7) — print_warning
# requires the logger module which may not be loaded when otel.sh is sourced standalone.
if [[ "$endpoint" != *"127.0.0.1"* && "$endpoint" != *"localhost"* \
      && "${OTEL_LOG_USER_PROMPTS:-0}" == "1" ]]; then
    log_warn "Prompt logging ENABLED → remote endpoint: ${endpoint}"
fi
```

### Behavior

- **Local endpoint** (default): no change — warning not shown.
- **Remote endpoint + prompts enabled**: one `print_warning` line visible in console at startup.
- **Non-interactive**: no blocking, no confirm prompt, no TTY requirement.
- **ICLAUDE_NO_TELEMETRY=1**: `setup_telemetry()` returns early, `CLAUDE_CODE_ENABLE_TELEMETRY` stays `0`, `print_telemetry_status()` is a no-op — warning never shown.

### Files

- `lib/telemetry/otel.sh` — `print_telemetry_status()` function (~5 lines added)

---

## Fix 2: python3 Heredoc in lat/check.sh

### Problem

`lib/lat/check.sh` in `check_lat_status()` interpolates `$settings_file` directly into a `python3 -c` string:

```bash
python3 -c "
import json, sys
with open('$settings_file') as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
" 2>/dev/null
```

The shell expands `$settings_file` before passing the string to Python. A path containing a single quote breaks Python syntax. Although `CLAUDE_CONFIG_DIR` is a trusted env var (making this non-exploitable), the pattern is fragile and inconsistent with safer alternatives already used in the codebase.

### Change

Replace with a heredoc that passes the path as a positional argument:

```bash
python3 - "$settings_file" << 'PYEOF' 2>/dev/null
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
PYEOF
```

`'PYEOF'` (quoted) prevents any shell expansion inside the heredoc. Path arrives as `sys.argv[1]` — no string interpolation into code.

### Behavior

- Functionally identical: same exit codes, same logic.
- Handles paths with spaces, single quotes, or other special characters correctly.
- Consistent with the heredoc pattern used elsewhere in `iclaude`.

### Files

- `lib/lat/check.sh` — `check_lat_status()` function (~5 lines replaced)

---

## Out of Scope

- `router.json` gitignore: intentional design — `${MY_PROVIDER_URL}` / `${MY_PROVIDER_API_KEY}` are JSON string literals read by CCR at runtime, not shell-expanded. No real credentials in git.
- `MICRO_VM_NET_TAP_IFACE` sysctl call: `_validate_iface_name` runs before all sudo calls; env var is internally computed.

---

## Testing

**Fix 1:**
```bash
# Set remote endpoint and verify warning appears
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.com:4318 ./iclaude.sh --test
# Expected: "⚠ Prompt logging ENABLED → remote endpoint: https://otel.example.com:4318"

# Default config — no warning
./iclaude.sh --test
# Expected: no warning line
```

**Fix 2:**
```bash
# Run lat check — should pass with no error
./iclaude.sh --lat-check
# Expected: same output as before, no Python errors
```

---

## Implementation Plan

1. Edit `lib/telemetry/otel.sh`: add warning block in `print_telemetry_status()`
2. Edit `lib/lat/check.sh`: replace `python3 -c` with heredoc
3. Smoke test both
4. Commit as `fix(security): OTEL remote endpoint warning + python3 heredoc in lat check`
