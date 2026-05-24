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

Ask the five questions below **one at a time**. Wait for the user's answer before asking the next. Do not batch them.

1. **Objective** — What problem does this solve, and why now?
2. **Desired outcomes** — What observable, user-facing states confirm success?
3. **Health metrics** — What must not degrade? (Goodhart's Law: name the metrics that stay stable even if the feature ships.)
4. **Constraints** — What architectural or technical constraints apply?
5. **Stop rules + autonomy** — What decisions can be made without asking? What conditions require escalating to the user?

## After all five answers

Write the intent doc using the template below. Fill each section with the user's answers verbatim or lightly edited for clarity.

**File path:** `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

Then commit:

```bash
git add docs/superpowers/intents/ && git commit -m "docs(idd): add intent doc for <topic>"
```

Finally say: "Intent doc ready. Run /brainstorm next."

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

## Constraints
- [architectural or technical constraint]

## Autonomy Level
[Decisions Claude makes without asking]

## Stop Rules
[Conditions that require escalating to user]
```

## Common mistakes

- **"It's a small change" / "It's just a flag"** — A new CLI flag is a CLI API change. Still run IDD. Intent docs take 5 minutes and prevent hours of misaligned work.
- **"I already know what to build"** — The intent doc is for the *user*, not the agent. It makes implicit assumptions explicit and reviewable.
- **"Let me ask one clarifying question and proceed"** — Asking scope is not capturing intent. Scope answers WHAT; intent captures WHY, outcomes, and stop conditions.
- **"We discussed this before"** — Check if intent doc exists. If not, create it.
