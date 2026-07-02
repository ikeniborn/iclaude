---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-verifier-microvm-design.md
review:
  plan_hash: f3ee32ae09a8a797
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - { id: F-001, phase: coverage, severity: WARNING, verdict: fixed, note: "spec §9 'LOEN.md contract table' deviation recorded as refinement 4 (no key table exists in LOEN.md; key documented in Hardening subsection + wiki contract section)" }
    - { id: F-002, phase: consistency, severity: WARNING, verdict: fixed, note: "Task 4 Step 5 e2e: pre-fingerprint capture folded before mkdir into the code block; executor NOTE removed" }
    - { id: F-003, phase: verifiability, severity: INFO, verdict: fixed, note: "Task 7 Step 6 gained grep checks confirming all four doc inserts landed" }
    - { id: F-004, phase: consistency, severity: INFO, verdict: fixed, note: "version-sync enforcement now cites check-plugin-version-sync.sh (spec §7) alongside test_loen_plugin.sh" }
  verdict: OK
---
# loen backlog step 3 — verifier microVM isolation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an OPT-IN `verifier_isolation: microvm` mode to the loen contract: `loen:audit check` runs the verifier as a headless Claude Code session inside an iclaude Firecracker microVM against a disposable snapshot of the tree — the judge becomes read-only by construction.

**Architecture:** One new orchestration script `plugin/loen/scripts/verify_microvm.sh` (subcommands `preflight` / `snapshot` / `extract` / `check`) reuses the existing, battle-tested `iclaude.sh --sandbox-microvm` launch path instead of re-implementing VM plumbing: it builds a snapshot dir (git archive HEAD + tracked staged/unstaged diff + run artifacts), points `MICRO_VM_WORKSPACE_MODE=isolated` + `MICRO_VM_WORKSPACE_PATH` at that throwaway dir, runs `claude -p` in the guest, and extracts the verdict from captured output via sentinel markers. Three tripwires make the guarantee deterministic: (1) silent-fallback detection (iclaude.sh downgrades to a host launch when microVM is unavailable — the script refuses such a verdict), (2) a required positive boot marker, (3) a host-tree fingerprint compared before/after. Contract key + isolation-aware audit dispatch; everything else stays as shipped.

**Tech Stack:** bash (plugin script + tests), existing iclaude microVM stack (`lib/sandbox/microvm.sh`, `lib/launcher/launch.sh` — untouched), YAML template, python3 heredoc asserts in tests.

## Global Constraints

Copied from the spec — every task implicitly includes these:

- Default behavior is byte-for-byte unchanged: contracts without `verifier_isolation` behave exactly as MVP (spec §6).
- NO silent fallback: any VM boot/provision/exec failure → `verify_microvm.sh` exits non-zero → `loen:audit check` reports `needs_work` with the failure log; never dispatch the in-session subagent as a substitute (spec §5).
- Snapshot content is pinned: `git archive HEAD` + tracked staged+unstaged changes applied on top + the run's `docs/loen/<run-id>/` artifacts; **untracked files are EXCLUDED**; nothing outside the repo enters the snapshot (spec §5.1, §8).
- No sync-back channel from guest to host tree (spec §5.5).
- `agents/verifier.md` body and model (`opus`) stay as shipped; the loop-guard hook and `check_layout.sh` are untouched; no new canonical artifact paths (spec §6).
- Template key is present and parses — NOT commented out (same rule as `eval_command`, spec §4).
- Minor version bump `0.3.0` → `0.4.0` in BOTH manifests (`plugin/loen/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`), sync enforced by `scripts/check-plugin-version-sync.sh` (spec §7) and by `tests/test_loen_plugin.sh`.
- Integration tests auto-SKIP when `/dev/kvm` is absent; unit tests always run (spec §8).
- Plugin scripts are referenced from SKILL.md as "this plugin's `scripts/<name>` resolved from the skill base dir" (existing audit convention).
- Docs and code comments in English; root `README.md` insert in Russian (that file is RU); `docs/functions/MICROVM.md` insert in Russian (surrounding sections are RU).

**Branch:** `dev-loen-verifier-microvm`, based off `dev` (previous loen increments merged into `dev`; confirm base + worktree question with the user at execution start per CLAUDE.md branch workflow). PR into `dev`.

## Key facts discovered at plan time (spec §5.2 "resolved by the explorer at plan time")

- `iclaude.sh` forwards everything after `--` verbatim to the guest claude (`iclaude.sh:684-688`), and unknown args are also forwarded (`iclaude.sh:689-692`). So the whole isolated verify launch is: `./iclaude.sh --sandbox-microvm -- --model opus --dangerously-skip-permissions -p "<one-line prompt>"`.
- `MICRO_VM_WORKSPACE_MODE=isolated` = one-way host→guest copy, no sync-back (`lib/launcher/launch.sh:584-587` skips sync-back for `isolated`); `MICRO_VM_WORKSPACE_PATH` overrides `$PWD` as the sync source (`lib/sandbox/microvm.sh:1388`). Pointing it at the throwaway snapshot dir means even a config-forced `full` mode could only sync back into the snapshot, never the real tree.
- **Silent-downgrade hazard:** `lib/launcher/launch.sh:198-204` — when `detect_microvm` fails, iclaude.sh prints `"Continuing without microVM isolation..."` and launches claude ON THE HOST. `verify_microvm.sh` must detect this marker and refuse the verdict. Positive marker on success: `"microVM: Firecracker started"` (cold boot, `microvm.sh:1589`) or `"microVM: resumed from snapshot"` (`microvm.sh:1089`).
- `.claude_config` is sourced by the child iclaude.sh (`lib/config/env-map.sh:57-62`) and its `ICLAUDE_*` assignments override inherited env. Defense: export BOTH bare and `ICLAUDE_`-prefixed overrides, plus the host-tree fingerprint tripwire (detective layer).
- `ICLAUDE_SESSION_ID` names the FC socket and session dir (`microvm.sh:1285-1292`); the wrapper MUST set a unique value (`loen-verify-$$`) or it could collide with (and `stop_microvm` would `rm -rf`) the parent session's dir.
- Guest shell is `/bin/sh` (dash) and args reach it via `printf '%q'` (`launch.sh:409-414,573`): a multiline `-p` prompt would be `$'...'`-quoted, which dash mangles. Therefore the full verifier prompt travels INSIDE the snapshot as `.loen-verifier-prompt.md`; the `-p` argument stays single-line ("read that file and follow it").
- Launcher `print_*` functions write to stdout (`lib/core/logging.sh`) — guest claude output is interleaved with launcher noise, hence sentinel markers `LOEN_VERIFIER_BEGIN`/`LOEN_VERIFIER_END` around the verifier report.
- Headless safety: the snapshot-select and snapshot-save prompts read stdin with `|| default` fallbacks (`microvm.sh:876,1605`), so a `</dev/null` run never hangs even if config enables snapshots; the wrapper still forces `MICRO_VM_SNAPSHOT_ENABLED=false` both-prefixed.
- In-session env available to the script: `SCRIPT_DIR` (iclaude repo root) and `ISOLATED_CONFIG_DIR` are exported by the launcher — used as defaults, overridable via `LOEN_ICLAUDE_SH` / `ISOLATED_CONFIG_DIR`.

**Plan-level refinements of the spec (all recorded, all reversible):**
1. Snapshot copies ALL `iterations/iter-NN/` canonical files plus `experiments.jsonl` (superset of the spec's `iter-NN/{diff.patch,gates.log}` wording) — the research-mode verifier cross-checks `experiments.jsonl` vs earlier iterations' `metrics.jsonl`, which requires them. Still only run evidence; nothing outside the repo.
2. The e2e integration test is additionally gated behind `ICLAUDE_LOEN_E2E=1` (beyond the spec's `/dev/kvm` auto-SKIP): it boots a real VM AND spends API tokens; an unconditional run would make the suite non-hermetic and billable. Documented in the test's SKIP message.
3. Exit-code contract for `verify_microvm.sh`: `0` verdict produced; `1` usage/preflight/contract error; `2` launch or isolation failure (incl. silent-fallback, missing verdict/markers); `3` host tree changed during the run (tripwire).
4. Spec §9 names a LOEN.md "contract table": `docs/functions/LOEN.md` has no loop.yaml key table today (its only table lists artifact paths), so the key is documented in the new "Hardening" subsection there plus the wiki's "loop.yaml contract" section — no new table is introduced.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `plugin/loen/skills/loop-delivery/assets/loop.template.yaml` | Modify | contract template gains `verifier_isolation: subagent` |
| `tests/test_loen_templates.sh` | Modify | pins the new key + default |
| `plugin/loen/scripts/verify_microvm.sh` | Create | the whole isolated verify flow: `preflight` / `snapshot` / `extract` / `check` |
| `tests/test_loen_verify_microvm.sh` | Create | unit tests (no KVM) + gated e2e |
| `plugin/loen/skills/audit/SKILL.md` | Modify | isolation-aware check dispatch + plan validation |
| `plugin/loen/.claude-plugin/plugin.json` | Modify | version 0.4.0 |
| `.claude-plugin/marketplace.json` | Modify | loen entry version 0.4.0 |
| `docs/functions/LOEN.md`, `docs/functions/MICROVM.md`, `plugin/loen/README.md`, `README.md` | Modify | docs (spec §9) |
| iwiki `iclaude/loen-plugin` | Update via MCP | Components / loop.yaml contract / Roadmap |

---

### Task 1: Contract key in the template

**Files:**
- Modify: `plugin/loen/skills/loop-delivery/assets/loop.template.yaml` (after line 8, `quality_gates`)
- Test: `tests/test_loen_templates.sh`

**Interfaces:**
- Produces: top-level contract key `verifier_isolation` with default value `subagent`; consumed by `verify_microvm.sh preflight/check` (Tasks 2, 4) and by the audit skill text (Task 5).

- [ ] **Step 1: Extend the template test (failing first)**

In `tests/test_loen_templates.sh`, inside the python3 heredoc, replace:

```python
assert "eval_command" in d, "loop.template.yaml missing eval_command"
assert "max_experiments" in d["budget"], "budget missing max_experiments"
```

with:

```python
assert "eval_command" in d, "loop.template.yaml missing eval_command"
assert "max_experiments" in d["budget"], "budget missing max_experiments"
assert d.get("verifier_isolation") == "subagent", (
    f"verifier_isolation must default to 'subagent', got: {d.get('verifier_isolation')!r}")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_loen_templates.sh
```

Expected: FAIL with `verifier_isolation must default to 'subagent', got: None`.

- [ ] **Step 3: Add the key to the template**

In `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`, replace:

```yaml
quality_gates: []           # commands that must exit 0 (verifiers)
eval_command: ""            # research mode: fixed eval; appends JSONL to $LOEN_METRICS_PATH (empty in delivery/repair)
```

with:

```yaml
quality_gates: []           # commands that must exit 0 (verifiers)
verifier_isolation: subagent # subagent (default) | microvm — verifier runs headless in an iclaude Firecracker microVM against a disposable tree snapshot (requires iclaude microVM install)
eval_command: ""            # research mode: fixed eval; appends JSONL to $LOEN_METRICS_PATH (empty in delivery/repair)
```

The key is a real value with a trailing comment — NOT commented out (template must keep parsing).

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_loen_templates.sh
```

Expected: `OK loop.template.yaml schema` + `PASS test_loen_templates.sh`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/loop-delivery/assets/loop.template.yaml tests/test_loen_templates.sh
git commit -m "feat(loen): add verifier_isolation contract key (default subagent)"
```

---

### Task 2: `verify_microvm.sh` — skeleton, `preflight`, `extract`

**Files:**
- Create: `plugin/loen/scripts/verify_microvm.sh` (mode 755)
- Test: `tests/test_loen_verify_microvm.sh` (new; grows in Tasks 3–4)

**Interfaces:**
- Produces (consumed by Tasks 3–5 and the audit skill):
  - `verify_microvm.sh preflight [loop.yaml]` — exit 0 when isolation is `subagent`/absent, or `microvm` with full host capability; exit 1 otherwise (invalid value, or missing KVM/firecracker/images with the "install microVM support … or drop to 'verifier_isolation: subagent'" hint on stderr).
  - `verify_microvm.sh extract <log-file>` — prints the text between `LOEN_VERIFIER_BEGIN` and `LOEN_VERIFIER_END` lines (markers excluded); empty output when no block.
  - Internal helpers reused by Task 4: `_read_isolation <loop.yaml>` (echoes `subagent|microvm|<raw>`), `_capability_check` (exit 0/1, prints missing list on stderr).
  - Env knobs: `LOEN_KVM_DEV` (default `/dev/kvm` — test injection point), `LOEN_ICLAUDE_SH` (default `${SCRIPT_DIR}/iclaude.sh`), `ISOLATED_CONFIG_DIR` (default `$PWD/.nvm-isolated/.claude-isolated`).

- [ ] **Step 1: Write the failing unit tests**

Create `tests/test_loen_verify_microvm.sh`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: FAIL with `missing plugin/loen/scripts/verify_microvm.sh`.

- [ ] **Step 3: Write the script (skeleton + preflight + extract)**

Create `plugin/loen/scripts/verify_microvm.sh`:

```bash
#!/usr/bin/env bash
# loen isolated verify flow (verifier_isolation: microvm). Runs the loen verifier as a
# headless Claude Code session inside an iclaude Firecracker microVM against a disposable
# snapshot of the tree — the judge is read-only by construction: the guest only ever sees
# a throwaway copy, and MICRO_VM_WORKSPACE_MODE=isolated has no sync-back channel.
#
# Subcommands:
#   preflight [loop.yaml]                       validate verifier_isolation + host capability
#   snapshot  <repo-root> <run-dir> <out-dir>   build the disposable tree snapshot
#   extract   <log-file>                        print the LOEN_VERIFIER_BEGIN/END block
#   check     <run-dir> <iter-NN> [checklist-file]  full isolated verify; writes verifier.md
#
# Exit codes: 0 ok / verdict produced; 1 usage, contract or preflight failure;
#             2 launch or isolation failure (silent host fallback, missing boot marker,
#               missing sentinel block or VERDICT line); 3 host tree changed (tripwire).
#
# Env knobs: LOEN_KVM_DEV (default /dev/kvm), LOEN_ICLAUDE_SH (default $SCRIPT_DIR/iclaude.sh),
#            ISOLATED_CONFIG_DIR (default ./.nvm-isolated/.claude-isolated),
#            LOEN_VERIFY_TIMEOUT (seconds, default 1800), LOEN_VERIFY_KEEP_SNAPSHOT=1 (debug).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

# Echo the contract's verifier_isolation value ('subagent' when absent/empty).
_read_isolation() {
    local contract="$1" line isolation
    line=$(grep -E '^verifier_isolation:' "$contract" | head -1 || true)
    line="${line%%#*}"
    isolation="${line#verifier_isolation:}"
    isolation="${isolation//[[:space:]]/}"
    isolation="${isolation//\"/}"
    isolation="${isolation//\'/}"
    [[ -z "$isolation" ]] && isolation="subagent"
    printf '%s' "$isolation"
}

# Host capability for microvm mode: KVM + firecracker + images + launcher.
_capability_check() {
    local cfg="${ISOLATED_CONFIG_DIR:-$PWD/.nvm-isolated/.claude-isolated}"
    local kvm="${LOEN_KVM_DEV:-/dev/kvm}"
    local iclaude_sh="${LOEN_ICLAUDE_SH:-${SCRIPT_DIR:-.}/iclaude.sh}"
    local missing=()
    [[ -r "$kvm" ]]                    || missing+=("KVM (${kvm} not readable)")
    [[ -x "${cfg}/bin/firecracker" ]]  || missing+=("firecracker binary (${cfg}/bin/firecracker)")
    [[ -f "${cfg}/bin/vmlinux" ]]      || missing+=("vmlinux kernel image")
    [[ -f "${cfg}/bin/rootfs.ext4" ]]  || missing+=("rootfs.ext4 guest image")
    [[ -f "${cfg}/bin/nvm.img" ]]      || missing+=("nvm.img (Node.js + claude for the guest)")
    [[ -x "$iclaude_sh" ]]             || missing+=("iclaude.sh launcher (${iclaude_sh})")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "verify_microvm: 'verifier_isolation: microvm' is not available on this host:" >&2
        printf '  - missing: %s\n' "${missing[@]}" >&2
        echo "  install microVM support (./iclaude.sh --install-microvm) or drop the contract to 'verifier_isolation: subagent'" >&2
        return 1
    fi
}

cmd_preflight() {
    local contract="${1:-}" isolation="subagent"
    if [[ -n "$contract" ]]; then
        [[ -f "$contract" ]] || { echo "verify_microvm: contract not found: ${contract}" >&2; return 1; }
        isolation=$(_read_isolation "$contract")
    fi
    case "$isolation" in
        subagent)
            echo "verify_microvm: preflight OK (verifier_isolation: subagent — nothing to check)"
            ;;
        microvm)
            _capability_check || return 1
            echo "verify_microvm: preflight OK (microvm available)"
            ;;
        *)
            echo "verify_microvm: invalid verifier_isolation '${isolation}' — must be 'subagent' or 'microvm'" >&2
            return 1
            ;;
    esac
}

# Print the report between the sentinel lines (markers excluded).
cmd_extract() {
    local log="${1:-}"
    [[ -f "$log" ]] || { echo "verify_microvm: log not found: ${log}" >&2; return 1; }
    awk '/^LOEN_VERIFIER_END$/{f=0} f{print} /^LOEN_VERIFIER_BEGIN$/{f=1}' "$log"
}

case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    *) usage ;;
esac
```

Then:

```bash
chmod +x plugin/loen/scripts/verify_microvm.sh
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: `PASS test_loen_verify_microvm.sh (unit: preflight + extract)`.

Note: on a dev host with a full microVM install the "missing prerequisites" test still fails the preflight because `LOEN_KVM_DEV=/nonexistent-kvm` and `ISOLATED_CONFIG_DIR` point at an empty dir — the injection points make the test hermetic.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/verify_microvm.sh tests/test_loen_verify_microvm.sh
git commit -m "feat(loen): verify_microvm.sh preflight + sentinel extract"
```

---

### Task 3: `snapshot` subcommand — disposable tree builder

**Files:**
- Modify: `plugin/loen/scripts/verify_microvm.sh`
- Test: `tests/test_loen_verify_microvm.sh`

**Interfaces:**
- Consumes: nothing new (pure git + fs).
- Produces: `verify_microvm.sh snapshot <repo-root> <run-dir> <out-dir>` — builds into `<out-dir>`: tracked tree at HEAD, tracked staged+unstaged changes applied on top (untracked EXCLUDED), the run's `loop.yaml` + all `iterations/iter-NN/{diff.patch,gates.log,metrics.jsonl}` + `experiments.jsonl` when present, and a relative symlink `docs/loen/current -> <run-id>`. `<out-dir>` must live OUTSIDE any git repo (the caller uses `mktemp -d` under `/tmp`; `git apply` relies on non-repo behavior). Function `_snapshot` reused by Task 4.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_loen_verify_microvm.sh`, immediately BEFORE the final `echo "PASS ..."` line (and update that line as shown):

```bash
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

echo "PASS test_loen_verify_microvm.sh (unit: preflight + extract + snapshot)"
```

- [ ] **Step 2: Run tests to verify the new part fails**

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: FAIL — `snapshot` hits the `usage` branch (`snapshot build failed`).

- [ ] **Step 3: Implement `_snapshot`**

In `plugin/loen/scripts/verify_microvm.sh`, insert BEFORE `cmd_preflight()`:

```bash
# Build the disposable tree copy the guest will judge. Content contract (spec §5.1):
# HEAD + tracked staged+unstaged changes + the run's evidence artifacts; untracked files
# and everything outside the repo are excluded. out_dir must be OUTSIDE any git repo.
_snapshot() {
    local repo="$1" run_dir="$2" out="$3"
    git -C "$repo" rev-parse --show-toplevel >/dev/null 2>&1 || {
        echo "verify_microvm: not a git repo: ${repo}" >&2; return 1; }
    [[ -f "$run_dir/loop.yaml" ]] || {
        echo "verify_microvm: run dir has no loop.yaml: ${run_dir}" >&2; return 1; }
    mkdir -p "$out"

    # 1. Tracked tree at HEAD.
    git -C "$repo" archive --format=tar HEAD | tar -xf - -C "$out"

    # 2. Tracked staged+unstaged changes on top (binary-safe). Untracked excluded.
    local patch
    patch=$(mktemp /tmp/loen-verify-XXXXXX.patch)
    git -C "$repo" diff HEAD --binary --no-color > "$patch"
    if [[ -s "$patch" ]]; then
        git -C "$out" apply --whitespace=nowarn "$patch"
    fi
    rm -f "$patch"

    # 3. The run's evidence artifacts + the current symlink the verifier body expects.
    local run_id iter_dir f dest
    run_id=$(basename "$run_dir")
    dest="$out/docs/loen/$run_id"
    mkdir -p "$dest"
    cp "$run_dir/loop.yaml" "$dest/loop.yaml"
    for iter_dir in "$run_dir"/iterations/iter-[0-9][0-9]; do
        [[ -d "$iter_dir" ]] || continue
        mkdir -p "$dest/iterations/$(basename "$iter_dir")"
        for f in diff.patch gates.log metrics.jsonl; do
            if [[ -f "$iter_dir/$f" ]]; then
                cp "$iter_dir/$f" "$dest/iterations/$(basename "$iter_dir")/$f"
            fi
        done
    done
    if [[ -f "$run_dir/experiments.jsonl" ]]; then
        cp "$run_dir/experiments.jsonl" "$dest/experiments.jsonl"
    fi
    ln -sfn "$run_id" "$out/docs/loen/current"
    echo "verify_microvm: snapshot ready at ${out}"
}
```

And extend the dispatcher: replace

```bash
case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    *) usage ;;
esac
```

with

```bash
case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    snapshot)  shift; [[ $# -eq 3 ]] || usage; _snapshot "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    *) usage ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: `PASS test_loen_verify_microvm.sh (unit: preflight + extract + snapshot)`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/verify_microvm.sh tests/test_loen_verify_microvm.sh
git commit -m "feat(loen): verify_microvm.sh snapshot builder (HEAD + tracked diff + run artifacts)"
```

---

### Task 4: `check` subcommand — the isolated verify flow

**Files:**
- Modify: `plugin/loen/scripts/verify_microvm.sh`
- Test: `tests/test_loen_verify_microvm.sh`

**Interfaces:**
- Consumes: `_read_isolation`, `_capability_check` (Task 2), `_snapshot` (Task 3); `iclaude.sh --sandbox-microvm -- …` launch path; sentinel extraction `cmd_extract`.
- Produces: `verify_microvm.sh check <run-dir> <iter-NN> [checklist-file]` — exit 0 iff a `VERDICT: APPROVE|REJECT` line was produced; writes the extracted report unchanged to `<run-dir>/iterations/<iter-NN>/verifier.md`; keeps the combined launch log at `/tmp/loen-verify-<pid>.log` for the `needs_work` failure report. Refuses to run when the contract is not `verifier_isolation: microvm` (audit dispatch bug guard).

- [ ] **Step 1: Write the failing tests (KVM-free paths of `check`)**

Append to `tests/test_loen_verify_microvm.sh`, BEFORE the final `echo "PASS ..."` line (and update that line as shown):

```bash
# --- check: contract guard + preflight gate (no VM needed) ---

# contract without microvm isolation → check must refuse (exit 1), not boot anything
if "$V" check "$run" iter-01 2>/dev/null; then
    fail "check must refuse a contract that is not verifier_isolation: microvm"
fi

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
```

- [ ] **Step 2: Run tests to verify the new part fails**

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: FAIL — `check` hits the `usage` branch and exits 1, so the FIRST new assertion passes vacuously but the `iter-99` case also exits 1… therefore assert the failure precisely: the run above fails at `check must refuse …` only after `check` exists. Before implementation ALL `check` invocations exit 1 via `usage`, so the three guards "pass" spuriously — verify instead that the script currently prints usage:

```bash
plugin/loen/scripts/verify_microvm.sh check 2>&1 | grep -q "Subcommands:" && echo "check not implemented yet (expected)"
```

Expected: `check not implemented yet (expected)`. (The real behavioral distinction lands in Step 4's message-level asserts.)

- [ ] **Step 3: Implement `cmd_check`**

In `plugin/loen/scripts/verify_microvm.sh`, insert AFTER `cmd_extract()`:

```bash
# Fingerprint of the host tree (tracked diff + full status incl. untracked). Any change
# during the isolated verify means isolation was breached or something else wrote to the
# tree mid-run — either way the verdict is not trustworthy.
_tree_fingerprint() {
    local repo="$1"
    {
        git -C "$repo" status --porcelain=v1 --untracked-files=all
        git -C "$repo" diff HEAD --binary --no-color | sha256sum
    } | sha256sum | awk '{print $1}'
}

cmd_check() {
    local run_dir="${1:-}" iter="${2:-}" checklist_file="${3:-}"
    [[ -n "$run_dir" && -n "$iter" ]] || usage
    [[ -f "$run_dir/loop.yaml" ]] || { echo "verify_microvm: no loop.yaml in ${run_dir}" >&2; return 1; }
    [[ -d "$run_dir/iterations/$iter" ]] || { echo "verify_microvm: no iteration dir ${run_dir}/iterations/${iter}" >&2; return 1; }

    # Guard against dispatch bugs: this flow is ONLY for microvm contracts.
    local isolation
    isolation=$(_read_isolation "$run_dir/loop.yaml")
    if [[ "$isolation" != "microvm" ]]; then
        echo "verify_microvm: check called for verifier_isolation '${isolation}' — use the subagent dispatch instead" >&2
        return 1
    fi
    _capability_check || return 1

    local iclaude_sh="${LOEN_ICLAUDE_SH:-${SCRIPT_DIR:-.}/iclaude.sh}"
    local repo_root run_id
    repo_root=$(git rev-parse --show-toplevel)
    run_id=$(basename "$(cd "$run_dir" && pwd)")

    # Tripwire baseline: the host tree must be bit-identical after the isolated run.
    local pre_fp
    pre_fp=$(_tree_fingerprint "$repo_root")

    # Disposable snapshot (under /tmp — outside any repo, required by _snapshot).
    local snap log
    snap=$(mktemp -d /tmp/loen-verify-snap-XXXXXX)
    log="/tmp/loen-verify-$$.log"
    # Keep the log always (audit reports needs_work with it); snapshot is disposable.
    trap '[[ "${LOEN_VERIFY_KEEP_SNAPSHOT:-0}" == "1" ]] || rm -rf "$snap"' RETURN

    _snapshot "$repo_root" "$run_dir" "$snap" >&2

    # The full prompt travels INSIDE the snapshot: the guest shell is dash and printf %q
    # would $'…'-quote a multiline -p argument, which dash mangles. The -p arg stays
    # one line and just points at the file.
    local agent_body
    agent_body=$(awk 'f==2{print} /^---$/{f++}' "${PLUGIN_DIR}/agents/verifier.md")
    local checklist="(no mode-specific checklist provided)"
    if [[ -n "$checklist_file" && -f "$checklist_file" ]]; then
        checklist=$(cat "$checklist_file")
    fi
    cat > "$snap/.loen-verifier-prompt.md" <<PROMPT
You are the loen verifier running in an ISOLATED microVM against a disposable snapshot
of the work tree (cwd = /workspace = repo root). Nothing you do here can reach the real
tree. Follow these instructions exactly:

${agent_body}

Mode-specific checklist:
${checklist}

Inputs (snapshot-relative, cwd = /workspace):
- contract: docs/loen/${run_id}/loop.yaml (also docs/loen/current/loop.yaml)
- iteration under review: docs/loen/${run_id}/iterations/${iter}/ (diff.patch, gates.log)

Print your ENTIRE final report between a line containing exactly LOEN_VERIFIER_BEGIN and
a line containing exactly LOEN_VERIFIER_END. The report MUST contain a line
'VERDICT: APPROVE' or 'VERDICT: REJECT'.
PROMPT

    # Launch headless. Env overrides are set BOTH bare and ICLAUDE_-prefixed because the
    # child sources .claude_config (ICLAUDE_* wins over inherited env for config'd keys).
    # ICLAUDE_SESSION_ID must be unique — it names the FC socket and the session dir the
    # child's stop_microvm will rm -rf.
    local timeout_s="${LOEN_VERIFY_TIMEOUT:-1800}"
    local rc=0
    (
        cd "$repo_root"
        env \
            ICLAUDE_SESSION_ID="loen-verify-$$" \
            MICRO_VM_WORKSPACE_MODE=isolated  ICLAUDE_MICRO_VM_WORKSPACE_MODE=isolated \
            MICRO_VM_WORKSPACE_PATH="$snap"   ICLAUDE_MICRO_VM_WORKSPACE_PATH="$snap" \
            MICRO_VM_SNAPSHOT_ENABLED=false   ICLAUDE_MICRO_VM_SNAPSHOT_ENABLED=false \
            MICRO_VM_SYNC_INTERVAL=0          ICLAUDE_MICRO_VM_SYNC_INTERVAL=0 \
            timeout -k 30 "$timeout_s" \
            "$iclaude_sh" --sandbox-microvm -- \
                --model opus --dangerously-skip-permissions \
                -p "Read the file .loen-verifier-prompt.md in the workspace root and follow its instructions exactly."
    ) </dev/null >"$log" 2>&1 || rc=$?

    # Tripwire 1: iclaude.sh silently downgrades to a HOST launch when microVM is
    # unavailable (lib/launcher/launch.sh) — that verdict would be un-isolated. Refuse.
    if grep -q "Continuing without microVM isolation" "$log"; then
        echo "verify_microvm: launcher fell back to a HOST run — verdict refused (log: ${log})" >&2
        return 2
    fi
    # Tripwire 2: require positive evidence the VM actually booted.
    if ! grep -qE "microVM: (Firecracker started|resumed from snapshot)" "$log"; then
        echo "verify_microvm: no evidence the microVM started (exit ${rc}; log: ${log})" >&2
        return 2
    fi
    # Tripwire 3: host tree must be unchanged (checked BEFORE writing verifier.md).
    local post_fp
    post_fp=$(_tree_fingerprint "$repo_root")
    if [[ "$pre_fp" != "$post_fp" ]]; then
        echo "verify_microvm: HOST TREE CHANGED during isolated verify — verdict refused (log: ${log})" >&2
        return 3
    fi

    local report
    report=$(cmd_extract "$log")
    if [[ -z "$report" ]]; then
        echo "verify_microvm: no LOEN_VERIFIER_BEGIN/END block in output (exit ${rc}; log: ${log})" >&2
        return 2
    fi
    if ! grep -qE '^VERDICT: (APPROVE|REJECT)$' <<<"$report"; then
        echo "verify_microvm: report has no VERDICT line (log: ${log})" >&2
        return 2
    fi

    printf '%s\n' "$report" > "$run_dir/iterations/$iter/verifier.md"
    echo "verify_microvm: verdict written to ${run_dir}/iterations/${iter}/verifier.md (log: ${log})"
}
```

And extend the dispatcher: replace

```bash
case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    snapshot)  shift; [[ $# -eq 3 ]] || usage; _snapshot "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    *) usage ;;
esac
```

with

```bash
case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    snapshot)  shift; [[ $# -eq 3 ]] || usage; _snapshot "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    check)     shift; cmd_check "$@" ;;
    *) usage ;;
esac
```

- [ ] **Step 4: Strengthen the guard tests with message-level asserts and run them**

In `tests/test_loen_verify_microvm.sh`, replace the first `check` guard block

```bash
# contract without microvm isolation → check must refuse (exit 1), not boot anything
if "$V" check "$run" iter-01 2>/dev/null; then
    fail "check must refuse a contract that is not verifier_isolation: microvm"
fi
```

with

```bash
# contract without microvm isolation → check must refuse (exit 1), not boot anything
if out=$("$V" check "$run" iter-01 2>&1); then
    fail "check must refuse a contract that is not verifier_isolation: microvm"
fi
echo "$out" | grep -q "use the subagent dispatch instead" || fail "check refusal message missing"
```

Then:

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected: `PASS test_loen_verify_microvm.sh (unit: preflight + extract + snapshot + check guards)`.

- [ ] **Step 5: Add the gated e2e integration test**

Append to `tests/test_loen_verify_microvm.sh`, AFTER the final unit `echo "PASS ..."` line:

```bash
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
```

Run:

```bash
bash tests/test_loen_verify_microvm.sh
```

Expected on a host without KVM: `SKIP e2e: /dev/kvm absent`. On a KVM host without the env gate: `SKIP e2e: set ICLAUDE_LOEN_E2E=1 …`. With `ICLAUDE_LOEN_E2E=1` and a full microVM install: `PASS e2e: isolated verdict produced`.

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/scripts/verify_microvm.sh tests/test_loen_verify_microvm.sh
git commit -m "feat(loen): isolated verify flow — headless verifier in a Firecracker guest"
```

---

### Task 5: Isolation-aware audit dispatch

**Files:**
- Modify: `plugin/loen/skills/audit/SKILL.md`

**Interfaces:**
- Consumes: `verify_microvm.sh preflight <loop.yaml>` and `verify_microvm.sh check <run-dir> <iter-NN> <checklist-file>` (Tasks 2, 4).
- Produces: skill text every `loen:audit` invocation follows; no code.

- [ ] **Step 1: Update the plan-stage bullet**

In `plugin/loen/skills/audit/SKILL.md`, replace:

```markdown
- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `needs_work` blocks Act.
```

with:

```markdown
- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `verifier_isolation`, when present, MUST be `subagent` or `microvm` — validate
  it AND the host capability with this plugin's
  `scripts/verify_microvm.sh preflight <run-dir>/loop.yaml` (resolved from the skill base
  dir): `microvm` on a host without KVM/Firecracker/images → `needs_work` with the
  script's "install microVM support or drop to `verifier_isolation: subagent`" hint. No
  silent downgrade at plan time. `needs_work` blocks Act.
```

- [ ] **Step 2: Update the check-stage bullet**

In the same file, replace:

```markdown
- **check** — dispatch the `verifier` subagent (isolated); write its verdict to
  `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates ran. `OK` iff the
  verdict is APPROVE and gates are green.
```

with:

```markdown
- **check** — dispatch the verifier per the contract's `verifier_isolation` key
  (`subagent` when absent). `subagent` → dispatch the `verifier` subagent (isolated),
  exactly the MVP path. `microvm` → write the mode-specific checklist (the same text the
  subagent dispatch prompt would carry) to a temp file OUTSIDE the run dir, then run this
  plugin's `scripts/verify_microvm.sh check <run-dir> <iter-NN> <checklist-file>`
  (resolved from the skill base dir): it snapshots the tree, runs the verifier headless
  inside an iclaude Firecracker microVM, and writes the returned text to
  `iterations/iter-NN/verifier.md` unchanged — downstream consumers are agnostic to where
  the verdict was produced. A non-zero exit (VM boot/provision failure, silent host
  fallback, missing verdict, host-tree tripwire) → verdict `needs_work` quoting the
  script's failure log path — NEVER fall back to the in-session subagent; the human may
  edit the contract to `subagent` to proceed un-isolated. In both dispatch modes the
  verdict lands at `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates
  ran. `OK` iff the verdict is APPROVE and gates are green.
```

- [ ] **Step 3: Verify skill lint still passes**

```bash
bash tests/test_loen_plugin.sh
```

Expected: `OK skill audit` among the output, `PASS test_loen_plugin.sh`.

- [ ] **Step 4: Commit**

```bash
git add plugin/loen/skills/audit/SKILL.md
git commit -m "feat(loen): isolation-aware audit dispatch (plan validation + microvm check path)"
```

---

### Task 6: Version bump 0.3.0 → 0.4.0 (both manifests)

**Files:**
- Modify: `plugin/loen/.claude-plugin/plugin.json:4`
- Modify: `.claude-plugin/marketplace.json:18` (the `loen` entry)
- Test: `tests/test_loen_plugin.sh` (existing sync check — no edits)

- [ ] **Step 1: Bump `plugin.json`**

In `plugin/loen/.claude-plugin/plugin.json`, replace:

```json
  "version": "0.3.0",
```

with:

```json
  "version": "0.4.0",
```

- [ ] **Step 2: Run the sync test to see it fail**

```bash
bash tests/test_loen_plugin.sh
```

Expected: FAIL with `version mismatch: marketplace 0.3.0 != plugin 0.4.0`.

- [ ] **Step 3: Bump the marketplace entry**

In `.claude-plugin/marketplace.json`, inside the `"name": "loen"` object, replace:

```json
      "version": "0.3.0",
```

with:

```json
      "version": "0.4.0",
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test_loen_plugin.sh
bash scripts/check-plugin-version-sync.sh
```

Expected: `PASS test_loen_plugin.sh`; version-sync script exits 0.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(loen): bump plugin to 0.4.0 (verifier microVM isolation)"
```

---

### Task 7: Docs + wiki + full suite (spec §9 process obligations)

**Files:**
- Modify: `docs/functions/LOEN.md`, `docs/functions/MICROVM.md`, `plugin/loen/README.md`, `README.md`
- Update via MCP: iwiki page `iclaude/loen-plugin` (domain `iclaude`)

- [ ] **Step 1: LOEN.md — hardening subsection + Scope update**

In `docs/functions/LOEN.md`, insert BEFORE the `## Scope` heading:

```markdown
## Hardening: verifier microVM isolation

Opt-in per run: set `verifier_isolation: microvm` in `loop.yaml` (default `subagent`
keeps MVP behavior byte-for-byte). With `microvm`, `loen:audit check` runs the verifier
as a headless Claude Code session inside an iclaude Firecracker microVM (this plugin's
`scripts/verify_microvm.sh`) against a disposable snapshot of the tree — `git archive
HEAD` + tracked staged/unstaged changes + the run's `docs/loen/<run-id>/` evidence;
untracked files excluded. There is no sync-back channel: the judge is read-only **by
construction**, not by convention. Requires the iclaude microVM install (KVM,
Firecracker, images — see `docs/functions/MICROVM.md`). `loen:audit plan` validates the
key and host capability up front; a VM failure at check time yields `needs_work` with
the failure log — never a silent fallback to the in-session subagent. Cost: VM boot +
snapshot add seconds-to-tens-of-seconds per check iteration, which is why the mode is
opt-in.
```

And in `## Scope`, replace:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`). Verifier microVM isolation and governance/observability are later
increments.
```

with:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`), opt-in verifier microVM isolation (`verifier_isolation: microvm`).
Governance/observability is a later increment.
```

- [ ] **Step 2: MICROVM.md — loen use-case pointer**

In `docs/functions/MICROVM.md`, in the section `## Что такое microVM и зачем`, after the line

```markdown
Полный threat model: [docs/SANDBOX_ANALYSIS.md](SANDBOX_ANALYSIS.md)
```

insert:

```markdown
**Use case — loen verifier:** плагин `loen` (см. [docs/functions/LOEN.md](LOEN.md),
раздел "Hardening") умеет запускать своего loop-верификатора headless внутри этой
microVM над одноразовым снапшотом дерева (`verifier_isolation: microvm` в `loop.yaml`) —
судья не имеет канала записи на хост.
```

- [ ] **Step 3: plugin README bullet**

In `plugin/loen/README.md`, after the `/loen:loop-goal` bullet (ends `never submits /goal itself.`), insert:

```markdown
- `verifier_isolation: microvm` (`loop.yaml`, opt-in) — run the verifier headless inside
  an iclaude Firecracker microVM against a disposable snapshot of the tree: the judge
  cannot touch the worker's tree at all. Requires the iclaude microVM install; default
  `subagent` keeps the in-session verifier.
```

- [ ] **Step 4: Root README (RU) — loen section**

In `README.md`, section `### Loop Engineering (loen)`, after the `**Артефакты:** …` paragraph (ends before the `Подробнее: [docs/functions/LOEN.md]…` line), insert:

```markdown
**Изоляция верификатора (opt-in):** `verifier_isolation: microvm` в `loop.yaml` —
верификатор выполняется headless внутри Firecracker microVM над одноразовым снапшотом
дерева (канала записи на хост нет). Требует установленный microVM
(`./iclaude.sh --install-microvm`); по умолчанию `subagent`. См.
[docs/functions/MICROVM.md](docs/functions/MICROVM.md).
```

- [ ] **Step 5: iwiki `iclaude/loen-plugin` updates (MCP tools, never CLI)**

Three section updates via `wiki_update_page(domain="iclaude", slug="loen-plugin", heading=…, new_body=…, source="plugin/loen/scripts/verify_microvm.sh")`:

1. `heading="Components"` — new_body = the existing Components body with one bullet appended after the `scripts/make_goal.py` bullet:
   > `scripts/verify_microvm.sh` — isolated verify flow (new in 0.4.0): when the contract says `verifier_isolation: microvm`, `loen:audit check` runs this instead of the verifier subagent. Subcommands: `preflight` (plan-stage key + host-capability validation), `snapshot` (disposable tree = `git archive HEAD` + tracked staged/unstaged diff + run artifacts; untracked excluded), `check` (headless `claude -p` in an iclaude Firecracker guest via `iclaude.sh --sandbox-microvm` with `MICRO_VM_WORKSPACE_MODE=isolated`; sentinel-extracted report written to `iterations/iter-NN/verifier.md` unchanged). Three deterministic tripwires: silent host-fallback marker, required boot marker, host-tree fingerprint before/after. Non-zero exit → `needs_work`, never a silent subagent fallback.
2. `heading="loop.yaml contract"` — new_body = existing body with the key list extended: after `eval_command (…)` add `verifier_isolation` (`subagent` default | `microvm` — opt-in hardened verifier dispatch, validated at `loen:audit plan` incl. host capability; new in 0.4.0).
3. `heading="Roadmap and backlog"` — new_body = existing body with: prose paragraph extended with the Increment 3 shipping sentence (0.4.0, actual PR number, test-suite count), and table row `| 3 | Verifier microVM FS isolation … |` status changed from `spec drafted (PR #78, pending review)` to `done (0.4.0, PR #<actual>)`.

Then:

```bash
# via MCP: wiki_lint(domain="iclaude") — expect no broken refs / orphans / stale pages
```

- [ ] **Step 6: Full loen + microVM-adjacent suite**

```bash
bash tests/test_loen_templates.sh
bash tests/test_loen_plugin.sh
bash tests/test_loen_verify_microvm.sh
bash tests/test_loen_layout.sh
bash tests/test_loen_guard.sh
python3 tests/test_loen_hook.py
bash tests/test_microvm.sh
```

Expected: all PASS (e2e section of `test_loen_verify_microvm.sh` prints its SKIP reason unless gated on).

And confirm the doc inserts landed (each exits 0):

```bash
grep -q 'Hardening: verifier microVM isolation' docs/functions/LOEN.md
grep -q 'Use case — loen verifier' docs/functions/MICROVM.md
grep -q 'verifier_isolation: microvm' plugin/loen/README.md
grep -q 'verifier_isolation: microvm' README.md
```

- [ ] **Step 7: Commit**

```bash
git add docs/functions/LOEN.md docs/functions/MICROVM.md plugin/loen/README.md README.md
git commit -m "docs(loen): verifier microVM isolation — LOEN.md hardening section, MICROVM.md pointer, READMEs"
```

---

## Process notes (execution time)

- `docs/TODO.md` row `loen-verifier-microvm` is driven by `/check-chain` (opened at `/check-chain spec`, closed by `/check-chain result`) — not a plan task.
- PR into `dev` via the git-workflow skill; after PR, remove the task worktree if one was created.
- Out of scope (spec §10): microvm as default dispatch, isolating planner/explorer, guest egress policy beyond the iclaude baseline, warm-pool/VM-reuse.

## Self-review (done at plan time)

- **Spec coverage:** §4 contract key → Task 1; §4 plan validation → Tasks 2+5; §4 check dispatch → Tasks 4+5; §5 flow steps 1–5 → Tasks 3–4 (snapshot / provision+verify+collect / teardown via the launcher's own traps + `rm -rf "$snap"`); §5 failure handling → Task 4 tripwires + Task 5 `needs_work` wording; §6 unchanged surfaces → Global Constraints (no task touches `agents/verifier.md`, hook, `check_layout.sh`); §7 delivery → Task 6; §8 tests → Tasks 1–4; §9 docs → Task 7; §10 out of scope → Process notes.
- **Deviations recorded:** snapshot artifact superset, e2e `ICLAUDE_LOEN_E2E=1` gate, exit-code contract — see "Plan-level refinements".
- **Type consistency:** subcommands `preflight|snapshot|extract|check`, helpers `_read_isolation`/`_capability_check`/`_snapshot`/`_tree_fingerprint`/`cmd_extract`, env knobs `LOEN_KVM_DEV`/`LOEN_ICLAUDE_SH`/`LOEN_VERIFY_TIMEOUT`/`LOEN_VERIFY_KEEP_SNAPSHOT`/`ICLAUDE_LOEN_E2E`, sentinels `LOEN_VERIFIER_BEGIN`/`LOEN_VERIFIER_END`, version `0.4.0` — used identically across all tasks.
