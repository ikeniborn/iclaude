---
chain:
  spec: docs/superpowers/specs/2026-06-22-session-scoped-idd-gate-design.md
---

# Session-Scoped IDD Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `idd-gate.py` block only the session that owns the IDD artifact, so other concurrent sessions are never gated by an artifact they did not create.

**Architecture:** Add a per-session ownership ledger (`$CLAUDE_CONFIG_DIR/state/idd-sessions.json`) keyed by absolute artifact path. The gate records ownership when a session writes/edits an artifact or invokes a claim-Skill, and resolves gate candidates only among artifacts the current `session_id` owns. No owned candidate → gate open (escape). All changes are confined to `idd-gate.py`; `idd-nudge.py` is untouched.

**Tech Stack:** Python 3 (stdlib only: `os`, `json`, `glob`, `time`, `subprocess`), Bash test harness driving the hook via stdin payloads.

## Global Constraints

- Hook stays **fail-open**: any internal exception → `exit 0` (never block on a bug). All new logic runs under `main`'s existing `try/except`.
- Missing `session_id` → treated as owning nothing → escape (gate open). Copied verbatim from spec.
- Ledger path is `$CLAUDE_CONFIG_DIR/state/idd-sessions.json`; if `CLAUDE_CONFIG_DIR` is unset the ledger is unreachable → every session owns nothing → all gates open.
- Ledger keys are **`os.path.abspath`-normalized** everywhere (record + lookup) so recorded paths (from `tool_input.file_path`) and resolved paths (from relative `glob.glob`) match.
- Ledger writes are atomic (`temp + os.replace`) and best-effort (write errors swallowed).
- `idd-nudge.py` MUST NOT change — a PostToolUse nudge already fires only for the writing session.
- Stdlib only; no new dependencies, no new committed files (the ledger is runtime state).

---

### Task 1: Test-harness session contract (behavior-preserving)

Refactor `tests/test-idd-gate.sh` to the new session contract **without changing the hook yet**. Because the current hook ignores `session_id` and the ledger, seeding ownership and adding `session_id` must leave every existing assertion green — proving the refactor is behavior-preserving. Cross-session and scoped behavior arrive in Task 2.

**Files:**
- Modify: `tests/test-idd-gate.sh`

**Interfaces:**
- Consumes: nothing new (drives the unmodified `idd-gate.py`).
- Produces (test helpers later tasks rely on):
  - `SID_A='sess-A'`, `SID_B='sess-B'` — session id constants.
  - `write_json file content [sid]` / `edit_json tool file [sid]` — payloads now embed `"session_id"` (default `$SID_A`).
  - `seed_owner root relpath sid` — writes `root/state/idd-sessions.json` with `{abspath(root/relpath): {session: sid, ts: now}}` (merges if present).
  - `run` exports `CLAUDE_CONFIG_DIR="$1"` so the ledger is isolated per temp root.
  - Every `mk_*` fixture seeds ownership of the artifact it creates for `$SID_A`.

- [ ] **Step 1: Add session constants + `seed_owner`, and export `CLAUDE_CONFIG_DIR` in `run`**

Replace the `run` helper (line 18) and the two payload helpers (lines 14-15), and add the new helpers right after them:

```bash
SID_A='sess-A'; SID_B='sess-B'

# write_json file content [sid] ; edit_json tool file [sid]  (sid defaults to SID_A)
write_json(){ printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "${3:-$SID_A}" "$1" "$2"; }
edit_json(){  printf '{"session_id":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "${3:-$SID_A}" "$1" "$2"; }

# seed_owner root relpath sid — record ownership in the temp-root ledger.
seed_owner(){
  python3 - "$1/state/idd-sessions.json" "$1/$2" "$3" <<'PY'
import json, os, sys, time
ledger, artifact, sid = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(ledger), exist_ok=True)
data = {}
if os.path.exists(ledger):
    try:
        with open(ledger) as f: data = json.load(f)
    except Exception: data = {}
data[os.path.abspath(artifact)] = {"session": sid, "ts": int(time.time())}
with open(ledger, "w") as f: json.dump(data, f)
PY
}

# Runs the hook in project-root $1 with an isolated ledger; prints exit code.
run(){ ( cd "$1" && printf '%s' "$2" | CLAUDE_CONFIG_DIR="$1" python3 "$HOOK" >/dev/null 2>&1; echo $? ); }
```

Also add `session_id` to the four static Skill payloads (lines 153-156):

```bash
SKILL_WP='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"writing-plans"}}'
SKILL_WP_NS='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
SKILL_FIN='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"finishing-a-development-branch"}}'
SKILL_EP='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'
```

- [ ] **Step 2: Seed ownership inside every `mk_*` fixture**

Append a `seed_owner` call at the end of each fixture so its artifact is owned by `$SID_A`. Add these lines:

- `mk_spec_passed` (after the `sed` on line 52): `seed_owner "$1" "docs/superpowers/specs/2026-06-14-fix-design.md" "$SID_A"`
- `mk_spec_noreview_at` (after the heredoc, line 67): `seed_owner "$1" "$2" "$SID_A"`
- `mk_spec_noreview` (end, line 81): `seed_owner "$1" "docs/superpowers/specs/2026-06-14-fix-design.md" "$SID_A"`
- `mk_plan_result` (before `echo "$f"`, line 99): `seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"`
- `mk_plan_noresult` (end, line 114): `seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"`
- `mk_plan_cmd_noreview` (end, line 128): `seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-command.md" "$SID_A"`
- `mk_plan_passed` (after `sed`, line 150): `seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"`

- [ ] **Step 3: Seed ownership for the dir-candidate fail-open test**

The forced-exception test (lines 269-270) needs the directory candidate owned by `$SID_A`, so scoped resolution returns it and `evaluate_gate` reaches `open(<dir>)`. Change:

```bash
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans/2026-06-14-dir-plan.md"
seed_owner "$T" "docs/superpowers/plans/2026-06-14-dir-plan.md" "$SID_A"
assert_exit "forced exception (dir candidate) → 0 (fail-open)" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"
```

- [ ] **Step 4: Run the full suite against the UNMODIFIED hook**

Run: `bash tests/test-idd-gate.sh`
Expected: `PASS=N FAIL=0` — identical pass count to before the refactor. The old hook ignores `session_id`/ledger, so seeding is inert and every exit code is unchanged. This proves the refactor is behavior-preserving.

- [ ] **Step 5: Commit**

```bash
git add tests/test-idd-gate.sh
git commit -m "test(idd): add session_id + ownership-ledger contract to gate tests

Behavior-preserving against the current global gate (session_id/ledger ignored);
prepares the harness for session-scoped resolution."
```

---

### Task 2: Session-scoped candidate resolution

Thread `session_id` through resolution so the gate only considers artifacts the current session owns. This is the core fix.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Modify: `tests/test-idd-gate.sh` (add cross-session + no-session_id + corrupt-ledger cases)

**Interfaces:**
- Produces (consumed by Task 3):
  - `ledger_path() -> str|None`
  - `load_ledger() -> dict` (`{abspath: {"session": str, "ts": int}}`, pruned)
  - `record_owner(path: str, sid: str) -> None`
  - `owns(path: str, sid: str, ledger: dict) -> bool`
  - `_is_artifact(path: str) -> bool`
  - `record_ownership(data: dict, tool: str, sid: str) -> None` (artifact branch only; claim branch added in Task 3)
  - `resolve_candidate(rule: dict, sid: str) -> str|None` (signature gains `sid`)
  - `handle_skill(data, sid)`, `handle_write(data, tool, sid)` (signatures gain `sid`)

- [ ] **Step 1: Write the failing cross-session test**

Add a new section after the `plan→impl write trigger` block (after line 246, inside the same kind of temp-root setup). Add to `tests/test-idd-gate.sh`:

```bash
echo "idd-gate: session scoping"

# Session B edits code; a FRESH unvalidated plan owned by Session A exists.
# Session B created nothing IDD-related → must NOT be blocked.
T=$(mktemp -d); mk_plan_noresult "$T"   # plan owned by SID_A, fresh, unvalidated
assert_exit "cross-session: B edits code, A owns plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh" "$SID_B")" 0
rm -rf "$T"
```

- [ ] **Step 2: Run it to confirm RED against the current hook**

Run: `bash tests/test-idd-gate.sh 2>&1 | grep 'cross-session'`
Expected: `✗ cross-session: B edits code, A owns plan → 0 (exit=2, ожидался 0)` — the global hook finds A's fresh unvalidated plan and blocks B.

- [ ] **Step 3: Add ledger primitives to `idd-gate.py`**

Insert after the `PLAN_RULE` definition (after line 69), before `normalize_skill`:

```python
LEDGER_MAX_AGE_SECONDS = 7 * 24 * 3600  # prune backstop for stale entries
ARTIFACT_DIRS = ("intents", "specs", "plans")


def ledger_path():
    """Path to the ownership ledger, or None when CLAUDE_CONFIG_DIR is unset
    (→ ledger unreachable → every session owns nothing → all gates open)."""
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    return os.path.join(cfg, "state", "idd-sessions.json") if cfg else None


def load_ledger():
    """Ledger {abspath: {"session", "ts"}}; {} on missing/corrupt (fail-open).
    Prunes entries whose artifact is gone or older than the max-age backstop."""
    path = ledger_path()
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, ValueError, OSError):
        return {}
    if not isinstance(data, dict):
        return {}
    now = time.time()
    out = {}
    for key, val in data.items():
        if not isinstance(val, dict) or not os.path.exists(key):
            continue
        if now - val.get("ts", 0) > LEDGER_MAX_AGE_SECONDS:
            continue
        out[key] = val
    return out


def record_owner(path, sid):
    """Stamp `sid` as owner of `path` (abspath-keyed, last-writer-wins).
    Atomic write; failures are swallowed (ownership is best-effort)."""
    lp = ledger_path()
    if not lp or not sid:
        return
    ledger = load_ledger()
    ledger[os.path.abspath(path)] = {"session": sid, "ts": int(time.time())}
    try:
        os.makedirs(os.path.dirname(lp), exist_ok=True)
        tmp = lp + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(ledger, f)
        os.replace(tmp, lp)
    except OSError:
        pass


def owns(path, sid, ledger):
    """True if `sid` owns `path` per the (pre-loaded) ledger."""
    if not sid:
        return False
    entry = ledger.get(os.path.abspath(path))
    return isinstance(entry, dict) and entry.get("session") == sid


def _is_artifact(path):
    """True if `path` lies under one of the IDD artifact directories."""
    return any(_under(path, os.path.join(DOCS_ROOT, d)) for d in ARTIFACT_DIRS)


def record_ownership(data, tool, sid):
    """Stamp ownership for the artifact this call touches. The claim branch for
    executing-plans / subagent-driven-development is added in a later task."""
    if tool in ("Write", "Edit", "MultiEdit"):
        path = (data.get("tool_input") or {}).get("file_path")
        if path and _is_artifact(path):
            record_owner(path, sid)
```

(`_is_artifact` calls `_under`, which is defined later in the file at line 132; that is fine — both are module-level functions resolved at call time, not import time.)

- [ ] **Step 4: Scope `resolve_candidate` and thread `sid` through the handlers + `main`**

Replace `resolve_candidate` (lines 77-84) with:

```python
def resolve_candidate(rule, sid):
    """Newest glob-matching artifact OWNED BY `sid`. None if none owned —
    escape: a session is gated only by artifacts it owns. None with no matches
    at all is the existing hotfix escape (no IDD docs)."""
    pattern = os.path.join(DOCS_ROOT, rule["dir"], rule["glob"])
    matches = glob.glob(pattern)
    if not matches:
        return None
    ledger = load_ledger()
    owned = [m for m in matches if owns(m, sid, ledger)]
    if not owned:
        return None
    return max(owned, key=os.path.getmtime)
```

In `handle_write` (line 192) change the signature to `def handle_write(data, tool, sid):` and pass `sid` to both `resolve_candidate` calls:
- line 201: `spec = resolve_spec_from_chain(content) or resolve_candidate(SPEC_RULE, sid)`
- line 211: `plan = resolve_candidate(PLAN_RULE, sid)`

In `handle_skill` (line 224) change the signature to `def handle_skill(data, sid):` and line 230 to `candidate = resolve_candidate(rule, sid)`.

In `main` (lines 239-256), parse `session_id`, record ownership, and pass `sid`:

```python
def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # битый stdin → fail-open

    tool = data.get("tool_name")
    sid = data.get("session_id")
    try:
        record_ownership(data, tool, sid)
        if tool == "Skill":
            handle_skill(data, sid)
        elif tool in ("Write", "Edit", "MultiEdit"):
            handle_write(data, tool, sid)
        else:
            sys.exit(0)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)
```

- [ ] **Step 5: Run the cross-session test to confirm GREEN**

Run: `bash tests/test-idd-gate.sh 2>&1 | grep 'cross-session'`
Expected: `✓ cross-session: B edits code, A owns plan → 0`

- [ ] **Step 6: Add no-session_id and corrupt-ledger escape cases**

Append to the `session scoping` section in `tests/test-idd-gate.sh`:

```bash
# No session_id in payload → cannot scope → escape (fail-open).
T=$(mktemp -d); mk_plan_noresult "$T"
assert_exit "no session_id → 0" "$T" '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'/lib/foo.sh"}}' 0
rm -rf "$T"

# Corrupt ledger → load_ledger returns {} → owns-nothing → escape.
T=$(mktemp -d); mk_plan_noresult "$T"
mkdir -p "$T/state"; printf 'garbage{' > "$T/state/idd-sessions.json"
assert_exit "corrupt ledger → 0 (fail-open)" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"
```

- [ ] **Step 7: Run the full suite**

Run: `bash tests/test-idd-gate.sh`
Expected: `PASS=N FAIL=0` (N grew by the three new session-scoping cases). Existing same-session block/allow cases stay green because their fixtures seed `$SID_A` and their payloads default to `$SID_A`.

- [ ] **Step 8: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py tests/test-idd-gate.sh
git commit -m "feat(idd): scope phase gate by owning session

Resolve gate candidates only among artifacts the current session_id owns,
recorded in a $CLAUDE_CONFIG_DIR/state ledger. A session that produced no IDD
artifact (or a different session's) escapes the gate. Fixes cross-session
false blocks. Missing session_id / unreachable ledger → fail-open."
```

---

### Task 3: Claim for executing-plans / subagent-driven-development

A session implementing a plan it did not author must still be gated by it. When such a session invokes the implementation skill, claim the globally-newest plan into its ownership.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Modify: `tests/test-idd-gate.sh`

**Interfaces:**
- Consumes: `record_owner`, `PLAN_RULE`, `normalize_skill` (Task 2).
- Produces: `newest_plan() -> str|None`; `CLAIM_SKILLS` set; claim branch in `record_ownership`.

- [ ] **Step 1: Write the failing claim test**

Append to the `session scoping` section in `tests/test-idd-gate.sh`:

```bash
# Claim: a session that owns NO plan invokes executing-plans. The claim stamps
# the newest plan into its ownership, so the unvalidated plan still gates it.
T=$(mktemp -d); mk_plan_noresult "$T"   # plan owned by SID_A, unvalidated
EP_B='{"session_id":"sess-B","tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'
assert_exit "claim: EP by non-owner B → 2" "$T" "$EP_B" 2
rm -rf "$T"
```

- [ ] **Step 2: Confirm RED**

Run: `bash tests/test-idd-gate.sh 2>&1 | grep 'claim:'`
Expected: `✗ claim: EP by non-owner B → 2 (exit=0, ожидался 2)` — without claim, B owns nothing → scoped resolve returns None → escape → 0.

- [ ] **Step 3: Add `newest_plan` + the claim branch**

Add `newest_plan` next to the other resolvers in `idd-gate.py` (after `resolve_candidate`):

```python
def newest_plan():
    """Newest plan across the repo, ignoring ownership — used at claim time."""
    pattern = os.path.join(DOCS_ROOT, PLAN_RULE["dir"], PLAN_RULE["glob"])
    matches = glob.glob(pattern)
    return max(matches, key=os.path.getmtime) if matches else None
```

Add `CLAIM_SKILLS` next to `ARTIFACT_DIRS`:

```python
CLAIM_SKILLS = {"executing-plans", "subagent-driven-development"}
```

Extend `record_ownership` with the Skill branch:

```python
def record_ownership(data, tool, sid):
    """Stamp ownership for the artifact this call touches (Write/Edit/MultiEdit
    of an artifact) or claims (executing-plans / subagent-driven-development →
    the newest plan, so an implementing session is gated by it)."""
    if tool in ("Write", "Edit", "MultiEdit"):
        path = (data.get("tool_input") or {}).get("file_path")
        if path and _is_artifact(path):
            record_owner(path, sid)
    elif tool == "Skill":
        skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
        if skill in CLAIM_SKILLS:
            plan = newest_plan()
            if plan:
                record_owner(plan, sid)
```

- [ ] **Step 4: Confirm GREEN + add the subagent-driven variant**

Run: `bash tests/test-idd-gate.sh 2>&1 | grep 'claim:'`
Expected: `✓ claim: EP by non-owner B → 2`

Then append the second claim skill case and re-run:

```bash
T=$(mktemp -d); mk_plan_noresult "$T"
SDD_B='{"session_id":"sess-B","tool_name":"Skill","tool_input":{"skill":"subagent-driven-development"}}'
assert_exit "claim: subagent-driven by non-owner B → 2" "$T" "$SDD_B" 2
rm -rf "$T"
```

- [ ] **Step 5: Run the full suite**

Run: `bash tests/test-idd-gate.sh`
Expected: `PASS=N FAIL=0`.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py tests/test-idd-gate.sh
git commit -m "feat(idd): claim newest plan on executing-plans / subagent-driven-development

A session implementing a plan it did not author claims the newest plan at skill
invocation, so plan→impl gating still applies within the implementing session."
```

---

### Task 4: Prune backstop test + docs

Lock down the max-age prune with an integration assertion and document session scoping where the gate is described.

**Files:**
- Modify: `tests/test-idd-gate.sh`
- Modify: `CLAUDE.md` (project root — the IDD→SDD gate section, ~lines 33-90)

- [ ] **Step 1: Add the prune assertion**

A stale ledger entry (old `ts`) must be dropped on the next `load_ledger`, so the once-owned artifact no longer gates. Append to `tests/test-idd-gate.sh`:

```bash
echo "idd-gate: ledger prune"
# Stale ownership entry (8 days old) is pruned on load → owns-nothing → escape.
T=$(mktemp -d); mk_plan_noresult "$T"
python3 - "$T/state/idd-sessions.json" "$T/docs/superpowers/plans/2026-06-14-fix-plan.md" <<'PY'
import json, os, sys, time
ledger, art = sys.argv[1], sys.argv[2]
data = {os.path.abspath(art): {"session": "sess-A", "ts": int(time.time()) - 8*24*3600}}
with open(ledger, "w") as f: json.dump(data, f)
PY
assert_exit "stale ownership pruned → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"
```

- [ ] **Step 2: Run the prune test**

Run: `bash tests/test-idd-gate.sh 2>&1 | grep 'prune\|stale ownership'`
Expected: `✓ stale ownership pruned → 0`. (The fixture's own `seed_owner` writes a fresh entry, so Step 1's heredoc overwrites the ledger with only the stale entry to isolate the prune path.)

- [ ] **Step 3: Run the full suite**

Run: `bash tests/test-idd-gate.sh`
Expected: `PASS=N FAIL=0`.

- [ ] **Step 4: Document session scoping in `CLAUDE.md`**

In the project-root `CLAUDE.md`, in the paragraph describing the gate (the block starting "A `PreToolUse` hook (`hooks/idd-gate.py`) ..."), add one sentence after the transitions table / "fails open" description:

> **Session scoping.** The gate resolves candidates only among artifacts the
> current `session_id` owns — recorded in `$CLAUDE_CONFIG_DIR/state/idd-sessions.json`
> when a session writes/edits an artifact or invokes
> `executing-plans`/`subagent-driven-development`. A session that produced no
> IDD artifact is never gated by another session's in-progress spec/plan.
> Missing `session_id` or an unreachable ledger → fail-open.

- [ ] **Step 5: iwiki lint (docs health)**

Run: `/iwiki-lint`
Expected: no broken `[[refs]]`, no new orphan/stale pages. (No `docs/wiki/` page documents the IDD gate today; the gate lives in `CLAUDE.md`, so no `iwiki-ingest` target is created — confirm lint stays clean.)

- [ ] **Step 6: Commit**

```bash
git add tests/test-idd-gate.sh CLAUDE.md
git commit -m "test(idd): assert stale-ownership prune; docs: note gate session scoping"
```

---

## Self-Review

**Spec coverage:**
- Repo-global → session-scoped resolution — Task 2 (`resolve_candidate(rule, sid)`).
- Ledger in `$CLAUDE_CONFIG_DIR/state/` — Task 2 (`ledger_path`/`load_ledger`/`record_owner`).
- Ownership via Write/Edit/MultiEdit of an artifact — Task 2 (`record_ownership` artifact branch).
- Ownership via claim on executing-plans/subagent-driven-development — Task 3.
- `chain.spec` stays authoritative, only fallback scoped — Task 2 Step 4 (line 201 keeps `resolve_spec_from_chain` first).
- `fresh()` 2h retained — Task 2 leaves `handle_write` plan→impl freshness check intact.
- Missing `session_id` → fail-open — Task 2 Step 6 (`no session_id → 0`).
- Atomic best-effort write, last-writer-wins — Task 2 Step 3 (`record_owner`).
- Prune (missing file + 7-day backstop) — Task 2 (`load_ledger`) + Task 4 assertion.
- `idd-nudge.py` unchanged — no task touches it.
- Test matrix (bug regression, same-session, no session_id, claim, prune) — Tasks 2-4.

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every run step states expected output.

**Type consistency:** `resolve_candidate(rule, sid)` signature is consistent across `handle_skill`/`handle_write`/`main`. `owns(path, sid, ledger)` takes a pre-loaded ledger (loaded once per `resolve_candidate`). `record_owner(path, sid)` vs `record_ownership(data, tool, sid)` are distinct and used consistently. Ledger keys are `os.path.abspath`-normalized in both `record_owner` and `owns`, matching `seed_owner`'s key.
