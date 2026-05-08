#!/usr/bin/env bash
# L1 — mock unit tests for _pii_dnat_preflight and _pii_dnat_sweep_stale.
# Uses PATH-overridden mocks for sudo and iptables; no real privileges required.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub print_* functions so sourced helpers don't depend on lib/core/print.sh
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
print_error()   { echo "ERR: $*"; }
print_success() { echo "OK: $*"; }

# Extract the two target functions from microvm.sh without sourcing the whole module.
# Awk picks each function block by its opening "name() {" and matches the closing "}" at column 1.
_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/sandbox/microvm.sh"
}
eval "$(_extract _pii_dnat_preflight)"
eval "$(_extract _pii_dnat_sweep_stale)"

PASS=0
FAIL=0
assert_eq() {
    if [[ "$1" == "$2" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL [$3]: got '$1' expected '$2'"
    fi
}
assert_contains() {
    if echo "$1" | grep -qF "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL [$3]: '$2' not found in output"
    fi
}

# Mock builder: writes sudo + iptables stubs into $TD, returns nothing.
# Args:
#   $1 - dir
#   $2 - sudo_ok ("1" = succeeds, "0" = fails)
#   $3 - iptables script body (stdin not used — just the case logic)
make_mocks() {
    local dir="$1" sudo_ok="$2" ipt_body="$3"
    cat > "$dir/sudo" <<EOF
#!/usr/bin/env bash
[[ "$sudo_ok" == "1" ]] || exit 1
[[ "\$1" == "-n" ]] && shift
exec "\$@"
EOF
    cat > "$dir/iptables" <<EOF
#!/usr/bin/env bash
$ipt_body
EOF
    chmod +x "$dir/sudo" "$dir/iptables"
}

# ---- Tests ----

# Test 1: preflight — PII inactive → 0, no probes
unset ICLAUDE_PII_ACTIVE ICLAUDE_PII_ACTIVE_PORT
out=$(_pii_dnat_preflight 2>&1); rc=$?
assert_eq "$rc" "0" "preflight: inactive returns 0"
assert_eq "$out" "" "preflight: inactive prints nothing"

# Test 2: preflight — sudo unavailable → 1 + warning
TD=$(mktemp -d)
make_mocks "$TD" 0 'exit 0'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "1" "preflight: no-sudo returns 1"
assert_contains "$out" "passwordless sudo unavailable" "preflight: no-sudo warning text"
rm -rf "$TD"

# Test 3: preflight — sudo OK + iptables OK → 0
TD=$(mktemp -d)
make_mocks "$TD" 1 'exit 0'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "0" "preflight: happy path returns 0"
assert_eq "$out" "" "preflight: happy path prints nothing"
rm -rf "$TD"

# Test 4: preflight — sudo OK but iptables nat fails → 1
TD=$(mktemp -d)
make_mocks "$TD" 1 'case "$*" in *"-t nat"*) exit 1 ;; *) exit 0 ;; esac'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "1" "preflight: iptables-nat-fail returns 1"
assert_contains "$out" "iptables nat table inaccessible" "preflight: iptables-nat-fail warning"
rm -rf "$TD"

# Test 5: preflight — net disabled → 0 (skip)
out=$(
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=false \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "0" "preflight: net-disabled returns 0"

# Test 6: sweep — empty rule list, terminates fast (no infinite loop)
TD=$(mktemp -d)
make_mocks "$TD" 1 '
case "$*" in
    *"--line-numbers"*)
        echo "Chain PREROUTING (policy ACCEPT)"
        echo "num  target  prot  opt  source  destination"
        ;;
    *"-D "*) exit 0 ;;
esac
exit 0
'
PATH="$TD:$PATH" timeout 5 bash -c "$(declare -f _pii_dnat_sweep_stale make_mocks); _pii_dnat_sweep_stale tap-iclaude-1"
assert_eq "$?" "0" "sweep: empty list terminates"
rm -rf "$TD"

# Test 7: sweep — drains 2 stale rules
TD=$(mktemp -d)
echo "2" > "$TD/state"
cat > "$TD/sudo" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "-n" ]] && shift
exec "\$@"
EOF
cat > "$TD/iptables" <<EOF
#!/usr/bin/env bash
STATE="$TD/state"
N=\$(cat "\$STATE")
case "\$*" in
    *"--line-numbers"*)
        if [[ "\$N" -gt 0 ]]; then
            echo "1  DNAT  tcp  --  0.0.0.0/0  172.16.0.1  /* iclaude-pii-dnat:tap-iclaude-1 */"
        fi
        ;;
    *"-D "*"PREROUTING 1"*|*"-D "*"INPUT 1"*)
        echo \$((N - 1)) > "\$STATE"
        ;;
esac
exit 0
EOF
chmod +x "$TD/sudo" "$TD/iptables"
PATH="$TD:$PATH" timeout 5 bash -c "$(declare -f _pii_dnat_sweep_stale); _pii_dnat_sweep_stale tap-iclaude-1"
remaining=$(cat "$TD/state")
assert_eq "$remaining" "0" "sweep: 2 stale rules drained"
rm -rf "$TD"

# Test 8: sweep — guard cap fires on pathological input (rule never goes away)
TD=$(mktemp -d)
make_mocks "$TD" 1 '
case "$*" in
    *"--line-numbers"*)
        echo "1  DNAT  tcp  --  0  0  /* iclaude-pii-dnat:tap-iclaude-1 */"
        ;;
    *"-D "*) exit 0 ;;
esac
exit 0
'
start_ts=$(date +%s)
PATH="$TD:$PATH" timeout 5 bash -c "$(declare -f _pii_dnat_sweep_stale); _pii_dnat_sweep_stale tap-iclaude-1"
rc=$?
end_ts=$(date +%s)
assert_eq "$rc" "0" "sweep: guard cap returns 0"
[[ $((end_ts - start_ts)) -lt 5 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL [sweep guard timing]: took $((end_ts - start_ts))s"; }
rm -rf "$TD"

# Test 9: sweep — empty tap arg returns 0 silently
out=$(bash -c "$(declare -f _pii_dnat_sweep_stale); _pii_dnat_sweep_stale \"\"" 2>&1); rc=$?
assert_eq "$rc" "0" "sweep: empty tap arg returns 0"

echo "L1: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
