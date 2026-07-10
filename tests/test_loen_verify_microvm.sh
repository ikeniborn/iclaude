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

run="$repo/docs/loen/demo"
mkdir -p "$run/evidence"
printf 'topic: demo\nstatus: active\n' > "$run/loop.yaml"
printf '# Act\ntoy action\n' > "$run/4_act.md"
printf '## Result\nPASS\n'   > "$run/5_check.md"
printf 'prior verdict\n'     > "$run/evidence/verifier-verdict.md"

snap="$tmp/snap"
"$V" snapshot "$repo" "$run" "$snap" >/dev/null || fail "snapshot build failed"

[[ "$(cat "$snap/tracked.txt")" == "v2-unstaged" ]]  || fail "unstaged tracked change missing in snapshot"
[[ "$(cat "$snap/staged-new.txt")" == "new-staged" ]] || fail "staged new file missing in snapshot"
[[ "$(cat "$snap/src/app.txt")" == "a" ]]             || fail "HEAD content missing in snapshot"
[[ ! -e "$snap/untracked.txt" ]]                      || fail "untracked file leaked into snapshot"
[[ ! -e "$snap/.git" ]]                               || fail ".git leaked into snapshot"
[[ -f "$snap/docs/loen/demo/loop.yaml" ]]             || fail "topic loop.yaml missing in snapshot"
[[ -f "$snap/docs/loen/demo/5_check.md" ]]            || fail "5_check.md missing in snapshot"
[[ -f "$snap/docs/loen/demo/evidence/verifier-verdict.md" ]] || fail "evidence missing in snapshot"
[[ ! -L "$snap/docs/loen/current" && "$(cat "$snap/docs/loen/current")" == "demo" ]] \
    || fail "docs/loen/current pointer wrong (must be a text file, not a symlink)"

# --- check: contract guard + preflight gate (no VM needed) ---

# contract without microvm isolation → check must refuse (exit 1), not boot anything
if out=$("$V" check "$run" 2>&1); then
    fail "check must refuse a contract that is not verifier_isolation: microvm"
fi
echo "$out" | grep -q "use the subagent dispatch instead" || fail "check refusal message missing"

# microvm contract but missing prerequisites → non-zero, no VM attempted
printf 'topic: demo\nstatus: active\nverifier_isolation: microvm\n' > "$run/loop.yaml"
if LOEN_KVM_DEV=/nonexistent-kvm ISOLATED_CONFIG_DIR="$tmp/empty-cfg" \
        "$V" check "$run" 2>/dev/null; then
    fail "check must fail preflight without prerequisites"
fi

# missing topic dir → usage/contract error
if "$V" check "$repo/docs/loen/nope" 2>/dev/null; then
    fail "check must reject a missing topic dir"
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
    e2e_run="docs/loen/loen-e2e-toy"
    mkdir -p "$e2e_run/evidence"
    cat > "$e2e_run/loop.yaml" <<'YAML'
topic: loen-e2e-toy
mode: delivery
status: active
objective: "toy: README.md exists at repo root"
verifier_isolation: microvm
mutable_scope: ["README.md"]
protected_scope: ["iclaude.sh"]
quality_gates: ["test -f README.md"]
budget: { max_iterations: 1 }
YAML
    printf '# Act\ntoy action\n' > "$e2e_run/4_act.md"
    printf '## Result\nPASS\n'   > "$e2e_run/5_check.md"
    if "$V" check "$e2e_run"; then
        [[ -s "$e2e_run/evidence/verifier-verdict.md" ]] || fail "e2e: verdict not written"
        grep -qE '^VERDICT: (APPROVE|REJECT)$' "$e2e_run/evidence/verifier-verdict.md" \
            || fail "e2e: verdict has no VERDICT"
        echo "PASS e2e: isolated verdict produced"
    else
        fail "e2e: verify_microvm.sh check failed"
    fi
    rm -rf "$e2e_run"
    post=$( { git status --porcelain=v1 --untracked-files=all; git diff HEAD --binary | sha256sum; } | sha256sum )
    [[ "$pre" == "$post" ]] || fail "e2e: host tree changed across the isolated verify"
fi
