---
review:
  spec_hash: ""
  last_run: 2026-05-26
  phases:
    structure:   { status: pending }
    coverage:    { status: pending }
    clarity:     { status: pending }
    consistency: { status: pending }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-05-26-check-result-intent.md
---
# check-result Command + IDD→SDD Chain Navigation Design

**Date:** 2026-05-26
**Scope:** `.nvm-isolated/.claude-isolated/commands/verify.md` → `check-result.md`, `check-spec.md`, `check-plan.md`
**Intent:** `docs/superpowers/intents/2026-05-26-check-result-intent.md`

---

## Problem

After executing a plan, no command verifies that what was built matches what was intended (intent → spec → plan → git diff). The IDD→SDD chain is also navigationally broken: `check-spec` and `check-plan` do not store links to upstream documents, requiring manual file lookup to pass context to a result-checker.

---

## Architecture

```
/idd          → intent doc      (docs/superpowers/intents/)
/brainstorm   → spec            (docs/superpowers/specs/)
/check-spec   → validates spec  ─┐ writes chain: block to frontmatter
/check-plan   → validates plan  ─┘ writes chain: block to frontmatter
[execution]   → git diff
/check-result → verifies result against full chain
```

Each command ends its report with a "Previous step:" footer pointing to its upstream document(s).

---

## chain: Frontmatter Block

Written by `check-spec` into the **spec file** frontmatter:

```yaml
chain:
  intent: docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md
```

Written by `check-plan` into the **plan file** frontmatter:

```yaml
chain:
  intent: docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md
  spec:   docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
```

`null` when the upstream document cannot be located. The `chain:` block is separate from the `review:` block — it does not interfere with hash logic, phases, or findings.

---

## Changes to check-spec.md

### Step 1 additions

When determining scope, also resolve the intent doc path:
- If `$ARGUMENTS` contains a second path pointing to an intent doc — use it
- Else if an intent doc is referenced in conversation context — use it
- Else — auto-discover: extract `<topic>` from spec filename (`YYYY-MM-DD-<topic>-design.md`), search `docs/superpowers/intents/` for `*<topic>*intent.md`
- If not found — set `intent: null`, continue without blocking

### Step 2 additions

After initializing the `review:` block, also initialize `chain:` if absent:

```yaml
chain:
  intent: <resolved path or null>
```

Hash logic, phases, and findings are unchanged.

### Report footer (append to existing format)

```
---
Previous step: <intent_path>
```

If `intent: null` — omit footer line.

---

## Changes to check-plan.md

### Step 1 additions

Resolve both intent and spec paths:
- Spec path: already known (the spec being checked against)
- Intent path: read `chain.intent` from spec frontmatter if present; else extract `<topic>` from plan filename and search `docs/superpowers/intents/` for `*<topic>*intent.md`

### Step 2 additions

Initialize `chain:` in plan frontmatter if absent:

```yaml
chain:
  intent: <resolved path or null>
  spec:   <spec path>
```

Hash logic, phases, and findings are unchanged.

### Report footer (append to existing format)

```
---
Previous step: <spec_path>
```

If intent is also known, append:

```
Chain: <intent_path> → <spec_path> → <plan_path>
```

---

## check-result.md (replaces verify.md)

`verify.md` is renamed and fully rewritten. The old code-review behavior (syntax checks, security scan, git diff quality review) is removed.

### Input

```
$ARGUMENTS = path/to/plan.md  [required]
             --since=<ref>    [optional, overrides HEAD diff base]
```

### Algorithm

**Step 1. Load plan**
- Read plan file from `$ARGUMENTS`
- Extract `chain.intent` and `chain.spec` from frontmatter
- If missing: extract `<topic>` from plan filename (`YYYY-MM-DD-<topic>-plan.md`), search `docs/superpowers/intents/` for `*<topic>*intent.md` and `docs/superpowers/specs/` for `*<topic>*design.md`
- If plan not found: halt with error "Plan not found. Specify path: `/check-result path/to/plan.md`"
- If intent or spec not found: warn, continue with available documents

**Step 2. Load documents**
- Intent doc: read Objective, Desired Outcomes, Constraints
- Spec: read requirements and success criteria sections
- Plan: read all steps (both `[ ]` and `[x]`)

**Step 3. Get git diff**
- Run: `git diff HEAD` (staged + unstaged)
- If diff is empty: report "No uncommitted changes found. Run after making changes or pass `--since=<ref>`."

**Step 4. Match plan steps to diff**

For each plan step:
1. Extract explicit file paths mentioned in the step text
2. Check if those files appear in `git diff HEAD`
3. For steps without explicit file paths: match semantically against diff content
4. Classify each step:
   - `DONE` — diff contains changes matching the step
   - `PARTIAL` — diff contains some but not all expected changes
   - `MISSING` — no diff evidence for this step

Also identify `EXCESS`: changed files with no corresponding plan step.

**Step 5. Check intent + spec coverage**

- For each Desired Outcome in the intent doc: is it reflected in the diff?
- For each requirement/success criterion in the spec: is it reflected in the diff?
- Missing coverage → finding with reference to the specific outcome/requirement

**Step 6. Generate report**

### Severity

| Severity | Condition |
|----------|-----------|
| `[CRITICAL]` | Plan step completely absent from diff |
| `[WARNING]` | Plan step partial; or excess changes unrelated to plan |
| `[INFO]` | Minor semantic mismatch; intent outcome only partially evidenced |

### Finding format

Each finding includes:
- **Plan:** what the plan step says
- **Diff:** what git diff shows (or "no changes found")
- **Fix options:** e.g., `commit missing changes` / `revert excess` / `update plan to reflect actual scope`

### Report format

```
## Result Check [date]

### Documents
- Plan:   <path> (chain.intent: <path>, chain.spec: <path>)
- Spec:   <path>
- Intent: <path>
- Diff base: git diff HEAD (<N> files changed)

### Plan Step Coverage
- DONE:    N steps
- PARTIAL: N steps
- MISSING: N steps

### Findings

#### [CRITICAL] Step 3: Rename verify.md to check-result.md
**Plan:** Rename `.nvm-isolated/.claude-isolated/commands/verify.md` to `check-result.md`
**Diff:** No rename found in diff. `verify.md` unchanged.
**Fix options:**
  1. `git mv verify.md check-result.md`
  2. Update plan to mark this step deferred

...

### Intent / Spec Coverage
- Desired Outcomes covered: N/M
- Spec requirements covered: N/M
- [WARNING] Desired Outcome "chain navigation in report footer" — no footer additions found in diff

### Excess Changes
- [WARNING] `lib/foo.sh` modified — no corresponding plan step

### Summary
- CRITICAL: N  WARNING: N  INFO: N
- Verdict: OK | requires attention

---
Previous step: <plan_path>
Chain: <intent_path> → <spec_path> → <plan_path>
```

---

## Success Criteria

1. `/check-result path/to/plan.md` produces a report covering all plan steps, intent outcomes, and spec requirements against git diff
2. `check-spec` writes `chain.intent` to spec frontmatter; report includes `Previous step:` footer
3. `check-plan` writes `chain.intent` + `chain.spec` to plan frontmatter; report includes `Previous step:` footer
4. Passing only a plan path to `check-result` resolves intent and spec automatically via `chain:` frontmatter
5. Existing `check-spec` and `check-plan` phase models, hash logic, and findings format are unchanged
