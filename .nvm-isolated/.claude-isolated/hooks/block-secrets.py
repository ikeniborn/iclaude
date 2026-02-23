#!/usr/bin/env python3
"""
PreToolUse hook — вторая линия обороны защиты секретов.

Перехватывает вызовы Read/Edit/Write/Bash и блокирует доступ
к чувствительным файлам через exit(2), что вызывает ошибку инструмента
без прерывания сессии Claude Code.

Exit codes:
  0 — разрешить (инструмент выполняется)
  2 — заблокировать (инструмент не выполняется, Claude получает ошибку)
"""

import sys
import json

# Директории, исключённые из проверки (хуки не блокируют сами себя)
EXCLUDE_DIRS = [
    '.claude-isolated/hooks',
    '.claude/hooks',
]

# Паттерны чувствительных файлов и путей
SENSITIVE_PATH_PATTERNS = [
    '.env',
    '.pem',
    '.key',
    '.pfx',
    '.p12',
    'credentials',
    'secret',
    '.ssh',
    '.aws',
    '.gnupg',
    '.kube',
    'token',
    'id_rsa',
    'id_ed25519',
    'id_ecdsa',
    'private_key',
    '.netrc',
    '.pgpass',
]

# Инструменты, которые проверяются на чувствительные пути
PATH_CHECK_TOOLS = {'Read', 'Edit', 'Write', 'MultiEdit'}


def is_excluded(path: str) -> bool:
    """Возвращает True, если путь находится в директории исключений."""
    path_norm = path.replace('\\', '/')
    for excl in EXCLUDE_DIRS:
        if excl in path_norm:
            return True
    return False


def is_sensitive_path(path: str) -> 'tuple[bool, str]':
    """Проверяет путь на совпадение с паттернами чувствительных файлов."""
    path_lower = path.lower()
    for pattern in SENSITIVE_PATH_PATTERNS:
        if pattern in path_lower:
            return True, pattern
    return False, ''


def main() -> None:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        # Если не можем прочитать вход — пропускаем (fail open)
        sys.exit(0)

    tool = data.get('tool_name', '')
    params = data.get('tool_input', {})

    # --- Проверка файловых инструментов (Read, Edit, Write, MultiEdit) ---
    if tool in PATH_CHECK_TOOLS:
        file_path = params.get('file_path', '') or ''
        if file_path and not is_excluded(file_path):
            blocked, pattern = is_sensitive_path(file_path)
            if blocked:
                print(
                    f"[block-secrets] BLOCKED {tool}: "
                    f"sensitive path '{pattern}' in: {file_path}",
                    file=sys.stderr
                )
                sys.exit(2)

    # --- Проверка Bash-команд ---
    # Проверяем только токены, похожие на файловые пути (начинаются с /, ~/, ./, ../)
    # чтобы избежать ложных срабатываний на имена команд, флаги и строки в коде
    if tool == 'Bash':
        command = params.get('command', '') or ''
        if command:
            import shlex
            try:
                tokens = shlex.split(command)
            except ValueError:
                tokens = command.split()

            for token in tokens:
                if token.startswith(('/', '~/', './', '../', '$HOME')):
                    if not is_excluded(token):
                        blocked, pattern = is_sensitive_path(token)
                        if blocked:
                            print(
                                f"[block-secrets] BLOCKED Bash: "
                                f"sensitive path '{pattern}' in arg: {token}",
                                file=sys.stderr
                            )
                            sys.exit(2)

    sys.exit(0)


if __name__ == '__main__':
    main()
