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
import subprocess

DOCS_ROOT = "docs/superpowers"
PLANS_DIR = os.path.join(DOCS_ROOT, "plans")

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
        "dir": "plans", "glob": "*.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "subagent-driven-development": {
        "dir": "plans", "glob": "*.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "finishing-a-development-branch": {
        "dir": "plans", "glob": "*.md",
        "block": "result_check", "hash_key": "plan_hash", "fix": "/check-result",
    },
}

# Write-trigger rules reuse existing GATE_MAP rows (same predicate, new trigger).
SPEC_RULE = GATE_MAP["writing-plans"]      # specs/*-design.md, review/spec_hash


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


def _frontmatter_from_lines(lines):
    """YAML-frontmatter между первыми двумя '---'. {} если его нет."""
    import yaml  # отложенный импорт: отсутствие → исключение → fail-open в main()
    if not lines or lines[0].strip() != "---":
        return {}
    fm = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm.append(line)
    data = yaml.safe_load("\n".join(fm))
    return data if isinstance(data, dict) else {}


def read_frontmatter(path):
    """YAML-frontmatter файла. {} если его нет."""
    with open(path, "r", encoding="utf-8") as f:
        return _frontmatter_from_lines(f.read().splitlines())


def resolve_spec_from_chain(content):
    """Путь к спеке из chain.spec в теле плана (tool_input.content).
    None, если frontmatter/chain.spec нет или файла нет на диске."""
    data = _frontmatter_from_lines((content or "").splitlines())
    chain = data.get("chain")
    spec = chain.get("spec") if isinstance(chain, dict) else None
    if spec and os.path.exists(spec):
        return spec
    return None


def _under(path, root):
    """True, если path лежит внутри root (оба приводятся к абсолютным от cwd)."""
    ap = os.path.abspath(path)
    ar = os.path.abspath(root)
    return ap == ar or ap.startswith(ar + os.sep)


def evaluate_gate(path, rule):
    """Возвращает None, если гейт ОТКРЫТ (allow), либо строку-причину BLOCK."""
    fm = read_frontmatter(path)
    block = fm.get(rule["block"])
    if not isinstance(block, dict):
        return "no %s: block" % rule["block"]

    if block.get(rule["hash_key"]) != body_hash(path):
        return "hash stale (edited after last check)"

    if rule["block"] == "result_check":
        if block.get("verdict") != "OK":
            return "result_check verdict: %s" % block.get("verdict")
        return None

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


def block(candidate, reason, fix):
    """Печатает причину в stderr и завершает с кодом 2 (блокировка)."""
    sys.stderr.write(
        "🚧 IDD gate: %s has not passed validation.\n"
        "Reason: %s\n"
        "Action: dispatch a subagent to run %s on %s (clean-context\n"
        "check-runner protocol), collect verdicts in the main session, "
        "resolve the CRITICAL\n"
        "findings, then retry.\n"
        % (candidate, reason, fix, candidate)
    )
    sys.exit(2)


def handle_write(data, tool):
    """Gate по записи downstream-артефакта (inline-переходы spec→plan, plan→impl)."""
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        sys.exit(0)  # нет пути → fail-open

    # spec→plan: создание файла плана (только Write, не Edit).
    if tool == "Write" and _under(path, PLANS_DIR) and path.endswith(".md"):
        content = (data.get("tool_input") or {}).get("content")
        spec = resolve_spec_from_chain(content) or resolve_candidate(SPEC_RULE)
        if spec is None:
            sys.exit(0)  # нет спеки → escape
        reason = evaluate_gate(spec, SPEC_RULE)
        if reason is None:
            sys.exit(0)
        block(spec, reason, SPEC_RULE["fix"])

    sys.exit(0)  # specs/intents, правка существующего плана и т.п.


def handle_skill(data):
    """Gate по вызову Skill (существующий путь IDD→SDD)."""
    skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)  # скилл не гейтируется
    candidate = resolve_candidate(rule)
    if candidate is None:
        sys.exit(0)  # нет артефакта → escape
    reason = evaluate_gate(candidate, rule)
    if reason is None:
        sys.exit(0)
    block(candidate, reason, rule["fix"])


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # битый stdin → fail-open

    tool = data.get("tool_name")
    try:
        if tool == "Skill":
            handle_skill(data)
        elif tool in ("Write", "Edit", "MultiEdit"):
            handle_write(data, tool)
        else:
            sys.exit(0)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
