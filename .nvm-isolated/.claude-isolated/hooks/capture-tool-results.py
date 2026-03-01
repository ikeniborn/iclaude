#!/usr/bin/env python3
"""
PostToolUse hook — фиксация результатов инструментов и агентов в сессии.

Перехватывает все вызовы инструментов после выполнения и записывает их
результаты в JSONL-лог рядом с транскриптом сессии, обогащая контекст
данными, недоступными в TOON-формате (.claude/sessions/).

Хранение:
  Основной:  {transcript_dir}/{session_id}-tool-results.jsonl
  Fallback:  {CLAUDE_CONFIG_DIR}/session-env/{session_id}/tool-results.jsonl

Exit codes:
  0 — всегда (hook не блокирует выполнение инструментов)

Просмотр:
  $CLAUDE_CONFIG_DIR/scripts/view-tool-results.sh [SESSION_ID]
"""
from __future__ import annotations

import json
import sys
import os
from pathlib import Path
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Инструменты для фиксации результатов
# ---------------------------------------------------------------------------
CAPTURE_TOOLS = {
    'Read',           # Содержимое файлов
    'Write',          # Подтверждение записи
    'Edit',           # Подтверждение редактирования
    'MultiEdit',      # Подтверждение мульти-редактирования
    'Bash',           # Вывод команд
    'Glob',           # Найденные файлы
    'Grep',           # Результаты поиска
    'Task',           # Результаты субагентов (ключевое!)
    'WebFetch',       # Содержимое веб-страниц
    'WebSearch',      # Результаты поиска
    'TodoRead',       # Список задач
    'TodoWrite',      # Подтверждение обновления задач
    'NotebookEdit',   # Ячейки ноутбука
    'LSP',            # LSP-результаты (определения, ссылки)
}

# Максимальный размер content на результат (символы)
MAX_CONTENT_CHARS = 8_000

# Максимальный размер поля input (для компактного хранения)
MAX_INPUT_FIELD_CHARS = 500


def truncate(text: str, limit: int = MAX_CONTENT_CHARS) -> str:
    """Обрезает длинный текст с пометкой."""
    if len(text) > limit:
        return text[:limit] + f'\n…[TRUNCATED: {len(text)} chars total]'
    return text


def extract_content(response) -> tuple[str, bool]:
    """
    Извлекает текстовое содержимое и флаг ошибки из ответа инструмента.

    Обрабатывает все форматы ответов Claude Code:
      - строка: прямой текст (Bash, Glob, Grep)
      - dict с content: str (Read, Write, Edit)
      - dict с content: list (составные ответы с type/text блоками)
      - list: сериализуется в JSON (Glob массив)
      - None: пустой результат
    """
    if response is None:
        return '', False

    if isinstance(response, str):
        return truncate(response), False

    if isinstance(response, dict):
        is_err = bool(response.get('is_error', False))
        content = response.get('content', response)

        if isinstance(content, str):
            return truncate(content), is_err

        if isinstance(content, list):
            parts: list[str] = []
            for item in content:
                if isinstance(item, dict):
                    if item.get('type') == 'text':
                        parts.append(item.get('text', ''))
                    elif item.get('type') == 'error':
                        parts.append(f'[ERROR] {item.get("text", "")}')
                    else:
                        parts.append(json.dumps(item, ensure_ascii=False))
                elif isinstance(item, str):
                    parts.append(item)
            return truncate('\n'.join(parts)), is_err

        # Произвольный dict — сериализуем
        return truncate(json.dumps(content, ensure_ascii=False)), is_err

    if isinstance(response, list):
        return truncate(json.dumps(response, ensure_ascii=False)), False

    return str(response), False


def compact_input(tool_input: dict) -> dict:
    """
    Компактизирует tool_input для хранения.
    Обрезает длинные строковые поля (например, content Write, new_string Edit).
    """
    if not tool_input:
        return {}
    result: dict = {}
    for key, value in tool_input.items():
        if isinstance(value, str) and len(value) > MAX_INPUT_FIELD_CHARS:
            result[key] = value[:MAX_INPUT_FIELD_CHARS] + '…'
        else:
            result[key] = value
    return result


def get_log_path(session_id: str, transcript_path: str, config_dir: str) -> Path:
    """
    Определяет путь к JSONL-файлу лога результатов.

    Предпочтительно: рядом с JSONL-транскриптом сессии
      {transcript_dir}/{session_id}-tool-results.jsonl

    Fallback: в session-env директории
      {config_dir}/session-env/{session_id}/tool-results.jsonl
    """
    if transcript_path:
        transcript = Path(transcript_path)
        parent = transcript.parent
        if parent.is_dir():
            return parent / f'{session_id}-tool-results.jsonl'

    # Fallback
    session_dir = Path(config_dir) / 'session-env' / (session_id or 'unknown')
    session_dir.mkdir(parents=True, exist_ok=True)
    return session_dir / 'tool-results.jsonl'


def main() -> None:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError, OSError):
        sys.exit(0)  # fail-open: не блокируем при ошибке парсинга

    tool_name = data.get('tool_name', '')

    # Пропускаем инструменты вне списка захвата
    if tool_name not in CAPTURE_TOOLS:
        sys.exit(0)

    tool_input = data.get('tool_input') or {}
    tool_response = data.get('tool_response')
    session_id = data.get('session_id') or ''
    transcript_path = data.get('transcript_path') or ''

    # Fallback для session_id если не передан
    if not session_id:
        session_id = 'session-' + datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')

    config_dir = os.environ.get(
        'CLAUDE_CONFIG_DIR',
        str(Path.home() / '.claude')
    )

    try:
        log_path = get_log_path(session_id, transcript_path, config_dir)

        content, is_error = extract_content(tool_response)

        record = {
            'ts': datetime.now(timezone.utc).isoformat(),
            'tool': tool_name,
            'input': compact_input(tool_input),
            'content': content,
            'error': is_error,
        }

        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(record, ensure_ascii=False) + '\n')

    except OSError:
        pass  # Тихо игнорируем ошибки I/O — не блокируем работу

    sys.exit(0)


if __name__ == '__main__':
    main()
