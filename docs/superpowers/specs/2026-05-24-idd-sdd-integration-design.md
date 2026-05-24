---
review:
  spec_hash: ebff71a4eb4049ae
  last_run: 2026-05-24
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "## Success Criteria"
      section_hash: cbf7149eeb4eac8b
      text: "SC#2 'finds and uses intent doc without additional setup' — 'uses' has no acceptance criterion. How does evaluator verify brainstorming actually consumed the intent doc vs. only located it?"
      verdict: open
      verdict_at: null
    - id: F-002
      phase: clarity
      severity: INFO
      section: "## Approach"
      section_hash: dd7e01fb5e77ece9
      text: "'non-trivial features' undefined in this section. Criterion (new module, API change, architectural decision) only appears in ## CLAUDE.md Change."
      verdict: open
      verdict_at: null
---
# IDD Integration Design

**Date:** 2026-05-24
**Scope:** `~/.claude/skills/idd/` + `iclaude/CLAUDE.md` + `iclaude/docs/superpowers/intents/`
**Goal:** Add IDD layer upstream of superpowers SDD workflow via custom `idd` skill.

---

## Problem

Superpowers workflow starts at brainstorming — spec-driven (SDD). No layer captures *why* we're building something before spec writing begins. Intent gets lost; specs can be precisely wrong (right HOW, wrong WHAT/WHY).

---

## Approach

Custom `idd` skill at `~/.claude/skills/idd/SKILL.md`.

- Global scope (all projects)
- Called manually before brainstorming on non-trivial features
- Creates `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`
- Commits the document
- Brainstorming Step 1 (project file scan) picks up intent doc automatically — no superpowers changes needed

**Layered stack:**
```
/idd           → intent doc (objective, outcomes, metrics, constraints, stop rules)
/brainstorm    → spec (reads intent doc as context in Step 1)
writing-plans  → implementation plan
execute        → code
```

---

## Intent Doc Format

Path: `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

```markdown
# Intent: <topic>

**Date:** YYYY-MM-DD
**Status:** draft | approved

## Objective
What are we building and why does it matter.

## Desired Outcomes
Observable states that prove success (user perspective).
- outcome 1
- outcome 2

## Health Metrics
What must not degrade during optimization.
- metric 1 (Goodhart's Law protection)

## Constraints
- Architectural / technical constraints

## Autonomy Level
Decisions Claude makes autonomously vs. decisions requiring user confirmation.

## Stop Rules
When to halt and escalate to user.
```

Sections map 1:1 to Intent Engineering Framework (Huryn 2026).

---

## Skill Design

### SKILL.md structure

```
~/.claude/skills/idd/
└── SKILL.md
```

**Frontmatter:**
- `name: idd`
- `description: Use when starting non-trivial feature work before brainstorming — captures objective, desired outcomes, health metrics, constraints, and stop rules as an intent document`
- Max 1024 chars, starts "Use when..."

**Content sections:**
- Overview: IDD in 2 sentences
- When to use / when not to use
- Process: 5-question interview → doc → commit
- Intent doc template (inline)
- Common mistakes

Target: < 500 words total.

### Skill workflow

```
/idd <topic>
  Ask 5 questions one-by-one:
  1. Objective + why
  2. Desired outcomes (observable, user-facing)
  3. Health metrics (what must not break)
  4. Constraints (arch/tech)
  5. Stop rules + autonomy level
  ↓
Write docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md
  ↓
git add + commit
  ↓
"Intent doc ready. Run /brainstorm next."
```

---

## TDD Plan for Skill Creation (required by writing-skills)

Skill type: **technique** — tested with application and gap scenarios.

### RED phase (before writing skill)

Run subagent test WITHOUT skill:
- Scenario A: "Start brainstorming a new iclaude feature" — does agent capture intent or jump straight to spec?
- Scenario B: "Feature request is ambiguous" — does agent surface stop rules or proceed?
- Document exact rationalizations and gaps.

### GREEN phase

Write minimal SKILL.md addressing specific RED failures.
Run same scenarios WITH skill — verify compliance.

### REFACTOR phase

Find new rationalizations → add counters → re-test.

---

## CLAUDE.md Change

Add to `iclaude/CLAUDE.md` → "Getting Started" section:

```markdown
## IDD → SDD workflow

For non-trivial features (new module, API change, architectural decision):

1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context
```

---

## File Changes Summary

| File | Action |
|------|--------|
| `~/.claude/skills/idd/SKILL.md` | Create |
| `iclaude/CLAUDE.md` | Add IDD→SDD section |
| `iclaude/docs/superpowers/intents/` | Create directory (first intent doc creates it) |

---

## Out of Scope

- ArcBlock/idd plugin — not used (external dependency, conflicts with superpowers)
- Modifying superpowers brainstorming skill — fork risk on updates
- Pipeline integration — no pipeline in iclaude
- Auto-triggering IDD before every brainstorm — manual invocation preferred

---

## Success Criteria

1. `/idd` produces intent doc matching the template in < 3 minutes
2. Brainstorming Step 1 finds and uses intent doc without additional setup
3. SKILL.md passes RED-GREEN-REFACTOR cycle (green on application + gap scenarios)
4. CLAUDE.md updated and committed
