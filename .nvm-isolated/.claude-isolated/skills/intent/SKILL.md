---
name: intent
description: Use BEFORE superpowers:brainstorming for any non-trivial work (new module, CLI flag, API change, arch decision). Triggers on "/idd", "capture intent", "intent doc". If brainstorming would start on non-trivial work without an approved intent doc in docs/superpowers/intents/, run IDD first. Brainstorm proceeds only when intent Status: approved.
---

# IDD — Intent-Driven Design

## Overview

IDD captures *why* before *how*. Run before `superpowers:brainstorming` to anchor the spec to real objectives — preventing specs that are precisely wrong (right HOW, wrong WHAT/WHY).

IDD owns WHY / WHAT / Outcomes / Constraints. Brainstorm owns HOW (architecture, components, error handling, tests). Once an intent doc is approved, brainstorm treats the IDD answers as fixed inputs and does not re-ask them.

## When to use / When not to use

| Trigger | Action |
|---------|--------|
| New module / new CLI flag / API change / arch decision | Run IDD |
| Hotfix / typo / formatting change | Skip |
| Intent doc already exists in `docs/superpowers/intents/` | Skip → go to brainstorm |
| "It's small" / "I already know what to build" | Run IDD anyway |

## Process

### Step 0: Load project context via iwiki (if available)

Before asking any questions, check whether `docs/wiki/` exists. If yes, load context in parallel:

1. `Skill(skill="iwiki:iwiki-query", args='<topic>')` — existing documentation for this topic

Store results as **wiki_context** for use in Steps 1–6 below.

Present to user:

```
Context from docs/wiki:
[sections found, or "No documentation found for this topic"]
```

If `docs/wiki/` is unavailable or query returns no results — skip silently. Do not block or mention the absence.

---

### Steps 1–6: Six questions (one at a time)

Ask each question **one at a time**. Wait for the user's answer before proceeding. Do not batch.

For each question, if **wiki_context** contains relevant information — show it as a hint before asking. If wiki_context is empty — ask the plain question.

---

**Q1 — Objective:** What problem does this solve, and why now?

> *If wiki_context has relevant docs:*
> "From existing documentation on '[topic]': [brief summary — what is already documented, what decisions were made].
> What exactly needs to change or be added, and why now?"

---

**Q2 — Desired Outcomes:** What observable, user-facing states confirm success?

*(No wiki enrichment — outcomes are user-defined, not derivable from existing docs.)*

---

**Q3 — Health Metrics:** What must not degrade?

> *If wiki_context returned components:*
> "These components reference this area: [list from wiki_context].
> Which of them must not break? Which metrics must stay stable?"
>
> *(Goodhart's Law: name the metrics that stay stable even if the feature ships.)*

---

**Q4 — Strategic Context:** What systems, modules, or people interact with this? Priority trade-off: trust / speed / cost?

> *If wiki_context has architecture sections:*
> "From the architecture documentation: [relevant fragment].
> What else interacts with this area? What is the priority — trust / speed / cost?"

---

**Q5 — Constraints:** What steering constraints (behavioral guidance) apply? What hard constraints (architectural or forbidden) apply?

> *If wiki_context has decisions or constraints sections:*
> "Existing architectural decisions on this topic: [fragment from docs/wiki].
> Which of them still hold? What is added as a new constraint?"

---

**Q6 — Autonomy & Stop Rules:** For each decision type, which autonomy zone applies: full / guarded / proposal-first / no-go? What conditions halt, escalate, or mark completion?

*(No lat enrichment — autonomy policy is defined by the user per feature.)*

---

### After all six answers

**Validation checklist** — verify before presenting the doc:

1. All sections filled — no empty bullets?
2. Every constraint maps to steering OR hard (not both)?
3. Autonomy zones cover all decision types in this feature?
4. Stop Rules include at least one "Done when:" criterion, phrased as an observable result or measurable metric (not "implemented / code written")?

Fix any failures inline, then present.

**Write the intent doc** using the template below. Fill each section with the user's answers verbatim or lightly edited for clarity.

**File path:** `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

**User review gate:**

1. Show a summary of the written document.
2. Ask: "Review the intent doc. Approve it or request changes."
3. On changes requested: edit → re-show → repeat.
4. On approval: set `Status: approved`, then commit once:

```bash
git add docs/superpowers/intents/ && git commit -m "docs(idd): add intent doc for <topic>"
```

5. Only after approval, hand off to brainstorm with this message:

```text
Intent doc approved at <path> (Status: approved).
Run superpowers:brainstorming. It MUST read this intent doc first and
treat Objective, Desired Outcomes, Health Metrics, and Hard Constraints
as FIXED inputs — do NOT re-ask Q1–Q5.
Carry Desired Outcomes + "Done when" verbatim into the design doc as an
"## Acceptance (from intent)" section so they reach writing-plans and
spec review.
```

## Intent doc template

```markdown
# Intent: <topic>

**Date:** YYYY-MM-DD
**Status:** draft

## Objective
[Answer to Q1]

## Desired Outcomes
- [observable state 1]
- [observable state 2]

## Health Metrics
- [metric that must not degrade]

## Strategic Context
- Interacts with: [modules / agents / humans]
- Priority trade-off: [trust | speed | cost]

## Constraints
### Steering (behavioral guidance)
- [guideline 1]
### Hard (architectural enforcement)
- [restriction 1]

## Autonomy Zones
- Full autonomy (reversible, low risk): [decision types]
- Guarded (log + confidence threshold): [decision types]
- Proposal-first (needs approval): [decision types]
- No autonomy (human only): [decision types]

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: [condition]
- Escalate if: [condition]
- Done when: [completion criterion — observable result or measurable metric,
  not "implemented / code written"]
```

## Outcome Verification (run AFTER superpowers, before merge)

**Trigger:** after superpowers:finishing-a-development-branch, before merge.

This is the IDD payoff superpowers does not provide: verify the RESULT against intent, not "tests green / code matches spec".

1. Re-read intent doc: Desired Outcomes + Health Metrics + "Done when".
2. Per Desired Outcome: run the real scenario, record the OBSERVABLE
   result. Green tests are NOT evidence of an outcome.
3. Per Health Metric: measure it, confirm no degradation.
4. Compare to intent. Mismatch = intent-compliance defect → return to
   spec/intent, do NOT patch code to mask it.
5. Done only when every Desired Outcome passes AND no Health Metric
   degraded. Passing tests on an unmet outcome = NOT done.

## Common mistakes

- **"It's a small change"** — A new CLI flag is a CLI API change. Still run IDD. Intent docs take 5 minutes and prevent hours of misaligned work.
- **"Let me ask one clarifying question and proceed"** — Asking scope is not capturing intent. Scope answers WHAT; intent captures WHY, outcomes, and stop conditions.
- **"lat not available"** — Skip Step 0 silently. Never block IDD or mention the absence of lat context. The process works without it.
- **"subagent-driven said not to stop"** — The intent doc's Autonomy Zones override continuous-execution. A no-go / proposal-first decision means halt and escalate.
- **"Tests are green, so it's done"** — Green tests are not a completed outcome. Done is determined by Outcome Verification against Desired Outcomes, not by a test run.
- **"Brainstorm already asked about the goal"** — If the intent doc is approved, brainstorm does not re-ask WHY/WHAT/Outcomes/Constraints. Duplicate questions mean the intent doc never reached brainstorm (see handoff).
