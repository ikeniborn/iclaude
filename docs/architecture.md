# loen Architecture

loen is a Claude Code plugin (`plugin/loen/`) that runs one bounded engineering task as a
**stage-oriented durable-topic** loop. This document describes the operating model, the
isolation ladder, the hook enforcement map, and the addressing scheme.

## Operating model

State is durable in files, not chat. Every unit of work is a **topic** under
`docs/loen/<topic>/`. Seven numbered artifacts carry the loop through its stages; a
machine-readable `loop.yaml` is the contract; skills advance the pipeline; hooks enforce the
contract deterministically on every tool event.

**Principle:** *missing file = missing state.* A resume reads the disk — it never "remembers"
progress from the conversation.

### The 7-stage pipeline

```
1_goal → 2_context → 3_plan → 4_act → 5_check → 6_reflect → 7_result
                        │                                        │
                     (approval gate)                          (Done)
                                                     └── handoff.md (human decision)
```

- `loop-start` bootstraps the topic, writes goal/context, delegates `3_plan.md` to
  `loop-plan`, and holds the one human approval gate.
- `loop-run` is the autonomous orchestrator: after approval it drives `act → check → reflect`
  to `7_result.md` (Done) or `handoff.md`, updating `loop.yaml` `run.state` /
  `run.current_pass` on every transition (resumable across compaction).
- The coarse outcomes (`loop-delivery` / `loop-repair` / `loop-autoresearch` / `loop-review`)
  are thin **configurators** that set `mode` and delegate into the same pipeline; they own no
  artifacts.

## Isolation ladder

| Level | Actor | Mechanism |
|---|---|---|
| L0 | worker | the main session — the only writer; edits inside `mutable_scope` |
| L1 | planner / explorer / reviewer / researcher | read-only subagents fed a bounded **capsule** (`loen_capsules.render_capsule`) — durable-artifact text, never chat |
| L3 | verifier (optional) | headless in an iclaude Firecracker microVM against a disposable snapshot (`scripts/verify_microvm.sh`), read-only by construction |

`stages.<stage>.roles` in `loop.yaml` binds which role may act at each stage
(`act: [worker]`, `check: [verifier]`, `reflect: [reviewer]`).

## Hook enforcement map

A shared library (`loen_common`, `loen_artifacts`, `loen_capsules`) backs six specialized
hooks. Enforcement is graded by `LOEN_MODE`: `off` (inert) / `advisory` (print only) /
`enforce` (block = exit 2, default) / `strict` (+ worker ≠ verifier identity).

| Hook | Event | Enforces |
|---|---|---|
| `loop-gate.py` | PreToolUse | active loop + stage ordering; `7_result` requires `5_check` PASS |
| `scope-guard.py` | PreToolUse | no edits to `protected_scope`; edits stay in `mutable_scope` |
| `tool-guard.py` | PreToolUse | tool in `tools.allowed`; role permitted for `current_stage` |
| `permission-guard.py` | PreToolUse | shell deny_patterns, `git reset --hard`, network off/allowlist |
| `evidence-gate.py` | Stop | a "done" stop needs `5_check` + `7_result` + verifier verdict + evidence |
| `audit-writer.py` | PostToolUse | regenerate `audit.html`; upsert the `docs/TODO.md` row |

Deterministic shell nets (`check_layout.sh`, `guard_protected.sh`) re-check the layout and
protected scope for Bash-written artifacts that bypass the PreToolUse hook.

## Addressing & information flow

The single addressing scheme is the relative path `docs/loen/<topic>/` (base root: env
`LOEN_ARTIFACT_ROOT`, default `docs/loen`). Information reaches consumers by path + file,
never by chat:

- **Orchestrator → subagent:** `loop-run` passes the topic path + a rendered capsule; the
  subagent reads artifacts from that path.
- **Hook ← tool event:** a hook derives the topic from the edited path
  (`topic_from_path`), reads `loop.yaml`, and enforces.
- **Active-topic discovery** (`event_topic`): env `LOEN_TOPIC` → path → `current_topic()`
  (the `docs/loen/current` pointer file, else a `status: active` `loop.yaml`).

## Artifacts

```
docs/loen/<topic>/
  1_goal.md 2_context.md 3_plan.md 4_act.md 5_check.md 6_reflect.md 7_result.md
  loop.yaml handoff.md audit.html attempts.jsonl evidence/
docs/loen/current            # pointer: active topic slug
docs/loen/governance.html    # cross-topic dashboard (/loen:governance)
```
