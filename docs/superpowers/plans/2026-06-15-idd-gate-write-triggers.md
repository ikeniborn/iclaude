---
review:
  plan_hash: d3d0d706bd6edf8b
  spec_hash: bd526fc2f6b04dd4
  last_run: 2026-06-15
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: structure
      severity: WARNING
      section: "Task 4: plan→impl write trigger + recency window"
      section_hash: 9c303d069361f495
      text: >-
        Task 4 Step 1 embeds a stray `CODE="$( : )"` placeholder line inside the
        test block, then relies on a prose instruction to delete it. Harmless if
        copied verbatim (no-op assignment) but confusing; inline the test cases
        without the placeholder.
      verdict: fixed
      verdict_at: 2026-06-15
    - id: F-002
      phase: coverage
      severity: CRITICAL
      section: "Task 7: Acceptance verification (Bash only — never gated)"
      section_hash: 424d5df0f14207bb
      text: >-
        Spec acceptance #7 ("a forced hook exception results in exit 0, fail-open
        verified") has no test step. The widened matcher runs the hook on every
        Write/Edit, so the broad except-Exception fail-open path around
        handle_write is the highest-risk path — yet it is exercised by neither the
        malformed-stdin nor the null-tool_input case (both exit before reaching it).
        Add a deterministic forced-exception test (e.g. a fresh plan candidate that
        is a directory, so read_frontmatter raises IsADirectoryError) asserting
        exit 0.
      verdict: fixed
      verdict_at: 2026-06-15
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-15-idd-gate-write-triggers-design.md
result_check:
  verdict: OK
  plan_hash: d3d0d706bd6edf8b
  last_run: 2026-06-15
---

# IDD Gate Write-Triggers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `hooks/idd-gate.py` block the inline `spec→plan` and `plan→impl` transitions by gating on the **write of the downstream artifact** (Write/Edit/MultiEdit), not only on `Skill` calls.

**Architecture:** One hook, tool-aware dispatch. `main()` routes `Skill` → `handle_skill()` (existing behaviour) and `Write`/`Edit`/`MultiEdit` → `handle_write()` (new). The gate predicate (`evaluate_gate`), hash pipeline (`body_hash`), and frontmatter reader are reused unchanged — only the trigger differs. Fail-open is preserved: the hook now runs on every write, so non-transition writes MUST take a fast `exit 0` path.

**Tech Stack:** Python 3 (stdlib + PyYAML), bash test harness (stdin-JSON → exit-code), `settings.json` PreToolUse hook wiring.

---

## Execution Ordering Note (read before starting)

After Task 6 widens the `settings.json` matcher to `Skill|Write|Edit|MultiEdit`, the `plan→impl` gate goes **live** — any subsequent `Edit`/`Write` to a file **outside** `docs/superpowers/` is gated by the newest fresh plan (which will be *this* plan). To avoid self-blocking during implementation:

- **Tasks 1–5 edit non-artifact files** (`hooks/idd-gate.py`, `tests/test-idd-gate.sh`, `CLAUDE.md`). These MUST complete **before** the matcher widens. The matcher is still `Skill`-only through Task 5, so these edits are ungated.
- **Task 6** widens the matcher (last file-editing task).
- **Task 7** is verification only and uses **Bash** (`py_compile`, test runner). The design doc states Bash writes bypass the gate, so Task 7 is never gated.

If verification (Task 7) surfaces a fix that needs an `Edit` to the hook, either get this plan validated via `/check-plan` first, or the edit will be gated.

Creating this plan file itself is a `Write` into `docs/superpowers/plans/*.md`, but the `spec→plan` gate is not live yet (matcher is `Skill`-only and `handle_write` does not exist), so writing it now is ungated.

## File Structure

- **Modify** `.nvm-isolated/.claude-isolated/hooks/idd-gate.py` — the gate. Add `block()`, `handle_skill()`, `handle_write()`, `_frontmatter_from_lines()`, `resolve_spec_from_chain()`, `fresh()`, `_under()`; add constants `PLANS_DIR`, `IMPL_GATE_FRESH_SECONDS`, `SPEC_RULE`, `PLAN_RULE`; fix the plan glob in `GATE_MAP`; rewrite `main()` into a tool dispatcher. Single responsibility: gate (block/allow), never validate.
- **Modify** `tests/test-idd-gate.sh` — the hook test suite. Add fixtures (`mk_spec_noreview_at`, `mk_plan_passed`, `mk_plan_cmd_noreview`), JSON builders (`write_json`, `edit_json`), and cases for the glob fix, `spec→plan`, and `plan→impl`.
- **Modify** `.nvm-isolated/.claude-isolated/settings.json:130` — widen the `idd-gate` PreToolUse matcher from `"Skill"` to `"Skill|Write|Edit|MultiEdit"`.
- **Modify** `CLAUDE.md` (project root) — correct the gate description: it is no longer "a PreToolUse Skill hook"; it now also fires on artifact writes.

All paths are relative to the project root `/home/ikeniborn/Documents/Project/iclaude`.

---

## Task 1: Refactor `main()` into a tool dispatcher (no behaviour change)

Pure refactor. Extract the block-message emission into `block()` and the Skill-gate flow into `handle_skill()`; `main()` becomes a dispatcher. The existing test suite is the guard — it must pass before and after.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py:141-177` (the `main()` function)
- Test: `tests/test-idd-gate.sh` (existing suite, run as regression guard)

- [ ] **Step 1: Run the existing suite to establish a green baseline**

Run: `bash tests/test-idd-gate.sh`
Expected: ends with `PASS=N FAIL=0` (all current Skill tests pass).

- [ ] **Step 2: Add `block()` above `main()`**

Insert this function immediately before `def main():` in `idd-gate.py`. It holds the block message previously inlined in `main()`, generalized (drop the Skill-specific "retry the skill invocation" wording):

```python
def block(candidate, reason, fix):
    """Печатает причину в stderr и завершает с кодом 2 (блокировка)."""
    sys.stderr.write(
        "🚧 IDD gate: %s has not passed validation.\n"
        "Reason: %s\n"
        "Action: dispatch a subagent to run %s on %s (clean-context\n"
        "check-runner protocol), collect verdicts in the main session, "
        "resolve the CRITICAL\n"
        "findings, then retry.\n"
        % (candidate, reason, fix, candidate)
    )
    sys.exit(2)
```

- [ ] **Step 3: Add `handle_skill()` above `main()`**

Insert immediately after `block()`. This is the existing Skill flow, lifted out of `main()`:

```python
def handle_skill(data):
    """Gate по вызову Skill (существующий путь IDD→SDD)."""
    skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)  # скилл не гейтируется
    candidate = resolve_candidate(rule)
    if candidate is None:
        sys.exit(0)  # нет артефакта → escape
    reason = evaluate_gate(candidate, rule)
    if reason is None:
        sys.exit(0)
    block(candidate, reason, rule["fix"])
```

- [ ] **Step 4: Replace `main()` with the dispatcher**

Replace the entire existing `def main():` body (lines 141-177) with:

```python
def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # битый stdin → fail-open

    tool = data.get("tool_name")
    try:
        if tool == "Skill":
            handle_skill(data)
        else:
            sys.exit(0)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)
```

Note: `handle_skill()` and `block()` exit via `sys.exit()`, which raises `SystemExit`. `SystemExit` derives from `BaseException`, **not** `Exception`, so the `except Exception` block does **not** swallow it — block (`exit 2`) and escape (`exit 0`) propagate correctly.

- [ ] **Step 5: Run the suite to confirm no regression**

Run: `bash tests/test-idd-gate.sh`
Expected: `PASS=N FAIL=0` — identical to the Step 1 baseline.

- [ ] **Step 6: Verify the file still compiles**

Run: `python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo OK`
Expected: `OK`

- [ ] **Step 7: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py
git commit -m "refactor(idd-gate): split main into dispatch + handle_skill + block

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Fix the plan glob (`*-plan.md` → `*.md`)

`GATE_MAP` resolves plans with `*-plan.md`, but only 2 of 37 plan files match that suffix (measured). The `plans/` directory holds only plans, so the correct glob is `*.md`. Fix it in the three plan rows. TDD via the `executing-plans` Skill against a plan whose name does not end in `-plan.md`.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py:48,52,56` (`glob` values in `GATE_MAP`)
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Write the failing test**

Add the `executing-plans` Skill constant next to the other `SKILL_*` constants (after line 102, `SKILL_FIN=...`):

```bash
SKILL_EP='{"tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'
```

Add this fixture after `mk_plan_noresult` (after line 98):

```bash
mk_plan_cmd_noreview(){ # root → unvalidated plan whose name does NOT end in -plan.md
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-command.md" <<'EOF'
---
chain:
  intent: null
---

# Plan: fix

Plan body content.
EOF
}
```

Add this test block before the final `echo "─────"` summary line (line 142):

```bash
echo "idd-gate: plan glob fix (*.md)"
T=$(mktemp -d); mk_plan_cmd_noreview "$T"
assert_exit "*-command.md plan resolves → 2" "$T" "$SKILL_EP" 2
rm -rf "$T"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test-idd-gate.sh`
Expected: FAIL — `✗ *-command.md plan resolves → 2 (exit=0, ожидался 2)`. Before the fix the glob `*-plan.md` does not match `2026-06-14-fix-command.md`, so `resolve_candidate` returns `None` and the gate escapes with `exit 0`.

- [ ] **Step 3: Fix the glob in `GATE_MAP`**

In `idd-gate.py`, change the three plan rows from `"glob": "*-plan.md"` to `"glob": "*.md"`. The rows are `executing-plans`, `subagent-driven-development`, and `finishing-a-development-branch`. After the edit they read:

```python
    "executing-plans": {
        "dir": "plans", "glob": "*.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "subagent-driven-development": {
        "dir": "plans", "glob": "*.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "finishing-a-development-branch": {
        "dir": "plans", "glob": "*.md",
        "block": "result_check", "hash_key": "plan_hash", "fix": "/check-result",
    },
```

Leave the `brainstorming` (`*-intent.md`) and `writing-plans` (`*-design.md`) rows unchanged — intents and specs are uniformly named.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-idd-gate.sh`
Expected: `✓ *-command.md plan resolves → 2`, and `PASS=N FAIL=0` overall (existing `finishing-a-development-branch` plan tests still pass — their fixtures are named `*-plan.md`, which `*.md` also matches).

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py tests/test-idd-gate.sh
git commit -m "fix(idd-gate): match plans with *.md, not *-plan.md (2/37 matched)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `spec→plan` write trigger

Gate the creation of a plan file. When a `Write` lands in `docs/superpowers/plans/*.md`, resolve the upstream spec — first via the plan's own `chain.spec` frontmatter, falling back to the newest spec — and apply the spec gate predicate. Add `handle_write()` and wire it into `main()`.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py` (constants, helpers, `handle_write`, `main` dispatch, `read_frontmatter` refactor)
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Write the failing tests**

Add these JSON builders after the `bodyhash` helper (after line 13):

```bash
write_json(){ printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
edit_json(){ printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
```

Add this fixture after `mk_spec_noreview` (after line 65) — an unvalidated spec at an arbitrary relative path, used to prove `chain.spec` precedence over the newest-spec fallback:

```bash
mk_spec_noreview_at(){ # root relpath → unvalidated spec at root/relpath
  local f="$1/$2"; mkdir -p "$(dirname "$f")"
  cat > "$f" <<'EOF'
---
chain:
  intent: null
---

# Design: old

Body content for hashing.
EOF
}
```

Add this test block before the final summary line (line 142). Note: `\n` inside the double-quoted content strings are literal backslash-n (bash does not expand them); `printf '%s'` passes them through unchanged, and `json.loads` decodes them into newlines:

```bash
echo "idd-gate: spec→plan write trigger"
PLAN_AT="docs/superpowers/plans/2026-06-15-new.md"
NOCHAIN="---\nchain:\n  intent: null\n---\n\n# Plan\n\nbody"

# chain.spec → validated spec → 0
T=$(mktemp -d); mk_spec_passed "$T"
C="---\nchain:\n  spec: docs/superpowers/specs/2026-06-14-fix-design.md\n---\n\n# Plan\n\nbody"
assert_exit "chain.spec → passed spec → 0" "$T" "$(write_json "$T/$PLAN_AT" "$C")" 0
rm -rf "$T"

# chain.spec → unvalidated spec, even though a NEWER validated spec exists → 2
# (proves chain.spec beats the newest-spec fallback)
T=$(mktemp -d)
mk_spec_noreview_at "$T" "docs/superpowers/specs/2026-06-10-old-design.md"
touch -d '1 hour ago' "$T/docs/superpowers/specs/2026-06-10-old-design.md"
mk_spec_passed "$T"   # 2026-06-14-fix-design.md is newer
C="---\nchain:\n  spec: docs/superpowers/specs/2026-06-10-old-design.md\n---\n\n# Plan\n\nbody"
assert_exit "chain.spec → unvalidated spec → 2" "$T" "$(write_json "$T/$PLAN_AT" "$C")" 2
rm -rf "$T"

# no chain.spec, newest spec validated → 0
T=$(mktemp -d); mk_spec_passed "$T"
assert_exit "fallback newest spec passed → 0" "$T" "$(write_json "$T/$PLAN_AT" "$NOCHAIN")" 0
rm -rf "$T"

# no chain.spec, newest spec unvalidated → 2
T=$(mktemp -d); mk_spec_noreview "$T"
assert_exit "fallback newest spec unvalidated → 2" "$T" "$(write_json "$T/$PLAN_AT" "$NOCHAIN")" 2
rm -rf "$T"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/test-idd-gate.sh`
Expected: the two `→ 2` cases FAIL with `exit=0`. `main()` currently routes everything except `Skill` to `exit 0`, so the unvalidated cases are not yet blocked.

- [ ] **Step 3: Refactor `read_frontmatter` to share a line-based parser**

`resolve_spec_from_chain` parses frontmatter from an in-memory string (the plan content), while `read_frontmatter` parses from a file path. Extract the shared core. Replace the existing `read_frontmatter` (lines 91-104) with:

```python
def _frontmatter_from_lines(lines):
    """YAML-frontmatter между первыми двумя '---'. {} если его нет."""
    import yaml  # отложенный импорт: отсутствие → исключение → fail-open в main()
    if not lines or lines[0].strip() != "---":
        return {}
    fm = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm.append(line)
    data = yaml.safe_load("\n".join(fm))
    return data if isinstance(data, dict) else {}


def read_frontmatter(path):
    """YAML-frontmatter файла. {} если его нет."""
    with open(path, "r", encoding="utf-8") as f:
        return _frontmatter_from_lines(f.read().splitlines())
```

- [ ] **Step 4: Add the `PLANS_DIR` and `SPEC_RULE` constants**

In `idd-gate.py`, add `PLANS_DIR` next to `DOCS_ROOT` (after line 27):

```python
PLANS_DIR = os.path.join(DOCS_ROOT, "plans")
```

Add `SPEC_RULE` immediately after the `GATE_MAP` dict closes (after line 59). It reuses the existing spec row — the predicate is identical, only the trigger differs:

```python
# Write-trigger rules reuse existing GATE_MAP rows (same predicate, new trigger).
SPEC_RULE = GATE_MAP["writing-plans"]      # specs/*-design.md, review/spec_hash
```

- [ ] **Step 5: Add `resolve_spec_from_chain()` and `_under()`**

Insert both after `read_frontmatter`:

```python
def resolve_spec_from_chain(content):
    """Путь к спеке из chain.spec в теле плана (tool_input.content).
    None, если frontmatter/chain.spec нет или файла нет на диске."""
    data = _frontmatter_from_lines((content or "").splitlines())
    chain = data.get("chain")
    spec = chain.get("spec") if isinstance(chain, dict) else None
    if spec and os.path.exists(spec):
        return spec
    return None


def _under(path, root):
    """True, если path лежит внутри root (оба приводятся к абсолютным от cwd)."""
    ap = os.path.abspath(path)
    ar = os.path.abspath(root)
    return ap == ar or ap.startswith(ar + os.sep)
```

- [ ] **Step 6: Add `handle_write()` with the spec→plan branch only**

Insert `handle_write()` immediately after `handle_skill()`. The plan→impl branch is added in Task 4; for now the function handles plan creation and otherwise escapes:

```python
def handle_write(data, tool):
    """Gate по записи downstream-артефакта (inline-переходы spec→plan, plan→impl)."""
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        sys.exit(0)  # нет пути → fail-open

    # spec→plan: создание файла плана (только Write, не Edit).
    if tool == "Write" and _under(path, PLANS_DIR) and path.endswith(".md"):
        content = (data.get("tool_input") or {}).get("content")
        spec = resolve_spec_from_chain(content) or resolve_candidate(SPEC_RULE)
        if spec is None:
            sys.exit(0)  # нет спеки → escape
        reason = evaluate_gate(spec, SPEC_RULE)
        if reason is None:
            sys.exit(0)
        block(spec, reason, SPEC_RULE["fix"])

    sys.exit(0)  # specs/intents, правка существующего плана и т.п.
```

- [ ] **Step 7: Wire `handle_write()` into `main()`**

In `main()`, change the dispatch `else` into an `elif`/`else` pair:

```python
        if tool == "Skill":
            handle_skill(data)
        elif tool in ("Write", "Edit", "MultiEdit"):
            handle_write(data, tool)
        else:
            sys.exit(0)
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bash tests/test-idd-gate.sh`
Expected: all four `spec→plan` cases pass (`✓`), and `PASS=N FAIL=0` overall (the glob-fix and existing Skill tests still pass).

- [ ] **Step 9: Verify the file compiles**

Run: `python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo OK`
Expected: `OK`

- [ ] **Step 10: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py tests/test-idd-gate.sh
git commit -m "feat(idd-gate): gate spec->plan on plan-file Write (chain.spec + fallback)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `plan→impl` write trigger + recency window

Gate code edits. When a `Write`/`Edit`/`MultiEdit` lands **outside** `docs/superpowers/`, resolve the newest plan; if it was edited within the recency window (`IMPL_GATE_FRESH_SECONDS`, 2h) apply the plan gate predicate, otherwise pass through. Writes under `docs/superpowers/` (plan checkbox edits, spec/intent edits) are never gated by this branch.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py` (constants, `fresh`, plan→impl branch in `handle_write`)
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Write the failing tests**

Add this fixture after `mk_plan_cmd_noreview` (added in Task 2):

```bash
mk_plan_passed(){ # root → plan with a passing review block (plan→impl → allow)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-plan.md"
  cat > "$f" <<'EOF'
---
review:
  plan_hash: PLACEHOLDER
  last_run: 2026-06-14
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings: []
---

# Plan: fix

Plan body content.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
}
```

Add this test block before the final summary line:

```bash
echo "idd-gate: plan→impl write trigger"
PLAN_F="docs/superpowers/plans/2026-06-14-fix-plan.md"

# code edit + fresh unvalidated plan → 2
T=$(mktemp -d); mk_plan_noresult "$T"   # chain-only plan, no review block, fresh
assert_exit "Edit code + fresh unvalidated plan → 2" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 2

# Write to a code path is also plan→impl (not mistaken for plan creation) → 2
assert_exit "Write code + fresh unvalidated plan → 2" "$T" "$(write_json "$T/src/x.py" "print(1)")" 2

# non-transition: editing the plan itself (checkbox tick) is never gated → 0
assert_exit "Edit existing plan (checkbox) → 0" "$T" "$(edit_json Edit "$T/$PLAN_F")" 0

# non-transition: editing a spec is never gated by plan→impl → 0
assert_exit "Edit spec → 0" "$T" "$(edit_json Edit "$T/docs/superpowers/specs/x-design.md")" 0
rm -rf "$T"

# code edit + STALE unvalidated plan → 0 (recency window passed)
T=$(mktemp -d); mk_plan_noresult "$T"
touch -d '3 hours ago' "$T/$PLAN_F"
assert_exit "Edit code + stale unvalidated plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# code edit + validated plan → 0
T=$(mktemp -d); mk_plan_passed "$T"
assert_exit "Edit code + validated plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# code edit + no plan at all → 0 (escape)
T=$(mktemp -d)
assert_exit "Edit code + no plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# fail-open: a forced internal exception → 0 (spec acceptance #7).
# The newest plan candidate is a DIRECTORY named *.md → resolve_candidate picks it
# (glob matches dirs), fresh() passes, then evaluate_gate → read_frontmatter →
# open(<dir>) raises IsADirectoryError → caught by main's `except Exception` →
# exit 0. The gate must NEVER block on an internal bug.
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans/2026-06-14-dir-plan.md"
assert_exit "forced exception (dir candidate) → 0 (fail-open)" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/test-idd-gate.sh`
Expected: the two `→ 2` cases FAIL with `exit=0`. `handle_write` currently falls straight to `sys.exit(0)` for non-plan-Write and for Edit, so a fresh unvalidated plan is not yet enforced. The `→ 0` cases already pass (they take the final `exit 0`), but they lock in the correct behaviour once the branch exists.

- [ ] **Step 3: Add the `IMPL_GATE_FRESH_SECONDS` and `PLAN_RULE` constants and `import time`**

Add `time` to the imports (after `import glob`, line 24):

```python
import time
```

Add the recency constant after `BLOCK_ON` (after line 30):

```python
# Recency window for the plan→impl gate: only a plan edited within this many
# seconds gates code edits; older (stale) drafts pass through. 2h.
IMPL_GATE_FRESH_SECONDS = 7200
```

Add `PLAN_RULE` next to `SPEC_RULE` (added in Task 3):

```python
PLAN_RULE = GATE_MAP["executing-plans"]    # plans/*.md, review/plan_hash
```

- [ ] **Step 4: Add the `fresh()` helper**

Insert after `_under()` (added in Task 3):

```python
def fresh(path, seconds):
    """True, если файл изменён не позже `seconds` секунд назад."""
    return time.time() - os.path.getmtime(path) <= seconds
```

- [ ] **Step 5: Add the plan→impl branch to `handle_write()`**

In `handle_write()`, insert this branch **between** the spec→plan branch and the final `sys.exit(0)`:

```python
    # plan→impl: правка файла вне docs/superpowers/ (любой инструмент).
    if not _under(path, DOCS_ROOT):
        plan = resolve_candidate(PLAN_RULE)
        if plan is None:
            sys.exit(0)  # нет плана → escape
        if not fresh(plan, IMPL_GATE_FRESH_SECONDS):
            sys.exit(0)  # устаревший черновик → не гейтим активную работу
        reason = evaluate_gate(plan, PLAN_RULE)
        if reason is None:
            sys.exit(0)
        block(plan, reason, PLAN_RULE["fix"])
```

After this edit `handle_write()` reads, in order: spec→plan branch → plan→impl branch → `sys.exit(0)`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/test-idd-gate.sh`
Expected: every `plan→impl` case passes (`✓`), and `PASS=N FAIL=0` overall.

- [ ] **Step 7: Verify the file compiles**

Run: `python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo OK`
Expected: `OK`

- [ ] **Step 8: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py tests/test-idd-gate.sh
git commit -m "feat(idd-gate): gate plan->impl on code edits, recency-bounded (2h)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Correct the gate description in `CLAUDE.md`

The root `CLAUDE.md` describes the gate as "a `PreToolUse` Skill hook" that "blocks each phase transition." After this change the gate also fires on artifact writes. Correct the description so the docs match behaviour. Done **before** Task 6 (matcher widening) so this non-artifact edit is ungated.

**Files:**
- Modify: `CLAUDE.md` (project root, section "Phase gates & the check-runner protocol")

- [ ] **Step 1: Read the current description**

Run: `grep -n "PreToolUse" CLAUDE.md`
Expected: locates the line `A \`PreToolUse\` Skill hook (\`hooks/idd-gate.py\`) blocks each phase transition until`.

- [ ] **Step 2: Replace the opening sentence of the section**

Replace:

```
A `PreToolUse` Skill hook (`hooks/idd-gate.py`) blocks each phase transition until
the upstream artifact has passed its validator. Mapped transitions:
```

with:

```
A `PreToolUse` hook (`hooks/idd-gate.py`) on `Skill|Write|Edit|MultiEdit` blocks
each phase transition until the upstream artifact has passed its validator. The
`intent→spec` transition is caught on the `Skill` call; `spec→plan` and `plan→impl`
happen inline, so they are caught on the **write** of the downstream artifact (the
plan file, resp. any code edit outside `docs/superpowers/`). Mapped transitions:
```

- [ ] **Step 3: Verify the edit landed**

Run: `grep -n "Skill|Write|Edit|MultiEdit" CLAUDE.md`
Expected: one match in the gate-description sentence.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): gate now fires on artifact writes, not only Skill

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Widen the `settings.json` matcher (gate goes live)

Widen the `idd-gate` PreToolUse matcher so Claude actually invokes the hook on writes. This is the **last file-editing task** — after it, the `plan→impl` gate enforces on every code edit. `block-secrets.py` and `redact-secrets.py` already run on `Write|Edit`; a third fast, fail-open Python hook on those tools is fine.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json:130` (the `idd-gate` matcher)

- [ ] **Step 1: Edit the matcher**

In the `PreToolUse` block, change the `idd-gate` hook's matcher from:

```json
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/idd-gate.py\""
          }
        ]
      }
```

to:

```json
      {
        "matcher": "Skill|Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/idd-gate.py\""
          }
        ]
      }
```

- [ ] **Step 2: Verify the JSON is still valid**

Run: `python3 -c "import json; json.load(open('.nvm-isolated/.claude-isolated/settings.json')); print('valid')"`
Expected: `valid`

- [ ] **Step 3: Confirm the matcher value**

Run: `grep -n "Skill|Write|Edit|MultiEdit" .nvm-isolated/.claude-isolated/settings.json`
Expected: one match.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "feat(idd-gate): wire write triggers — matcher Skill|Write|Edit|MultiEdit

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Acceptance verification (Bash only — never gated)

Run the full acceptance checklist from the spec. Uses only Bash, so the now-live gate does not interfere.

**Files:** none modified.

- [ ] **Step 1: Hook compiles (acceptance #1)**

Run: `python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo OK`
Expected: `OK`

- [ ] **Step 2: Full hook test suite passes (acceptance #2–#7)**

Run: `bash tests/test-idd-gate.sh`
Expected: ends with `PASS=N FAIL=0`. This covers: spec→plan block/allow (chain.spec + fallback), plan→impl fresh-block / stale-allow / validated-allow / no-plan-allow, plan-checkbox-edit never gated, the `*-command.md` glob fix, and fail-open (malformed-stdin, null-tool_input, **and the forced-exception directory-candidate case — acceptance #7**).

- [ ] **Step 3: Confirm the security-hook suite is unaffected**

Run: `python3 -m pytest tests/test_patterns_examples.py -q`
Expected: all tests pass (this change does not touch `block-secrets.py` / `redact-secrets.py`, but the three hooks share the `Write|Edit` matcher, so confirm no interaction regression).

- [ ] **Step 4: Manual smoke — fresh unvalidated plan blocks a code edit (acceptance #3)**

Run:
```bash
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans"
printf -- '---\nchain:\n  intent: null\n---\n\n# Plan\n\nbody\n' > "$T/docs/superpowers/plans/2026-06-15-smoke-plan.md"
( cd "$T" && printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'/lib/x.sh"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/idd-gate.py 2>&1; echo "exit: $?" )
rm -rf "$T"
```
Expected: prints the `🚧 IDD gate:` block message naming `/check-plan`, then `exit: 2`.
Note: run this from the project root so the hook path resolves; the `cd "$T"` is inside the subshell only.

- [ ] **Step 5: Run lat-check (project post-task requirement)**

Run: `lat check`
Expected: passes (no wiki-link or code-ref breakage). The hook lives under `.nvm-isolated/.claude-isolated/hooks/`, outside the `lat.md/`-tracked tree, so no doc-graph update is expected; this step only confirms nothing else broke.

---

## Self-Review

**Spec coverage:**
- Triggers — `spec→plan` (Write into `plans/*.md`) → Task 3; `plan→impl` (Write/Edit/MultiEdit outside `docs/superpowers/`) → Task 4. ✓
- Non-transition passthrough — plan checkbox Edit, spec/intent Edit → Task 4 tests; subagent writes under `docs/superpowers/` covered by the same "`_under(DOCS_ROOT)` → exit 0" logic. ✓
- Candidate resolution — `chain.spec` then newest-spec fallback (Task 3); newest plan, recency-gated (Task 4). ✓
- `fresh()` wall-clock check → Task 4. ✓
- Plan glob fix in both new code (`PLAN_RULE` → `executing-plans` row) and `GATE_MAP` rows → Task 2. ✓
- Invariants — fail-open (`except Exception` verified by malformed-stdin, null-tool_input, and the forced-exception directory-candidate test → acceptance #7), escape hatch (no artifact → exit 0), hash parity (`body_hash` reused unchanged), `evaluate_gate` reused, check-runner block message via `block()`. ✓
- `settings.json` wiring → Task 6. ✓
- Testing list from spec → Tasks 2–4 cases. ✓

**Placeholder scan:** No `TODO`/`TBD`/`???`/`FIXME` or vague-error-handling text; every code step shows complete, copy-ready code.

**Type/name consistency:** `SPEC_RULE` (Task 3) and `PLAN_RULE` (Task 4) both reference `GATE_MAP` rows and are used by `handle_write`. `_frontmatter_from_lines` (Task 3) is consumed by both `read_frontmatter` and `resolve_spec_from_chain`. `handle_write(data, tool)` signature matches the `main()` dispatch call. `fresh(path, seconds)`, `_under(path, root)`, `block(candidate, reason, fix)` signatures match all call sites. `IMPL_GATE_FRESH_SECONDS` defined once (Task 4), used once. Consistent.

**Known limitations (carried from spec, not bugs):** `plan→impl` is topic-blind (newest plan), bounded by the recency window; Bash file writes bypass the gate; the recency window is a speed-bump, not a vault; git operations can reset mtime. Documented, accepted for v1.
