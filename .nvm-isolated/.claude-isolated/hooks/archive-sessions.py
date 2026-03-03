#!/usr/bin/env python3
"""
Stop hook — очистка корня sessions/ после завершения сессии.

Срабатывает при завершении Claude Code сессии (после каждого хода).

Удаляет из sessions/ корня для данного session_id:
  - readable-{UUID}.toon       — 0-байтовый маркер финализации Claude Code
  - readable-{UUID}.txt        — текстовый транскрипт (избыточен, есть .toon)
  - readable-{UUID}.txt.meta   — метаданные транскрипта

.toon.tmp.{PID} не трогаем — их чистит archive_stale_sessions() в launch.sh.

Реальное содержимое сессии (.toon с данными) пишется статуслайном
напрямую в sessions/{YYYY-MM-DD}/ — ни перемещения, ни дублирования.

Входные данные stdin (JSON):
  {"session_id": "...", "transcript_path": "..."}

Exit codes:
  0 — всегда (fail-open, не блокирует завершение)
"""

import sys
import json
import os
import re
from pathlib import Path
from typing import Optional


def find_sessions_dir(transcript_path: str) -> Optional[Path]:
    """Определяет путь к sessions/ директории проекта."""
    # 1. Из CLAUDE_PROJECT_DIR (экспортируется launch.sh)
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if project_dir:
        candidate = Path(project_dir) / ".claude" / "sessions"
        if candidate.is_dir():
            return candidate

    # 2. Из transcript_path — ищём .claude/sessions/ вверх по дереву
    # transcript_path: .../project/.nvm-isolated/.claude-isolated/projects/{encoded}/{UUID}.jsonl
    # (не содержит .claude/sessions/, поэтому этот путь на практике не срабатывает —
    # fallback обеспечивает путь 3 ниже)
    if transcript_path:
        tp = Path(transcript_path)
        parts = tp.parts
        for i, part in enumerate(parts):
            if part == "sessions" and i > 0 and parts[i - 1] == ".claude":
                candidate = Path(*parts[: i + 1])
                if candidate.is_dir():
                    return candidate

    # 3. Поиск вверх по дереву от cwd
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        candidate = parent / ".claude" / "sessions"
        if candidate.is_dir():
            return candidate

    return None


def cleanup_session_root(sessions_dir: Path, session_id: str) -> None:
    """Удаляет мусорные файлы сессии из корня sessions/."""
    if not sessions_dir.is_dir():
        return

    for pattern in (
        f"readable-{session_id}.toon",      # 0-байтовый маркер Claude Code
        f"readable-{session_id}.txt",        # текстовый транскрипт (избыточен)
        f"readable-{session_id}.txt.meta",   # метаданные транскрипта
    ):
        f = sessions_dir / pattern
        if f.exists() and f.parent == sessions_dir:
            try:
                f.unlink()
            except OSError:
                pass


def main() -> int:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        data = {}

    session_id = data.get("session_id", "")
    transcript_path = data.get("transcript_path", "")

    # Validate session_id from stdin to UUID format before use in file operations
    # (prevents path traversal via crafted session_id in hook JSON).
    _UUID_RE = re.compile(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
    )
    if session_id and not _UUID_RE.fullmatch(session_id):
        session_id = ""  # force fallback to transcript_path extraction

    # Попытка извлечь session_id из transcript_path если не передан явно.
    # transcript_path вида .../projects/{encoded}/{UUID}.jsonl
    if not session_id and transcript_path:
        m = re.search(
            r"([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\.jsonl$",
            transcript_path,
        )
        if m:
            session_id = m.group(1)

    if not session_id:
        return 0

    sessions_dir = find_sessions_dir(transcript_path)
    if sessions_dir is None:
        return 0

    cleanup_session_root(sessions_dir, session_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
