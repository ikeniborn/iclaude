---
review:
  plan_hash: d14e6e3caa97bd28
  spec_hash: 026d57b0bf4d7783
  last_run: 2026-05-24
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "### Task 1: Snapshot v1 word count (baseline)"
      section_hash: 105a53c48142bdc3
      text: "Task 1 records pre-edit baseline word count — no spec requirement mandates it; SC#5 only requires post-edit count ≤ 600"
      verdict: fixed
      verdict_at: 2026-05-24
---
# IDD Skill v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `SKILL.md` for the IDD skill from v1 (5 questions, no review gate) to v2 (6 questions, Huryn 2026 full coverage, validation checklist, user review gate).

**Architecture:** Single-file replacement — `.nvm-isolated/.claude-isolated/skills/idd/SKILL.md`. No code changes, no new files. All 5 spec success criteria are verifiable by grep + word count post-edit.

**Tech Stack:** Bash (wc, grep), git

---

## File Map

| File | Action | Why |
|------|---------|-----|
| `.nvm-isolated/.claude-isolated/skills/idd/SKILL.md` | Rewrite | All 5 changes from spec |

---

### Task 1: Write v2 SKILL.md

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/idd/SKILL.md` (full rewrite)

All 5 spec changes applied in one replacement:
1. Q set 5→6 (add Q4 Strategic Context; split old Q4 Constraints into steering/hard; rename old Q5→Q6 with 4-zone autonomy + stop rules)
2. Updated intent doc template (new sections: Strategic Context, Constraints→Steering/Hard, Autonomy Zones 4-zone)
3. User review gate (show → approve/change → status draft→approved → re-commit)
4. Validation checklist (4 checks before presenting doc to user)
5. Common mistakes trimmed from 4 → 2 entries

- [ ] **Step 1: Write the new SKILL.md**

Replace entire file content with:

```markdown
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
```

- [ ] **Step 2: Confirm file saved**

Run:
```bash
head -5 .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: frontmatter block starting with `---`

---

### Task 2: Verify all success criteria

**Files:**
- Read: `.nvm-isolated/.claude-isolated/skills/idd/SKILL.md`

- [ ] **Step 1: SC#5 — word count ≤ 600**

Run:
```bash
wc -w .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: number ≤ 600

- [ ] **Step 2: SC#1 — all 7 Huryn components present**

Run:
```bash
grep -c "Strategic Context\|Health Metrics\|Desired Outcomes\|Objective\|Constraints\|Autonomy\|Stop Rules" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: ≥ 7 (each component appears at least once)

- [ ] **Step 3: SC#2 — template has new sections**

Run:
```bash
grep -E "## Strategic Context|### Steering|### Hard|## Autonomy Zones" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: 4 lines matching (all new template sections present)

- [ ] **Step 4: SC#3 — review gate text present**

Run:
```bash
grep "Status: approved\|Approve it or request changes" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: 2 matching lines

- [ ] **Step 5: SC#4 — Q numbering consistent with template (no Q5↔template mismatch)**

Run:
```bash
grep -n "Q[0-9]\|question" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: Q1–Q6 in process section; no Q5 reference to autonomy (old name), no Q6 reference to constraints (wrong section)

- [ ] **Step 6: SC#2 — no old "Autonomy Level" section (v1 name)**

Run:
```bash
grep "Autonomy Level" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: no output (section was renamed to "Autonomy Zones")

- [ ] **Step 7: Common mistakes trimmed to 2**

Run:
```bash
grep -c "^\- \*\*" .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
```
Expected: 2

---

### Task 3: Commit

**Files:**
- Stage: `.nvm-isolated/.claude-isolated/skills/idd/SKILL.md`

- [ ] **Step 1: Stage and commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/idd/SKILL.md
git commit -m "feat(idd): upgrade skill to v2 — Huryn 2026 full coverage, review gate, 6 questions"
```

Expected: commit created on `dev` branch.

- [ ] **Step 2: Confirm commit**

```bash
git log --oneline -1
```
Expected: commit message starting with `feat(idd):`
