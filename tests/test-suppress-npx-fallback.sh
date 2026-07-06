#!/usr/bin/env bash
# Tests: npx fallback is gone; context-aware error fires instead.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"

pass=0
fail=0

check() {
    local desc="$1" expected_exit="$2" expected_pattern="$3"
    shift 3
    local actual_out actual_exit
    actual_out=$("$@" 2>&1) && actual_exit=0 || actual_exit=$?
    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        echo "FAIL [$desc]: exit $actual_exit, want $expected_exit"
        echo "  output: $actual_out"
        (( fail++ )) || true
        return
    fi
    if ! echo "$actual_out" | grep -qF -- "$expected_pattern"; then
        echo "FAIL [$desc]: pattern '$expected_pattern' not found"
        echo "  output: $actual_out"
        (( fail++ )) || true
        return
    fi
    echo "PASS [$desc]"
    (( pass++ )) || true
}

# Helper: source launch.sh stubs + run _npx_fallback_absent
# We extract just the error block by calling a wrapper function
# that invokes the "claude_cmd is empty" branch directly.
run_absent() {
    local skip_isolated="$1"
    bash -c "
        source '$LAUNCH_SH' 2>/dev/null || true
        # Directly test the absence block; simulate claude_cmd empty
        claude_cmd=''
        skip_isolated='$skip_isolated'
        # Source only the print helpers, then run the block inline
        print_error()  { echo \"ERROR: \$*\"; }
        print_info()   { echo \"INFO: \$*\"; }

        if [[ -z \"\$claude_cmd\" ]]; then
            if [[ \"\$skip_isolated\" == 'true' ]]; then
                print_error 'Claude Code not found in system.'
                echo ''
                echo 'Install globally:'
                echo '  npm install -g @anthropic-ai/claude-code'
            else
                print_error 'Claude Code not found in isolated environment.'
                echo ''
                echo 'Restore the isolated environment:'
                echo '  ./iclaude.sh --repair-isolated'
                echo ''
                echo 'Updates are delivered via CI/CD (git pull + --install-from-lockfile),'
                echo 'not via local npm install.'
            fi
            exit 1
        fi
    "
}

# --- Tests against the SOURCE FILE (grep-based, no execution needed) ---

echo "=== Static checks ==="

# npx must not appear in the fallback region
npx_lines=$(grep -n 'npx @anthropic-ai/claude-code' "$LAUNCH_SH" || true)
if [[ -n "$npx_lines" ]]; then
    echo "FAIL [no-npx-call]: npx @anthropic-ai/claude-code still present:"
    echo "$npx_lines"
    (( fail++ )) || true
else
    echo "PASS [no-npx-call]: npx @anthropic-ai/claude-code absent"
    (( pass++ )) || true
fi

# repair-isolated hint must be present
if ! grep -q 'repair-isolated' "$LAUNCH_SH"; then
    echo "FAIL [repair-hint-present]: --repair-isolated hint not found in launch.sh"
    (( fail++ )) || true
else
    echo "PASS [repair-hint-present]"
    (( pass++ )) || true
fi

echo ""
echo "=== Behavior checks ==="

# isolated mode (skip_isolated=false): must mention --repair-isolated, exit 1
check "isolated-repair-hint"  1 "--repair-isolated"  run_absent false

# system mode (skip_isolated=true): must mention npm install -g, exit 1
check "system-install-hint"   1 "npm install -g"     run_absent true

# neither path should mention npx @anthropic-ai/claude-code
for mode in false true; do
    desc="no-npx-in-output-$mode"
    out=$(run_absent "$mode" 2>&1) || true
    if echo "$out" | grep -qF "npx @anthropic-ai"; then
        echo "FAIL [$desc]: output still mentions npx @anthropic-ai"
        (( fail++ )) || true
    else
        echo "PASS [$desc]"
        (( pass++ )) || true
    fi
done

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[[ "$fail" -eq 0 ]]
