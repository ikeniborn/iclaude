---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-03-loen-prompt-quality-design.md
review:
  spec_hash: 0c1e6d31d46724a4
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
Status: design approved (Middle scope + Change D), pending implementation plan

## Benchmark (corrected)

The reference for "good prompt" is the set of **functional** superpowers skills as
exemplars — NOT the `writing-skills` meta-doctrine. Studied (6.1.1): `brainstorming`,
`writing-plans`, `subagent-driven-development` (sdd), `executing-plans`,
`systematic-debugging`, `test-driven-development` (TDD), `verification-before-completion`
(VBC).

What the exemplars exhibit, and whether loen matches:

| Craft trait (from the functional exemplars) | loen today |
|---|---|
| SHORT trigger-led `description` (11–30 words; a brief what-clause is fine — `brainstorming` has one) | ✗ 40–60 words, whole workflow inlined |
| `Red Flags` self-check list for discipline-under-pressure (sdd "Never:", systematic-debugging / TDD / VBC "STOP") | ✗ has `## Rules`/`## Stop conditions`, but not a Red-Flags self-check |
| Evidence-before-completion self-check (VBC: no completion claim without fresh evidence) | ~ enforced by the verifier + `gates.log`, but the worker has no self-check bullet |
| Test-first discipline for behavior changes (TDD Iron Law) | ✗ `loop-repair` proves regression via inversion evidence, but `loop-delivery` never mandates test-first |
| Strong imperatives / never-list; subagent + single-writer discipline | ✓ present |

loen matches on imperatives, subagent mechanics, and (in `loop-repair`) the TDD red-green
regression proof. It diverges on description brevity, a Red-Flags self-check, an explicit
evidence-before-done bullet, and — in `loop-delivery` — a test-first mandate.

## Principle

Changes **A / B / C** are form-hardening that RESTATE existing rules or shorten metadata —
zero behavior change. Change **D** is ONE deliberate behavior addition (test-first in
`loop-delivery`), explicitly approved to close the gap the TDD exemplar exposes; it is the
single exception to "restatement only". Everything else — sub-agents (`agents/*`),
`scripts/`, `hooks/`, both READMEs, and the other skills' `## Steps` — is unchanged.

loen stays self-contained: Change D encodes test-first in loen's own words; it does NOT add
a cross-plugin dependency on `superpowers:test-driven-development`.

The READMEs already carry their own trigger-style table and do not quote descriptions —
untouched.

## Change A — recalibrated descriptions (all 6 skills)

Short, trigger-led (concise — ≤ 35 whitespace tokens, roughly half the 40–60-token
originals), sibling loops named as anti-triggers. Workflow enumeration removed from the
description (it already lives in each skill body).

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

Add one `## Red Flags — STOP` section per loop-* skill, near its `## Stop conditions` (for
`loop-autoresearch`, after `## Error handling`). Every bullet RESTATES a rule already in
that skill's body (trace column below). The VBC bullet (evidence-before-done) and, for
`loop-delivery`, the TDD bullet (added by Change D) are restatements of existing gates too.

### `skills/loop-delivery/SKILL.md` — Red Flags
```markdown
## Red Flags — STOP

- Writing production code for a behavior change before a failing test exists → delete it; restart test-first.
- Editing a `protected_scope` path → stop; the scope IS the contract.
- Weakening or skipping a `quality_gate` to go green → never; fix the code.
- Editing the diff you are verifying, or rubber-stamping your own work → the verifier is independent.
- Reporting the task done without green gates AND a verifier APPROVE for the final iteration → not done; re-run, don't claim.
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
- Reporting the failure fixed without the originally-failing command exiting 0 in the final `gates.log` → not fixed.
- Auto-merge, or past a `handoff_conditions` trigger, or past `budget.max_iterations` → hard stop.
```

### `skills/loop-autoresearch/SKILL.md` — Red Flags
```markdown
## Red Flags — STOP

- Improving the metric by weakening validation, eval data, or the eval script → never (unless eval design IS the objective).
- More than one main variable changed in an experiment → not isolatable; one variable per experiment.
- Hand-editing `metrics.jsonl` / `experiments.jsonl` → never; append via `log_experiment.py`.
- Treating a tie on the primary as progress → a tie is not an improvement; revert.
- Keeping a change on a claimed metric delta the verifier did not re-confirm → not kept.
- Two consecutive eval failures, or past `budget.max_experiments`, or a `handoff_conditions` trigger → stop.
```

### Red-Flags → existing-rule trace (verification aid)

| Bullet | Source rule already in the body |
|---|---|
| delivery: production code before failing test | Change D (new Act-step rule) |
| delivery: protected_scope / quality_gate / verifier / handoff / budget | Steps 5–8 + `## Rules` + `## Stop conditions` |
| delivery: done without gates + verifier APPROVE | Step 8 + `loen:audit result` |
| repair: reproduce / minimal / regression / inversion | Steps 3–5 + Done condition |
| repair: fixed without failing command exit 0 | Done condition #1 |
| autoresearch: weaken-eval / one variable / no hand-edit / tie / budget | `## Hard rules` + `## Error handling` |
| autoresearch: kept without verifier re-confirm | Step 9 + `loen:audit` research check |

## Change C — F5 nuance clause (`skills/loop-autoresearch/SKILL.md`, ~line 99)

Replace the soft "when possible" nuance clause with a conditional on an observable
predicate (already consistent with the existing "any deviation … MUST be logged" line):

> - Keep seed, model version, eval command, and dataset fixed across experiments; if any must change, log the deviation in the experiment record.

## Change D — test-first mandate in `loop-delivery` (approved behavior addition)

This is the ONE deliberate behavior change. Insert into `loop-delivery`'s Act step
(Step 5), right after "Make the smallest diff toward the objective.":

> When the change adds or alters behavior, work test-first: add a failing test that pins the objective, confirm it fails for the right reason, then write the smallest code that makes it pass. A pure refactor keeps the existing tests green; config/chore work with no behavioral surface is exempt.

The matching Red-Flags bullet is the first bullet of `loop-delivery`'s Red-Flags block
above ("Writing production code for a behavior change before a failing test exists →
delete it; restart test-first"). The three-way conditional (behavior change / pure
refactor / config-chore) is keyed to an observable predicate — mirroring the TDD
exemplar's own scoped exceptions — not a soft nuance clause.

## Not in scope

- **Descriptions on audit/governance/loop-goal get only the recalibration** (Change A); no
  Red Flags block — they are validator / dashboard / optional-wrapper skills, not
  discipline-under-pressure execution loops. `audit`'s existing `## Rules` already serves
  that role.
- **Decision flowcharts** (the broad option), **F2** rationalization tables, **F6**
  baseline pressure-tests — separate track; each is heavier and/or needs the exemplars'
  RED phase (real baseline runs), not pure text.
- Bodies' `## Steps` of skills other than `loop-delivery`'s Act step, `agents/*`,
  `scripts/`, `hooks/`, READMEs — untouched.

## Invariants

- Every `description` starts with a trigger ("Use when …"); front-matter valid YAML under
  1024 chars; each description is concise — ≤ 35 whitespace tokens (roughly half the
  40–60-token originals; the anti-trigger routing costs a few words, and em-dashes count as
  tokens).
- Every Red-Flags bullet maps to a rule in the same skill's body — via an existing rule
  (A/B/C) or via Change D's new Act-step rule for the `loop-delivery` test-first bullet.
- Only `loop-delivery`'s Act step gains a NEW behavior rule (Change D). No other behavior
  line changes: elsewhere only `description:` fields, additive Red-Flags sections, and the
  F5 clause.
- loen stays self-contained: no cross-plugin dependency introduced.
- Discovery keywords preserved: `loen`, `loop.yaml`, `/goal`, `triage`, failing test,
  metric, `protected_scope`, `quality_gate`.

## Verification (prompt text, no runtime surface)

1. `grep '^description:'` across the 6 SKILL.md files → each starts with "Use when"; token
   count ≤ 35 (well under the original 40–60).
2. Each Red-Flags bullet traces to a source rule per the trace table (delivery's first
   bullet traces to the Change D Act-step rule).
3. `loop-delivery` Act step (Step 5) contains "test-first"; its Red-Flags block's first
   bullet is the test-first STOP.
4. Front-matter parses as YAML; each description < 1024 chars.
5. `git diff` touches only: 6 `description:` lines, 3 additive `## Red Flags` sections, the
   one F5 clause, and the one `loop-delivery` Act-step insertion — no other existing rule
   line altered.
6. `tests/test_loen_plugin.sh` PASS.

## Branch / PR

- Base: `dev-loen-prompt-hardening` off `dev`.
- Worktree: `wk-dev-loen-prompt-hardening`.
- PR target: `dev`.
