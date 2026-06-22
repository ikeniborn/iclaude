#!/usr/bin/env python3
"""
PreToolUse hook — IDD→SDD phase gate.

Перехватывает вызовы инструмента Skill и блокирует переход к следующему
этапу цепи IDD→SDD, пока upstream-артефакт не прошёл валидацию
(нет открытых CRITICAL, все фазы passed, хеш тела совпадает).

Роль хука — ТОЛЬКО gate (block/allow); он никогда не валидирует. Валидацию
выполняет /check-* в субагенте, вердикты собираются в основной сессии.
Коммуникация — через frontmatter review:/result_check:.

Session scoping — гейт резолвит кандидата ТОЛЬКО среди артефактов, которыми
владеет текущая сессия (session_id из payload), записанных в ledger
$CLAUDE_CONFIG_DIR/state/idd-sessions.json. Сессия, не создававшая артефакт,
не гейтится чужим артефактом. Нет session_id / ledger недоступен → fail-open.

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
import time
import subprocess

DOCS_ROOT = "docs/superpowers"
PLANS_DIR = os.path.join(DOCS_ROOT, "plans")

# Единственный тюнинг строгости: какие severity блокируют переход.
BLOCK_ON = {"CRITICAL"}

# Recency window for the plan→impl gate: only a plan edited within this many
# seconds gates code edits; older (stale) drafts pass through. 2h.
IMPL_GATE_FRESH_SECONDS = 7200

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
PLAN_RULE = GATE_MAP["executing-plans"]    # plans/*.md, review/plan_hash

# ── session-ownership ledger ────────────────────────────────────────────
LEDGER_MAX_AGE_SECONDS = 7 * 24 * 3600  # prune backstop for stale entries
ARTIFACT_DIRS = ("intents", "specs", "plans")
CLAIM_SKILLS = {"executing-plans", "subagent-driven-development"}


def ledger_path():
    """Path to the ownership ledger, or None when CLAUDE_CONFIG_DIR is unset
    (→ ledger unreachable → every session owns nothing → all gates open)."""
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    return os.path.join(cfg, "state", "idd-sessions.json") if cfg else None


def load_ledger():
    """Ledger {abspath: {"session", "ts"}}; {} on missing/corrupt (fail-open).
    Prunes entries whose artifact is gone or older than the max-age backstop."""
    path = ledger_path()
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, ValueError, OSError):
        return {}
    if not isinstance(data, dict):
        return {}
    now = time.time()
    out = {}
    for key, val in data.items():
        if not isinstance(val, dict) or not os.path.exists(key):
            continue
        if now - val.get("ts", 0) > LEDGER_MAX_AGE_SECONDS:
            continue
        out[key] = val
    return out


def record_owner(path, sid):
    """Stamp `sid` as owner of `path` (abspath-keyed, last-writer-wins).
    Atomic write; failures are swallowed (ownership is best-effort)."""
    lp = ledger_path()
    if not lp or not sid:
        return
    ledger = load_ledger()
    ledger[os.path.abspath(path)] = {"session": sid, "ts": int(time.time())}
    try:
        os.makedirs(os.path.dirname(lp), exist_ok=True)
        tmp = "%s.%d.tmp" % (lp, os.getpid())  # per-process temp: no shared-temp race
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(ledger, f)
        os.replace(tmp, lp)
    except OSError:
        pass


def owns(path, sid, ledger):
    """True if `sid` owns `path` per the (pre-loaded) ledger."""
    if not sid:
        return False
    entry = ledger.get(os.path.abspath(path))
    return isinstance(entry, dict) and entry.get("session") == sid


def _is_artifact(path):
    """True if `path` lies under one of the IDD artifact directories. Directory
    membership is sufficient — recording is intentionally permissive; a file that
    does not match a rule's glob simply never becomes a candidate (resolve_candidate
    re-filters by glob), so a spurious ledger entry is harmless and gets pruned."""
    return any(_under(path, os.path.join(DOCS_ROOT, d)) for d in ARTIFACT_DIRS)


def record_ownership(data, tool, sid):
    """Stamp ownership for the artifact this call touches (Write/Edit/MultiEdit
    of an artifact) or claims (executing-plans / subagent-driven-development →
    the newest plan, so an implementing session is gated by it)."""
    if tool in ("Write", "Edit", "MultiEdit"):
        path = (data.get("tool_input") or {}).get("file_path")
        if path and _is_artifact(path):
            record_owner(path, sid)
    elif tool == "Skill":
        skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
        if skill in CLAIM_SKILLS:
            plan = newest_plan()
            if plan:
                record_owner(plan, sid)


def normalize_skill(name):
    """Суффикс после последнего ':' ('superpowers:writing-plans' → 'writing-plans')."""
    return name.rsplit(":", 1)[-1].strip()


def resolve_candidate(rule, sid):
    """Newest glob-matching artifact OWNED BY `sid`. None if none owned —
    escape: a session is gated only by artifacts it owns. None with no matches
    at all is the existing hotfix escape (no IDD docs)."""
    pattern = os.path.join(DOCS_ROOT, rule["dir"], rule["glob"])
    matches = glob.glob(pattern)
    if not matches:
        return None
    ledger = load_ledger()
    owned = [m for m in matches if owns(m, sid, ledger)]
    if not owned:
        return None
    return max(owned, key=os.path.getmtime)


def newest_plan():
    """Newest plan across the repo, ignoring ownership — used at claim time."""
    pattern = os.path.join(DOCS_ROOT, PLAN_RULE["dir"], PLAN_RULE["glob"])
    matches = glob.glob(pattern)
    return max(matches, key=os.path.getmtime) if matches else None


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


def fresh(path, seconds):
    """True, если файл изменён не позже `seconds` секунд назад."""
    return time.time() - os.path.getmtime(path) <= seconds


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


def handle_write(data, tool, sid):
    """Gate по записи downstream-артефакта (inline-переходы spec→plan, plan→impl)."""
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        sys.exit(0)  # нет пути → fail-open

    # spec→plan: создание файла плана (только Write, не Edit).
    if tool == "Write" and _under(path, PLANS_DIR) and path.endswith(".md"):
        content = (data.get("tool_input") or {}).get("content")
        spec = resolve_spec_from_chain(content) or resolve_candidate(SPEC_RULE, sid)
        if spec is None:
            sys.exit(0)  # нет спеки → escape
        reason = evaluate_gate(spec, SPEC_RULE)
        if reason is None:
            sys.exit(0)
        block(spec, reason, SPEC_RULE["fix"])

    # plan→impl: правка файла вне docs/superpowers/ (любой инструмент).
    if not _under(path, DOCS_ROOT):
        plan = resolve_candidate(PLAN_RULE, sid)
        if plan is None:
            sys.exit(0)  # нет плана → escape
        if not fresh(plan, IMPL_GATE_FRESH_SECONDS):
            sys.exit(0)  # устаревший черновик → не гейтим активную работу
        reason = evaluate_gate(plan, PLAN_RULE)
        if reason is None:
            sys.exit(0)
        block(plan, reason, PLAN_RULE["fix"])

    sys.exit(0)  # specs/intents, правка существующего плана и т.п.


def handle_skill(data, sid):
    """Gate по вызову Skill (существующий путь IDD→SDD)."""
    skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)  # скилл не гейтируется
    candidate = resolve_candidate(rule, sid)
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
    sid = data.get("session_id")
    try:
        record_ownership(data, tool, sid)
        if tool == "Skill":
            handle_skill(data, sid)
        elif tool in ("Write", "Edit", "MultiEdit"):
            handle_write(data, tool, sid)
        else:
            sys.exit(0)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
