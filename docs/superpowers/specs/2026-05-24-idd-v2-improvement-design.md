---
review:
  spec_hash: 026d57b0bf4d7783
  last_run: 2026-05-24
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: structure
      severity: INFO
      section: "## Validation Checklist (new, post-doc)"
      section_hash: bf37569ed0615321
      text: 'Line 134: "TBD" appears as quoted concept in checklist item ("no \"TBD\" or empty bullets?") — not an actual placeholder, but triggers literal pattern match'
      verdict: open
      verdict_at: null
    - id: F-002
      phase: clarity
      severity: WARNING
      section: "### 4. Q5 renamed and split into Q5 + Q6"
      section_hash: 12e2ed0705f9a3b4
      text: 'Section title uses "Q5" but body says "Q6 is now explicitly two sub-questions" — Q5 was renamed Q6; title is ambiguous for readers without full context'
      verdict: fixed
      verdict_at: 2026-05-24
    - id: F-003
      phase: clarity
      severity: WARNING
      section: "## Success Criteria"
      section_hash: ed616e668fe3d571
      text: 'SC#5 says "~79 lines / ~500 words estimate" — estimate qualifier makes SC#5 non-objectively verifiable; actual word count should be the criterion'
      verdict: fixed
      verdict_at: 2026-05-24
    - id: F-004
      phase: clarity
      severity: INFO
      section: "## Validation Checklist (new, post-doc)"
      section_hash: bf37569ed0615321
      text: '"all real decision types in this feature" (item 3) has no definition of what qualifies as a decision type — evaluator must infer from feature context'
      verdict: open
      verdict_at: null
---
# IDD Skill v2 — Improvement Design

**Date:** 2026-05-24
**Scope:** `~/.claude/skills/idd/SKILL.md`
**Goal:** Align IDD skill with Huryn 2026 Intent Engineering Framework (7 components), fix contradictions, add user review gate.

---

## Problem

Current IDD skill (v1, 79 lines) was built before the full Huryn 2026 framework was verified against. Comparison reveals:

1. **Missing component:** Strategic Context (what systems/agents/people interact with this feature; priority trade-offs)
2. **Simplified components:** Constraints has no steering vs. hard distinction; Autonomy has no 4-zone model
3. **No user review gate:** Intent doc is committed as `draft` without user approval — brainstorm spec has this gate; IDD doesn't
4. **Q5 ↔ template mismatch:** Q5 asks "autonomy + stop rules" as one question but template has two sections
5. **Redundancy:** Common mistakes partially duplicates When-to-use table

---

## Reference: Huryn 2026 Framework (7 components)

| Component | Definition |
|-----------|------------|
| Objective | Problem + why it matters |
| Desired Outcomes | Observable states proving success (user-facing) |
| Health Metrics | What must not degrade while optimizing |
| **Strategic Context** | Systems/agents/humans that interact; priority trade-off (trust/speed/cost) |
| Constraints | Steering (behavioral guidance) vs. Hard (architectural enforcement) |
| Decision Types & Autonomy | 4 zones: full / guarded / proposal-first / no autonomy |
| Stop Rules | Halt conditions, escalation triggers, completion criteria |

---

## Changes

### 1. Question set: 5 → 6 questions

| # | Question | Huryn Component |
|---|----------|----------------|
| Q1 | What problem does this solve, and why now? | Objective |
| Q2 | What observable, user-facing states confirm success? | Desired Outcomes |
| Q3 | What must not degrade? (Goodhart's Law) | Health Metrics |
| Q4 | **What systems, modules, or people interact with this? Priority: trust / speed / cost?** | Strategic Context ← new |
| Q5 | What steering constraints (behavioral guidance) apply? What hard constraints (architectural/forbidden)? | Constraints |
| Q6 | For each decision type — which autonomy zone? (full / guarded / proposal-first / no-go). What conditions halt or escalate? | Decision Types & Autonomy + Stop Rules |

Q6 replaces old Q5, which combined autonomy and stop rules ambiguously.

### 2. Updated intent doc template

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

### 3. User review gate (new)

After writing the intent doc, IDD skill must:

1. Show a summary of the written document
2. Ask: "Review the intent doc. Approve it or request changes."
3. On approval: update `Status: draft` → `Status: approved`, re-commit
4. On changes requested: edit → re-show → repeat
5. Only after approval: "Intent doc approved. Run /brainstorm next."

This mirrors the brainstorming skill's "User reviews spec" gate.

### 4. Q5 renamed and split into Q5 + Q6

Q6 is now explicitly two sub-questions:
1. "For each decision type, which autonomy zone applies?" → fills `## Autonomy Zones`
2. "What conditions halt, escalate, or mark completion?" → fills `## Stop Rules`

Ask them in one message but label them clearly so the user knows both sections are being filled.

### 5. Redundancy cleanup

Remove 2 of 4 Common mistakes entries that duplicate the When-to-use table:
- Keep: `"It's a small change"` (hardest rationalization to counter)
- Keep: `"Let me ask one clarifying question and proceed"` (scope ≠ intent distinction)
- Remove: `"I already know what to build"` (already covered by When-to-use row)
- Remove: `"We discussed this before"` (already covered by When-to-use row)

---

## What Does NOT Change

- Frontmatter description — "is starting non-trivial feature work" stays; it's for skill discovery (using-superpowers), not a contradiction with manual invocation in CLAUDE.md
- File path convention: `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`
- Commit message format: `docs(idd): add intent doc for <topic>`
- IDD→SDD→plans→execute workflow structure
- Superpowers brainstorming skill — not modified (fork risk)

---

## Validation Checklist (new, post-doc)

After writing the intent doc, before user review:
1. All sections filled — no "TBD" or empty bullets?
2. Every Constraint maps to steering OR hard (not both)?
3. Autonomy zones cover all real decision types in this feature?
4. Stop Rules include at least one "Done when:" criterion (not just halt/escalate)?

If any check fails, fix inline before presenting to user.

---

## File Changes

| File | Action |
|------|--------|
| `~/.claude/skills/idd/SKILL.md` | Update (6 questions, new template, review gate, validation checklist, trimmed Common mistakes) |

---

## Success Criteria

1. SKILL.md covers all 7 Huryn 2026 components
2. Intent docs produced by v2 include Strategic Context + steering/hard constraints + 4-zone autonomy
3. User must explicitly approve intent doc before brainstorm is invoked
4. No contradictions between Q numbering and template sections
5. SKILL.md word count ≤ 600 (`wc -w ~/.claude/skills/idd/SKILL.md` after update)
