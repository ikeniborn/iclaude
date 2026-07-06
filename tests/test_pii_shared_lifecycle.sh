#!/usr/bin/env bash
# Regression tests for PII proxy shared lifecycle fixes:
#   Fix A: orphan detection (kill proxy with 0 consumers)
#   Fix B: shared.starter file (starter SID tracking)
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }

# ---------------------------------------------------------------------------
# Fix A: orphan detection — static checks
# ---------------------------------------------------------------------------

# A1: orphan block exists (consumer count check before _salive branch)
if grep -qE '_consumer_count.*-eq.*0.*_salive.*false|_salive=false.*_consumer_count.*-eq.*0' "$LAUNCH_SH" ||
   grep -A5 '_consumer_count' "$LAUNCH_SH" 2>/dev/null | grep -q '_salive=false'; then
    pass "A1" "orphan block sets _salive=false"
else
    # Check combined: _consumer_count declared AND used in an orphan guard
    grep -q '_consumer_count' "$LAUNCH_SH" || fail "A1" "_consumer_count not found in launch.sh"
    grep -A10 '_consumer_count' "$LAUNCH_SH" | grep -q 'kill.*_spid\|_salive=false' ||
        fail "A1" "orphan block: _consumer_count found but no kill or _salive=false follows it"
    pass "A1" "orphan block contains _consumer_count check"
fi

# A1-order: _consumer_count must appear AFTER _sweep_dead_pii_consumers
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
text = open(sys.argv[1]).read()
sweep_idx = text.find('_sweep_dead_pii_consumers')
assert sweep_idx != -1, "_sweep_dead_pii_consumers not found"
count_idx = text.find('_consumer_count', sweep_idx)
assert count_idx != -1 and count_idx > sweep_idx, \
    "_consumer_count must appear after _sweep_dead_pii_consumers"
print("PASS[A1-order]: _consumer_count declared after _sweep_dead_pii_consumers")
PYCHECK
[[ $? -eq 0 ]] || fail "A1-order" "_consumer_count not declared after _sweep_dead_pii_consumers"

# A2: starter deletion present in orphan kill block
grep -A20 '_consumer_count' "$LAUNCH_SH" | grep -q 'shared\.starter' ||
    fail "A2" "orphan block does not delete shared.starter"
pass "A2" "orphan block deletes shared.starter"

# ---------------------------------------------------------------------------
# Fix B: shared.starter — static checks
# ---------------------------------------------------------------------------

# B1: starter written after proxy PID recorded (start branch)
# Must appear after the `echo "$_proxy_pid" > "$_shared_pid_file"` line
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys, re
text = open(sys.argv[1]).read()
pid_write = text.find('echo "$_proxy_pid" > "$_shared_pid_file"')
starter_write = text.find('shared.starter', pid_write)
assert pid_write != -1, "pid write line not found"
assert starter_write != -1 and starter_write > pid_write, \
    "shared.starter write must appear after pid write"
print("PASS[B1]: shared.starter written after PID recorded")
PYCHECK
[[ $? -eq 0 ]] || fail "B1" "shared.starter not written in start branch after PID"

# B2: _starter_sid used in attach meta block (not d['session_id'])
grep -q '_starter_sid' "$LAUNCH_SH" ||
    fail "B2" "_starter_sid variable not found in launch.sh"
# Old code used d['session_id'] — new code must not contain it in the attach block
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
text = open(sys.argv[1]).read()
# Find the attach branch (inside flock subshell, after _salive == true)
attach_idx = text.find("_register_pii_consumer")
assert attach_idx != -1, "_register_pii_consumer not found"
# Check the next 600 chars after _register_pii_consumer for the meta block
block = text[attach_idx:attach_idx+600]
assert "d['session_id']" not in block, \
    "attach meta block still uses d['session_id'] — should use _starter_sid via sys.argv"
print("B2-neg: d['session_id'] not found in attach meta block (correct)")
PYCHECK
[[ $? -eq 0 ]] || fail "B2" "attach meta block still uses d['session_id'] — not updated"

# B3: _starter_sid passed as sys.argv argument (not interpolated into Python string)
grep -A5 '_starter_sid' "$LAUNCH_SH" | grep -q 'sys\.argv\[1\]\|"\$_starter_sid"' ||
    fail "B3" "_starter_sid not passed via sys.argv or as quoted arg to python"
pass "B3" "_starter_sid passed safely to python (not interpolated)"

# B4: starter deleted on last consumer stop
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
text = open(sys.argv[1]).read()
# Find the last-consumer stop block (after _count -eq 0 in stop_pii_proxy_server)
stop_idx = text.find('stop_pii_proxy_server()')
assert stop_idx != -1, "stop_pii_proxy_server not found"
stop_section = text[stop_idx:]
count_zero = stop_section.find('_count -eq 0')
assert count_zero != -1, "_count -eq 0 block not found in stop section"
block = stop_section[count_zero:count_zero+500]
assert 'shared.starter' in block, "shared.starter not deleted in last-consumer stop block"
print("PASS[B4]: shared.starter deleted in last-consumer stop block")
PYCHECK
[[ $? -eq 0 ]] || fail "B4" "shared.starter not deleted in stop_pii_proxy_server last-consumer block"

echo ""
echo "All static checks passed."
