---
name: idd
description: Use when the user types "/idd", asks to "capture intent before brainstorming", requests an "intent doc", or is starting non-trivial feature work (new module, new CLI flag, API change, architectural decision) before running /brainstorm.
---

# IDD — Intent-Driven Design

## Overview

IDD captures *why* before *how*. Run before `/brainstorm` to anchor the spec to real objectives — preventing specs that are precisely wrong (right HOW, wrong WHAT/WHY).

## When to use / When not to use

| Trigger | Action |
|---------|--------|
| New module / new CLI flag / API change / arch decision | Run IDD |
| Hotfix / typo / formatting change | Skip |
| Intent doc already exists in `docs/superpowers/intents/` | Skip → go to /brainstorm |
| "It's small" / "I already know what to build" | Run IDD anyway |

## Process

Ask the six questions below **one at a time**. Wait for the user's answer before asking the next. Do not batch them.

1. **Objective** — What problem does this solve, and why now?
2. **Desired Outcomes** — What observable, user-facing states confirm success?
3. **Health Metrics** — What must not degrade? (Goodhart's Law: name the metrics that stay stable even if the feature ships.)
4. **Strategic Context** — What systems, modules, or people interact with this? Priority trade-off: trust / speed / cost?
5. **Constraints** — What steering constraints (behavioral guidance) apply? What hard constraints (architectural or forbidden) apply?
6. **Autonomy & Stop Rules** — For each decision type, which autonomy zone applies: full / guarded / proposal-first / no-go? What conditions halt, escalate, or mark completion?

## After all six answers

**Validation checklist** — verify before presenting the doc:
1. All sections filled — no empty bullets?
2. Every constraint maps to steering OR hard (not both)?
3. Autonomy zones cover all decision types in this feature?
4. Stop Rules include at least one "Done when:" criterion?

Fix any failures inline, then present.

**Write the intent doc** using the template below. Fill each section with the user's answers verbatim or lightly edited for clarity.

**File path:** `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

Commit:
```bash
git add docs/superpowers/intents/ && git commit -m "docs(idd): add intent doc for <topic>"
```

**User review gate:**
1. Show a summary of the written document.
2. Ask: "Review the intent doc. Approve it or request changes."
3. On approval: update `Status: draft` → `Status: approved`, re-commit.
4. On changes requested: edit → re-show → repeat.
5. Only after approval: "Intent doc approved. Run /brainstorm next."

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

## Stop Rules
- Halt if: [condition]
- Escalate if: [condition]
- Done when: [completion criterion]
```

## Common mistakes

- **"It's a small change"** — A new CLI flag is a CLI API change. Still run IDD. Intent docs take 5 minutes and prevent hours of misaligned work.
- **"Let me ask one clarifying question and proceed"** — Asking scope is not capturing intent. Scope answers WHAT; intent captures WHY, outcomes, and stop conditions.
