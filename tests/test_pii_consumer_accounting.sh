#!/usr/bin/env bash
# Static + behavioral checks for PII consumer-accounting fixes (B1 inherited-env guard, B2 PID-keyed).
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; exit 1; }

# ---------------------------------------------------------------------------
# B1: inherited-env reuse guard. Must appear BEFORE the existing inherited-SID
# guard (line with `-f "$PII_PROXY_PID_FILE"`), be gated on ICLAUDE_PII_ACTIVE +
# CCR_UPSTREAM_ACTIVE, and return 0 after setting PII_PROXY_SESSION_OWNED=false.
# ---------------------------------------------------------------------------
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys, re
t = open(sys.argv[1]).read()
fn = t.find('start_pii_proxy_server()')
assert fn != -1, "start_pii_proxy_server not found"
sid_guard = t.find('-f "$PII_PROXY_PID_FILE"', fn)
assert sid_guard != -1, "existing inherited-SID guard not found"
region = t[fn:sid_guard]  # function start .. existing SID guard
assert 'ICLAUDE_PII_ACTIVE:-' in region, "B1: ICLAUDE_PII_ACTIVE guard not before SID guard"
assert 'CCR_UPSTREAM_ACTIVE' in region, "B1: guard must also exclude CCR_UPSTREAM_ACTIVE"
m = re.search(r'ICLAUDE_PII_ACTIVE.*?PII_PROXY_SESSION_OWNED=false.*?return 0', region, re.S)
assert m, "B1: guard must set PII_PROXY_SESSION_OWNED=false and return 0 before the SID/shared blocks"
print("PASS[B1-static]: inherited-env guard returns early before SID/shared accounting")
PYCHECK
[[ $? -eq 0 ]] || fail "B1-static" "guard structure missing"

# B1-behavior: extract the function, stub deps, and call it with inherited env set.
# It must return 0, set PII_PROXY_SESSION_OWNED=false, and start NO server process.
B1_TMP="$(mktemp -d)"
# Extract the function body (from 'start_pii_proxy_server() {' to its closing brace at column 0).
awk '/^start_pii_proxy_server\(\) \{/{f=1} f{print} /^\}/{if(f){exit}}' "$LAUNCH_SH" > "$B1_TMP/fn.sh"
grep -q 'start_pii_proxy_server()' "$B1_TMP/fn.sh" || fail "B1-behavior" "could not extract function"

# Create a fake server script file so the -f check passes
touch "$B1_TMP/server.py"

B1_RESULT="$(
  bash -c '
    set -u
    SENTINEL="'"$B1_TMP"'/started"
    # stubs for everything the early-return path might touch
    print_info() { :; }
    print_warning() { :; }
    print_error() { :; }
    get_pii_proxy_python() { echo "python3"; }
    setsid() { echo started > "$SENTINEL"; }   # if the guard fails, real start path would run
    PII_PROXY_SERVER_SCRIPT="'"$B1_TMP"'/server.py"
    PII_PROXY_VENV="/nonexistent"
    # inherited-from-parent env that must trigger the early guard
    ICLAUDE_PII_ACTIVE=1
    ANTHROPIC_BASE_URL="http://127.0.0.1:12345"
    CCR_SESSION_OWNED=false
    CCR_UPSTREAM_ACTIVE=false
    PII_PROXY_SESSION_OWNED=unset
    source "'"$B1_TMP"'/fn.sh"
    start_pii_proxy_server false
    rc=$?
    echo "rc=$rc owned=$PII_PROXY_SESSION_OWNED started=$([[ -f "$SENTINEL" ]] && echo yes || echo no)"
  '
)"
echo "  [B1-behavior] $B1_RESULT"
echo "$B1_RESULT" | grep -q 'rc=0' || { rm -rf "$B1_TMP"; fail "B1-behavior" "guard did not return 0"; }
echo "$B1_RESULT" | grep -q 'owned=false' || { rm -rf "$B1_TMP"; fail "B1-behavior" "PII_PROXY_SESSION_OWNED not set to false"; }
echo "$B1_RESULT" | grep -q 'started=no' || { rm -rf "$B1_TMP"; fail "B1-behavior" "a server process was started despite inherited env"; }
rm -rf "$B1_TMP"
pass "B1-behavior" "inherited env -> early return 0, SESSION_OWNED=false, no server started"

echo "ALL PASS"
