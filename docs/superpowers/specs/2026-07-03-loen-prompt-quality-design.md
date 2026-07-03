---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-03-loen-prompt-quality-design.md
review:
  spec_hash: 1d0bd32a4cdb41b6
  last_run: 2026-07-03
  runner: "main-session (check-runner protocol)"
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings: []
  verdict: OK
---

# loen prompt quality — surgical hardening (design)

Date: 2026-07-03
Topic: loen-prompt-quality
Status: design approved (Middle scope), pending implementation plan

## Benchmark (corrected)

The reference for "good prompt" is the set of **functional** superpowers skills as
exemplars — NOT the `writing-skills` meta-doctrine. Studied (6.1.1):
`brainstorming`, `writing-plans`, `subagent-driven-development` (sdd),
`executing-plans`, `systematic-debugging`.

What those exemplars actually exhibit, and whether loen matches:

| Craft trait (from the functional exemplars) | loen today |
|---|---|
| SHORT trigger-led `description` (11–30 words; a brief what-clause is fine — `brainstorming` has one) | ✗ 40–60 words, whole workflow inlined |
| `Red Flags` self-check list for discipline-under-pressure (sdd "Never:", systematic-debugging "STOP") | ✗ has `## Rules`/`## Stop conditions`, but not a Red-Flags self-check |
| "When to Use / When NOT / use sibling instead" | ✗ absent |
| Decision flowchart (dot digraph) for branch/loop points (brainstorming, sdd) | ✗ absent (linear numbered steps only) |
| Strong imperatives / never-list (sdd, systematic-debugging) | ✓ present ("Never edit the diff", "Never weaken a gate") |
| Subagent + single-writer discipline (sdd File Handoffs) | ✓ present (worker = only writer; subagents return text) |

loen already matches the exemplars on **imperatives and subagent mechanics** (its real
strength). It diverges on **description brevity**, a **Red-Flags** self-check, and
**sibling routing**.

## Principle

Surgical hardening of **form** toward the functional exemplars. **Zero behavior change**
to loop engineering: new prose only RESTATES existing rules or shortens metadata. Bodies'
`## Steps`, sub-agents (`agents/*`), `scripts/`, `hooks/`, and both READMEs keep their
current behavior. The READMEs already carry their own trigger-style table and do not quote
descriptions — untouched.

Scope chosen: **Middle** (short descriptions + Red Flags on the discipline loops + F5).
Decision flowcharts are OUT (heavier, drift toward behavior-shaping; a possible later
track alongside the excluded F2 rationalization tables and F6 baseline pressure-tests).

## Change A — recalibrated descriptions (all 6 skills)

Short, trigger-led (target 22–30 words), sibling loops named as anti-triggers. Workflow
enumeration removed from the description (it already lives in each skill body).

### `skills/loop-delivery/SKILL.md`
> Use when delivering ONE bounded change — a feature, refactor, or chore — as a controlled, audited loop in any repo. Not for a failing test (use loop-repair) or a numeric metric (use loop-autoresearch).

### `skills/loop-repair/SKILL.md`
> Use when a specific test, CI job, or regression is failing and must be fixed under a reproduce-first controlled loop with proven regression coverage. Not for open-ended work (use loop-delivery) or metrics (use loop-autoresearch).

### `skills/loop-autoresearch/SKILL.md`
> Use when improving ONE numeric metric under a controlled research loop with a fixed eval and kept/reverted experiments. Not for a feature (use loop-delivery) or a failing test (use loop-repair).

### `skills/audit/SKILL.md`
> Use when a loen loop stage — plan, act, check, or result — must be validated and gated before the next one. Mode-aware for delivery/repair/research; the execution-loop analog of check-chain.

### `skills/governance/SKILL.md`
> Use when you need a cross-run dashboard over all docs/loen/ runs, or --triage to turn failing runs into proposed next actions (proposals only; never launches loops or edits runs).

### `skills/loop-goal/SKILL.md`
> Use when an active, human-approved loen run should keep going multi-turn on its own — wraps it in Claude's native /goal from loop.yaml. Optional; never bootstraps a run or submits /goal itself.

## Change B — Red Flags block (the 3 discipline loop skills)

Add one `## Red Flags — STOP` section per loop-* skill, near its `## Stop conditions`.
Every bullet RESTATES an existing rule already in that skill's body — nothing new is
introduced. Matches the sdd / systematic-debugging self-check form.

### `skills/loop-delivery/SKILL.md` — Red Flags
```markdown
## Red Flags — STOP

- Editing a `protected_scope` path → stop; the scope IS the contract.
- Weakening or skipping a `quality_gate` to go green → never; fix the code.
- Editing the diff you are verifying, or rubber-stamping your own work → the verifier is independent.
- Auto-merging, or proceeding past a `handoff_conditions` trigger (schema / PII / license / architecture / prod-creds) → hard stop, ask the human.
- Continuing past `budget` → stop; report the best result and the blocker.
```

### `skills/loop-repair/SKILL.md` — Red Flags
```markdown
## Red Flags — STOP

- "Fixing" a failure you have not reproduced → stop; no reproduction, no fix.
- A non-test hunk not required for the failing command to pass → out of scope, drop it.
- Changing tests beyond ADDING the regression test → not allowed.
- Claiming regression coverage without logged inversion evidence (stash → FAIL → pop → PASS) → not proven.
- Auto-merge, or past a `handoff_conditions` trigger, or past `budget.max_iterations` → hard stop.
```

### `skills/loop-autoresearch/SKILL.md` — Red Flags
```markdown
## Red Flags — STOP

- Improving the metric by weakening validation, eval data, or the eval script → never (unless eval design IS the objective).
- More than one main variable changed in an experiment → not isolatable; one variable per experiment.
- Hand-editing `metrics.jsonl` / `experiments.jsonl` → never; append via `log_experiment.py`.
- Treating a tie on the primary as progress → a tie is not an improvement; revert.
- Two consecutive eval failures, or past `budget.max_experiments`, or a `handoff_conditions` trigger → stop.
```

## Change C — F5 nuance clause (`skills/loop-autoresearch/SKILL.md`, ~line 99)

Replace the soft "when possible" nuance clause with a conditional on an observable
predicate (already consistent with the existing "any deviation … MUST be logged" line):

> - Keep seed, model version, eval command, and dataset fixed across experiments; if any must change, log the deviation in the experiment record.

## Not in scope

- **Descriptions on audit/governance/loop-goal get only the recalibration** (Change A); no
  Red Flags block — they are validator / dashboard / optional-wrapper skills, not
  discipline-under-pressure execution loops. `audit`'s existing `## Rules` already serves
  that role.
- **Decision flowcharts** (the broad option), **F2** rationalization tables, **F6**
  baseline pressure-tests — separate track; each is heavier and/or needs the exemplars'
  RED phase (real baseline runs), not pure text.
- Bodies' `## Steps`, `agents/*`, `scripts/`, `hooks/`, READMEs — untouched.

## Invariants

- Every `description` starts with a trigger ("Use when …"); front-matter stays valid YAML
  under 1024 chars; each description 22–30 words.
- Every Red-Flags bullet maps to a rule already present in the same skill's body (a
  restatement, not a new rule).
- Discovery keywords preserved: `loen`, `loop.yaml`, `/goal`, `triage`, failing test,
  metric, `protected_scope`, `quality_gate`.
- No behavior line changed: only `description:` fields, additive Red-Flags sections, and
  the single F5 clause.

## Verification (prompt text, no runtime surface)

1. `grep '^description:'` across the 6 SKILL.md files → each starts with "Use when"; word
   count 22–30.
2. Each Red-Flags bullet traces to an existing rule (map bullet → source line in the same
   file's `## Rules` / `## Stop conditions` / `## Steps`).
3. Front-matter parses as YAML; each description < 1024 chars.
4. `git diff` touches only: 6 `description:` lines, 3 additive `## Red Flags` sections, the
   one `loop-autoresearch` F5 clause — zero edits to existing Steps/Rules logic.
5. `tests/test_loen_plugin.sh` PASS (frontmatter lint: `name:` + `description:` present).

## Branch / PR

- Base: `dev-loen-prompt-hardening` off `dev`.
- Worktree: `wk-dev-loen-prompt-hardening`.
- PR target: `dev`.
