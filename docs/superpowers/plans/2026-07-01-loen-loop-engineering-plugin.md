---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md
  plan: docs/superpowers/plans/2026-07-01-loen-loop-engineering-plugin.md
review:
  plan_hash: be17d7cb6429664d
  last_run: 2026-07-01
  recheck: { effort: max, verdict: OK, note: "re-verified vs real codebase: hook contract, plugin-enable mechanism, CLAUDE_PLUGIN_ROOT scope, CI" }
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - { id: F-001, severity: INFO, verdict: accepted, note: "report.template.html asset in spec §5 tree not built; audit renders via html-report skill (§12) — static base template unnecessary" }
    - { id: F-002, severity: WARNING, verdict: accepted, note: "explorer model haiku (overridable per §5.3); agents use bare names (loen: prefix only in spec table) — non-functional" }
    - { id: F-003, severity: WARNING, verdict: fixed, note: "audit act-stage guard path ${CLAUDE_PLUGIN_ROOT}/../scripts corrected to ${CLAUDE_PLUGIN_ROOT}/scripts" }
    - { id: F-004, severity: WARNING, verdict: fixed, note: "added SKILL.md frontmatter lint (Task 7 Step 2); loop-delivery/audit now have a measurable DoD" }
    - { id: F-005, severity: CRITICAL, verdict: fixed, note: "no plugin-enable step; added Task 10 (enabledPlugins loen@iclaude + --repair-plugins + verify load) — else plugin is dead code" }
    - { id: F-006, severity: WARNING, verdict: fixed, note: "assets via ${CLAUDE_PLUGIN_ROOT} in skills/subagents (hook-only env); switched to skill base-dir + absolute path to planner" }
    - { id: F-007, severity: WARNING, verdict: fixed, note: "loop-guard scope parser block-style only; hardened for inline flow lists + planner emits block-style + flow test" }
    - { id: F-008, severity: WARNING, verdict: fixed, note: "Bash-written artifacts bypass PreToolUse hook; added deterministic check_layout.sh + test, run by audit each stage (R16 closure)" }
    - { id: F-009, severity: INFO, verdict: fixed, note: "run-id date via date +%F; docs/loen/current symlink created via Bash before first Write (else hook blocks)" }
    - { id: F-010, severity: INFO, verdict: fixed, note: "README Документация-table row for LOEN.md; executor note on redact-secrets cosmetic masking of os.* in Bash output" }
    - { id: F-101, severity: WARNING, verdict: fixed, note: "stale counts in Task9 note (9 tasks/4 suites -> 10 tasks/5 suites)" }
  verdict: OK
---
# loen — Loop Engineering Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `loen`, a self-contained publishable Claude Code plugin that runs a controlled `Plan→Act→Check→Report` agent loop with an independent verifier, a machine-readable `loop.yaml` contract, and a deterministic hook that hard-enforces artifact layout/naming under `docs/loen/<run-id>/`.

**Architecture:** In-repo plugin at `plugin/loen/` (iwiki precedent), registered in the root `.claude-plugin/marketplace.json` (marketplace `iclaude`). Ships two skills (`loop-delivery`, `audit`), three read-only isolated subagents (`planner`, `explorer`, `verifier`), one PreToolUse hook (`loop-guard.py`), one gate script (`guard_protected.sh`), and template assets. Runtime results are written by the worker only, under `docs/loen/<run-id>/`; templates are plugin assets read via `${CLAUDE_PLUGIN_ROOT}`.

**Tech Stack:** Bash + Python3 (no third-party deps in the hook/guard — minimal inline YAML reading), JSON plugin manifests, Markdown skills/agents. Tests are shell + python (`tests/` flat, repo convention).

**Spec:** `docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md`

**Conventions used by every code artifact:**
- Active run pointer: `docs/loen/current` is a **symlink** to the active run dir `docs/loen/<R>/`.
- `<R>` (run-id) regex: `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$`.
- Canonical artifact paths (sole source of truth = the hook regexes in Task 4).
- Scope globs (`mutable_scope`, `protected_scope`) match with `fnmatch` semantics (`*` matches `/`).

---

## Task 1: Plugin skeleton + marketplace registration

**Files:**
- Create: `plugin/loen/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (add the `loen` entry)
- Create: `plugin/loen/README.md`
- Test: `tests/test_loen_plugin.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_plugin.sh`:

```bash
#!/usr/bin/env bash
# Validate the loen plugin manifest + marketplace registration.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }

pj="plugin/loen/.claude-plugin/plugin.json"
mj=".claude-plugin/marketplace.json"

[[ -f "$pj" ]] || fail "missing $pj"

python3 - "$pj" "$mj" <<'PY'
import json, sys
pj, mj = sys.argv[1], sys.argv[2]
p = json.load(open(pj))
assert p.get("name") == "loen", f"plugin name != loen: {p.get('name')}"
assert p.get("version"), "plugin.json missing version"
for k in ("description", "author", "license"):
    assert p.get(k), f"plugin.json missing {k}"
m = json.load(open(mj))
entry = next((x for x in m.get("plugins", []) if x.get("name") == "loen"), None)
assert entry, "loen not registered in marketplace.json"
assert entry.get("source") == "./plugin/loen", f"bad source: {entry.get('source')}"
assert entry.get("version") == p["version"], (
    f"version mismatch: marketplace {entry.get('version')} != plugin {p['version']}")
print("OK plugin manifest + marketplace registration")
PY
echo "PASS test_loen_plugin.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_loen_plugin.sh`
Expected: FAIL with `missing plugin/loen/.claude-plugin/plugin.json`

- [ ] **Step 3: Create the plugin manifest**

Create `plugin/loen/.claude-plugin/plugin.json`:

```json
{
  "name": "loen",
  "description": "Loop Engineering harness: run a controlled Plan→Act→Check→Report agent loop with an independent verifier, a machine-readable loop.yaml contract, and hard artifact-layout guardrails.",
  "version": "0.1.0",
  "author": { "name": "ikeniborn" },
  "keywords": ["loop-engineering", "agent-loop", "verifier", "workflow", "guardrails", "tdd"],
  "license": "MIT",
  "homepage": "https://github.com/ikeniborn/iclaude",
  "repository": "https://github.com/ikeniborn/iclaude"
}
```

- [ ] **Step 4: Register in the marketplace**

Modify `.claude-plugin/marketplace.json` — add a second object to the `plugins` array (after the `iwiki` entry):

```json
    {
      "name": "loen",
      "description": "Loop Engineering harness plugin: controlled agent loop, independent verifier, artifact-layout guardrails.",
      "version": "0.1.0",
      "source": "./plugin/loen",
      "author": { "name": "ikeniborn" },
      "category": "workflow"
    }
```

- [ ] **Step 5: Create the plugin README**

Create `plugin/loen/README.md`:

```markdown
# loen — Loop Engineering

Run one bounded engineering task as a controlled loop: **Plan → Act → Check → Report**,
against a machine-readable `loop.yaml` contract, judged by an independent verifier.

- `/loop-delivery <task>` — execute the loop (planner fills `loop.yaml`, you approve, worker
  makes the smallest diff, gates + verifier check it, report is generated).
- `loen:audit <stage>` — validate a stage (`plan|act|check|result`) and regenerate the
  human-readable `docs/loen/<run-id>/report.html`.

All results live under `docs/loen/<run-id>/`. Templates ship inside the plugin.
A PreToolUse hook hard-enforces the artifact layout/naming and the loop's mutable/protected
scope. See the repo `docs/functions/LOEN.md` for the full guide.
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/test_loen_plugin.sh`
Expected: `PASS test_loen_plugin.sh`

- [ ] **Step 7: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json plugin/loen/README.md .claude-plugin/marketplace.json tests/test_loen_plugin.sh
git commit -m "feat(loen): plugin skeleton + marketplace registration"
```

---

## Task 2: Template assets — loop.yaml schema + state skeleton

**Files:**
- Create: `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`
- Create: `plugin/loen/skills/loop-delivery/assets/state.template.md`
- Test: `tests/test_loen_templates.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_templates.sh`:

```bash
#!/usr/bin/env bash
# The loop.yaml template must parse as YAML and carry the required contract keys.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

tpl="plugin/loen/skills/loop-delivery/assets/loop.template.yaml"
[[ -f "$tpl" ]] || fail "missing $tpl"

python3 - "$tpl" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
required = ["name","mode","objective","context_sources","mutable_scope","protected_scope",
           "quality_gates","metrics","budget","stop_conditions","handoff_conditions",
           "rollback_policy","logging"]
missing = [k for k in required if k not in d]
assert not missing, f"loop.template.yaml missing keys: {missing}"
assert isinstance(d["mutable_scope"], list) and isinstance(d["protected_scope"], list)
assert isinstance(d["budget"], dict) and "max_iterations" in d["budget"]
print("OK loop.template.yaml schema")
PY
echo "PASS test_loen_templates.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_loen_templates.sh`
Expected: FAIL with `missing plugin/loen/skills/loop-delivery/assets/loop.template.yaml`

- [ ] **Step 3: Create the loop.yaml schema template**

Create `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`:

```yaml
# loen loop contract — filled by the planner, approved by a human, then executed.
name:                       # run-id: <YYYY-MM-DD>-<topic>
mode: delivery              # delivery | repair | research
objective: ""               # one measurable end state
context_sources: []         # docs/files the worker must read first
mutable_scope: []           # globs the worker MAY edit
protected_scope: []         # globs the worker MUST NOT edit (guard/hook read these)
quality_gates: []           # commands that must exit 0 (verifiers)
metrics:
  primary: []
  secondary: []
budget:
  max_iterations: 3
  max_wall_time_minutes: 90
  max_cost_usd: 5
stop_conditions: []         # e.g. "all quality gates pass"
handoff_conditions: []      # schema / PII / license / architecture / prod-creds -> stop, ask human
rollback_policy: ""         # how to revert failed experiments
logging:
  state_file: docs/loen/<run-id>/state.md
```

- [ ] **Step 4: Create the state skeleton template**

Create `plugin/loen/skills/loop-delivery/assets/state.template.md`:

```markdown
# Loop state — <run-id>

Baseline, attempts, decisions, known failures. Append-only; one block per iteration.

## Baseline
- Objective: <from loop.yaml>
- Gates: <quality_gates>

## Attempts
<!-- iter-NN: command(s) run, exit codes, verifier verdict, keep/revert decision, risks -->
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_loen_templates.sh`
Expected: `PASS test_loen_templates.sh`

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/skills/loop-delivery/assets/ tests/test_loen_templates.sh
git commit -m "feat(loen): loop.yaml schema + state skeleton assets"
```

---

## Task 3: guard_protected.sh (defense-in-depth gate)

**Files:**
- Create: `plugin/loen/scripts/guard_protected.sh`
- Test: `tests/test_loen_guard.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_guard.sh`:

```bash
#!/usr/bin/env bash
# guard_protected.sh must fail (exit 1) when the git diff touches a protected path,
# and pass (exit 0) when it does not.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$repo_root/plugin/loen/scripts/guard_protected.sh"
[[ -f "$guard" ]] || { echo "FAIL: missing $guard" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email t@t; git config user.name t
mkdir -p datasets src
echo "seed" > src/app.py
git add -A; git commit -qm seed
cat > loop.yaml <<'YAML'
protected_scope:
  - datasets/*
  - src/frozen.py
mutable_scope:
  - src/*
YAML

# clean-ish change (only mutable) -> exit 0
echo "change" >> src/app.py
git add -A
if bash "$guard" loop.yaml; then :; else echo "FAIL: guard blocked a clean diff" >&2; exit 1; fi

# protected change -> exit 1
echo "raw" > datasets/raw.csv
git add -A
if bash "$guard" loop.yaml; then echo "FAIL: guard allowed a protected change" >&2; exit 1; fi

echo "PASS test_loen_guard.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_loen_guard.sh`
Expected: FAIL with `missing .../plugin/loen/scripts/guard_protected.sh`

- [ ] **Step 3: Create the guard script**

Create `plugin/loen/scripts/guard_protected.sh`:

```bash
#!/usr/bin/env bash
# loen protected-path guard (defense-in-depth; runs inside quality_gates).
# Reads protected_scope globs from the active loop.yaml and fails if `git diff` touches any.
# Usage: guard_protected.sh [path/to/loop.yaml]   (default: docs/loen/current/loop.yaml)
set -euo pipefail

LOOP_YAML="${1:-docs/loen/current/loop.yaml}"
if [[ ! -e "$LOOP_YAML" ]]; then
  echo "guard_protected: no loop.yaml at $LOOP_YAML — nothing to guard" >&2
  exit 0
fi

mapfile -t protected < <(python3 - "$LOOP_YAML" <<'PY'
import sys, re
cur = None
for line in open(sys.argv[1], encoding="utf-8"):
    s = line.rstrip("\n")
    if re.match(r"^protected_scope:", s): cur = True; continue
    if re.match(r"^[A-Za-z_]", s): cur = None; continue
    m = re.match(r"^\s*-\s*(.+?)\s*$", s)
    if m and cur:
        print(m.group(1).strip().strip('"').strip("'"))
PY
)

changed="$(git diff --name-only HEAD 2>/dev/null || true)"
rc=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  for g in "${protected[@]:-}"; do
    [[ -z "$g" ]] && continue
    # shellcheck disable=SC2053
    if [[ "$f" == $g ]]; then
      echo "ERROR: protected path changed: $f (matches '$g')" >&2
      rc=1
    fi
  done
done <<< "$changed"

[[ $rc -eq 0 ]] && echo "guard_protected: OK"
exit $rc
```

- [ ] **Step 4: Make it executable + run test to verify it passes**

Run:
```bash
chmod +x plugin/loen/scripts/guard_protected.sh
bash tests/test_loen_guard.sh
```
Expected: `PASS test_loen_guard.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/guard_protected.sh tests/test_loen_guard.sh
git commit -m "feat(loen): protected-path guard script + test"
```

---

## Task 4: Hook loop-guard.py (scope + layout/naming enforcement)

**Files:**
- Create: `plugin/loen/hooks/loop-guard.py`
- Create: `plugin/loen/hooks/hooks.json`
- Test: `tests/test_loen_hook.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_hook.py`:

```python
#!/usr/bin/env python3
"""Unit tests for the loen loop-guard PreToolUse hook.
Exit 0 = allow, exit 2 = block. The hook reads tool_input.file_path from stdin JSON
and enforces layout/naming under docs/loen/ plus scope from the active loop.yaml."""
import json, os, subprocess, sys, tempfile, textwrap

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "loop-guard.py")


def run(cwd, file_path, tool="Write"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": file_path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd)
    return p.returncode


def setup_run(root, run_id="2026-07-01-demo", mutable=("src/*",), protected=("datasets/*",), flow=False):
    d = os.path.join(root, "docs", "loen", run_id)
    os.makedirs(os.path.join(d, "iterations"), exist_ok=True)
    with open(os.path.join(d, "loop.yaml"), "w") as f:
        if flow:  # inline flow-style lists
            f.write("mutable_scope: [%s]\n" % ", ".join(mutable))
            f.write("protected_scope: [%s]\n" % ", ".join(protected))
        else:      # block-style lists
            f.write("mutable_scope:\n")
            for g in mutable:
                f.write(f"  - {g}\n")
            f.write("protected_scope:\n")
            for g in protected:
                f.write(f"  - {g}\n")
    cur = os.path.join(root, "docs", "loen", "current")
    if os.path.islink(cur):
        os.unlink(cur)
    os.symlink(run_id + "/", cur)
    return run_id


def main():
    fails = []
    def check(name, got, want):
        if got != want:
            fails.append(f"{name}: got exit {got}, want {want}")

    with tempfile.TemporaryDirectory() as root:
        # no active loop -> non-loen path allowed (no-op)
        check("no-loop non-loen allow", run(root, os.path.join(root, "src/app.py")), 0)
        # no active loop -> write under docs/loen (not the pointer) blocked
        check("no-loop loen-artifact block",
              run(root, os.path.join(root, "docs/loen/2026-07-01-demo/loop.yaml")), 2)
        # bootstrap: setting the current pointer is always allowed
        check("bootstrap current allow", run(root, os.path.join(root, "docs/loen/current")), 0)

        R = setup_run(root)
        base = os.path.join(root, "docs", "loen", R)
        # canonical artifact -> allow
        check("canonical loop.yaml", run(root, os.path.join(base, "loop.yaml")), 0)
        check("canonical iter file",
              run(root, os.path.join(base, "iterations/iter-01/verifier.md")), 0)
        # malformed iteration name -> block
        check("bad iter name",
              run(root, os.path.join(base, "iterations/iter-1/verifier.md")), 2)
        # non-canonical loen path -> block
        check("non-canonical loen", run(root, os.path.join(base, "notes.txt")), 2)
        # cross-topic write -> block
        check("cross-topic",
              run(root, os.path.join(root, "docs/loen/2026-07-01-other/loop.yaml")), 2)
        # scope: mutable allowed, protected blocked, out-of-scope blocked
        check("mutable allow", run(root, os.path.join(root, "src/app.py")), 0)
        check("protected block", run(root, os.path.join(root, "datasets/raw.csv")), 2)
        check("out-of-scope block", run(root, os.path.join(root, "lib/x.sh")), 2)

        # inline flow-style scope must be enforced too
        setup_run(root, run_id="2026-07-01-flow", mutable=("lib/*",), protected=("secrets/*",), flow=True)
        check("flow mutable allow", run(root, os.path.join(root, "lib/x.sh")), 0)
        check("flow protected block", run(root, os.path.join(root, "secrets/k")), 2)

    if fails:
        print("FAIL test_loen_hook.py")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("PASS test_loen_hook.py")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_loen_hook.py`
Expected: FAIL/error — the hook file does not exist yet.

- [ ] **Step 3: Create the hook**

Create `plugin/loen/hooks/loop-guard.py`:

```python
#!/usr/bin/env python3
"""loen loop-guard — deterministic PreToolUse guard for Write|Edit|MultiEdit.

A. Layout/naming enforcement for writes under docs/loen/ (within the active topic).
B. Scope enforcement elsewhere (protected_scope / mutable_scope from the active loop.yaml).

No-op when there is no active loop (docs/loen/current absent) for non-loen paths.
Composes with the always-on secret-blocking hooks (separate).
Exit 0 = allow. Exit 2 = block (reason on stderr)."""
import fnmatch
import json
import os
import re
import sys

LOEN_ROOT = "docs/loen"
CURRENT = os.path.join(LOEN_ROOT, "current")
RUN_ID = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$")


def canon_patterns(R):
    Rq = re.escape(R)
    return [
        re.compile(r"^docs/loen/current$"),
        re.compile(r"^docs/loen/RUNBOOK\.md$"),
        re.compile(rf"^docs/loen/{Rq}/loop\.yaml$"),
        re.compile(rf"^docs/loen/{Rq}/plan\.md$"),
        re.compile(rf"^docs/loen/{Rq}/state\.md$"),
        re.compile(rf"^docs/loen/{Rq}/pr-summary\.md$"),
        re.compile(rf"^docs/loen/{Rq}/report\.html$"),
        re.compile(rf"^docs/loen/{Rq}/experiments\.jsonl$"),
        re.compile(rf"^docs/loen/{Rq}/iterations/iter-\d{{2}}/(diff\.patch|gates\.log|verifier\.md)$"),
    ]


def rel(path):
    try:
        return os.path.relpath(os.path.abspath(path), os.getcwd()).replace(os.sep, "/")
    except Exception:
        return path


def active_run():
    """Return the active run-id from the docs/loen/current symlink, or None."""
    if os.path.islink(CURRENT):
        return os.path.basename(os.readlink(CURRENT).rstrip("/"))
    return None


def _inline_list(s):
    """Parse an inline flow list 'key: [a, b]' -> [a, b]; None if not inline."""
    m = re.match(r"^[\w-]+:\s*\[(.*)\]\s*$", s)
    if m is None:
        return None
    body = m.group(1).strip()
    return [x.strip().strip('"').strip("'") for x in body.split(",") if x.strip()] if body else []


def load_scope(R):
    """Return (mutable, protected) glob lists from the active loop.yaml, or ([], []).
    Handles BOTH block-style lists and inline flow lists ('key: [a, b]')."""
    ly = os.path.join(LOEN_ROOT, R, "loop.yaml") if R else None
    if not ly or not os.path.exists(ly):
        return [], []
    mutable, protected, cur = [], [], None
    with open(ly, encoding="utf-8") as f:
        for line in f:
            s = line.rstrip("\n")
            hit = mutable if re.match(r"^mutable_scope:", s) else \
                  protected if re.match(r"^protected_scope:", s) else None
            if hit is not None:
                inline = _inline_list(s)
                if inline is None:
                    cur = hit            # block-style list follows on next lines
                else:
                    hit.extend(inline)   # inline flow list on this line
                    cur = None
                continue
            if re.match(r"^[A-Za-z_]", s):
                cur = None
                continue
            m = re.match(r"^\s*-\s*(.+?)\s*$", s)
            if m and cur is not None:
                cur.append(m.group(1).strip().strip('"').strip("'"))
    return mutable, protected


def block(msg):
    sys.stderr.write("loen loop-guard: " + msg + "\n")
    sys.exit(2)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    fp = (data.get("tool_input") or {}).get("file_path")
    if not fp:
        sys.exit(0)
    path = rel(fp)
    R = active_run()

    if path == "docs/loen/current":
        sys.exit(0)  # bootstrap: setting the active-run pointer is always allowed
    if path == "docs/loen/RUNBOOK.md":
        sys.exit(0)

    if path.startswith("docs/loen/"):
        if R is None:
            block("no active loop (docs/loen/current missing); bootstrap the run first")
        m = re.match(r"^docs/loen/([^/]+)/", path)
        seg = m.group(1) if m else ""
        if not RUN_ID.match(seg):
            block(f"malformed run-id segment '{seg}' (expected <YYYY-MM-DD>-<topic>)")
        if seg != R:
            block(f"cross-topic write: '{seg}' != active run '{R}' — stay within the active topic")
        for pat in canon_patterns(R):
            if pat.match(path):
                sys.exit(0)
        block(
            f"non-canonical loen artifact path: {path}\n"
            f"  expected: docs/loen/{R}/{{loop.yaml,plan.md,state.md,pr-summary.md,report.html,experiments.jsonl}}\n"
            f"  or:       docs/loen/{R}/iterations/iter-NN/{{diff.patch,gates.log,verifier.md}}"
        )

    # outside docs/loen/ -> scope enforcement, only when a loop is active
    if R is None:
        sys.exit(0)
    mutable, protected = load_scope(R)
    for g in protected:
        if fnmatch.fnmatch(path, g):
            block(f"protected_scope violation: {path} matches '{g}'")
    if mutable and not any(fnmatch.fnmatch(path, g) for g in mutable):
        block(f"out-of-scope edit: {path} not in mutable_scope {mutable}")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Create the hook registration**

Create `plugin/loen/hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/loop-guard.py\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python3 tests/test_loen_hook.py`
Expected: `PASS test_loen_hook.py`

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/hooks/ tests/test_loen_hook.py
git commit -m "feat(loen): loop-guard hook (scope + layout/naming enforcement) + tests"
```

- [ ] **Step 7: Write the failing layout-validator test**

The hook guards only `Write|Edit|MultiEdit`. Artifacts written via **Bash** (`git diff > diff.patch`,
`cmd > gates.log`) bypass it — so `loen:audit` runs a deterministic filesystem validator each
stage. Create `tests/test_loen_layout.sh`:

```bash
#!/usr/bin/env bash
# check_layout.sh must accept a canonical docs/loen/<R>/ tree and reject any non-canonical file.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
chk="$repo_root/plugin/loen/scripts/check_layout.sh"
[[ -f "$chk" ]] || { echo "FAIL: missing $chk" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
R=2026-07-01-demo; run="docs/loen/$R"
mkdir -p "$run/iterations/iter-01"
: > "$run/loop.yaml"; : > "$run/state.md"
: > "$run/iterations/iter-01/diff.patch"; : > "$run/iterations/iter-01/gates.log"
bash "$chk" "$run" || { echo "FAIL: rejected a canonical layout" >&2; exit 1; }
: > "$run/scratch.txt"   # non-canonical
if bash "$chk" "$run"; then echo "FAIL: accepted a non-canonical artifact" >&2; exit 1; fi
echo "PASS test_loen_layout.sh"
```

- [ ] **Step 8: Run it to verify it fails**

Run: `bash tests/test_loen_layout.sh`
Expected: FAIL with `missing .../plugin/loen/scripts/check_layout.sh`

- [ ] **Step 9: Create the layout validator**

Create `plugin/loen/scripts/check_layout.sh`:

```bash
#!/usr/bin/env bash
# loen layout validator (deterministic net). Every file under docs/loen/<R>/ must match a
# canonical path — catches artifacts written via Bash that bypass the PreToolUse hook.
# Usage: check_layout.sh [run-dir]   (default: resolve docs/loen/current)
set -euo pipefail
run="${1:-}"
if [[ -z "$run" ]]; then
  [[ -L docs/loen/current ]] || { echo "check_layout: no docs/loen/current" >&2; exit 0; }
  run="docs/loen/$(basename "$(readlink docs/loen/current)")"
fi
R="$(basename "$run")"
[[ "$R" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$ ]] || { echo "check_layout: bad run-id '$R'" >&2; exit 1; }
rc=0
while IFS= read -r f; do
  rel="${f#"$run"/}"
  case "$rel" in
    loop.yaml|plan.md|state.md|pr-summary.md|report.html|experiments.jsonl) ;;
    iterations/iter-[0-9][0-9]/diff.patch) ;;
    iterations/iter-[0-9][0-9]/gates.log) ;;
    iterations/iter-[0-9][0-9]/verifier.md) ;;
    *) echo "check_layout: non-canonical artifact: $f" >&2; rc=1 ;;
  esac
done < <(find "$run" -type f 2>/dev/null)
[[ $rc -eq 0 ]] && echo "check_layout: OK ($R)"
exit $rc
```

- [ ] **Step 10: Make executable, run test, commit**

```bash
chmod +x plugin/loen/scripts/check_layout.sh
bash tests/test_loen_layout.sh
git add plugin/loen/scripts/check_layout.sh tests/test_loen_layout.sh
git commit -m "feat(loen): deterministic layout validator (catches Bash-written artifacts)"
```

---

## Task 5: Subagents — planner / explorer / verifier

**Files:**
- Create: `plugin/loen/agents/planner.md`
- Create: `plugin/loen/agents/explorer.md`
- Create: `plugin/loen/agents/verifier.md`
- Test: extend `tests/test_loen_plugin.sh` with an agent-frontmatter check

- [ ] **Step 1: Add a failing frontmatter-lint check to the plugin test**

Append to `tests/test_loen_plugin.sh` (before the final `echo "PASS ..."` line):

```bash
# --- agent frontmatter lint ---
for a in planner explorer verifier; do
  f="plugin/loen/agents/$a.md"
  [[ -f "$f" ]] || fail "missing agent $f"
  python3 - "$f" "$a" <<'PY'
import sys, re
f, name = sys.argv[1], sys.argv[2]
t = open(f, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, f"{f}: missing frontmatter"
fm = m.group(1)
for key in ("name:", "description:", "tools:", "model:"):
    assert key in fm, f"{f}: frontmatter missing {key}"
assert re.search(rf"^name:\s*{name}\s*$", fm, re.M), f"{f}: name != {name}"
print(f"OK agent {name}")
PY
done
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_loen_plugin.sh`
Expected: FAIL with `missing agent plugin/loen/agents/planner.md`

- [ ] **Step 3: Create planner.md**

Create `plugin/loen/agents/planner.md`:

```markdown
---
name: planner
description: Decompose a loop task, assess risks, and produce the filled loop.yaml contract + a short step plan. Read-only; returns everything as text for the worker to persist.
tools: Read, Grep, Glob
model: opus
---

You run in an isolated context. You do NOT write files. Your entire output is your return
value: (1) a complete `loop.yaml` (filled from the schema below) and (2) a short numbered
plan. The worker persists them.

Inputs you are given: the task description and the ABSOLUTE path to the loop.yaml schema
(the worker passes it in your dispatch prompt — loop-delivery resolves it from its own skill
directory; do not rely on `${CLAUDE_PLUGIN_ROOT}`, which is only set for hooks). Read the
repo to fill real values.

Steps:
1. Read the task and the schema. Read `docs/loen/RUNBOOK.md` if present.
2. Infer the project's check commands (from package.json / pyproject.toml / Makefile / CI)
   for `quality_gates` when no RUNBOOK exists.
3. Fill every schema key with concrete values:
   - `name`: the run-id `<YYYY-MM-DD>-<topic>`.
   - `mutable_scope` / `protected_scope`: minimal, specific globs. Never leave both empty.
   - `objective`: one measurable end state.
   - `quality_gates`: real commands that exit 0 on success.
   - `budget`, `stop_conditions`, `handoff_conditions`, `rollback_policy`: fill sensibly.
4. Produce a short plan (3–8 steps), each with a one-line definition of done.

Return format:
- A fenced ```yaml block: the complete loop.yaml.
- Then a `## Plan` section: numbered steps with their DoD.
Do not include prose outside these two blocks. Flag any handoff-worthy risk explicitly.
```

- [ ] **Step 4: Create explorer.md**

Create `plugin/loen/agents/explorer.md`:

```markdown
---
name: explorer
description: Read-only evidence gathering before act or review. Traces real code paths and returns a compact digest, keeping the main loop context clean.
tools: Read, Grep, Glob
model: haiku
---

You run in an isolated context and write nothing. You gather evidence and return a compact
digest — the worker never sees the files you read, only your summary.

Steps:
1. Given a question (e.g. "where is X handled?", "what does the current gate output?"),
   search the repo with Grep/Glob and read only the relevant excerpts.
2. Trace the real execution path; cite files and symbols as `path:line`.
3. Return a tight digest: the answer, the key files/symbols, and any risk you noticed.

Keep the return under ~30 lines. Do not dump whole files. Do not propose edits.
```

- [ ] **Step 5: Create verifier.md**

Create `plugin/loen/agents/verifier.md`:

```markdown
---
name: verifier
description: Strict, independent verifier of a loop iteration's diff and evidence. Read-only; runs the gates itself and returns APPROVE/REJECT with findings. Never the worker's rubber stamp.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You run in a fresh isolated context — you never see the worker's reasoning. Review the
current diff and evidence like a production owner. You edit nothing; you MAY run the
loop.yaml `quality_gates` with Bash to confirm evidence independently.

Inputs: the active `docs/loen/current/loop.yaml`, the iteration's
`docs/loen/<run-id>/iterations/iter-NN/{diff.patch,gates.log}`.

Check:
- acceptance criteria in `objective` are met and the evidence actually ran;
- no `protected_scope` file changed; the diff stays within `mutable_scope`;
- the diff is small and reviewable;
- no hidden schema / migration / PII / secret / license risk;
- a rollback path is clear.

Return exactly:
- `VERDICT: APPROVE` or `VERDICT: REJECT`
- `EVIDENCE:` commands you ran + their exit codes
- `MISSING:` checks not yet run (or "none")
- `RISKS:` concrete risks (or "none")
- `REQUIRED FIXES:` numbered, concrete (empty on APPROVE)
Default to REJECT when evidence is absent or ambiguous.
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/test_loen_plugin.sh`
Expected: `PASS test_loen_plugin.sh` (with `OK agent planner/explorer/verifier`)

- [ ] **Step 7: Commit**

```bash
git add plugin/loen/agents/ tests/test_loen_plugin.sh
git commit -m "feat(loen): planner/explorer/verifier subagents + frontmatter lint"
```

---

## Task 6: Skill loop-delivery (executor)

**Files:**
- Create: `plugin/loen/skills/loop-delivery/SKILL.md`

- [ ] **Step 1: Create the skill**

Create `plugin/loen/skills/loop-delivery/SKILL.md`:

```markdown
---
name: loop-delivery
description: Execute one delivery task as a controlled loop — plan, act (smallest diff), check (gates + independent verifier), report — writing all artifacts under docs/loen/<run-id>/. Independent of the IDD→SDD chain; works in any repo.
---

# Loop Delivery

Run ONE bounded task as a controlled loop. You are the **worker** and the **only writer**.
Subagents (`planner`, `explorer`, `verifier`) run in isolated context and return text — you
persist their output. All artifacts go under `docs/loen/<run-id>/` (the loop-guard hook
enforces the layout).

## Steps

1. **Bootstrap the run.** Derive `<today>` via `date +%F`; `run-id = <today>-<topic>`.
   With **Bash** (not the Write tool) create the run dir and the pointer BEFORE any
   Write-tool artifact — the loop-guard hook blocks docs/loen writes when no run is active:
   `mkdir -p docs/loen/<run-id>/iterations && ln -sfn <run-id> docs/loen/current`.
   Copy the state skeleton from this skill's `assets/state.template.md` (the skill base
   directory is printed when this skill is invoked; `assets/` is a sibling of this SKILL.md)
   into `docs/loen/<run-id>/state.md`.
2. **Author the contract.** Dispatch the `planner` subagent (isolated), passing the task and
   the ABSOLUTE path to this skill's `assets/loop.template.yaml` (resolved from the skill
   base directory — not `${CLAUDE_PLUGIN_ROOT}`, which is unset outside hooks). Instruct the
   planner to emit `mutable_scope`/`protected_scope` as block-style YAML lists. It returns a
   filled `loop.yaml` + a plan. Validate the YAML parses, then write
   `docs/loen/<run-id>/loop.yaml` and `docs/loen/<run-id>/plan.md`.
3. **Human approval gate.** Show the contract (scope + budget). Ask the human to approve
   before any edit. Do not proceed without it.
4. **Run `loen:audit plan`** — must return `OK` before Act.
5. **Act.** Make the smallest diff toward the objective. Stay in `mutable_scope` (the hook
   blocks otherwise). Save the iteration diff to
   `docs/loen/<run-id>/iterations/iter-NN/diff.patch` (`git diff > …`). Use `explorer`
   when you need code evidence without loading files into this context.
6. **Check.** Run the `quality_gates` from `loop.yaml`; capture output to
   `iterations/iter-NN/gates.log`. Then **run `loen:audit check`** — it dispatches the
   `verifier` and writes `iterations/iter-NN/verifier.md`.
7. **Fix.** Address only verifier-confirmed issues. Repeat Act→Check within
   `budget.max_iterations`.
8. **Report.** When gates are green and the verifier APPROVEs, **run `loen:audit result`**
   to finalize `report.html`, write `pr-summary.md`, and mark the `docs/TODO.md` row.

## Stop conditions
- All quality gates pass and the verifier APPROVEs → produce the PR-ready summary.
- A gate fails for a reason needing a human decision → stop.
- `budget` exceeded → stop, report the best result and the blocker.
- A `handoff_conditions` trigger (schema / PII / license / architecture / prod creds) →
  hard stop, ask the human. Never auto-merge.
```

- [ ] **Step 2: Commit**

```bash
git add plugin/loen/skills/loop-delivery/SKILL.md
git commit -m "feat(loen): loop-delivery executor skill"
```

---

## Task 7: Skill audit (validator + live report)

**Files:**
- Create: `plugin/loen/skills/audit/SKILL.md`

- [ ] **Step 1: Create the skill**

Create `plugin/loen/skills/audit/SKILL.md`:

```markdown
---
name: audit
description: Validate a loen loop stage (plan|act|check|result), gate progression, and regenerate the human-readable docs/loen/<run-id>/report.html via the html-report skill. Mirrors check-chain for the execution loop.
---

# loen:audit — loop stage validator + live report

Invoke as `loen:audit <stage>` where `stage ∈ plan | act | check | result`. Read the active
run from `docs/loen/current`. Every stage returns a verdict `OK` / `needs_work`, gates the
next stage, and **regenerates `docs/loen/<run-id>/report.html`** (via the `html-report`
skill) plus appends to `state.md`.

## Stage checks

- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `needs_work` blocks Act.
- **act** — the latest `iterations/iter-NN/diff.patch` exists and touches only
  `mutable_scope`; no `protected_scope` path present (cross-check with this plugin's
  `scripts/guard_protected.sh` via the run's loop.yaml, resolved from the skill base dir);
  and the run dir passes this plugin's `scripts/check_layout.sh` — the deterministic net
  that catches any Bash-written non-canonical artifact that bypassed the PreToolUse hook.
- **check** — dispatch the `verifier` subagent (isolated); write its verdict to
  `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates ran. `OK` iff the
  verdict is APPROVE and gates are green.
- **result** — every plan step is done, gates green, verifier APPROVE across the final
  iteration. On `OK`: finalize `report.html`, ensure `pr-summary.md` exists, and mark the
  `docs/TODO.md` row (`Result: OK`, `Status: done`, `Closed: <today>`) keyed by `<topic>`.

## report.html (every stage)

Invoke the `html-report` skill targeting `docs/loen/<run-id>/report.html` with: the
contract (`loop.yaml`), an iterations table (diff summary, gates pass/fail, verifier
verdict), metrics before/after (research mode), budget spend, current stage/verdict, and
handoff reasons. Self-contained, opens by double-click.

## Rules
- Never edit the diff you are judging. Never weaken a gate to pass.
- All writes land at canonical `docs/loen/<run-id>/` paths (the loop-guard hook enforces
  this); the report is `report.html`, nothing else.
```

- [ ] **Step 2: Add a SKILL.md frontmatter lint + run it**

Append to `tests/test_loen_plugin.sh` (before the final `echo "PASS test_loen_plugin.sh"` line):

```bash
# --- skill frontmatter lint ---
for s in loop-delivery audit; do
  f="plugin/loen/skills/$s/SKILL.md"
  [[ -f "$f" ]] || fail "missing skill $f"
  python3 - "$f" "$s" <<'PY'
import sys, re
f, name = sys.argv[1], sys.argv[2]
t = open(f, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, f"{f}: missing frontmatter"
fm = m.group(1)
for key in ("name:", "description:"):
    assert key in fm, f"{f}: frontmatter missing {key}"
assert re.search(rf"^name:\s*{name}\s*$", fm, re.M), f"{f}: name != {name}"
print(f"OK skill {name}")
PY
done
```

Run: `bash tests/test_loen_plugin.sh`
Expected: `PASS test_loen_plugin.sh` (with `OK skill loop-delivery` and `OK skill audit`)

- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/audit/SKILL.md tests/test_loen_plugin.sh
git commit -m "feat(loen): audit stage-validator skill + skill frontmatter lint"
```

---

## Task 8: Repo docs — LOEN.md + README section

**Files:**
- Create: `docs/functions/LOEN.md`
- Modify: `README.md` (add a `### Loop Engineering (loen)` subsection under the features)

- [ ] **Step 1: Create docs/functions/LOEN.md**

Create `docs/functions/LOEN.md`:

```markdown
# Loop Engineering (loen)

`loen` is an in-repo Claude Code plugin (`plugin/loen/`, marketplace `iclaude`) that runs a
controlled `Plan → Act → Check → Report` agent loop with an independent verifier.

## Install

The plugin ships with the repo. Enable it at user scope through the plugin system
(marketplace `iclaude`, plugin `loen`). It installs to
`.nvm-isolated/.claude-isolated/plugins/cache/iclaude/loen/<version>/`.

## Use

- `/loop-delivery <task>` — the executor. The `planner` subagent fills a `loop.yaml`
  contract, you approve scope + budget, the worker makes the smallest diff, `quality_gates`
  + the independent `verifier` check it, and a report is produced.
- `loen:audit plan|act|check|result` — validate a stage, gate progression, and regenerate
  `docs/loen/<run-id>/report.html`.

## Artifacts

All results live under `docs/loen/<run-id>/` (run-id = `<YYYY-MM-DD>-<topic>`):

| Path | Content |
|---|---|
| `loop.yaml` | the contract (planner-filled, human-approved) |
| `plan.md` | the step plan |
| `state.md` | append-only attempt/decision log |
| `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` | per-iteration evidence |
| `report.html` | consolidated human-readable report |
| `pr-summary.md` | PR-ready summary |

Templates ship inside the plugin (not scaffolded into the project). A PreToolUse hook
(`loop-guard.py`) hard-enforces the layout/naming within the active topic and the loop's
`mutable_scope`/`protected_scope`. It is a no-op in non-loop repos.

## Subagents

`planner` (opus), `explorer` (haiku), `verifier` (sonnet) — all read-only, isolated
context; the worker (main session) is the single writer.

## Scope

MVP ships delivery + verifier + guard. `loop-repair` / `loop-autoresearch` and governance
are later increments.
```

- [ ] **Step 2: Add the README section**

Modify `README.md` — (a) insert this subsection after the "Сжатие токенов (Caveman)" section (before "### Обновление и диагностика"); (b) add a row to the "Документация по разделам" table: `| Loop Engineering (loen) | docs/functions/LOEN.md |`.

```markdown
### Loop Engineering (loen)

Плагин `loen` (`plugin/loen/`, маркетплейс `iclaude`) запускает управляемую петлю
`Plan → Act → Check → Report` с независимым verifier. Задача описывается машиночитаемым
контрактом `loop.yaml`; worker делает минимальный diff; детерминированные gates и
subagent `verifier` подтверждают результат; отчёт собирается в `docs/loen/<run-id>/report.html`.

```bash
# В сессии:
/loop-delivery <task>              # выполнить петлю (planner → апрув → act → verifier → отчёт)
/loen:audit plan|act|check|result  # проверить стадию + обновить report.html
```

**Артефакты:** `docs/loen/<run-id>/` (loop.yaml, plan.md, state.md, iterations/iter-NN/,
report.html, pr-summary.md). Шаблоны — ассеты плагина. Хук `loop-guard.py` жёстко
контролирует раскладку/именование и scope; в не-loop репозиториях — no-op.

Подробнее: [docs/functions/LOEN.md](docs/functions/LOEN.md).
```

- [ ] **Step 3: Commit**

```bash
git add docs/functions/LOEN.md README.md
git commit -m "docs(loen): add LOEN.md guide + README section"
```

---

## Task 9: Full test run + wiki page + TODO

**Files:**
- Run: all `tests/test_loen_*`
- iwiki: write the `loen-plugin` page in the `iclaude` domain
- Modify: `docs/TODO.md` (Notes: implementation complete)

- [ ] **Step 1: Run the full loen test suite**

Run:
```bash
bash tests/test_loen_plugin.sh
bash tests/test_loen_templates.sh
bash tests/test_loen_guard.sh
bash tests/test_loen_layout.sh
python3 tests/test_loen_hook.py
```
Expected: five `PASS ...` lines, no failures.

- [ ] **Step 2: Verify the plugin version-sync guard passes**

Run: `bash scripts/check-plugin-version-sync.sh`
Expected: exit 0 (loen `plugin.json` version == `marketplace.json` version).

- [ ] **Step 3: Write the iwiki page**

Using the iwiki MCP tools (domain `iclaude`): `wiki_write_page(domain="iclaude",
slug="loen-plugin", markdown=<overview of loen: purpose, components, artifact model,
loop.yaml contract, hook enforcement, subagent roster>, source="plugin/loen")`, then
`wiki_lint` — no broken `[[refs]]`, no orphan/stale pages.

- [ ] **Step 4: Update the TODO row**

Modify the `loen-loop-engineering-plugin` row in `docs/TODO.md` — append to Notes:
`implementation complete (10 tasks TDD); 5/5 loen test suites green`.

- [ ] **Step 5: Commit**

```bash
git add docs/TODO.md
git commit -m "chore(loen): full test suite green + iwiki page + TODO update"
```

---

## Task 10: Enable the plugin + verify it loads

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json` (add `loen@iclaude` to `enabledPlugins`)

Building `plugin/loen/` does NOT activate it. Claude Code loads in-repo plugins only when
they are listed in `enabledPlugins` of the isolated `settings.json` (this is why the `iwiki`
plugin — absent from that list — is dormant).

- [ ] **Step 1: Ensure the iclaude marketplace path resolves on this machine**

The isolated `settings.json` `extraKnownMarketplaces.iclaude.path` is committed and may point
at another machine. Run: `./iclaude.sh --repair-plugins`
Expected: plugin/marketplace paths rewritten to this repo; no error.

- [ ] **Step 2: Enable loen in enabledPlugins**

In `.nvm-isolated/.claude-isolated/settings.json`, add to the `enabledPlugins` object:

```json
    "loen@iclaude": true
```

- [ ] **Step 3: Verify the plugin loads (fresh session)**

Enabling requires a NEW Claude Code session to load skills/agents/hooks. Start `./iclaude.sh` and verify:
- the `loop-delivery` and `loen:audit` skills appear in the skill list;
- the `planner`/`explorer`/`verifier` subagents are available to the Agent tool;
- the `loop-guard` hook fires: with `docs/loen/current` set, a Write to a non-canonical
  `docs/loen/<R>/x` is blocked.

Expected: all load; the hook blocks the non-canonical write.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "chore(loen): enable loen@iclaude in isolated settings"
```

---

## Notes for the executor

- **TDD order matters:** Tasks 1–4 are test-first (real assertions). Tasks 5–8 are content
  artifacts (markdown/JSON) verified by lint + the full run in Task 9.
- **Do not create `docs/loen/` in this repo as a committed fixture** — the hook/layout tests
  build their own tempdir fixtures; runtime `docs/loen/` artifacts are produced per loop run
  and are not part of the plugin.
- **`${CLAUDE_PLUGIN_ROOT}` is set for HOOKS only.** In `hooks.json` it is correct. Inside a
  SKILL body or a subagent it is NOT reliably set — reference assets/scripts from the skill's
  printed base directory and pass absolute paths to subagents. Tests use repo-relative paths.
- **Redaction display artifact:** the always-on `redact-secrets` hook cosmetically masks
  tokens like `os.path.islink` / `os.symlink` in **Bash output** (a `grep REDACTED` of the
  file returns nothing — the file is correct). Do NOT "fix" `REDACTED…` seen in `cat`/`grep`
  output; trust the file and the tests.
- **Verifier is not a hard FS sandbox:** it has `Bash` to run gates, which may write caches
  (`__pycache__`, `.pytest_cache`). Acceptable; it must not edit source. For true isolation
  run it under iclaude microVM (optional, not default).
- **No test CI:** the repo has no test-running workflow; run the loen suites manually
  (Task 9). `docs/loen/<run-id>/` artifacts are committed as the loop's audit trail.
- **No auto-merge.** The loop always ends at a human PR review.
```
