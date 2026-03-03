#!/usr/bin/env python3
"""
PostToolUse hook — логирует вызовы мутирующих инструментов.

Перехватывает Write/Edit/MultiEdit/Bash и записывает результаты в:
  {CLAUDE_PROJECT_DIR}/.claude/tools/{YYYY-MM-DD}/{session_id}.toon

Формат файла: TOON (таблица вызовов + JSON метаданные).
Запись атомарная: tmp → rename (безопасно при параллельных агентах).

Что НЕ логируется:
  - Read, Glob, Grep и другие немутирующие инструменты
  - Содержимое файлов (content/new_string) — только пути и команды

Переменные окружения:
  CLAUDE_PROJECT_DIR  — корень проекта (устанавливается iclaude.sh)
  CLAUDE_SESSION_ID   — ID сессии (если доступен)
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Allowed characters for session_id used as a filename component.
# Rejects path separators, dots, null bytes and other traversal sequences.
_SAFE_SESSION_ID_RE = re.compile(r'^[a-zA-Z0-9_\-]{1,64}$')

MUTABLE_TOOLS = {"Write", "Edit", "MultiEdit", "Bash"}


def get_project_dir() -> Optional[Path]:
    """Найти корневую директорию проекта."""
    # Приоритет 1: переменная окружения (установлена iclaude.sh)
    d = os.environ.get("CLAUDE_PROJECT_DIR")
    if d:
        p = Path(d)
        if p.exists():
            return p

    # Приоритет 2: ищем .claude/ вверх по дереву от cwd
    cwd = Path.cwd()
    for candidate in [cwd, *cwd.parents]:
        if (candidate / ".claude").is_dir():
            return candidate

    return None


def get_session_id(hook_input: dict) -> str:
    """Получить session_id из hook input или окружения."""
    # Из stdin (Claude Code передаёт session_id в PostToolUse)
    # Validate before use as filename component to prevent path traversal.
    sid = hook_input.get("session_id") or hook_input.get("sessionId")
    if sid and _SAFE_SESSION_ID_RE.fullmatch(str(sid)):
        return str(sid)

    # Из переменной окружения
    sid = os.environ.get("CLAUDE_SESSION_ID")
    if sid:
        return sid

    # Ищем в .claude/sessions/ проекта (берём последний файл)
    project_dir = get_project_dir()
    if project_dir:
        sessions_dir = project_dir / ".claude" / "sessions"
        if sessions_dir.is_dir():
            files = sorted(sessions_dir.glob("readable-*.toon.tmp.*"))
            if files:
                m = re.search(r"readable-([a-f0-9-]{36})\.toon\.tmp\.", files[-1].name)
                if m:
                    return m.group(1)

    # Fallback: PID текущего процесса
    return f"pid-{os.getpid()}"


def get_target(tool_name: str, tool_input: dict) -> str:
    """Получить краткое описание цели инструмента."""
    if tool_name in ("Write", "Edit", "MultiEdit"):
        return tool_input.get("file_path") or ""
    elif tool_name == "Bash":
        cmd = tool_input.get("command", "")
        # Первые 80 символов команды, без переносов строк
        return cmd.replace("\n", " ").replace("\r", "")[:80] if cmd else ""
    return ""


def get_status(tool_result: Optional[Dict]) -> str:
    """Получить статус выполнения инструмента."""
    if not tool_result:
        return "success"
    if isinstance(tool_result, dict):
        if tool_result.get("error") or tool_result.get("is_error"):
            return "error"
    return "success"


def get_compact_input(tool_name: str, tool_input: dict) -> dict:
    """Компактное представление tool_input (без больших полей контента).

    Не сохраняем:
      - Write.content       — содержимое файла (может быть мегабайты)
      - Edit.new_string     — новое содержимое (может быть большим)
    Сохраняем полностью:
      - Bash.command        — полная команда (важна для анализа)
      - Edit.old_string     — поисковый паттерн (обычно короткий)
    """
    if tool_name == "Write":
        return {"file_path": tool_input.get("file_path")}
    elif tool_name == "Edit":
        return {
            "file_path": tool_input.get("file_path"),
            "old_string": tool_input.get("old_string"),
        }
    elif tool_name == "MultiEdit":
        # Сохраняем edits без new_string (могут быть большими)
        edits = tool_input.get("edits", [])
        compact_edits = [
            {"old_string": e.get("old_string")}
            for e in edits
        ]
        return {
            "file_path": tool_input.get("file_path"),
            "edits": compact_edits,
        }
    elif tool_name == "Bash":
        return {"command": tool_input.get("command", "") or ""}
    return {}


def parse_toon_file(filepath: Path) -> Tuple[Dict, List]:
    """Прочитать существующий .toon файл, вернуть (meta, details)."""
    if not filepath.exists():
        return {}, []
    try:
        content = filepath.read_text(encoding="utf-8")
        if "---JSON---" in content:
            json_part = content.split("---JSON---", 1)[1].strip()
            data = json.loads(json_part)
            return data, data.get("details", [])
    except Exception:
        pass
    return {}, []


def build_toon_content(meta: dict, details: list) -> str:
    """Построить TOON файл из метаданных и списка вызовов."""
    lines = ["TOON:calls:v1", "ts|tool|status|target"]

    for d in details:
        ts = d.get("ts", "")
        tool = d.get("tool", "")
        status = d.get("status", "success")
        target = str(d.get("target", "")).replace("|", "/").replace("\n", " ")
        lines.append(f"{ts}|{tool}|{status}|{target}")

    lines.append("")
    lines.append("---JSON---")

    # Сохраняем полные данные в JSON секции
    meta_copy = dict(meta)
    meta_copy["details"] = details
    meta_copy["calls"] = "<<TOON:calls>>"
    lines.append(json.dumps(meta_copy, ensure_ascii=False, indent=2))
    lines.append("")

    return "\n".join(lines)


def atomic_write(filepath: Path, content: str) -> None:
    """Атомарная запись файла через временный файл + rename."""
    # Уникальное имя tmp по PID — безопасно при параллельных агентах
    tmp_path = filepath.with_name(f"{filepath.stem}.{os.getpid()}.tmp")
    try:
        tmp_path.write_text(content, encoding="utf-8")
        tmp_path.replace(filepath)
    except Exception:
        # Если rename не удался — удалить tmp
        try:
            tmp_path.unlink(missing_ok=True)
        except Exception:
            pass
        raise


def main() -> None:
    try:
        hook_input = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = hook_input.get("tool_name", "")

    # Логируем только мутирующие инструменты
    if tool_name not in MUTABLE_TOOLS:
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {}) or {}
    tool_result = hook_input.get("tool_result")

    project_dir = get_project_dir()
    if not project_dir:
        sys.exit(0)

    now = datetime.now(timezone.utc)
    date_str = now.strftime("%Y-%m-%d")
    ts_str = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    session_id = get_session_id(hook_input)
    target = get_target(tool_name, tool_input)
    status = get_status(tool_result)
    compact_input = get_compact_input(tool_name, tool_input)

    # Создать директорию .claude/tools/{YYYY-MM-DD}/
    tools_dir = project_dir / ".claude" / "tools" / date_str
    try:
        tools_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        sys.exit(0)

    toon_file = tools_dir / f"{session_id}.toon"

    # Defense-in-depth: verify no path traversal despite validation above.
    if toon_file.parent.resolve() != tools_dir.resolve():
        sys.exit(0)  # fail-open: skip logging rather than crashing

    # Прочитать существующий файл (если есть)
    existing_meta, details = parse_toon_file(toon_file)

    if not existing_meta:
        existing_meta = {
            "session_id": session_id,
            "project": str(project_dir),
            "started_at": ts_str,
        }

    # Добавить новую запись
    call = {
        "ts": ts_str,
        "tool": tool_name,
        "status": status,
        "target": target,
        "input": compact_input,
    }
    details.append(call)

    # Атомарно перезаписать файл
    try:
        content = build_toon_content(existing_meta, details)
        atomic_write(toon_file, content)
    except Exception:
        pass  # fail-open: не прерывать работу Claude при ошибке логирования

    sys.exit(0)


if __name__ == "__main__":
    main()
