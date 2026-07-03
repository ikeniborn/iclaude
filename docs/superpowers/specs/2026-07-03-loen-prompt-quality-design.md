# loen prompt quality — surgical hardening (design)

Date: 2026-07-03
Topic: loen-prompt-hardening
Status: design approved, pending implementation plan

## Problem

The `plugin/loen` skill prompts are technically strong and discipline-strict, but their
**form** diverges from the reference standard defined by
`superpowers/skills/writing-skills/SKILL.md` in two systemic ways:

- **F1 (all 6 skills):** every `description` front-matter field summarizes the skill's
  workflow instead of stating triggering conditions. `writing-skills` warns (with eval
  evidence) that a workflow-summarizing description becomes a shortcut agents follow
  *instead of* reading the skill body.
- **F5 (`loop-autoresearch`):** a discipline rule carries a soft nuance clause
  ("…fixed when possible"), which `writing-skills` explicitly flags ("No nuance clauses —
  reopens the negotiation").

A related gap, **F4** (no "when NOT to use / which sibling loop instead" guidance), is
folded into the F1 rewrite as anti-triggers rather than duplicated body sections.

Out of scope (require the reference standard's RED phase — baseline pressure tests — and
are not pure text edits): **F2** (rationalization tables / red-flag lists) and **F6**
(TDD-for-skills baseline testing). **F3** (restructuring dense procedural prose) is
deliberately excluded: `superpowers/CLAUDE.md` states that reformatting behavior-shaping
skill content without eval evidence is unacceptable, and the loen loop bodies are
behavior-shaping.

## Principle

Surgical hardening of **form** against the reference standard. **Zero behavior change** to
loop engineering. Every changed line traces to F1, F4, or F5. Bodies (`## Steps`,
`## Rules`, `## Stop conditions`), sub-agents (`agents/*`), `scripts/`, `hooks/`, and both
READMEs are untouched.

The READMEs already use their own trigger-style table (e.g. "Fix a failing test / CI /
regression"); they do not quote the front-matter descriptions and describe no behavior we
change, so they stay as-is.

## Changes

Six files, front-matter `description` only (F1 + F4), plus one clause in `loop-autoresearch`
(F5). New descriptions are trigger-first ("Use when…"), keep discovery keywords, and name
sibling loops as anti-triggers.

### `skills/loop-delivery/SKILL.md` — description

> Use when you have ONE bounded delivery task — a feature, refactor, or chore — to run
> under a controlled, auditable loop with scope guards, quality gates, and an independent
> verifier, in any repo. Not for a specific failing test/CI job (use loop-repair) or
> improving a numeric metric (use loop-autoresearch).

### `skills/loop-repair/SKILL.md` — description

> Use when a specific test, CI job, or regression is failing and must be fixed under a
> controlled loop that reproduces first, isolates the cause, applies the minimal diff, and
> proves regression coverage. Not for open-ended feature work (use loop-delivery) or metric
> optimization (use loop-autoresearch).

### `skills/loop-autoresearch/SKILL.md` — description

> Use when improving ONE numeric metric — accuracy, latency, cost — under a controlled
> research loop with a fixed eval and kept/reverted experiments logged as JSONL, in any
> repo. Not for delivering a feature (use loop-delivery) or fixing a failing test (use
> loop-repair).

### `skills/audit/SKILL.md` — description

> Use when a loen loop stage must be validated and gated before the next one — plan, act,
> check, or result — and the run's report.html refreshed. Mode-aware for delivery, repair,
> and research contracts. The execution-loop analog of check-chain.

### `skills/governance/SKILL.md` — description

> Use when you need a cross-run view over all docs/loen/ runs — success rate, metric
> deltas, handoff reasons, failure taxonomy — as an offline governance.html dashboard. Add
> --triage to turn failing runs into proposed next actions (proposals only; never launches
> loops or edits runs).

### `skills/loop-goal/SKILL.md` — description

> Use when an active, human-approved loen run should keep going multi-turn without
> hand-holding — wraps it in Claude's native /goal condition generated from loop.yaml, plus
> a session-scoped /loop recipe for long-running gates. Optional; never bootstraps a run or
> submits /goal itself.

### `skills/loop-autoresearch/SKILL.md` — F5 clause (currently ~line 99)

Replace the soft "when possible" nuance clause with a conditional keyed to an observable
predicate (already consistent with the existing "any deviation … MUST be logged" line):

> - Keep seed, model version, eval command, and dataset fixed across experiments; if any
>   must change, log the deviation in the experiment record.

## Invariants (from the reference standard)

- Every `description` starts with `Use when`.
- Front-matter stays valid YAML and under 1024 characters.
- Discovery keywords preserved: `loen`, `loop.yaml`, `/goal`, `triage`, `report.html`,
  `governance.html`, failing test, metric, JSONL.
- No behavior line changed — only `description:` fields and the single F5 clause.

## Verification (prompt text, no runtime surface)

1. `grep -A0 '^description:'` across the 6 SKILL.md files → each begins with `Use when`.
2. Front-matter parses as YAML; each description < 1024 chars.
3. `git diff` touches only `description:` lines plus the one `loop-autoresearch` F5 clause —
   zero body / Rules / Steps / Stop-conditions lines.

## Branch / PR

- Base: `dev-loen-prompt-hardening` off `dev`.
- Worktree: `wk-dev-loen-prompt-hardening`.
- PR target: `dev`.
