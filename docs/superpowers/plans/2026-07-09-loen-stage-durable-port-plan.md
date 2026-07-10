---
review:
  stage: plan
  plan_hash: ef33cb8386e042bf
  last_run: 2026-07-10
  phases:
    structure: {status: passed}
    coverage: {status: passed}
    dependencies: {status: passed}
    verifiability: {status: passed}
    consistency: {status: passed}
  findings:
    - id: F-001
      phase: structure
      severity: WARNING
      section: "Task 4: loen_capsules.py — bounded context capsules"
      section_hash: 3af974f4f1d7b31f
      fragment: "Claude Code uses the microVM path from verify_microvm.sh, validated in Task 24"
      text: "Task 4 Step 3 cites 'validated in Task 24', but the plan has only 23 tasks; the microVM verifier is validated in Task 20 (test_loen_verify_microvm.sh, kept) and the Task 23 smoke. Dangling task reference."
      fix: "Replace 'Task 24' with 'Task 20 (test_loen_verify_microvm.sh) / Task 23 (smoke)'."
      verdict: fixed
      verdict_at: 2026-07-10
    - id: F-002
      phase: coverage
      severity: WARNING
      section: "Task 3: loen_artifacts.py — durable-state authority"
      section_hash: a19a2e58ea607374
      fragment: "validate_run_contract checks (1-8); check 8 = research mode -> stop_conditions containing target"
      text: "Spec 3 states validate_run_contract enforces mode-specific requirements including 'review needs a review scope', but Task 3's checklist (checks 1-8) implements only the research target requirement; no review-mode check is listed, and test_loen_run_contract.py exercises only delivery/research."
      fix: "Add a review-mode check (review scope present) as validate_run_contract check 9 and cover it in test_loen_run_contract.py, or state explicitly that review-scope is validated elsewhere."
      verdict: fixed
      verdict_at: 2026-07-10
    - id: F-003
      phase: verifiability
      severity: WARNING
      section: "Task 14: Stage skills loop-plan, loop-act, loop-check, loop-reflect"
      section_hash: bfad159fddc43afb
      fragment: "grep -q \"SKILL\" plugin/loen/skills/$s/SKILL.md ... (manual read to confirm the artifact + sections)"
      text: "Task 14 Step 2's sanity-check greps only for the literal string 'SKILL' (matched by virtually any SKILL.md) and defers real verification to an unmeasurable 'manual read'. Unlike Tasks 13/15 it does not assert the four skills' output artifacts or required sections."
      fix: "Grep each skill for its declared output artifact/sections (loop-act -> 4_act.md/## Changed Paths, loop-check -> verifier/5_check.md, loop-reflect -> 7_result.md)."
      verdict: fixed
      verdict_at: 2026-07-10
    - id: F-004
      phase: consistency
      severity: INFO
      section: "File structure"
      section_hash: f03a29e56ea3f4a6
      fragment: "Created tests list (10 entries) omits test_loen_hooks_wiring.sh and test_loen_agents.sh"
      text: "The File-structure 'Created' manifest lists 10 new tests but omits test_loen_hooks_wiring.sh (Task 11) and test_loen_agents.sh (Task 12), both authored as new files by their tasks."
      fix: "Add test_loen_hooks_wiring.sh and test_loen_agents.sh to the Created list."
      verdict: fixed
      verdict_at: 2026-07-10
    - id: F-005
      phase: dependencies
      severity: INFO
      section: "Task 13: loop-start skill"
      section_hash: 83596dde97f366a6
      fragment: "invoke loop-plan (the single writer of 3_plan.md)"
      text: "Task 13 (loop-start) references invoking loop-plan, whose SKILL.md is authored later in Task 14 — a forward reference. Harmless (both authored within this plan; runtime not exercised until the Task 23 smoke), flagged for traceability."
      fix: "Optionally reorder Task 14's loop-plan before Task 13, or note the forward dependency; no functional change required."
      verdict: fixed
      verdict_at: 2026-07-10
chain:
  intent: n/a
  spec: docs/superpowers/specs/2026-07-09-loen-stage-durable-port-design.md
  plan: docs/superpowers/plans/2026-07-09-loen-stage-durable-port-plan.md
result_check:
  verdict: OK
  plan_hash: ef33cb8386e042bf
  last_run: 2026-07-10
---
# loen — Stage-Oriented Durable-Topic Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Claude Code plugin `plugin/loen` from its outcome-oriented model (6 coarse skills, `state.md` + `iterations/iter-NN/`, one fail-open hook) into the icodex stage-oriented durable-topic model, adapted to the Claude Code runtime, with an auto-running `loop-run` orchestrator.

**Architecture:** State is durable in seven numbered artifacts under `docs/loen/<topic>/`. A shared Python library (`loen_common`/`loen_artifacts`/`loen_capsules`) backs six specialized hooks (four PreToolUse, one Stop, one PostToolUse) that enforce a rich `loop.yaml` contract under a graded `LOEN_MODE`. Thirteen skills (7 pipeline + 4 configurators + governance + audit) drive a 7-stage pipeline; `loop-run` executes `act→check→reflect` autonomously after the plan is approved. Five read-only subagents plus the main-session worker do the work.

**Tech Stack:** Python 3 (stdlib only — no PyYAML), Bash, Markdown SKILL.md/agent files, JSON hook I/O. Reference implementation to port: `/home/ikeniborn/Documents/Project/icodex/plugins/loen` (Codex plugin). Current source to replace: `/home/ikeniborn/Documents/Project/iclaude/plugin/loen`.

## Global Constraints

- **Python: stdlib only.** No third-party deps; `loop.yaml` is parsed by a bespoke line-oriented parser (no PyYAML). Copied verbatim from spec §4.
- **Tool-name mapping (Codex → Claude Code):** `apply_patch`/`shell`/`read`/`search` → `Write`/`Edit`/`MultiEdit`/`Bash`/`Read`/`Grep`/`Glob`. `tool_class()` normalizes to `{edit, shell, read, search}`.
- **Hook I/O contract (Claude Code):** hooks read a JSON payload from stdin with `tool_name` and `tool_input.file_path` (and `tool_input.command` for Bash); **exit 2 = block, exit 0 = allow**; any crash → exit 0 (fail-open) in `advisory`/`off`, fail-closed only where the spec says so. Matches the existing `loop-guard.py` contract.
- **Artifact root:** env `LOEN_ARTIFACT_ROOT` (default `docs/loen`). Topic dir = `<root>/<topic>/`. Slug rule `^[a-z0-9][a-z0-9-]*$`.
- **Graded `LOEN_MODE`:** `off` | `advisory` | `enforce` (default) | `strict`. `block_or_nudge` returns exit 2 only in `enforce`/`strict`.
- **Active-loop signal:** `loop.yaml: status: active` + convenience pointer `docs/loen/current` (plain text, one line = active topic slug).
- **Target version:** `plugin/loen/.claude-plugin/plugin.json` → `1.0.0`.
- **Docs language:** English for code/comments/docs; `README.ru.md` is the Russian mirror of `README.md`.
- **Tests:** standalone scripts under `tests/`, run as `bash tests/<name>.sh` or `python3 tests/<name>.py`; REPO root via `dirname`. No central runner. Each returns `PASS <name>` on success, non-zero on failure.
- **Never auto-merge.** The loop always ends at a human PR review.

**Reference-port convention (applies to every Python task):** where a task says "port `icodex .../X.py`", the icodex file is the complete source of truth. Apply the tool-name mapping and the path/schema changes enumerated in that task. Read the icodex file first, then write the adapted iclaude file. The authored test in each task is the acceptance contract; the icodex source must not be copied blindly — every `apply_patch`/`shell`/`read`/`search` string, every `docs/loen/current` symlink assumption, and every WASM reference must be adapted to the Claude Code equivalents named in the task.

---

## File structure

**Created:**
- `plugin/loen/hooks/loen_common.py` — foundation: mode, event_topic, YAML parser, path/tool helpers, `block_or_nudge`.
- `plugin/loen/hooks/loen_artifacts.py` — durable-state authority: STAGE_FILES, slug/scaffold, contract validation, audit render, TODO upsert, attempts log.
- `plugin/loen/hooks/loen_capsules.py` — `render_capsule`.
- `plugin/loen/hooks/loop-gate.py`, `scope-guard.py`, `tool-guard.py`, `permission-guard.py`, `evidence-gate.py`, `audit-writer.py` — the six specialized hooks.
- `plugin/loen/assets/templates/{1_goal,2_context,3_plan,4_act,5_check,6_reflect,7_result}.md`, `loop.yaml`, `handoff.md`, `audit.html` — durable templates.
- `plugin/loen/skills/loop-start/SKILL.md`, `loop-run/SKILL.md`, `loop-plan/SKILL.md`, `loop-act/SKILL.md`, `loop-check/SKILL.md`, `loop-reflect/SKILL.md`, `loop-status/SKILL.md`, `loop-review/SKILL.md` — new skills.
- `plugin/loen/agents/reviewer.md`, `researcher.md` — new agents.
- `docs/architecture.md` — isolation ladder + operating model.
- `tests/test_loen_common.py`, `test_loen_artifacts.py`, `test_loen_capsules.py`, `test_loen_scope_guard.py`, `test_loen_tool_guard.py`, `test_loen_permission_guard.py`, `test_loen_loop_gate.py`, `test_loen_evidence_gate.py`, `test_loen_audit_writer.py`, `test_loen_run_contract.py`, `test_loen_hooks_wiring.sh` (Task 11), `test_loen_agents.sh` (Task 12) — new tests.

**Modified:**
- `plugin/loen/.claude-plugin/plugin.json` — version → 1.0.0.
- `plugin/loen/hooks/hooks.json` — new event→script wiring.
- `plugin/loen/agents/{explorer,planner,verifier}.md` — align with new roles/outputs.
- `plugin/loen/skills/{loop-delivery,loop-repair,loop-autoresearch}/SKILL.md` — become thin configurators.
- `plugin/loen/skills/{governance,audit}/SKILL.md` — topic-layout aware.
- `plugin/loen/scripts/{check_layout.sh,guard_protected.sh,loen_stats.py,log_experiment.py,verify_microvm.sh}` — topic layout; resolve `make_goal.py`.
- `plugin/loen/README.md`, `plugin/loen/README.ru.md` — full rewrite.
- `docs/functions/LOEN.md` — new model.
- `tests/{test_loen_layout.sh,test_loen_templates.sh,test_loen_plugin.sh,test_loen_stats.py}` — rewritten; `tests/test_loen_guard.sh`, `test_loen_hook.py`, `test_loen_goal.py` — removed/repurposed.

**Deleted:**
- `plugin/loen/hooks/loop-guard.py` — replaced by the six hooks + library.
- `plugin/loen/skills/loop-goal/SKILL.md` — folded into `loop-run` native-`/goal` fallback.

---

## Phase 1 — Shared library, templates, contract

### Task 1: `loen_common.py` — foundation module

**Files:**
- Create: `plugin/loen/hooks/loen_common.py`
- Test: `tests/test_loen_common.py`

**Interfaces:**
- Produces:
  - `mode() -> str` — reads env `LOEN_MODE`, returns one of `off|advisory|enforce|strict` (default `enforce`; unknown → `enforce`).
  - `is_off() -> bool` — `mode() == "off"`.
  - `artifact_root() -> str` — env `LOEN_ARTIFACT_ROOT` or `"docs/loen"`.
  - `validate_topic_slug(slug: str) -> bool` — matches `^[a-z0-9][a-z0-9-]*$`.
  - `topic_from_path(path: str) -> str | None` — if `path` is under `<root>/<topic>/...`, return `<topic>`, else `None`.
  - `is_loen_topic_path(path: str) -> bool`.
  - `current_topic() -> str | None` — read `<root>/current` (one line slug); if absent, scan `<root>/*/loop.yaml` for `status: active`; else `None`.
  - `event_topic(event: dict) -> str | None` — env `LOEN_TOPIC` → `topic_from_path(file_path)` → `current_topic()`.
  - `parse_loop_yaml(text: str) -> dict` — bespoke indent parser (nested dicts, block-style lists, inline `[a, b]` flow lists, `{k: v}` inline maps).
  - `read_loop_artifact(topic: str) -> dict | None` — parse `<root>/<topic>/loop.yaml` or `None`.
  - `loop_policy(topic: str) -> dict` — convenience view: `{mutable_scope, protected_scope, tools, permissions, stages, status, mode, run}`.
  - `extract_paths(event: dict) -> list[str]` — file paths a tool call would write (from `tool_input.file_path`; for `MultiEdit`, the single `file_path`).
  - `normalize_path(p: str) -> str` — repo-relative, `./`-stripped, no trailing slash.
  - `matches_any(path: str, globs: list[str]) -> bool` — `fnmatch` incl. `**`.
  - `tool_class(tool_name: str) -> str` — `Write|Edit|MultiEdit` → `edit`; `Bash` → `shell`; `Read` → `read`; `Grep|Glob` → `search`; else `other`.
  - `block_or_nudge(msg: str) -> int` — `strict`/`enforce`: print `msg` to stderr, return `2`; `advisory`: print `msg`, return `0`; `off`: return `0`.
  - `should_run_hook(event: dict) -> tuple[bool, str|None]` — `(not is_off()) and event_topic(event) is not None`; returns `(run?, topic)`.

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
"""Unit tests for loen_common — the shared hook foundation."""
import importlib.util, os, sys, tempfile, pathlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(REPO, "plugin", "loen", "hooks", "loen_common.py")

def load():
    spec = importlib.util.spec_from_file_location("loen_common", MOD)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def test_mode_default_and_env():
    c = load()
    os.environ.pop("LOEN_MODE", None); assert c.mode() == "enforce"
    os.environ["LOEN_MODE"] = "off"; assert c.mode() == "off" and c.is_off()
    os.environ["LOEN_MODE"] = "bogus"; assert c.mode() == "enforce"
    os.environ.pop("LOEN_MODE", None)

def test_slug():
    c = load()
    assert c.validate_topic_slug("fix-parser-1")
    assert not c.validate_topic_slug("Fix_Parser")
    assert not c.validate_topic_slug("-bad")

def test_topic_from_path():
    c = load()
    assert c.topic_from_path("docs/loen/my-topic/4_act.md") == "my-topic"
    assert c.topic_from_path("src/app.py") is None

def test_parse_loop_yaml_nested_and_lists():
    c = load()
    y = c.parse_loop_yaml(
        "topic: t\nstatus: active\n"
        "mutable_scope:\n  - src/**\n  - tests/**\n"
        "stages:\n  act: {roles: [worker]}\n"
        "permissions:\n  network: {mode: off, allowlist: []}\n")
    assert y["topic"] == "t" and y["status"] == "active"
    assert y["mutable_scope"] == ["src/**", "tests/**"]
    assert y["stages"]["act"]["roles"] == ["worker"]
    assert y["permissions"]["network"]["mode"] == "off"

def test_block_or_nudge_modes():
    c = load()
    os.environ["LOEN_MODE"] = "enforce"; assert c.block_or_nudge("x") == 2
    os.environ["LOEN_MODE"] = "advisory"; assert c.block_or_nudge("x") == 0
    os.environ["LOEN_MODE"] = "off"; assert c.block_or_nudge("x") == 0
    os.environ.pop("LOEN_MODE", None)

def test_current_topic_via_pointer(tmp := None):
    c = load()
    d = tempfile.mkdtemp(); cwd = os.getcwd()
    try:
        os.chdir(d); os.environ["LOEN_ARTIFACT_ROOT"] = "docs/loen"
        pathlib.Path("docs/loen/t1").mkdir(parents=True)
        pathlib.Path("docs/loen/current").write_text("t1\n")
        assert c.current_topic() == "t1"
    finally:
        os.chdir(cwd); os.environ.pop("LOEN_ARTIFACT_ROOT", None)

def test_tool_class():
    c = load()
    assert c.tool_class("Write") == "edit" and c.tool_class("Bash") == "shell"
    assert c.tool_class("Grep") == "search" and c.tool_class("Read") == "read"

if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn(); print(f"ok {name}")
    print("PASS test_loen_common.py")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_loen_common.py`
Expected: FAIL — `No such file or directory` / `ModuleNotFoundError` for `loen_common.py`.

- [ ] **Step 3: Write `loen_common.py`**

Port `icodex/plugins/loen/hooks/loen_common.py`, applying the Global-Constraints tool-name mapping and these exact adaptations:
- `tool_class()`: map the Claude Code tool names (`Write|Edit|MultiEdit`→`edit`, `Bash`→`shell`, `Read`→`read`, `Grep|Glob`→`search`) instead of Codex `apply_patch`/`shell`/`read`/`search`.
- `extract_paths()`: read `tool_input.file_path` (Claude Code) instead of parsing `apply_patch` `*** Add/Update/Delete File:` headers. Keep an `apply_patch` fallback removed — Claude Code has no such tool.
- `current_topic()`: read the `<root>/current` **plain-text pointer** (one line = slug) first; the icodex symlink path is replaced. Fall back to scanning `<root>/*/loop.yaml` for `status: active`.
- Keep the bespoke `parse_loop_yaml` indent parser verbatim in behavior (nested dicts, block lists, inline flow `[..]`, inline maps `{..}`); it must satisfy `test_parse_loop_yaml_nested_and_lists`.
- `mode()` ladder and `block_or_nudge()` semantics exactly as the Global Constraints state.

Inline the enforcement primitive so there is no ambiguity:

```python
import os, sys, fnmatch, re

_MODES = ("off", "advisory", "enforce", "strict")

def mode():
    m = os.environ.get("LOEN_MODE", "enforce").strip().lower()
    return m if m in _MODES else "enforce"

def is_off():
    return mode() == "off"

def block_or_nudge(msg):
    m = mode()
    if m in ("enforce", "strict"):
        print(f"[loen] {msg}", file=sys.stderr)
        return 2
    if m == "advisory":
        print(f"[loen] (advisory) {msg}", file=sys.stderr)
    return 0

def artifact_root():
    return os.environ.get("LOEN_ARTIFACT_ROOT", "docs/loen")

_SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")

def validate_topic_slug(slug):
    return bool(slug) and bool(_SLUG.match(slug))

def tool_class(tool_name):
    t = (tool_name or "")
    if t in ("Write", "Edit", "MultiEdit"): return "edit"
    if t == "Bash": return "shell"
    if t == "Read": return "read"
    if t in ("Grep", "Glob"): return "search"
    return "other"
```

Implement the remaining functions (`topic_from_path`, `current_topic`, `event_topic`, `parse_loop_yaml`, `read_loop_artifact`, `loop_policy`, `extract_paths`, `normalize_path`, `matches_any`, `should_run_hook`) per the Produces block, porting the icodex parser body.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tests/test_loen_common.py`
Expected: `PASS test_loen_common.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loen_common.py tests/test_loen_common.py
git commit -m "feat(loen): add loen_common shared hook foundation"
```

### Task 2: Durable templates (7 numbered artifacts + loop.yaml + handoff + audit.html)

**Files:**
- Create: `plugin/loen/assets/templates/1_goal.md`, `2_context.md`, `3_plan.md`, `4_act.md`, `5_check.md`, `6_reflect.md`, `7_result.md`, `loop.yaml`, `handoff.md`, `audit.html`
- Test: `tests/test_loen_templates.sh` (rewrite of the existing one)

**Interfaces:**
- Produces the canonical template set consumed by `scaffold_topic` (Task 3) and the skills. Sentinels: `5_check.md` result line uses `PASS`; `7_result.md` outcome uses `Done`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# All durable templates exist and carry their required section headings + sentinels.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
t="$repo_root/plugin/loen/assets/templates"
fail(){ echo "FAIL: $1" >&2; exit 1; }
for f in 1_goal 2_context 3_plan 4_act 5_check 6_reflect 7_result; do
  [[ -f "$t/$f.md" ]] || fail "missing $f.md"
done
for f in loop.yaml handoff.md audit.html; do [[ -f "$t/$f" ]] || fail "missing $f"; done
grep -q "## User Request" "$t/1_goal.md" || fail "1_goal missing User Request"
grep -q "## Success Criteria" "$t/1_goal.md" || fail "1_goal missing Success Criteria"
grep -q "## Facts" "$t/2_context.md" || fail "2_context missing Facts"
grep -q "## Steps" "$t/3_plan.md" || fail "3_plan missing Steps"
grep -q "## Checks" "$t/3_plan.md" || fail "3_plan missing Checks"
grep -q "## Changed Paths" "$t/4_act.md" || fail "4_act missing Changed Paths"
grep -q "## Result" "$t/5_check.md" || fail "5_check missing Result"
grep -q "PASS" "$t/5_check.md" || fail "5_check missing PASS sentinel"
grep -q "## Decision" "$t/6_reflect.md" || fail "6_reflect missing Decision"
grep -q "## Outcome" "$t/7_result.md" || fail "7_result missing Outcome"
grep -q "Done" "$t/7_result.md" || fail "7_result missing Done sentinel"
grep -q "^topic:" "$t/loop.yaml" || fail "loop.yaml missing topic"
grep -q "^status:" "$t/loop.yaml" || fail "loop.yaml missing status"
grep -q "^run:" "$t/loop.yaml" || fail "loop.yaml missing run block"
echo "PASS test_loen_templates.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_loen_templates.sh`
Expected: FAIL — `missing 1_goal.md` (templates not yet created; old templates lived under `skills/loop-delivery/assets/`).

- [ ] **Step 3: Write the templates**

Author each file. Port section structure from `icodex/plugins/loen/assets/templates/*` (they already match the spec §1 table). `loop.yaml` is the full spec §3 schema (with `topic`, `status`, `run:`, `stages.<stage>.roles`, `tools`, `permissions.filesystem` mirroring top-level scope, `capsule`, `governance`). Example `loop.yaml` header (complete file follows the spec §3 block verbatim):

```yaml
topic: ""
mode: delivery
status: active
objective: ""
current_stage: goal
context_sources: []
mutable_scope: []
protected_scope: []
quality_gates: []
verifier_isolation: subagent
eval_command: ""
metrics: {primary: [], secondary: []}
budget: {max_iterations: 3, max_experiments: 5, max_wall_time_minutes: 90, max_cost_usd: 5}
stop_conditions: []
handoff_conditions: []
rollback_policy: ""
run: {plan_approved: false, plan_hash: "", state: prepare, max_passes: 3, current_pass: 0}
stages:
  act: {roles: [worker]}
  check: {roles: [verifier]}
  reflect: {roles: [reviewer]}
tools: {allowed: [Read, Grep, Glob, Bash, Write, Edit, MultiEdit], denied: []}
permissions:
  filesystem: {mutable_scope: [], protected_scope: []}
  network: {mode: off, allowlist: []}
  shell: {allow: [], deny_patterns: []}
capsule: {required_fields: [topic, objective, mode, current_stage, mutable_scope, protected_scope, quality_gates, relevant_files, last_evidence, question]}
governance: {}
logging: {state_file: docs/loen/<topic>/attempts.jsonl}
```

`5_check.md` must contain a `## Result` section with a `PASS` example line; `7_result.md` a `## Outcome` with a `Done` example line.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_loen_templates.sh`
Expected: `PASS test_loen_templates.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/assets/templates tests/test_loen_templates.sh
git commit -m "feat(loen): add durable stage templates and loop.yaml contract"
```

### Task 3: `loen_artifacts.py` — durable-state authority

**Files:**
- Create: `plugin/loen/hooks/loen_artifacts.py`
- Test: `tests/test_loen_artifacts.py`, `tests/test_loen_run_contract.py`

**Interfaces:**
- Consumes: `loen_common` (parse_loop_yaml, artifact_root, validate_topic_slug).
- Produces:
  - `STAGE_FILES: list[str]` = `["1_goal.md","2_context.md","3_plan.md","4_act.md","5_check.md","6_reflect.md","7_result.md"]`.
  - `scaffold_topic(topic: str, templates_dir: str, root: str) -> None` — create `<root>/<topic>/` with all 7 stage files + `loop.yaml` (topic filled) + `evidence/`; write the `<root>/current` pointer.
  - `loop_yaml_text(topic: str, **overrides) -> str` — render the loop.yaml template with the topic and overrides.
  - `plan_body_hash(plan_md_text: str) -> str` — sha256 (first 16 hex) of the plan body with any frontmatter excluded (`awk` equivalent in Python).
  - `validate_run_contract(loop: dict, plan_text: str) -> tuple[bool, list[str]]` — returns `(ok, errors)`; checks listed below.
  - `render_audit(topic: str, root: str) -> str` — regenerate `audit.html` from artifacts; verdict `Done` iff `7_result.md` contains `Done` AND `5_check.md` contains `PASS` AND `evidence/` non-empty.
  - `upsert_todo_row(topic: str, stage: str, verdict: str, today: str) -> None` — idempotent `docs/TODO.md` row keyed by `<topic>`.
  - `append_attempt(topic: str, record: dict, root: str) -> None` — append one compact JSON line to `<root>/<topic>/attempts.jsonl`.

`validate_run_contract` checks (each failure appends a message):
1. `loop["run"]["plan_approved"] is True`.
2. `loop["run"]["plan_hash"] == plan_body_hash(plan_text)`.
3. `loop["mode"] in {"delivery","repair","research","review"}`.
4. `mutable_scope` non-empty (usable).
5. at least one `quality_gates` entry (a verifier command).
6. `budget["max_iterations"] > 0`.
7. `rollback_policy` non-empty.
8. research mode → a `stop_conditions` entry containing `target`.
9. review mode → a non-empty review scope: either `context_sources` non-empty OR `1_goal.md` names the diff/PR/branch under review (`loop["review_scope"]` if present). Covered by a `test_contract_review_needs_scope` case in `test_loen_run_contract.py`.

- [ ] **Step 1: Write the failing test (`test_loen_run_contract.py`)**

```python
#!/usr/bin/env python3
import importlib.util, os, hashlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m

def test_plan_hash_excludes_frontmatter():
    a = load("loen_artifacts")
    body = "# Plan\n\nstep 1\n"
    with_fm = "---\nreview: {}\n---\n" + body
    assert a.plan_body_hash(with_fm) == a.plan_body_hash(body)

def test_contract_rejects_unapproved():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = {"run": {"plan_approved": False, "plan_hash": ""}, "mode": "delivery",
            "mutable_scope": ["src/**"], "quality_gates": ["pytest"],
            "budget": {"max_iterations": 3}, "rollback_policy": "git revert",
            "stop_conditions": []}
    ok, errs = a.validate_run_contract(loop, plan)
    assert not ok and any("plan_approved" in e for e in errs)

def test_contract_accepts_valid_delivery():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = {"run": {"plan_approved": True, "plan_hash": a.plan_body_hash(plan)},
            "mode": "delivery", "mutable_scope": ["src/**"],
            "quality_gates": ["pytest"], "budget": {"max_iterations": 3},
            "rollback_policy": "git revert", "stop_conditions": []}
    ok, errs = a.validate_run_contract(loop, plan)
    assert ok, errs

def test_contract_research_needs_target():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    base = {"run": {"plan_approved": True, "plan_hash": a.plan_body_hash(plan)},
            "mode": "research", "mutable_scope": ["src/**"],
            "quality_gates": ["eval"], "budget": {"max_iterations": 3},
            "rollback_policy": "revert", "stop_conditions": []}
    ok, _ = a.validate_run_contract(base, plan); assert not ok
    base["stop_conditions"] = ["reach target: accuracy > 0.9"]
    ok, _ = a.validate_run_contract(base, plan); assert ok

if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_run_contract.py")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_loen_run_contract.py`
Expected: FAIL — `ModuleNotFoundError`/`AttributeError` (module absent).

- [ ] **Step 3: Write `loen_artifacts.py`**

Port `icodex/plugins/loen/hooks/loen_artifacts.py`, adapting:
- `STAGE_FILES` verbatim.
- `render_audit`: emit HTML; keep the `Done` verdict rule (7_result has `Done` ∧ 5_check has `PASS` ∧ `evidence/` non-empty).
- `plan_body_hash`: strip a leading `---\n…\n---\n` frontmatter block (the `awk 'fm>=2'` rule from the check-chain hashing), then `hashlib.sha256(body.encode()).hexdigest()[:16]`.
- `scaffold_topic`: copy from `assets/templates/` (Task 2), fill `topic:` in loop.yaml, create `evidence/`, write `<root>/current`.
- `upsert_todo_row`: match the `CLAUDE.md` Task Log columns; keyed by `<topic>`; create the file with the header if absent.
- `append_attempt`: `json.dumps(record, sort_keys=True, separators=(",",":"))` + `\n`.

Write `test_loen_artifacts.py` too (scaffold creates 7 files + loop.yaml + current pointer; `render_audit` verdict flips on the three conditions; `upsert_todo_row` is idempotent). Author it in the same standalone style.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 tests/test_loen_run_contract.py && python3 tests/test_loen_artifacts.py`
Expected: `PASS test_loen_run_contract.py` and `PASS test_loen_artifacts.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loen_artifacts.py tests/test_loen_artifacts.py tests/test_loen_run_contract.py
git commit -m "feat(loen): add loen_artifacts durable-state authority + contract validation"
```

### Task 4: `loen_capsules.py` — bounded context capsules

**Files:**
- Create: `plugin/loen/hooks/loen_capsules.py`
- Test: `tests/test_loen_capsules.py`

**Interfaces:**
- Consumes: `loen_common`, `loen_artifacts`.
- Produces: `render_capsule(topic_dir: str, role: str, question: str) -> str` — a bounded text block containing: Topic, Objective, Loop mode, Current stage, Mutable scope, Protected scope, Quality gates, Relevant files (parsed from `2_context.md`), Last evidence summary (from `5_check.md`), and the given `role` + `question`. Reads only durable artifacts; never chat.

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
import importlib.util, os, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m

def test_capsule_contains_bounded_fields():
    cap = load("loen_capsules")
    d = tempfile.mkdtemp(); td = pathlib.Path(d, "docs/loen/t"); td.mkdir(parents=True)
    (td / "loop.yaml").write_text(
        "topic: t\nmode: delivery\ncurrent_stage: check\nobjective: ship X\n"
        "mutable_scope:\n  - src/**\nprotected_scope:\n  - migrations/**\n"
        "quality_gates:\n  - pytest\n")
    (td / "2_context.md").write_text("## Facts\n- relevant: src/app.py\n")
    (td / "5_check.md").write_text("## Result\nPASS: 12 tests\n")
    out = cap.render_capsule(str(td), "verifier", "Is iteration 2 safe to keep?")
    for needle in ["t", "ship X", "delivery", "check", "src/**",
                   "migrations/**", "pytest", "verifier",
                   "Is iteration 2 safe to keep?"]:
        assert needle in out, needle

if __name__ == "__main__":
    test_capsule_contains_bounded_fields(); print("PASS test_loen_capsules.py")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_loen_capsules.py`
Expected: FAIL — module absent.

- [ ] **Step 3: Write `loen_capsules.py`**

Port `icodex/plugins/loen/hooks/loen_capsules.py`'s `render_capsule`. Drop the Codex WASM `validate_verifier_execution` helper (Claude Code uses the microVM path from `verify_microvm.sh`, validated in Task 20 (`test_loen_verify_microvm.sh`) and smoked in Task 23). Parse `loop.yaml` via `loen_common.parse_loop_yaml`; extract "relevant files" lines from `2_context.md` and the last non-empty summary line from `5_check.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tests/test_loen_capsules.py`
Expected: `PASS test_loen_capsules.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loen_capsules.py tests/test_loen_capsules.py
git commit -m "feat(loen): add loen_capsules bounded-context renderer"
```

---

## Phase 2 — Specialized hooks + wiring

Each hook is a standalone script: read the event JSON from stdin, resolve `(run?, topic)` via `should_run_hook`, load `loop_policy`, enforce, and return via `block_or_nudge`. Every hook fails open on unexpected exceptions in `off`/`advisory`. Each hook task follows the same TDD shape: author a `tests/test_loen_<hook>.py` that pipes a JSON payload to the hook and asserts the exit code, write the hook, verify.

### Task 5: `scope-guard.py` (PreToolUse)

**Files:**
- Create: `plugin/loen/hooks/scope-guard.py`
- Test: `tests/test_loen_scope_guard.py`

**Interfaces:**
- Consumes: `loen_common.loop_policy`, `extract_paths`, `matches_any`, `block_or_nudge`.
- Behavior: for each written path — allow the topic's own dir; block if it matches any `permissions.filesystem.protected_scope` glob; if `mutable_scope` non-empty and the path matches none of it, block ("out-of-scope edit"). No active loop → allow.

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "scope-guard.py")

def run(cwd, path, tool="Write"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen"})
    return p.returncode

def setup():
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: active\n"
        "permissions:\n  filesystem: {mutable_scope: [src/**], protected_scope: [migrations/**]}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    return d

def test_allows_in_scope():
    d = setup(); assert run(d, "src/app.py") == 0

def test_blocks_protected():
    d = setup(); assert run(d, "migrations/001.sql") == 2

def test_blocks_out_of_scope():
    d = setup(); assert run(d, "README.md") == 2

def test_allows_topic_dir():
    d = setup(); assert run(d, "docs/loen/t/4_act.md") == 0

def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d, "anything.py") == 0

if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_scope_guard.py")
```

- [ ] **Step 2: Run to verify it fails**

Run: `python3 tests/test_loen_scope_guard.py`
Expected: FAIL — hook missing (non-zero from `subprocess`/`FileNotFoundError`).

- [ ] **Step 3: Write `scope-guard.py`**

Port `icodex/plugins/loen/hooks/scope-guard.py`; read `permissions.filesystem` from `loop_policy`; `sys.exit(block_or_nudge(...))` on violation, else `sys.exit(0)`. Wrap the body in `try/except Exception: sys.exit(0)` so it fails open outside `enforce`/`strict`.

- [ ] **Step 4: Run to verify it passes**

Run: `python3 tests/test_loen_scope_guard.py`
Expected: `PASS test_loen_scope_guard.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/scope-guard.py tests/test_loen_scope_guard.py
git commit -m "feat(loen): add scope-guard PreToolUse hook"
```

### Task 6: `loop-gate.py` (PreToolUse)

**Files:**
- Create: `plugin/loen/hooks/loop-gate.py`
- Test: `tests/test_loen_loop_gate.py`

**Interfaces:**
- Behavior: edits under `docs/loen/<topic>/` require `status: active`; block writing `N_*.md` if any lower-numbered stage file is missing; block writing `7_result.md` unless `5_check.md` contains `PASS`; block a `current_stage:` jump past a missing artifact. Bootstrap writes (`current`, top-level RUNBOOK) allowed.

- [ ] **Step 1: Write the failing test** — assert: (a) writing `4_act.md` when `3_plan.md` absent → 2; (b) writing `4_act.md` with `1_goal..3_plan` present + `status: active` → 0; (c) `7_result.md` without `5_check` PASS → 2. Author in the same subprocess style as Task 5.

- [ ] **Step 2: Run to verify it fails** — `python3 tests/test_loen_loop_gate.py` → FAIL (hook missing).

- [ ] **Step 3: Write `loop-gate.py`** — port `icodex .../loop-gate.py`; stage-ordering + `status: active` + `5_check` PASS gate on `7_result`. Fail open on exception outside enforce/strict.

- [ ] **Step 4: Run to verify it passes** — `python3 tests/test_loen_loop_gate.py` → `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loop-gate.py tests/test_loen_loop_gate.py
git commit -m "feat(loen): add loop-gate stage-ordering PreToolUse hook"
```

### Task 7: `tool-guard.py` (PreToolUse)

**Files:**
- Create: `plugin/loen/hooks/tool-guard.py`
- Test: `tests/test_loen_tool_guard.py`

**Interfaces:**
- Behavior: `tool_class(tool_name)`'s underlying tool must be in `tools.allowed`; the acting role (from `tool_input`/env `LOEN_ROLE`) must be in `stages.<current_stage>.roles`. Violation → `block_or_nudge`.

- [ ] **Step 1: Write the failing test** — assert: a `Bash` call when `tools.allowed` lacks `Bash` → 2; an allowed tool by a permitted role → 0; a role absent from `stages.<current_stage>.roles` → 2.

- [ ] **Step 2: Run to verify it fails** — FAIL (hook missing).

- [ ] **Step 3: Write `tool-guard.py`** — port `icodex .../tool-guard.py`; read `tools` + `stages` from `loop_policy`; role via `event.get("tool_input",{}).get("role")` or env `LOEN_ROLE` (default `worker`). Fail open on exception outside enforce/strict.

- [ ] **Step 4: Run to verify it passes** — `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/tool-guard.py tests/test_loen_tool_guard.py
git commit -m "feat(loen): add tool-guard PreToolUse hook"
```

### Task 8: `permission-guard.py` (PreToolUse)

**Files:**
- Create: `plugin/loen/hooks/permission-guard.py`
- Test: `tests/test_loen_permission_guard.py`

**Interfaces:**
- Behavior: for `Bash` calls, block if the command matches a `permissions.shell.deny_patterns` regex, hard-block `git reset --hard`, enforce `permissions.network.mode: off` (block curl/wget/ssh/scp/nc unless host in `allowlist`), and enforce the `permissions.shell.allow` allowlist when non-empty.

- [ ] **Step 1: Write the failing test** — assert: `git reset --hard` → 2; a `curl example.com` with `network.mode: off` → 2; a plain `ls` with empty allow/deny → 0; a command matching a `deny_patterns` entry → 2.

- [ ] **Step 2: Run to verify it fails** — FAIL (hook missing).

- [ ] **Step 3: Write `permission-guard.py`** — port `icodex .../permission-guard.py`; read the `Bash` command from `tool_input.command`. Fail open on exception outside enforce/strict.

- [ ] **Step 4: Run to verify it passes** — `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/permission-guard.py tests/test_loen_permission_guard.py
git commit -m "feat(loen): add permission-guard PreToolUse hook"
```

### Task 9: `evidence-gate.py` (Stop)

**Files:**
- Create: `plugin/loen/hooks/evidence-gate.py`
- Test: `tests/test_loen_evidence_gate.py`

**Interfaces:**
- Behavior: on a Stop event that signals "done", require `5_check.md`, `7_result.md`, a verifier verdict file under `evidence/`, and a non-empty `evidence/`. In `strict`, also require distinct worker vs verifier identity. Missing → `block_or_nudge`. If the stop does not signal done, or no active loop → allow.

- [ ] **Step 1: Write the failing test** — assert: a done-signal Stop with only `5_check.md` present → 2; with `5_check.md` + `7_result.md` + `evidence/verifier-verdict.md` present → 0; a non-done Stop → 0. The Stop payload shape: `{"hook_event_name":"Stop","stop_reason":"...", ...}` — mirror the icodex "done" detection.

- [ ] **Step 2: Run to verify it fails** — FAIL (hook missing).

- [ ] **Step 3: Write `evidence-gate.py`** — port `icodex .../evidence-gate.py`; adapt the done-signal detection to the Claude Code Stop payload; require the four artifacts; `strict` identity check compares a `worker_id`/`verifier_id` marker in `evidence/`.

- [ ] **Step 4: Run to verify it passes** — `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/evidence-gate.py tests/test_loen_evidence_gate.py
git commit -m "feat(loen): add evidence-gate Stop hook"
```

### Task 10: `audit-writer.py` (PostToolUse)

**Files:**
- Create: `plugin/loen/hooks/audit-writer.py`
- Test: `tests/test_loen_audit_writer.py`

**Interfaces:**
- Behavior: side-effecting recorder — on a PostToolUse event with an active topic, regenerate `<root>/<topic>/audit.html` via `loen_artifacts.render_audit` and upsert the `docs/TODO.md` row via `upsert_todo_row`. Never blocks (always exit 0).

- [ ] **Step 1: Write the failing test** — assert: after a PostToolUse event for topic `t`, `docs/loen/t/audit.html` exists and `docs/TODO.md` contains a `t` row; exit code is 0. Provide a fixed `today` via env `LOEN_TODAY` for determinism.

- [ ] **Step 2: Run to verify it fails** — FAIL (hook missing).

- [ ] **Step 3: Write `audit-writer.py`** — port `icodex .../audit-writer.py`; call `render_audit` + `upsert_todo_row`; wrap in `try/except: pass` and always `sys.exit(0)`.

- [ ] **Step 4: Run to verify it passes** — `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/audit-writer.py tests/test_loen_audit_writer.py
git commit -m "feat(loen): add audit-writer PostToolUse hook"
```

### Task 11: Rewire `hooks.json`; delete `loop-guard.py`

**Files:**
- Modify: `plugin/loen/hooks/hooks.json`
- Delete: `plugin/loen/hooks/loop-guard.py`
- Delete: `tests/test_loen_guard.sh`, `tests/test_loen_hook.py`
- Test: `tests/test_loen_hooks_wiring.sh` (new)

**Interfaces:**
- Produces the event→script wiring from spec §4.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
j="$repo_root/plugin/loen/hooks/hooks.json"
py(){ python3 -c "import json,sys;d=json.load(open('$j'));print($1)"; }
[[ -f "$j" ]] || { echo "FAIL: no hooks.json" >&2; exit 1; }
# PreToolUse has 4 scripts in order
order="$(python3 - "$j" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
pre=d["hooks"]["PreToolUse"][0]["hooks"]
print(",".join(h["command"].split("/")[-1].split('"')[0].replace('.py;','') for h in pre))
PY
)"
echo "$order" | grep -q "loop-gate" || { echo "FAIL: loop-gate not wired" >&2; exit 1; }
echo "$order" | grep -q "permission-guard" || { echo "FAIL: permission-guard not wired" >&2; exit 1; }
python3 - "$j" <<'PY' || { echo "FAIL: missing Stop/PostToolUse" >&2; exit 1; }
import json,sys
d=json.load(open(sys.argv[1]))["hooks"]
assert "Stop" in d and "PostToolUse" in d
assert any("evidence-gate" in h["command"] for g in d["Stop"] for h in g["hooks"])
assert any("audit-writer" in h["command"] for g in d["PostToolUse"] for h in g["hooks"])
PY
[[ -f "$repo_root/plugin/loen/hooks/loop-guard.py" ]] && { echo "FAIL: loop-guard.py still present" >&2; exit 1; }
echo "PASS test_loen_hooks_wiring.sh"
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/test_loen_hooks_wiring.sh` → FAIL (old single-hook wiring, `loop-guard.py` present).

- [ ] **Step 3: Write `hooks.json` + delete `loop-guard.py`**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|Bash|Read|Grep|Glob",
        "hooks": [
          { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/loop-gate.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0", "timeout": 30 },
          { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/scope-guard.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0", "timeout": 30 },
          { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/tool-guard.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0", "timeout": 30 },
          { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/permission-guard.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0", "timeout": 30 }
        ]
      }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit|MultiEdit|Bash", "hooks": [ { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/audit-writer.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; exit 0", "timeout": 30 } ] }
    ],
    "Stop": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/evidence-gate.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0", "timeout": 30 } ] }
    ]
  }
}
```

Then `git rm plugin/loen/hooks/loop-guard.py tests/test_loen_guard.sh tests/test_loen_hook.py`.

- [ ] **Step 4: Run to verify it passes** — `bash tests/test_loen_hooks_wiring.sh` → `PASS`. Also re-run every Phase-2 hook test.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/hooks.json tests/test_loen_hooks_wiring.sh
git rm plugin/loen/hooks/loop-guard.py tests/test_loen_guard.sh tests/test_loen_hook.py
git commit -m "feat(loen): rewire hooks.json to six specialized hooks; drop loop-guard"
```

---

## Phase 3 — Agents

### Task 12: Agents — align 3, add reviewer + researcher

**Files:**
- Modify: `plugin/loen/agents/explorer.md`, `planner.md`, `verifier.md`
- Create: `plugin/loen/agents/reviewer.md`, `researcher.md`
- Test: `tests/test_loen_agents.sh` (new)

**Interfaces:** each agent `.md` carries frontmatter `name`, `description`, `tools`, `model` matching spec §5. worker is the main session — no worker agent file.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
a="$repo_root/plugin/loen/agents"
for role in explorer planner verifier reviewer researcher; do
  [[ -f "$a/$role.md" ]] || { echo "FAIL: missing agent $role" >&2; exit 1; }
  head -20 "$a/$role.md" | grep -qi "^name:" || { echo "FAIL: $role no name" >&2; exit 1; }
  head -20 "$a/$role.md" | grep -qi "^tools:" || { echo "FAIL: $role no tools" >&2; exit 1; }
done
# reviewer + researcher are read-only (no Write/Edit in tools)
for role in reviewer researcher explorer planner; do
  if head -20 "$a/$role.md" | grep -i "^tools:" | grep -qE "Write|Edit|MultiEdit"; then
    echo "FAIL: $role must be read-only" >&2; exit 1; fi
done
echo "PASS test_loen_agents.sh"
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/test_loen_agents.sh` → FAIL (reviewer/researcher absent).

- [ ] **Step 3: Write the agents** — create `reviewer.md` (opus, Read/Grep/Glob; reviews diff/PR → findings for `5_check`/`6_reflect`) and `researcher.md` (fable, Read/Grep/Glob/Bash; metrics/experiments → `2_context`/`5_check`), porting tone from `icodex .../agents/loen-reviewer.toml` and `loen-researcher.toml` into Claude `.md` frontmatter. Update `verifier.md` to mention `evidence/verifier-verdict.md` output + optional microVM isolation. Keep `explorer.md`/`planner.md` behavior; confirm `planner.md` now emits the full spec §3 `loop.yaml`.

- [ ] **Step 4: Run to verify it passes** — `bash tests/test_loen_agents.sh` → `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/agents tests/test_loen_agents.sh
git commit -m "feat(loen): add reviewer/researcher agents; align existing roles"
```

---

## Phase 4 — Pipeline skills

SKILL.md files are prose deliverables. Each task authors the full `SKILL.md` (frontmatter `name` + `description`, then the body). Content contract per file is exact; the body is authored from the spec, porting structure from the matching `icodex/plugins/loen/skills/*/SKILL.md`.

### Task 13: `loop-start` skill

**Files:**
- Create: `plugin/loen/skills/loop-start/SKILL.md`
- Test: covered by `tests/test_loen_plugin.sh` (Task 20) — registration + required-section check.

**Content contract (`loop-start/SKILL.md`):** frontmatter `name: loop-start`, `description` naming `/loen:loop-start <topic>`. Body MUST specify, in order: (1) validate slug via `validate_topic_slug`; (2) `scaffold_topic` (Bash, not Write — the loop-gate allows bootstrap); (3) write `1_goal.md` (User Request + Success Criteria) and `2_context.md` (Facts + Constraints); (4) **invoke `loop-plan`** as the single writer of `3_plan.md`; (5) **plan approval gate** — present the plan, wait for human `approve`; (6) compute `plan_hash = plan_body_hash(3_plan.md)`, set `loop.yaml` `status: active`, `run.plan_approved: true`, `run.plan_hash`, write the `docs/loen/current` pointer; (7) hand off to `loop-run`.

> **Forward-dependency note:** step (4) invokes `loop-plan`, whose `SKILL.md` is authored in Task 14. This is a documentation forward reference only — no runtime coupling is exercised until the Task 23 smoke, by which point both skills exist. No reordering required.

- [ ] **Step 1: Author `loop-start/SKILL.md`** per the content contract.
- [ ] **Step 2: Sanity-check** — `grep -q "loop-plan" plugin/loen/skills/loop-start/SKILL.md && grep -q "plan_approved" plugin/loen/skills/loop-start/SKILL.md` → both present.
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/loop-start/SKILL.md
git commit -m "feat(loen): add loop-start bootstrap skill"
```

### Task 14: Stage skills `loop-plan`, `loop-act`, `loop-check`, `loop-reflect`

**Files:**
- Create: `plugin/loen/skills/loop-plan/SKILL.md`, `loop-act/SKILL.md`, `loop-check/SKILL.md`, `loop-reflect/SKILL.md`

**Content contracts:**
- `loop-plan`: goal+context+loop.yaml → one bounded `3_plan.md` with exact verify commands (`## Steps`, `## Checks`). Single writer of `3_plan.md`.
- `loop-act`: execute exactly one bounded action as the worker; write `4_act.md` (Action, Changed Paths, Commands); append a row to `attempts.jsonl`. Stay in `mutable_scope`.
- `loop-check`: run `quality_gates` → `5_check.md` (Evidence, Result with `PASS`); dispatch the `verifier` subagent with a capsule → `evidence/verifier-verdict.md`.
- `loop-reflect`: read verdict + gates → decide keep/fix/revert/handoff → `6_reflect.md`; when complete write `7_result.md` (`Done`).

- [ ] **Step 1: Author the four `SKILL.md` files** per the contracts, porting structure from the matching `icodex` stage skills.
- [ ] **Step 2: Sanity-check** — each file exists and names its declared output artifact/sections:

```bash
set -e
p=plugin/loen/skills
grep -q "3_plan.md"  "$p/loop-plan/SKILL.md"   && grep -q "## Checks"        "$p/loop-plan/SKILL.md"
grep -q "4_act.md"   "$p/loop-act/SKILL.md"    && grep -q "## Changed Paths" "$p/loop-act/SKILL.md"
grep -q "5_check.md" "$p/loop-check/SKILL.md"  && grep -qi "verifier"        "$p/loop-check/SKILL.md"
grep -q "7_result.md" "$p/loop-reflect/SKILL.md" && grep -q "6_reflect.md"   "$p/loop-reflect/SKILL.md"
echo "loop-plan/act/check/reflect content OK"
```
Expected: `loop-plan/act/check/reflect content OK` (non-zero exit if any artifact/section is missing).
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/loop-plan plugin/loen/skills/loop-act plugin/loen/skills/loop-check plugin/loen/skills/loop-reflect
git commit -m "feat(loen): add loop-plan/act/check/reflect stage skills"
```

### Task 15: `loop-run` skill — autonomous orchestrator

**Files:**
- Create: `plugin/loen/skills/loop-run/SKILL.md`

**Content contract (`loop-run/SKILL.md`):** frontmatter `name: loop-run`, `description` naming `/loen:loop-run`. Body MUST specify the auto-run state machine from spec §6:
1. **Preflight gate:** call `validate_run_contract(loop.yaml, 3_plan.md)`; if not OK (esp. `plan_approved != true` or `plan_hash` mismatch) → refuse with "approve the plan in loop-start first" and stop.
2. **Loop** over `run.state` `prepare→act→check→reflect`:
   - act → invoke `loop-act`; check → invoke `loop-check` (dispatch verifier); reflect → invoke `loop-reflect`.
   - reflect outcomes: gates green ∧ verifier `APPROVE` → write `7_result.md`, `status: done`, STOP; `REJECT` ∧ `current_pass < max_passes` → `current_pass++`, feed required fixes back to act; budget exceeded ∨ `handoff_condition` ∨ `REJECT` past budget ∨ gate-needs-human → write `handoff.md`, `status: handoff`, STOP.
   - update `loop.yaml` `run.state`/`run.current_pass` on every transition (resumable).
3. **Termination:** `7_result.md` (Done) or `handoff.md`. Never auto-merge — end at a human PR review.
4. **Cross-turn fallback:** if `budget.max_iterations > 5` OR `budget.max_wall_time_minutes > 60`, emit and self-run a native `/goal` (absorbs old `loop-goal`); otherwise stay in-session.

- [ ] **Step 1: Author `loop-run/SKILL.md`** per the contract.
- [ ] **Step 2: Sanity-check** — `grep -q "validate_run_contract" ... && grep -q "handoff" ... && grep -q "max_passes" ...` all present.
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/loop-run/SKILL.md
git commit -m "feat(loen): add loop-run autonomous orchestrator skill"
```

### Task 16: `loop-status` skill

**Files:**
- Create: `plugin/loen/skills/loop-status/SKILL.md`

**Content contract:** read-only; report current stage, latest evidence, open decisions, next action from artifacts; "missing file = missing state".

- [ ] **Step 1: Author `loop-status/SKILL.md`.**
- [ ] **Step 2: Sanity-check** — file exists, frontmatter `name: loop-status`.
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/loop-status/SKILL.md
git commit -m "feat(loen): add loop-status read-only summary skill"
```

---

## Phase 5 — Configurators + cross-cutting

### Task 17: Configurators — `loop-delivery`, `loop-repair`, `loop-autoresearch`, `loop-review`

**Files:**
- Modify: `plugin/loen/skills/loop-delivery/SKILL.md`, `loop-repair/SKILL.md`, `loop-autoresearch/SKILL.md`
- Create: `plugin/loen/skills/loop-review/SKILL.md`
- Delete: `plugin/loen/skills/loop-delivery/assets/` (templates moved to `assets/templates/` in Task 2)

**Content contract:** each configurator is thin — "set `mode` (`delivery`/`repair`/`research`/`review`) + call `loop-start`, then `loop-run`". `loop-repair` frames the failure into `2_context.md`; `loop-autoresearch` sets `mode: research`, `eval_command`, metrics; `loop-review` sets `mode: review`, review scope in `1_goal.md`. They own no artifacts.

- [ ] **Step 1: Rewrite the three existing configurators + author `loop-review`** to delegate. Remove the now-duplicated `loop-delivery/assets/` (templates live in `assets/templates/`).
- [ ] **Step 2: Sanity-check** — each configurator references `loop-start` and `loop-run`, and sets its `mode`.
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/loop-delivery plugin/loen/skills/loop-repair plugin/loen/skills/loop-autoresearch plugin/loen/skills/loop-review
git rm -r plugin/loen/skills/loop-delivery/assets
git commit -m "feat(loen): turn outcome skills into thin configurators; add loop-review"
```

### Task 18: `governance` + `audit` skills — topic-layout aware

**Files:**
- Modify: `plugin/loen/skills/governance/SKILL.md`, `plugin/loen/skills/audit/SKILL.md`
- Delete: `plugin/loen/skills/loop-goal/SKILL.md`

**Content contract:**
- `governance`: aggregate all `docs/loen/<topic>/` runs (topic layout, not run-id) for the offline dashboard; `--triage` proposes next actions; add the icodex recurring-policy framing.
- `audit`: manual stage re-validator `loen:audit <plan|act|check|result>` → `OK`/`needs_work`; reads the numbered artifacts; note that inside `loop-run` gating is automatic (hooks + verifier).
- Remove `loop-goal` (folded into `loop-run`).

- [ ] **Step 1: Rewrite `governance` + `audit`; delete `loop-goal`.**
- [ ] **Step 2: Sanity-check** — `governance` references `docs/loen/<topic>`; `audit` lists the four stages; `loop-goal` gone.
- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/governance plugin/loen/skills/audit
git rm -r plugin/loen/skills/loop-goal
git commit -m "feat(loen): topic-aware governance/audit; remove loop-goal skill"
```

---

## Phase 6 — Scripts

### Task 19: Topic-layout scripts — `check_layout.sh`, `guard_protected.sh`; resolve `make_goal.py`

**Files:**
- Modify: `plugin/loen/scripts/check_layout.sh`, `guard_protected.sh`
- Delete: `plugin/loen/scripts/make_goal.py`, `tests/test_loen_goal.py`
- Modify: `tests/test_loen_layout.sh` (rewrite)

**Decision (resolves spec INFO F-006):** `make_goal.py` is **removed** — the native-`/goal` fallback is inlined into the `loop-run` skill body (Task 15), so no standalone generator is needed.

**Interfaces:** `check_layout.sh <topic-dir>` accepts only canonical topic files (`[1-7]_*.md`, `loop.yaml`, `handoff.md`, `audit.html`, `attempts.jsonl`, `evidence/*`) and rejects anything else. `guard_protected.sh` parses `protected_scope` (block-style) from `loop.yaml` and fails if `git diff --name-only HEAD` touches a protected glob.

- [ ] **Step 1: Write the failing test (`test_loen_layout.sh` rewrite)**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
chk="$repo_root/plugin/loen/scripts/check_layout.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
topic="my-topic"; run="docs/loen/$topic"
mkdir -p "$run/evidence"
for f in 1_goal 2_context 3_plan 4_act 5_check 6_reflect 7_result; do : > "$run/$f.md"; done
: > "$run/loop.yaml"; : > "$run/attempts.jsonl"; : > "$run/audit.html"
: > "$run/evidence/verifier-verdict.md"
bash "$chk" "$run" || { echo "FAIL: rejected canonical topic layout" >&2; exit 1; }
: > "$run/scratch.txt"
if bash "$chk" "$run"; then echo "FAIL: accepted non-canonical artifact" >&2; exit 1; fi
echo "PASS test_loen_layout.sh"
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/test_loen_layout.sh` → FAIL (old script expects `iterations/iter-NN/`).

- [ ] **Step 3: Rewrite the scripts** — update `check_layout.sh` canonical patterns to the topic layout; update `guard_protected.sh` to read `protected_scope` from `<topic>/loop.yaml`; `git rm make_goal.py tests/test_loen_goal.py`.

- [ ] **Step 4: Run to verify it passes** — `bash tests/test_loen_layout.sh` → `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/check_layout.sh plugin/loen/scripts/guard_protected.sh tests/test_loen_layout.sh
git rm plugin/loen/scripts/make_goal.py tests/test_loen_goal.py
git commit -m "feat(loen): topic-layout scripts; remove make_goal (folded into loop-run)"
```

### Task 20: Adapt `loen_stats.py`, `log_experiment.py`, `verify_microvm.sh`; rewrite `test_loen_stats.py` + plugin registration test

**Files:**
- Modify: `plugin/loen/scripts/loen_stats.py`, `log_experiment.py`, `verify_microvm.sh`
- Modify: `tests/test_loen_stats.py`, `tests/test_loen_plugin.sh`, keep `tests/test_loen_experiment.py`, `tests/test_loen_verify_microvm.sh`

**Interfaces:** `loen_stats.py` scans `docs/loen/<topic>/` (not `<run-id>/`) and aggregates success/keep/revert/handoff from `6_reflect.md`/`7_result.md` + `evidence/`. `log_experiment.py` appends to `attempts.jsonl`/`experiments.jsonl` with the same validation. `verify_microvm.sh` unchanged in subcommands, retargeted to the topic tree.

- [ ] **Step 1: Write the failing tests** — rewrite `test_loen_stats.py` to build a topic tree and assert the aggregator reads it; rewrite `test_loen_plugin.sh` to assert all 13 skills + 5 agents + 6 hooks are present and `plugin.json` version is `1.0.0`:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
p="$repo_root/plugin/loen"
for s in loop-start loop-run loop-plan loop-act loop-check loop-reflect loop-status \
         loop-delivery loop-repair loop-autoresearch loop-review governance audit; do
  [[ -f "$p/skills/$s/SKILL.md" ]] || { echo "FAIL: missing skill $s" >&2; exit 1; }
done
[[ -f "$p/skills/loop-goal/SKILL.md" ]] && { echo "FAIL: loop-goal not removed" >&2; exit 1; }
for a in explorer planner verifier reviewer researcher; do
  [[ -f "$p/agents/$a.md" ]] || { echo "FAIL: missing agent $a" >&2; exit 1; }; done
for h in loen_common loen_artifacts loen_capsules loop-gate scope-guard tool-guard permission-guard evidence-gate audit-writer; do
  [[ -f "$p/hooks/$h.py" ]] || { echo "FAIL: missing hook $h" >&2; exit 1; }; done
grep -q '"version": "1.0.0"' "$p/.claude-plugin/plugin.json" || { echo "FAIL: version not 1.0.0" >&2; exit 1; }
echo "PASS test_loen_plugin.sh"
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/test_loen_plugin.sh` → FAIL (version still 0.5.1, skills incomplete until Phase 4/5 done). (This test passes only after Task 21 bumps the version.)

- [ ] **Step 3: Adapt the scripts + `test_loen_stats.py`** to the topic layout.

- [ ] **Step 4: Run to verify** — `python3 tests/test_loen_stats.py` → `PASS`; `python3 tests/test_loen_experiment.py` → `PASS`; `bash tests/test_loen_verify_microvm.sh` → `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/loen_stats.py plugin/loen/scripts/log_experiment.py plugin/loen/scripts/verify_microvm.sh tests/test_loen_stats.py tests/test_loen_plugin.sh
git commit -m "feat(loen): adapt stats/experiment/microvm scripts to topic layout"
```

---

## Phase 7 — Docs + version bump

### Task 21: Version bump + `docs/architecture.md` + `docs/functions/LOEN.md`

**Files:**
- Modify: `plugin/loen/.claude-plugin/plugin.json` (version → `1.0.0`)
- Create: `docs/architecture.md`
- Modify: `docs/functions/LOEN.md`

**Decision (resolves spec INFO F-007):** `docs/architecture.md` (new) + `docs/functions/LOEN.md` update are **in scope**.

- [ ] **Step 1: Bump version** — set `"version": "1.0.0"` in `plugin/loen/.claude-plugin/plugin.json`.
- [ ] **Step 2: Write `docs/architecture.md`** — isolation ladder (L0 main-session worker → L1 subagent+capsule → L3 microVM verifier), the 7-stage pipeline, the hook enforcement map, the durable-topic addressing scheme (mirror icodex `docs/architecture.md`).
- [ ] **Step 3: Update `docs/functions/LOEN.md`** — replace the outcome-model description with the stage/durable-topic model, the 13-skill map, auto-run, and the graded `LOEN_MODE`.
- [ ] **Step 4: Verify** — `bash tests/test_loen_plugin.sh` → `PASS` (version now 1.0.0 and full skill/agent/hook set present).
- [ ] **Step 5: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json docs/architecture.md docs/functions/LOEN.md
git commit -m "docs(loen): architecture.md, LOEN.md, bump plugin to 1.0.0"
```

### Task 22: Rewrite `README.md` + `README.ru.md` (MANDATORY, in sync)

**Files:**
- Modify: `plugin/loen/README.md`, `plugin/loen/README.ru.md`

**Content contract:** both files describe the NEW process schema and dependencies — the 7-stage durable-topic pipeline, the 13 skills (with the auto-run chain `configurator → loop-start → approve → loop-run`), the 7 numbered artifacts under `docs/loen/<topic>/`, the shared library + 6 hooks + graded `LOEN_MODE`, the 5 agents, the scripts, and `verifier_isolation: subagent|microvm`. Update the "What it solves" table and the version to `0.5.x → 1.0.0`. `README.ru.md` is the exact Russian mirror of `README.md` (same content, only language differs).

- [ ] **Step 1: Rewrite `README.md`** per the content contract (English).
- [ ] **Step 2: Rewrite `README.ru.md`** as the Russian mirror — same sections, same tables, same commands.
- [ ] **Step 3: Verify sync** — both list the 13 skills and the 6 hooks and version `1.0.0`:

```bash
for f in plugin/loen/README.md plugin/loen/README.ru.md; do
  grep -q "loop-run" "$f" && grep -q "loop-start" "$f" && grep -q "1.0.0" "$f" \
    || { echo "MISS in $f"; }
done
```

- [ ] **Step 4: Commit**

```bash
git add plugin/loen/README.md plugin/loen/README.ru.md
git commit -m "docs(loen): rewrite README (EN+RU) for stage/durable-topic model and auto-run"
```

---

## Phase 8 — End-to-end verification

### Task 23: Full-suite green + smoke a topic lifecycle

**Files:** none created; runs the whole suite + a manual smoke.

- [ ] **Step 1: Run the entire loen test suite**

```bash
set -e
for t in tests/test_loen_common.py tests/test_loen_artifacts.py tests/test_loen_run_contract.py \
         tests/test_loen_capsules.py tests/test_loen_scope_guard.py tests/test_loen_loop_gate.py \
         tests/test_loen_tool_guard.py tests/test_loen_permission_guard.py \
         tests/test_loen_evidence_gate.py tests/test_loen_audit_writer.py \
         tests/test_loen_stats.py tests/test_loen_experiment.py; do
  echo "== $t =="; python3 "$t"
done
for t in tests/test_loen_templates.sh tests/test_loen_layout.sh tests/test_loen_hooks_wiring.sh \
         tests/test_loen_agents.sh tests/test_loen_plugin.sh tests/test_loen_verify_microvm.sh; do
  echo "== $t =="; bash "$t"
done
```

Expected: every line ends `PASS ...`.

- [ ] **Step 2: Smoke a topic lifecycle** — using the run skill: create a throwaway topic, confirm `scaffold_topic` produces the 7 files + `loop.yaml` + `current` pointer, hand-approve a trivial plan, run one `act→check→reflect` pass, confirm `7_result.md` (Done) or `handoff.md` is written and `audit.html`/`docs/TODO.md` update. Verify a `protected_scope` edit is blocked by `scope-guard` (`LOEN_MODE=enforce`).

- [ ] **Step 3: Update the wiki + docs currency** — if the iwiki MCP server reports a domain bound to this project, update the loen page(s) via `wiki_update_page`/`wiki_write_page` and run `wiki_lint`; confirm `docs/TODO.md` row `loen-stage-durable-port` reflects the delivered state.

- [ ] **Step 4: Commit any doc/wiki fixups**

```bash
git add -A
git commit -m "test(loen): full suite green; smoke topic lifecycle; docs currency"
```

---

## Self-review notes (traceability to spec)

- Spec §1 artifact model → Tasks 2, 3 (scaffold), 19 (layout net).
- Spec §2 13 skills → Tasks 13–18 (7 pipeline), 17 (4 configurators), 18 (governance/audit); registration asserted in Task 20.
- Spec §3 `loop.yaml` contract → Task 2 (template), Task 3 (`validate_run_contract`, incl. the resolved F-001/F-002 schema: `stages.<stage>.roles`, `permissions.filesystem` mirrors top-level).
- Spec §4 hooks + shared library + graded `LOEN_MODE` → Tasks 1, 3, 4 (library), 5–11 (hooks + wiring).
- Spec §5 agents (5, worker = main session) → Task 12 (F-003 resolved: five read-only subagents).
- Spec §6 auto-run (F-005 threshold `max_iterations>5` OR `max_wall_time_minutes>60`) → Task 15.
- Spec §7 migration/tests/versioning → Tasks 11, 19, 20, 21, 22 (READMEs), plus the removals (loop-guard, loop-goal, make_goal — F-006 resolved: removed).
- Spec §7 docs (F-007 in scope) → Tasks 21 (architecture.md, LOEN.md), 22 (READMEs EN+RU).
