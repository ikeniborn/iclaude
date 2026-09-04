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
import os
import time


SECURITY_FLAG_FILE = '/tmp/iclaude-security-event.json'
FLAG_TTL = 30  # секунд


def write_security_flag(event_type: str, detail: str) -> None:
    """Записывает флаг события безопасности для статус-лайна."""
    try:
        payload = {
            'type': event_type,
            'detail': detail,
            'ts': time.time(),
            'ttl': FLAG_TTL,
        }
        with open(SECURITY_FLAG_FILE, 'w') as f:
            json.dump(payload, f)
    except OSError:
        pass

# Директории, исключённые из проверки (хуки не блокируют сами себя)
EXCLUDE_DIRS = [
    '.claude-isolated/hooks',
    '.claude/hooks',
]

# Суффиксы-шаблоны: .env.example, .env.sample, .env.template, .env.dist
# считаются безопасными (не содержат реальных секретов)
SAFE_SUFFIXES = (
    '.example',
    '.sample',
    '.template',
    '.dist',
    '.defaults',
    '.placeholder',
)

# Паттерны чувствительных файлов и путей
# Проверяются как подстрока в ПОЛНОМ пути (включая директории)
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
    'id_rsa',
    'id_ed25519',
    'id_ecdsa',
    'private_key',
    '.netrc',
    '.pgpass',
]

# Паттерны для проверки только по ИМЕНИ ФАЙЛА (не полному пути).
# Исключает ложные срабатывания на исходники вроде lib/oauth/token.sh,
# token_manager.py и т.д., но блокирует файлы-хранилища токенов.
TOKEN_FILENAME_PATTERNS = (
    '.token',        # скрытый файл ~/.token
    'token.json',    # JSON-хранилища: token.json, access_token.json, refresh_token.json
    'token.txt',     # текстовые токены
    'token.yaml',
    'token.yml',
    'token.xml',
    'access_token',  # access_token.json, access_token.txt и т.д.
    'refresh_token', # refresh_token.json и т.д.
    'oauth_token',
    'auth_token',
    'api_token',
    'id_token',
)

# Инструменты, которые проверяются на чувствительные пути
PATH_CHECK_TOOLS = {'Read', 'Edit', 'Write', 'MultiEdit'}


def is_excluded(path: str) -> bool:
    """Возвращает True, если путь находится в директории исключений."""
    path_norm = path.replace('\\', '/')
    for excl in EXCLUDE_DIRS:
        if excl in path_norm:
            return True
    return False


def is_safe_template(path: str) -> bool:
    """Возвращает True если файл — известный безопасный шаблон (.env.example и т.п.)."""
    path_lower = path.lower()
    # Получаем имя файла (последняя часть пути)
    filename = path_lower.rsplit('/', 1)[-1]
    return filename.endswith(SAFE_SUFFIXES)


def is_sensitive_path(path: str) -> 'tuple[bool, str]':
    """Проверяет путь на совпадение с паттернами чувствительных файлов."""
    # Шаблонные файлы (.env.example и т.п.) не блокируем
    if is_safe_template(path):
        return False, ''
    path_lower = path.lower()
    # Проверка по полному пути (директории + имя файла)
    for pattern in SENSITIVE_PATH_PATTERNS:
        if pattern in path_lower:
            return True, pattern
    # Проверка token-паттернов только по имени файла,
    # чтобы не блокировать исходники вроде lib/oauth/token.sh
    filename = path_lower.rsplit('/', 1)[-1]
    for pattern in TOKEN_FILENAME_PATTERNS:
        if pattern in filename:
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
                reason = f"🔒 Доступ заблокирован: чувствительный файл '{pattern}' — {file_path}"
                print(reason, file=sys.stderr)
                write_security_flag('block', f"'{pattern}' in {os.path.basename(file_path)}")
                print(json.dumps({'reason': reason}))
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
                            reason = f"🔒 Доступ заблокирован: чувствительный путь '{pattern}' в аргументе: {token}"
                            print(reason, file=sys.stderr)
                            write_security_flag('block', f"'{pattern}' in bash arg")
                            print(json.dumps({'reason': reason}))
                            sys.exit(2)

    sys.exit(0)


if __name__ == '__main__':
    main()
