---
name: loop-start
description: Use to bootstrap a loen loop — validate a durable topic slug, scaffold docs/loen/<topic>/, write the goal/context, get one bounded plan approved, and arm the contract. The single human gate of the loop.
---

# Loop Start

Bootstrap ONE durable loop **topic**. You are the worker (the only writer). State lives in
files under `docs/loen/<topic>/` — never in chat. This skill ends at the plan-approval gate;
after approval, `loop-run` drives the loop autonomously.

## Procedure

1. **Validate the topic slug.** Lowercase kebab, `^[a-z0-9][a-z0-9-]*$`. Reject empty slugs,
   slashes, path traversal, uppercase, spaces, leading/trailing dashes.

2. **Pick the mode** from the invoking configurator (default `delivery`; `repair` / `research`
   / `review` for the specialized entry skills).

3. **Scaffold the topic with Bash, not Write** (the loop-gate allows bootstrap via Bash; the
   templates live in the plugin):

   ```bash
   TEMPLATES="$(cd "$(dirname "$(command -v python3)")" >/dev/null; echo)"  # noop guard
   python3 - "$TOPIC" <<'PY'
   import os, sys
   sys.path.insert(0, "plugin/loen/hooks")
   import loen_artifacts as a
   topic = sys.argv[1]
   a.scaffold_topic(topic, "plugin/loen/assets/templates", "docs/loen")
   print("scaffolded docs/loen/%s" % topic)
   PY
   ```

   This creates `1_goal.md … 7_result.md`, `loop.yaml` (topic filled, `status: active`),
   `handoff.md`, `audit.html`, `attempts.jsonl`, `evidence/`, and the `docs/loen/current`
   pointer.

4. **Write `1_goal.md`** (User Request + Success Criteria) and **`2_context.md`** (Facts,
   Constraints, Relevant Files) from durable facts — not chat memory.

5. **Fill `loop.yaml`** with concrete values: `objective`, `mutable_scope` / `protected_scope`
   (minimal specific globs — never both empty), `quality_gates` (real commands that exit 0),
   `stages` role bindings, `tools.allowed`, `permissions` (filesystem mirrors the top-level
   scope), `budget`, `stop_conditions`, `handoff_conditions`, `rollback_policy`. Leave
   `run.plan_approved: false` and `run.plan_hash: ""` for now.

6. **Generate the plan.** Invoke **`loop-plan`** — it is the single writer of `3_plan.md`
   (it may dispatch the `planner` subagent). Do not write `3_plan.md` here yourself.

7. **Plan-approval gate (the one human gate).** Present `3_plan.md` and `loop.yaml` scope to
   the human. Wait for an explicit `approve`. Do not proceed on silence.

8. **Arm the contract** after approval — set in `loop.yaml`: `status: active`,
   `run.plan_approved: true`, and `run.plan_hash` = the plan body hash:

   ```bash
   python3 - <<'PY'
   import sys; sys.path.insert(0, "plugin/loen/hooks")
   import loen_artifacts as a
   text = open("docs/loen/%s/3_plan.md" % "$TOPIC").read()
   print("plan_hash:", a.plan_body_hash(text))
   PY
   ```

   Write that hash into `run.plan_hash`. Refresh the `docs/loen/current` pointer (the scaffold
   already wrote it).

9. **Hand off to `loop-run`.** Report the topic, the artifact directory, the approval state,
   and that `/loen:loop-run` will now execute the loop autonomously to `7_result.md` or
   `handoff.md`.

## Output

Report: topic, `docs/loen/<topic>/`, mode, `run.plan_approved: true`, `run.plan_hash`, and the
next command `/loen:loop-run`.
