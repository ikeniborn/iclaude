---
rfc: 0002
title: Agent Pipeline Protocol Specification
status: Active
created: 2026-03-04
authors: [iclaude project]
supersedes: null
---

# RFC-0002: Agent Pipeline Protocol Specification

## Abstract

This RFC specifies the formal protocol for the iclaude multi-agent pipeline:
Researcher → [Critic] → Planner → [Critic] → Executor → [Critic]. It defines the
data contracts between agents (input.toon, research.toon, plan.toon, report.json),
the verdict semantics for the Critic agent (PASS/WARN/RETRY/ABORT), retry loop limits,
approval gate conditions, and agent role boundaries. This RFC is the authoritative
specification; AGENT.md files in `agents/` are the implementing ADRs.

**Status: Active**

## Motivation

The multi-agent pipeline requires strict data contracts to prevent hallucination and
ensure reproducible behavior. Without formal specification:

1. Sub-agents may write output files to incorrect paths (CWD instead of WORKSPACE)
2. Downstream agents cannot validate input format, leading to silent errors
3. Retry loops without exit conditions lead to infinite regress
4. Approval gates without clear criteria lead to inconsistent human intervention

This RFC formalizes what was previously implicit in the orchestrator SKILL.md.

## Pipeline Architecture

### Stage Overview

```
Orchestrator
    ↓
[1] Researcher Agent  → research.toon
    ↓
[2] Critic Agent (mode=research) → research-critique.toon
    ↓
[3] Approval Gate (human) → yes/no
    ↓
[4] Planning Agent → plan.toon
    ↓
[5] Critic Agent (mode=plan) → plan-critique.toon
    ↓
[6] Approval Gate (human) → yes/no/show-plan
    ↓
[7] Execution Agent → report.json
    ↓
[8] Critic Agent (mode=execution) → execution-critique.toon
    ↓
[9] Final Report (orchestrator)
```

### Agent Roles and Boundaries

| Agent | Reads | Writes | MUST NOT |
|-------|-------|--------|----------|
| Researcher | input.toon, codebase | research.toon | Modify project files |
| Critic | workspace/*.toon or *.json | {mode}-critique.toon | Modify project files |
| Planner | input.toon, research.toon | plan.toon | Read project files directly |
| Executor | plan.toon, input.toon | report.json, project files | Skip validation steps |

## Data Contracts

### input.toon

Written by orchestrator. Read by Researcher, Critic (all modes), Planner.

```json
{
  "task_input": {
    "task_description": "string",
    "focus_areas": ["codebase", "architecture", "risks", "external_docs"],
    "hints": {
      "language_hint": "null | string",
      "skip_context7": "boolean",
      "skip_local_docs": "boolean"
    }
  }
}
```

### research.toon

Written by Researcher. Read by Planner and Critic (research + plan modes).

MUST contain `schema_version: "2.1.0"` at the top level.

Required fields:
- `research_results.project_context` — language, framework, entry_point, architecture_style
- `research_results.codebase_analysis.relevant_files` — at least 1 item with relevance
- `research_results.architecture_analysis.affected_components` — non-empty array
- `research_results.risk_assessment.risks` — array (may be empty for minimal complexity)
- `research_results.recommendations.complexity_hint` — one of: minimal, standard, complex

TOON format: relevant_files MUST use TOON block if length >= 5. See RFC-0003.

### plan.toon

Written by Planner. Read by Executor and Critic (plan + execution modes).

MUST contain `research_schema_version` matching research.toon's `schema_version`.

Required fields:
- `execution_plan.metadata.complexity` — from research complexity_hint
- `execution_plan.phases` — array of phase objects
- `execution_plan.research_references.reusable_components_used` — non-empty array
- `execution_plan.research_references.risks_mitigated` — entries for all high/critical risks

Each phase MUST contain:
- `steps` — array with >= 2 items (or TOON block reference)
- `validation` — non-empty string with validation command
- `commit_message` — Conventional Commits format: `type(scope): description`

### report.json

Written by Executor. Read by Critic (execution mode).

MUST contain `schema_version: "2.1.0"`.

Required fields:
- `status` — one of: COMPLETED, FAILED, PARTIAL
- `phases` — array matching plan phases count
- `files_changed` — array with action (created|modified|deleted) per file
- `commits` — array with hash (>= 7 chars) and Conventional Commits message
- `risks_encountered` — array (may be empty)
- `next_steps` — array of suggested follow-up actions

## Critic Agent Protocol

### Verdict Semantics

| Verdict | Score Range | Meaning | Pipeline Action |
|---------|------------|---------|-----------------|
| PASS | >= 85 | Artifact meets quality bar | Continue to next stage |
| WARN | 70-84 | Acceptable with noted issues | Continue, show warnings at Gate |
| RETRY | 50-69 | Insufficient quality | Re-run agent with guidance (research/plan only) |
| ABORT | < 50 or ABORT trigger | Critical failure | Stop pipeline, human intervention required |

ABORT triggers override score and immediately produce ABORT verdict regardless of score.

### Retry Loop Protocol

RETRY verdict applies only to Researcher and Planner agents. Executor uses WARN instead.

**Retry loop MUST terminate after 2 retries:**

```
attempt 0: Run agent → Critic evaluates
attempt 1: IF RETRY → re-run with critique guidance → Critic re-evaluates
attempt 2: IF RETRY → re-run with critique guidance → Critic re-evaluates
           IF still RETRY after attempt 2 → emit ABORT, stop pipeline
```

**Double-demerit rule:** If a critique issue from attempt N is NOT addressed in attempt N+1,
the Critic MUST apply -5 additional points for each unresolved issue (beyond the original deduction).
This prevents superficial reformulations that don't fix root causes.

### Approval Gate Protocol

Approval gates occur after Critic evaluations at stages [2] and [5].

The orchestrator MUST present to the human:
1. Research/plan summary (key findings or phase list)
2. Critic score and verdict
3. Any WARN issues from critique
4. Explicit yes/no prompt

For PASS verdict: proceed automatically if human answers "yes".
For WARN verdict: show warnings prominently, require explicit "yes".
For ABORT: gate is skipped — pipeline stops immediately.

## Workspace Protocol

### File Paths

All agents MUST use absolute paths for workspace file operations:

```
CORRECT: Write("/absolute/path/.claude/workspace/SESSION/research.toon", ...)
WRONG:   Write("research.toon", ...)  ← writes to CWD (wrong project)
```

The orchestrator MUST pre-substitute `{WORKSPACE}` and `{PROJECT_ROOT}` in AGENT.md
content before passing to sub-agents. Sub-agents MUST NOT resolve placeholder values
themselves.

### Session ID Format

Session IDs MUST follow format: `YYYY-MM-DDTHHMM` (15 characters, generated by `date +%Y-%m-%dT%H%M`).

Session IDs MUST NOT contain descriptive suffixes or task names. Use `input.toon.task_description` for task identification.

### Workspace Location

```
{PROJECT_ROOT}/.claude/workspace/{SESSION_ID}/
```

This path MUST be added to PROJECT_ROOT/.gitignore if not already present.

### Retry Artifact Naming Pattern

When the Critic produces a RETRY verdict and an agent is re-run, the previous critique file MUST be renamed before the new critique is written. This preserves the history of all evaluation attempts for traceability.

```
RETRY_NUMBER=1: {mode}-critique.toon → {mode}-critique-r1.toon  (rename before new write)
RETRY_NUMBER=2: {mode}-critique.toon → {mode}-critique-r2.toon  (rename before new write)
Final:          {mode}-critique.toon  (no suffix — always the latest)
```

The Critic agent is responsible for the rename operation (via `Bash(mv ...)`). The orchestrator and downstream agents MUST always read `{mode}-critique.toon` (without suffix) as the current/final critique.

The research.toon and plan.toon files are **overwritten** on retry (not renamed) — only critique files follow the rename pattern.

**Full workspace file set after 1 retry:**
```
{SESSION_ID}/
├── input.toon
├── research.toon              ← overwritten by retry
├── research-critique-r1.toon  ← previous critique (archived)
├── research-critique.toon     ← final critique (latest)
├── plan.toon
├── plan-critique.toon
├── report.json
└── execution-critique.toon
```

## Hallucination Prevention Mechanisms

The pipeline includes several structural features that prevent agent hallucinations:

### 1. Schema Version Cross-Reference

plan.toon's `research_schema_version` MUST match research.toon's `schema_version`.
The Critic verifies this cross-reference. Mismatch triggers a -5 penalty.

This prevents a Planner from hallucinating a research that doesn't exist or using
stale research from a previous session.

### 2. ABORT Triggers as Guardrails

Each Critic rubric includes ABORT triggers for conditions that indicate the agent
produced fundamentally incorrect output (e.g., no relevant files found, empty plan phases).
These hard stops prevent downstream agents from working with garbage input.

### 3. Reusable Components Reference Chain

The Planner MUST reference specific components from research.toon in its plan.
The Critic verifies that file paths in plan.toon match paths found in research.toon.
This prevents the Planner from hallucinating files that don't exist.

### 4. Validation Commands Per Phase

Each plan phase MUST specify a validation command. The Executor MUST run this command
and record the result. This provides objective pass/fail criteria independent of agent
judgment.

## References

- [RFC-0001: Documentation Standards](RFC-0001-documentation-standards.md)
- [RFC-0003: TOON Protocol](RFC-0003-toon-protocol.md)
- [RFC-0004: Inter-Agent Communication Optimization](RFC-0004-inter-agent-communication.md)
- [agents/researcher-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/researcher-agent/AGENT.md)
- [agents/planning-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/planning-agent/AGENT.md)
- [agents/execution-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/execution-agent/AGENT.md)
- [agents/critic-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/critic-agent/AGENT.md)
- [agents/_shared/workspace.md](../.nvm-isolated/.claude-isolated/agents/_shared/workspace.md)
