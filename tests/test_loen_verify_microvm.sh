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

# --- snapshot builder ---

repo="$tmp/repo"
mkdir -p "$repo/src"
git -C "$repo" init -q
printf 'v1\n' > "$repo/tracked.txt"
printf 'a\n'  > "$repo/src/app.txt"
git -C "$repo" add .
git -C "$repo" -c user.email=t@t -c user.name=t commit -q -m base
printf 'v2-unstaged\n' > "$repo/tracked.txt"                       # tracked, unstaged
printf 'new-staged\n'  > "$repo/staged-new.txt"
git -C "$repo" add staged-new.txt                                  # tracked, staged
printf 'secret\n' > "$repo/untracked.txt"                          # untracked → EXCLUDED

run="$repo/docs/loen/2026-07-02-demo"
mkdir -p "$run/iterations/iter-01"
printf 'name: 2026-07-02-demo\n' > "$run/loop.yaml"
printf 'diff-evidence\n'  > "$run/iterations/iter-01/diff.patch"
printf 'gates ok\n'       > "$run/iterations/iter-01/gates.log"

snap="$tmp/snap"
"$V" snapshot "$repo" "$run" "$snap" >/dev/null || fail "snapshot build failed"

[[ "$(cat "$snap/tracked.txt")" == "v2-unstaged" ]]  || fail "unstaged tracked change missing in snapshot"
[[ "$(cat "$snap/staged-new.txt")" == "new-staged" ]] || fail "staged new file missing in snapshot"
[[ "$(cat "$snap/src/app.txt")" == "a" ]]             || fail "HEAD content missing in snapshot"
[[ ! -e "$snap/untracked.txt" ]]                      || fail "untracked file leaked into snapshot"
[[ ! -e "$snap/.git" ]]                               || fail ".git leaked into snapshot"
[[ -f "$snap/docs/loen/2026-07-02-demo/loop.yaml" ]]  || fail "run loop.yaml missing in snapshot"
[[ -f "$snap/docs/loen/2026-07-02-demo/iterations/iter-01/gates.log" ]] || fail "gates.log missing in snapshot"
[[ "$(readlink "$snap/docs/loen/current")" == "2026-07-02-demo" ]] || fail "docs/loen/current symlink wrong"

# --- check: contract guard + preflight gate (no VM needed) ---

# contract without microvm isolation → check must refuse (exit 1), not boot anything
if out=$("$V" check "$run" iter-01 2>&1); then
    fail "check must refuse a contract that is not verifier_isolation: microvm"
fi
echo "$out" | grep -q "use the subagent dispatch instead" || fail "check refusal message missing"

# microvm contract but missing prerequisites → non-zero, no VM attempted
printf 'name: 2026-07-02-demo\nverifier_isolation: microvm\n' > "$run/loop.yaml"
if LOEN_KVM_DEV=/nonexistent-kvm ISOLATED_CONFIG_DIR="$tmp/empty-cfg" \
        "$V" check "$run" iter-01 2>/dev/null; then
    fail "check must fail preflight without prerequisites"
fi

# missing iteration dir → usage error
if "$V" check "$run" iter-99 2>/dev/null; then
    fail "check must reject a missing iteration dir"
fi

echo "PASS test_loen_verify_microvm.sh (unit: preflight + extract + snapshot + check guards)"

# --- integration e2e (real Firecracker guest; repo convention: auto-SKIP without KVM) ---
# Additionally gated behind ICLAUDE_LOEN_E2E=1: it boots a VM and spends API tokens.
if [[ ! -r /dev/kvm ]]; then
    echo "SKIP e2e: /dev/kvm absent"
elif [[ "${ICLAUDE_LOEN_E2E:-0}" != "1" ]]; then
    echo "SKIP e2e: set ICLAUDE_LOEN_E2E=1 to run (boots a microVM + calls the API)"
else
    # Fingerprints must bracket the toy run's WHOLE lifetime (created below, removed
    # before the post-capture), so pre is taken before mkdir.
    pre=$( { git status --porcelain=v1 --untracked-files=all; git diff HEAD --binary | sha256sum; } | sha256sum )
    e2e_run="docs/loen/2026-07-02-loen-e2e-toy"
    mkdir -p "$e2e_run/iterations/iter-01"
    cat > "$e2e_run/loop.yaml" <<'YAML'
name: 2026-07-02-loen-e2e-toy
mode: delivery
objective: "toy: README.md exists at repo root"
verifier_isolation: microvm
mutable_scope: ["README.md"]
protected_scope: ["iclaude.sh"]
quality_gates: ["test -f README.md"]
budget: { max_iterations: 1 }
YAML
    printf 'toy diff\n' > "$e2e_run/iterations/iter-01/diff.patch"
    printf '$ test -f README.md\nexit 0\n' > "$e2e_run/iterations/iter-01/gates.log"
    if "$V" check "$e2e_run" iter-01; then
        [[ -s "$e2e_run/iterations/iter-01/verifier.md" ]] || fail "e2e: verifier.md not written"
        grep -qE '^VERDICT: (APPROVE|REJECT)$' "$e2e_run/iterations/iter-01/verifier.md" \
            || fail "e2e: verifier.md has no VERDICT"
        echo "PASS e2e: isolated verdict produced"
    else
        fail "e2e: verify_microvm.sh check failed"
    fi
    rm -rf "$e2e_run"
    post=$( { git status --porcelain=v1 --untracked-files=all; git diff HEAD --binary | sha256sum; } | sha256sum )
    [[ "$pre" == "$post" ]] || fail "e2e: host tree changed across the isolated verify"
fi
