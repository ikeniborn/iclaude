---
review:
  plan_hash: 8a312422a3481583
  spec_hash: 824d37b4b07dd785
  last_run: 2026-06-14
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: verifiability
      severity: WARNING
      section: Task 1
      section_hash: 8d81e10a6e9b036f
      text: >-
        Test-count off-by-one. The embedded suite defines 13 assert_exit cases,
        but every "Expected" line counted 12 (Task 1 `PASS=0 FAIL=12`; Task 4 and
        Task 8 `PASS=12 FAIL=0`; Task 2 `PASS=5 FAIL=7`). The script prints the
        real tally, so actual runs show `FAIL=13` / `PASS=13` / `PASS=6 FAIL=7`.
        Final exit code (0 when FAIL==0) is still correct, so convergence is not
        blocked — only the documented expected output is wrong. Fix: bump every
        expected count to a 13-case total.
      verdict: fixed
      verdict_at: 2026-06-14
    - id: F-002
      phase: verifiability
      severity: WARNING
      section: Task 3
      section_hash: 30f3a8bd7e399377
      text: >-
        Task 3 Step 4 expected state was wrong. It claimed `needs_work`,
        `нет result_check` and `hash drift` all still fail (`PASS=9 FAIL=3`). But
        the "no block" and "hash stale" guards added in Task 3 Step 2 sit ABOVE
        the result_check stub branch, so `нет result_check`→exit 2 and
        `hash drift`→exit 2 already pass at Task 3; only `needs_work` (stub
        returns None→exit 0) fails. Real result: `PASS=12 FAIL=1`. Fixed: Task 3
        expected restated as 12/1, only `needs_work` remains red.
      verdict: fixed
      verdict_at: 2026-06-14
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-14-idd-sdd-gates-design.md
---

# IDD→SDD Phase Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single `PreToolUse` Skill hook (`idd-gate.py`) that blocks each IDD→SDD phase transition until the upstream artifact has passed its validator (no open CRITICAL, all phases `passed`, body hash matches).

**Architecture:** The hook is *only* a gate — it reads the upstream artifact's `review:` / `result_check:` frontmatter and allows (`exit 0`) or blocks (`exit 2`). It never validates; validation is done by `/check-*` commands (dispatched to a clean-context subagent). The hook computes the artifact body hash by shelling out to the *identical* bash pipeline the validators use, guaranteeing parity. Fail-open: any internal exception → `exit 0` (a bug in the gate must never wedge every `Skill` call).

**Tech Stack:** Python 3 (stdlib + PyYAML 6.x for frontmatter), bash (hash pipeline + tests), JSON settings.

---

## ⚠️ Naming-convention note (read before Task 1)

The spec's Skill→artifact map keys plan/result gates on the glob **`plans/*-plan.md`**. Most existing files in `docs/superpowers/plans/` are named `YYYY-MM-DD-<topic>.md` (no `-plan` suffix), so they will **not** match — by the predicate's escape hatch the plan/result gates simply allow (no candidate → `exit 0`). This is intentional per spec (gate only when the artifact exists) and matches `check-result.md` / `check-plan.md`, which already assume the `-plan.md` convention. Consequence: **new plans must be named `*-plan.md` for the plan/result gates to engage** (this plan file is named `2026-06-14-idd-sdd-gates-plan.md` for exactly that reason). The glob lives in a single `GATE_MAP` constant — change it there if the convention is ever revised. Do not silently switch to `*.md` (it would grab non-plan files).

`brainstorming` (`intents/*-intent.md`) and `writing-plans` (`specs/*-design.md`) match the real convention and need no caveat. `/check-intent` already ships (`commands/check-intent.md` exists), so the `brainstorming` row is safe to enable per the spec's ordering requirement (edge case 7).

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `.nvm-isolated/.claude-isolated/hooks/idd-gate.py` | Create | The `PreToolUse` Skill gate: normalize skill → resolve candidate → evaluate predicate → allow/block. Single responsibility: gating. |
| `tests/test-idd-gate.sh` | Create | Bash stdin→exit-code test suite with self-contained fixtures (follows `tests/test-redact-hook.sh` pattern). |
| `.nvm-isolated/.claude-isolated/commands/check-result.md` | Modify | Add canonical hash section + a step that stamps `result_check:` into the **plan** frontmatter (the merge gate's pass signal). |
| `.nvm-isolated/.claude-isolated/settings.json` | Modify | Append a `PreToolUse` entry, `matcher: "Skill"` → `idd-gate.py`. |
| `CLAUDE.md` (project root) | Modify | Document the clean-context check-runner protocol under the IDD→SDD workflow section (the block message references it). |

**Build order:** test suite first (red) → hook skeleton (escape paths green) → review predicate (review tests green) → result_check predicate (suite green) → settings wiring → `check-result` stamp → CLAUDE.md doc → acceptance.

---

## Task 1: Test suite (all red)

Write the full bash test suite first. With no hook present, every case fails — that is the expected starting state.

**Files:**
- Create: `tests/test-idd-gate.sh`

- [ ] **Step 1: Write the test suite**

Create `tests/test-idd-gate.sh`:

```bash
#!/usr/bin/env bash
# tests/test-idd-gate.sh — тесты IDD→SDD gate (hooks/idd-gate.py).
# Запускать из корня проекта iclaude: ./tests/test-idd-gate.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.nvm-isolated/.claude-isolated/hooks/idd-gate.py"
PASS=0; FAIL=0
pass(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
fail(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

# Канонический хеш тела — ТОТ ЖЕ пайплайн, что у валидаторов и хука.
bodyhash(){ awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$1" | sha256sum | cut -c1-16; }

# Запускает хук в указанном project-root, печатает exit code.
run(){ ( cd "$1" && printf '%s' "$2" | python3 "$HOOK" >/dev/null 2>&1; echo $? ); }

assert_exit(){ # label cwd json expected
  local got; got=$(run "$2" "$3")
  if [[ "$got" == "$4" ]]; then pass "$1"; else fail "$1 (exit=$got, ожидался $4)"; fi
}

# ── fixtures ────────────────────────────────────────────────────────────
# Хеш считается с PLACEHOLDER в frontmatter, затем подставляется sed'ом:
# тело (всё после 2-го '---') не меняется, поэтому хеш остаётся валидным.

mk_spec_passed(){ # root → валидная пройденная спека (writing-plans → allow)
  local d="$1/docs/superpowers/specs"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-design.md"
  cat > "$f" <<'EOF'
---
review:
  spec_hash: PLACEHOLDER
  last_run: 2026-06-14
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - { id: F-001, severity: WARNING, verdict: open }
chain:
  intent: null
---

# Design: fix

Body content for hashing.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
}

mk_spec_noreview(){ # root → спека без review-блока (→ block)
  local d="$1/docs/superpowers/specs"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-design.md" <<'EOF'
---
chain:
  intent: null
---

# Design: fix

Body content for hashing.
EOF
}

mk_plan_result(){ # root verdict → план с result_check (печатает путь)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-plan.md"
  cat > "$f" <<EOF
---
result_check:
  verdict: $2
  plan_hash: PLACEHOLDER
  last_run: 2026-06-14
---

# Plan: fix

Plan body content.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
  echo "$f"
}

mk_plan_noresult(){ # root → план без result_check (→ block)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-plan.md" <<'EOF'
---
chain:
  intent: null
---

# Plan: fix

Plan body content.
EOF
}

SKILL_WP='{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}'
SKILL_WP_NS='{"tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
SKILL_FIN='{"tool_name":"Skill","tool_input":{"skill":"finishing-a-development-branch"}}'

echo "idd-gate: escape & non-gated"
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/specs"
assert_exit "не-гейтируемый скилл → 0" "$T" '{"tool_name":"Skill","tool_input":{"skill":"systematic-debugging"}}' 0
assert_exit "пустая specs/ → 0 (escape)"  "$T" "$SKILL_WP" 0
assert_exit "битый stdin → 0 (fail-open)" "$T" 'garbage{'   0
rm -rf "$T"

echo "idd-gate: review-предикат"
T=$(mktemp -d); mk_spec_passed "$T"
F="$T/docs/superpowers/specs/2026-06-14-fix-design.md"
assert_exit "passed-спека → 0"            "$T" "$SKILL_WP"    0
assert_exit "namespaced имя → 0 (как bare)" "$T" "$SKILL_WP_NS" 0
mk_spec_noreview "$T"
assert_exit "нет review: → 2"             "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/spec_hash: .*/spec_hash: 0000000000000000/' "$F"
assert_exit "stale hash → 2"              "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/coverage:    { status: passed }/coverage:    { status: in_progress }/' "$F"
assert_exit "фаза in_progress → 2"        "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/severity: WARNING/severity: CRITICAL/' "$F"
assert_exit "открытый CRITICAL → 2"       "$T" "$SKILL_WP" 2
rm -rf "$T"

echo "idd-gate: result_check-предикат"
T=$(mktemp -d); P=$(mk_plan_result "$T" OK)
assert_exit "result_check OK → 0"         "$T" "$SKILL_FIN" 0
sed -i 's/verdict: OK/verdict: needs_work/' "$P"
assert_exit "needs_work → 2"              "$T" "$SKILL_FIN" 2
mk_plan_noresult "$T"
assert_exit "нет result_check → 2"        "$T" "$SKILL_FIN" 2
P=$(mk_plan_result "$T" OK)
printf '\nextra line\n' >> "$P"
assert_exit "hash drift (тело изменено) → 2" "$T" "$SKILL_FIN" 2
rm -rf "$T"

echo "─────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Make it executable and run it (expect all-red)**

Run:
```bash
chmod +x tests/test-idd-gate.sh && ./tests/test-idd-gate.sh; echo "exit: $?"
```
Expected: every assertion fails (hook file does not exist yet → `python3` errors → exit codes non-matching), final line `PASS=0 FAIL=13`, script `exit: 1`.

- [ ] **Step 3: Commit**

```bash
git add tests/test-idd-gate.sh
git commit -m "test(idd-gate): add stdin→exit-code suite for the IDD→SDD gate"
```

---

## Task 2: Hook skeleton — escape & non-gated paths

Create the hook with the dispatch skeleton: parse stdin, normalize the skill name, look it up in `GATE_MAP`, resolve the newest candidate file, and a fail-open wrapper. `evaluate_gate` is a stub that allows everything (the real predicate lands in Tasks 3–4). This makes the three escape/non-gated cases pass.

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Write the skeleton**

Create `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`:

```python
#!/usr/bin/env python3
"""
PreToolUse hook — IDD→SDD phase gate.

Перехватывает вызовы инструмента Skill и блокирует переход к следующему
этапу цепи IDD→SDD, пока upstream-артефакт не прошёл валидацию
(нет открытых CRITICAL, все фазы passed, хеш тела совпадает).

Роль хука — ТОЛЬКО gate (block/allow); он никогда не валидирует. Валидацию
выполняет /check-* в субагенте, вердикты собираются в основной сессии.
Коммуникация — через frontmatter review:/result_check:.

Exit codes:
  0 — разрешить (Skill выполняется)
  2 — заблокировать (Skill не выполняется, Claude получает stderr)

Fail-open: любое внутреннее исключение → exit 0. Баг в гейте НЕ должен
ломать каждый вызов Skill. Это противоположность block-secrets.py (fail-closed).
"""

import sys
import json
import os
import glob

DOCS_ROOT = "docs/superpowers"

# Единственный тюнинг строгости: какие severity блокируют переход.
BLOCK_ON = {"CRITICAL"}

# skill (суффикс после последнего ':') → правило гейта:
#   dir      — поддиректория docs/superpowers/
#   glob     — шаблон файла-артефакта
#   block    — имя блока state во frontmatter ('review' | 'result_check')
#   hash_key — поле с хешем тела внутри блока
#   fix      — команда-валидатор для сообщения о блокировке
GATE_MAP = {
    "brainstorming": {
        "dir": "intents", "glob": "*-intent.md",
        "block": "review", "hash_key": "intent_hash", "fix": "/check-intent",
    },
    "writing-plans": {
        "dir": "specs", "glob": "*-design.md",
        "block": "review", "hash_key": "spec_hash", "fix": "/check-spec",
    },
    "executing-plans": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "subagent-driven-development": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "finishing-a-development-branch": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "result_check", "hash_key": "plan_hash", "fix": "/check-result",
    },
}


def normalize_skill(name):
    """Суффикс после последнего ':' ('superpowers:writing-plans' → 'writing-plans')."""
    return name.rsplit(":", 1)[-1].strip()


def resolve_candidate(rule):
    """Самый недавно изменённый файл, совпавший с glob в upstream-директории.
    None, если совпадений нет — escape hatch: hotfix без IDD-доков проходит."""
    pattern = os.path.join(DOCS_ROOT, rule["dir"], rule["glob"])
    matches = glob.glob(pattern)
    if not matches:
        return None
    return max(matches, key=os.path.getmtime)


def evaluate_gate(path, rule):
    """Возвращает None, если гейт ОТКРЫТ (allow), либо строку-причину BLOCK.
    Заглушка: реальный предикат добавляется в Tasks 3–4."""
    return None


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # битый stdin → fail-open

    if data.get("tool_name") != "Skill":
        sys.exit(0)

    skill = normalize_skill(data.get("tool_input", {}).get("skill", ""))
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)  # скилл не гейтируется

    try:
        candidate = resolve_candidate(rule)
        if candidate is None:
            sys.exit(0)  # нет артефакта → escape
        reason = evaluate_gate(candidate, rule)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)

    if reason is None:
        sys.exit(0)

    sys.stderr.write(
        "🚧 IDD gate: %s has not passed validation.\n"
        "Reason: %s\n"
        "Action: dispatch a subagent to run %s on %s (clean-context\n"
        "check-runner protocol), collect verdicts in the main session, "
        "resolve the CRITICAL\n"
        "findings, then retry the skill invocation.\n"
        % (candidate, reason, rule["fix"], candidate)
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Compile-check**

Run:
```bash
python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo COMPILE_OK
```
Expected: `COMPILE_OK`.

- [ ] **Step 3: Run the suite (escape cases pass, predicate cases still fail)**

Run:
```bash
./tests/test-idd-gate.sh; echo "exit: $?"
```
Expected: the three `escape & non-gated` cases pass; `passed-спека → 0`, `namespaced имя → 0`, and `result_check OK → 0` also pass (stub allows); the seven `→ 2` cases fail. Final line `PASS=6 FAIL=7`, `exit: 1`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py
git commit -m "feat(idd-gate): hook skeleton with escape + fail-open paths"
```

---

## Task 3: Review predicate

Implement the `review:`-based predicate: read frontmatter, recompute the body hash via the canonical bash pipeline, then block on missing block / stale hash / a phase not `passed` / an open CRITICAL finding. The `result_check` rule still returns `None` (real logic in Task 4).

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Add the hash + frontmatter helpers**

In `idd-gate.py`, add `import subprocess` to the imports (after `import glob`):

```python
import glob
import subprocess
```

Then add these two helpers immediately above `def evaluate_gate(`:

```python
def body_hash(path):
    """Хеш тела документа — ИДЕНТИЧНЫЙ пайплайн валидаторов (исключаем дрейф,
    шеллясь в тот же bash, а не переписывая на Python)."""
    pipeline = (
        "awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "
        '"%s" | sha256sum | cut -c1-16' % path
    )
    out = subprocess.run(
        ["bash", "-c", pipeline],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def read_frontmatter(path):
    """YAML-frontmatter между первыми двумя '---'. {} если его нет."""
    import yaml  # отложенный импорт: отсутствие → исключение → fail-open в main()
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    fm = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm.append(line)
    data = yaml.safe_load("\n".join(fm))
    return data if isinstance(data, dict) else {}
```

- [ ] **Step 2: Replace the `evaluate_gate` stub with the review predicate**

Replace the entire stub `def evaluate_gate(...)` body with:

```python
def evaluate_gate(path, rule):
    """Возвращает None, если гейт ОТКРЫТ (allow), либо строку-причину BLOCK."""
    fm = read_frontmatter(path)
    block = fm.get(rule["block"])
    if not isinstance(block, dict):
        return "no %s: block" % rule["block"]

    if block.get(rule["hash_key"]) != body_hash(path):
        return "hash stale (edited after last check)"

    if rule["block"] == "result_check":
        return None  # merge-gate реализуется в Task 4

    # review-based gate: все фазы passed + нет открытых CRITICAL
    for name, ph in (block.get("phases") or {}).items():
        status = ph.get("status") if isinstance(ph, dict) else None
        if status != "passed":
            return "phase %s: %s" % (name, status)

    open_critical = [
        f.get("id", "?")
        for f in (block.get("findings") or [])
        if isinstance(f, dict)
        and f.get("severity") in BLOCK_ON
        and f.get("verdict") == "open"
    ]
    if open_critical:
        return "open CRITICAL: " + ", ".join(open_critical)

    return None
```

- [ ] **Step 3: Compile-check**

Run:
```bash
python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo COMPILE_OK
```
Expected: `COMPILE_OK`.

- [ ] **Step 4: Run the suite (review cases now green)**

Run:
```bash
./tests/test-idd-gate.sh; echo "exit: $?"
```
Expected: all `escape` + all `review-предикат` cases pass; in the `result_check` block, `result_check OK → 0` passes (stub), and `нет result_check → 2` + `hash drift → 2` already pass — the no-block / hash-stale guards sit *above* the stub branch; only `needs_work → 2` still fails (stub returns `None` → exit 0). Final line `PASS=12 FAIL=1`, `exit: 1`.

- [ ] **Step 5: Inspect the block message once (manual sanity)**

Run:
```bash
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/specs"
cat > "$T/docs/superpowers/specs/x-design.md" <<'EOF'
---
chain:
  intent: null
---
# Design
body
EOF
( cd "$T" && echo '{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}' \
  | python3 "$PWD/.nvm-isolated/.claude-isolated/hooks/idd-gate.py" ); echo "exit: $?"
rm -rf "$T"
```
Expected: the `🚧 IDD gate:` block message on stderr naming `/check-spec`, `exit: 2`.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py
git commit -m "feat(idd-gate): review predicate (hash, phases, open CRITICAL)"
```

---

## Task 4: result_check (merge) predicate

Replace the `result_check` stub branch with the merge-gate logic: block unless `result_check.verdict == OK` (the hash equality is already enforced above the branch). This turns the suite fully green.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Test: `tests/test-idd-gate.sh`

- [ ] **Step 1: Implement the merge branch**

In `evaluate_gate`, replace:

```python
    if rule["block"] == "result_check":
        return None  # merge-gate реализуется в Task 4
```

with:

```python
    if rule["block"] == "result_check":
        if block.get("verdict") != "OK":
            return "result_check verdict: %s" % block.get("verdict")
        return None
```

- [ ] **Step 2: Compile-check**

Run:
```bash
python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo COMPILE_OK
```
Expected: `COMPILE_OK`.

- [ ] **Step 3: Run the full suite (all green)**

Run:
```bash
./tests/test-idd-gate.sh; echo "exit: $?"
```
Expected: final line `PASS=13 FAIL=0`, `exit: 0`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/idd-gate.py
git commit -m "feat(idd-gate): result_check merge-gate predicate"
```

---

## Task 5: Wire the hook in settings.json

Append a new `PreToolUse` entry with `matcher: "Skill"`. The existing matchers (`Read|Edit|Write|MultiEdit|Bash`, `Write|Edit|MultiEdit|Bash`) do not cover `Skill`, so this is purely additive.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`

- [ ] **Step 1: Read the current PreToolUse array**

Run:
```bash
python3 - <<'PY'
import json
d=json.load(open(".nvm-isolated/.claude-isolated/settings.json"))
print(json.dumps(d["hooks"]["PreToolUse"], indent=2, ensure_ascii=False))
PY
```
Expected: two entries (`block-secrets.py`, `redact-secrets.py`), no `Skill` matcher.

- [ ] **Step 2: Append the Skill entry**

Use Edit on `.nvm-isolated/.claude-isolated/settings.json`. Find the `redact-secrets.py` entry that closes the `PreToolUse` array and append the new object after it. Replace:

```json
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/redact-secrets.py\""
          }
        ]
      }
    ]
```

with:

```json
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/redact-secrets.py\""
          }
        ]
      },
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/idd-gate.py\""
          }
        ]
      }
    ]
```

(The closing `]` shown is the end of the `PreToolUse` array. If your local file differs in trailing whitespace, match the exact `redact-secrets.py` block and add the comma + new object.)

- [ ] **Step 3: Validate JSON + confirm the entry is present**

Run:
```bash
python3 - <<'PY'
import json
d=json.load(open(".nvm-isolated/.claude-isolated/settings.json"))
pt=d["hooks"]["PreToolUse"]
skill=[e for e in pt if e["matcher"]=="Skill"]
assert skill and "idd-gate.py" in skill[0]["hooks"][0]["command"], "Skill hook missing"
print("OK: %d PreToolUse entries, Skill→idd-gate wired" % len(pt))
PY
```
Expected: `OK: 3 PreToolUse entries, Skill→idd-gate wired` (valid JSON; a parse error means the edit broke the file — fix before continuing).

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "feat(settings): wire idd-gate.py as PreToolUse Skill hook"
```

---

## Task 6: Extend check-result.md to stamp `result_check:`

`check-result` currently produces a read-only report. Add the canonical hash section (so its `plan_hash` matches the gate's) and a final step that writes a machine-readable `result_check:` block into the **plan** frontmatter. The plan body is never touched.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-result.md`

- [ ] **Step 1: Add the canonical hashing section**

The file opens with one intro line, then `## Алгоритм`. Insert the hashing section between them. Replace:

```markdown
Сверь результаты выполнения плана с цепочкой IDD→SDD: intent + spec + plan vs git diff.

Поддерживаемые аргументы:
- Путь к файлу плана — обязателен
- `--since=<ref>` — использовать diff от указанного ref вместо HEAD

## Алгоритм
```

with:

```markdown
Сверь результаты выполнения плана с цепочкой IDD→SDD: intent + spec + plan vs git diff.

Поддерживаемые аргументы:
- Путь к файлу плана — обязателен
- `--since=<ref>` — использовать diff от указанного ref вместо HEAD

## Алгоритм

### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Хеш тела плана для `result_check.plan_hash` считается ТЕМ ЖЕ пайплайном, что у
остальных валидаторов и у idd-gate, иначе merge-gate не сойдётся:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <PLAN_FILE> | sha256sum | cut -c1-16
```

Команда ОБЯЗАНА запускать именно эту bash-команду через инструмент Bash. «В уме»
не пересчитывать.
```

- [ ] **Step 2: Add the stamping step before `## Severity`**

The report step is `### Шаг 6. Сформируй отчёт`, immediately followed by `## Severity`. Insert a new step between them. Replace:

```markdown
### Шаг 6. Сформируй отчёт

## Severity
```

with:

```markdown
### Шаг 6. Сформируй отчёт

### Шаг 7. Запиши state в frontmatter плана

После отчёта впиши машиночитаемый блок в **frontmatter плана** (тело плана НЕ
трогать — это сигнал прохождения merge-gate для idd-gate).

1. Посчитай хеш тела плана по каноническому алгоритму (см. выше).
2. Определи вердикт: `OK`, если CRITICAL findings нет (нет MISSING-шагов);
   иначе `needs_work`.
3. Создай блок `result_check:` (или обнови существующий) во frontmatter плана:
   ```yaml
   result_check:
     verdict: OK | needs_work
     plan_hash: <хеш тела плана>
     last_run: <today>
   ```
   Если frontmatter в плане отсутствует — добавь его в начало файла
   (`---` … `---`), не меняя тело.

## Severity
```

- [ ] **Step 3: Verify both edits landed**

Run:
```bash
grep -q 'sha256sum | cut -c1-16' .nvm-isolated/.claude-isolated/commands/check-result.md \
  && grep -q '### Шаг 7. Запиши state в frontmatter плана' .nvm-isolated/.claude-isolated/commands/check-result.md \
  && grep -q 'result_check:' .nvm-isolated/.claude-isolated/commands/check-result.md \
  && echo CHECK_RESULT_OK
```
Expected: `CHECK_RESULT_OK`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-result.md
git commit -m "feat(check-result): stamp result_check state into plan frontmatter"
```

---

## Task 7: Document the check-runner protocol in CLAUDE.md

Add the clean-context check-runner protocol under the IDD→SDD workflow section, so the gate's block message ("dispatch a subagent to run /check-X …") points at documented behavior.

**Files:**
- Modify: `CLAUDE.md` (project root)

- [ ] **Step 1: Append the protocol after the IDD→SDD steps**

Replace:

```markdown
## IDD → SDD workflow

For non-trivial features (new module, new CLI flag, API change, architectural decision):

1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context (Step 1 picks it up automatically)

## Commands
```

with:

```markdown
## IDD → SDD workflow

For non-trivial features (new module, new CLI flag, API change, architectural decision):

1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context (Step 1 picks it up automatically)

### Phase gates & the check-runner protocol

A `PreToolUse` Skill hook (`hooks/idd-gate.py`) blocks each phase transition until
the upstream artifact has passed its validator. Mapped transitions:

| Skill | Upstream artifact | Validator |
|-------|-------------------|-----------|
| `brainstorming` | `intents/*-intent.md` | `/check-intent` |
| `writing-plans` | `specs/*-design.md` | `/check-spec` |
| `executing-plans` / `subagent-driven-development` | `plans/*-plan.md` | `/check-plan` |
| `finishing-a-development-branch` | `plans/*-plan.md` (`result_check`) | `/check-result` |

The gate is **open** when no matching artifact exists (hotfix escape) or when the
artifact's `review:` / `result_check:` frontmatter shows all phases `passed`, a
matching body hash, and no open CRITICAL. Otherwise the gate blocks (`exit 2`) with
a message naming the fix command. The hook fails **open** on any internal error.

**When the gate blocks, do NOT run the check inline — dispatch a clean-context
subagent:**

1. **Dispatch.** Call the Agent tool: read `commands/check-<X>.md` and execute its
   algorithm against `<artifact_path>`; run all deterministic phases; compute
   hashes via the canonical bash pipeline; write the `review:` block (and
   `result_check:` for `check-result`) with new findings as `verdict: open`; do
   **not** request verdicts interactively — return the findings (`id, phase,
   severity, section, text`) as structured output. For `check-spec`, include a
   concise task/requirements summary in the prompt (the one input not derivable
   from the artifact alone).
2. **Subagent runs on a fresh context** — it reads only the target artifact, writes
   the state block, and returns findings. This is clean-context validation by
   construction, no `/clear` needed.
3. **Verdicts (main session).** Present any open CRITICAL findings and collect
   verdicts. `accepted` / `wontfix` → patch the frontmatter (gate opens — the
   predicate counts only CRITICAL with `verdict: open`). `fixed` → the user edits
   the artifact body (hash changes) → re-dispatch the subagent to re-validate.
4. **Retry.** Re-invoke the gated skill; the gate re-reads the now-passing state and
   allows the transition.

The check-runner dispatch is **never gated** — it uses Read/Bash/Edit and the Agent
tool, never a gated `Skill`. If the subagent dies or returns nothing, fall back to
running the check inline (clean-context benefit lost for that run; gate not wedged).

## Commands
```

- [ ] **Step 2: Verify the section landed**

Run:
```bash
grep -q '### Phase gates & the check-runner protocol' CLAUDE.md && echo CLAUDE_OK
```
Expected: `CLAUDE_OK`.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): document IDD→SDD gates + check-runner protocol"
```

---

## Task 8: Final acceptance

Walk the spec's acceptance criteria end-to-end.

**Files:** (none — verification only)

- [ ] **Step 1: Compile + full suite**

Run:
```bash
python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/idd-gate.py && echo COMPILE_OK
./tests/test-idd-gate.sh; echo "suite exit: $?"
```
Expected: `COMPILE_OK`, then `PASS=13 FAIL=0`, `suite exit: 0`. (Spec acceptance 1, 2, 3, 4.)

- [ ] **Step 2: Verify fail-open on a forced exception (acceptance 5)**

Run:
```bash
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/specs"
# каталог вместо файла под glob → open() внутри предиката бросит исключение
mkdir -p "$T/docs/superpowers/specs/broken-design.md"
( cd "$T" && echo '{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}' \
  | python3 "$PWD/.nvm-isolated/.claude-isolated/hooks/idd-gate.py" 2>/dev/null ); echo "exit: $?"
rm -rf "$T"
```
Expected: `exit: 0` (fail-open — a broken candidate must not wedge the session). Note: run from the iclaude repo root so `$PWD` resolves the hook; the `cd "$T"` is in a subshell.

- [ ] **Step 3: Verify the real in-repo spec opens the writing-plans gate (acceptance 6)**

Run:
```bash
echo '{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/idd-gate.py; echo "exit: $?"
```
Expected: `exit: 0`. The newest `specs/*-design.md` is `2026-06-14-idd-sdd-gates-design.md`, whose `review.spec_hash` (`824d37b4b07dd785`) matches its body hash, all phases `passed`, all findings `fixed` → gate open. (If a newer unvalidated `*-design.md` is added later, this would block — that is the intended behavior.)

- [ ] **Step 4: Spec acceptance checklist review**

Confirm each spec criterion maps to a verified step (no code change — a read-through):
- (1) `py_compile` — Step 1. ✓
- (2) open CRITICAL blocks `writing-plans`, resolution allows — suite `открытый CRITICAL → 2` + `passed-спека → 0`. ✓
- (3) `result_check.verdict: OK` allows `finishing-a-development-branch`, body edit blocks — suite `result_check OK → 0` + `hash drift → 2`. ✓
- (4) empty/absent candidate always allows — suite `пустая specs/ → 0`. ✓
- (5) forced hook exception → `exit 0` — Step 2. ✓
- (6) end-to-end chain proceeds when checks pass — Step 3 (real spec) + per-phase suite cases. ✓
- (7) check-runner protocol (subagent validate + main-session verdicts, inline fallback) — documented in `CLAUDE.md` (Task 7); behavioral, exercised at runtime. ✓

- [ ] **Step 5: Post-task checklist (project CLAUDE.md requirement)**

Run the lat-check skill and update `lat.md/` if the gate/hook is documented there. Then:
```bash
git status --short
```
Expected: clean tree (all changes committed across Tasks 1–7).

---

## Self-Review

**Spec coverage:** All four in-scope artifacts (`idd-gate.py`, `check-result.md`, `settings.json`, `CLAUDE.md`) have tasks (2–4, 6, 5, 7). GATE_MAP includes all five mapped skills. Candidate selection (newest by mtime), the canonical hash pipeline (shelled out, not reimplemented), fail-open, the block-message format, `BLOCK_ON = {"CRITICAL"}`, namespaced-name normalization, and both predicates (review + result_check) are implemented and tested. All seven acceptance criteria are walked in Task 8.

**Implementation ordering (edge case 7):** `/check-intent` already ships (`commands/check-intent.md`), so the `brainstorming` GATE_MAP row is enabled with no degradation needed.

**Naming-convention risk:** flagged up front — plan/result gates only engage on `*-plan.md` files; the glob is a single GATE_MAP constant.

**Type consistency:** `evaluate_gate(path, rule)`, `body_hash(path)`, `read_frontmatter(path)`, `resolve_candidate(rule)`, `normalize_skill(name)` keep identical signatures across Tasks 2–4. The `rule` dict keys (`dir`, `glob`, `block`, `hash_key`, `fix`) are used consistently. Frontmatter keys (`review`, `result_check`, `spec_hash`/`plan_hash`/`intent_hash`, `phases`, `findings`, `severity`, `verdict`, `status`) match the validators' format verbatim.
