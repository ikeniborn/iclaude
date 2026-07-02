#!/usr/bin/env bash
# Unit tests for plugin/loen/scripts/verify_microvm.sh (no KVM needed) + gated e2e.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

V=plugin/loen/scripts/verify_microvm.sh
[[ -f "$V" ]] || fail "missing $V"
bash -n "$V" || fail "bash -n $V"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- preflight: contract parsing ---

# no contract arg → treated as subagent → OK
"$V" preflight >/dev/null || fail "preflight with no contract must pass"

# explicit subagent (with trailing comment) → OK
cat > "$tmp/loop.yaml" <<'YAML'
name: 2026-07-02-demo
verifier_isolation: subagent  # subagent (default) | microvm
YAML
"$V" preflight "$tmp/loop.yaml" >/dev/null || fail "subagent contract must pass preflight"

# key absent → default subagent → OK
cat > "$tmp/loop-nokey.yaml" <<'YAML'
name: 2026-07-02-demo
YAML
"$V" preflight "$tmp/loop-nokey.yaml" >/dev/null || fail "absent key must default to subagent"

# bogus value → reject
cat > "$tmp/loop-bogus.yaml" <<'YAML'
verifier_isolation: bogus
YAML
if "$V" preflight "$tmp/loop-bogus.yaml" 2>/dev/null; then
    fail "verifier_isolation: bogus must be rejected"
fi

# microvm + missing prerequisites → non-zero + explicit hint
cat > "$tmp/loop-mv.yaml" <<'YAML'
verifier_isolation: microvm
YAML
if out=$(LOEN_KVM_DEV=/nonexistent-kvm ISOLATED_CONFIG_DIR="$tmp/empty-cfg" \
        "$V" preflight "$tmp/loop-mv.yaml" 2>&1); then
    fail "microvm preflight must fail without prerequisites"
fi
echo "$out" | grep -q "install microVM support" || fail "preflight hint missing 'install microVM support'"
echo "$out" | grep -q "verifier_isolation: subagent" || fail "preflight hint missing 'drop to subagent'"

# missing contract file → non-zero
if "$V" preflight "$tmp/does-not-exist.yaml" 2>/dev/null; then
    fail "missing contract file must fail preflight"
fi

# --- extract: sentinel block ---

cat > "$tmp/out.log" <<'LOG'
ℹ microVM: starting Firecracker VMM...
launcher noise
LOEN_VERIFIER_BEGIN
VERDICT: APPROVE
EVIDENCE: bash tests/toy.sh → exit 0
MISSING: none
LOEN_VERIFIER_END
trailing noise
LOG
r=$("$V" extract "$tmp/out.log")
grep -q '^VERDICT: APPROVE$' <<<"$r" || fail "extract lost the VERDICT line"
if grep -q 'noise' <<<"$r"; then fail "extract leaked launcher noise"; fi

# no markers → empty output
: > "$tmp/empty.log"
r=$("$V" extract "$tmp/empty.log")
[[ -z "$r" ]] || fail "extract of markerless log must be empty"

echo "PASS test_loen_verify_microvm.sh (unit: preflight + extract)"
