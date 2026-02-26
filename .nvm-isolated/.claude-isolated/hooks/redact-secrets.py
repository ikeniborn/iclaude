#!/usr/bin/env python3
"""
PreToolUse hook — маскирование секретов в содержимом инструментов.

Дополняет block-secrets.py:
  block-secrets.py  → блокирует доступ к файлам по чувствительным ПУТЯМ
  redact-secrets.py → маскирует секреты в СОДЕРЖИМОМ аргументов инструментов

Перехватывает Write/Edit/MultiEdit/Bash и заменяет найденные секреты
плейсхолдерами, используя toolInputOverride (Claude Code v2.0.10+).

Exit codes:
  0 — разрешить (с изменёнными или оригинальными аргументами)
  2 — не используется (fail-open: при ошибке пропускаем)

Поведение:
  - Обнаружен секрет → печатаем JSON в stdout с toolInputOverride
  - Ничего не обнаружено → выходим молча
  - Ошибка парсинга → выходим молча (fail-open, не блокируем работу)
"""
from __future__ import annotations  # Python 3.8+ совместимость для list[...], tuple[...]

import json
import re
import sys

# ---------------------------------------------------------------------------
# Паттерны обнаружения и замены
# Каждый элемент: (compiled_regex, placeholder_string, description)
#
# Порядок важен: более специфичные паттерны идут раньше общих.
# ---------------------------------------------------------------------------
REDACT_PATTERNS: list[tuple[re.Pattern, str, str]] = [
    # Anthropic / OpenAI / Stripe / совместимые SDK ключи (sk-..., sk-ant-..., sk-proj-...)
    (
        re.compile(r'\bsk-(?:ant-api03-|ant-|proj-|or-v1-)?[A-Za-z0-9\-_]{20,}'),
        '[API_KEY_REDACTED]',
        'Anthropic/OpenAI/Stripe API key',
    ),
    # AWS Access Key ID
    (
        re.compile(r'\bAKIA[0-9A-Z]{16}\b'),
        '[AWS_ACCESS_KEY_ID]',
        'AWS Access Key ID',
    ),
    # AWS Secret Access Key: сохраняем имя переменной, заменяем только значение
    (
        re.compile(
            r'(?i)((?:aws[_\-]?secret[_\-]?(?:access[_\-]?)?key|AWS_SECRET_ACCESS_KEY)'
            r'\s*[=:]\s*)["\']?[A-Za-z0-9/+]{40}["\']?'
        ),
        r'\1[AWS_SECRET_KEY_REDACTED]',
        'AWS Secret Access Key',
    ),
    # Приватные ключи PEM (однострочные и многострочные)
    # Покрывает: RSA, EC, DSA, OPENSSH, ENCRYPTED (PKCS#8), PGP
    # re.DOTALL не нужен: [\s\S] уже покрывает переносы строк
    (
        re.compile(
            r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'
            r'[\s\S]*?'
            r'-----END (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'
        ),
        '[PRIVATE_KEY_REDACTED]',
        'PEM private key block',
    ),
    # GitHub токены классические (ghp_, gho_, ghu_, ghs_, ghr_)
    (
        re.compile(r'\bgh[pousr]_[A-Za-z0-9_]{36,}\b'),
        '[GITHUB_TOKEN]',
        'GitHub token',
    ),
    # GitHub fine-grained PAT (github_pat_...) — введён в 2022
    (
        re.compile(r'\bgithub_pat_[A-Za-z0-9_]{82,}\b'),
        '[GITHUB_TOKEN]',
        'GitHub fine-grained PAT',
    ),
    # Credentials в URL (scheme://user:pass@host) — любая схема с авторизацией
    # Покрывает: https, ftp, postgresql, mysql, mongodb, redis, amqp, smtp, ldap и др.
    (
        re.compile(r'([a-zA-Z][a-zA-Z0-9+\-.]*://)[^:@\s/]+:[^@\s/]+@'),
        r'\1[CREDENTIALS]@',
        'credentials in URL',
    ),
    # Пароли в конфигах: password = "...", password: value (с кавычками и без)
    # Минимум 8 символов чтобы избежать false positives на тестовых значениях
    # Не маскируем ${VAR} плейсхолдеры — они подставляются из окружения
    (
        re.compile(
            r'(?i)((?:password|passwd|pwd|db_pass|pgpassword)\s*[=:]\s*)'
            r'(?!\$\{)'      # не маскировать ${VAR} плейсхолдеры
            r'(?:["\']([^"\']{8,})["\']|([^\s#\n"\'$]{8,}))'
        ),
        r'\1"[PASSWORD_REDACTED]"',
        'password in config',
    ),
    # Generic secret/token/api_key в assignments (осторожный паттерн)
    # charset включает = для поддержки base64-значений с padding (YWJj...==)
    (
        re.compile(
            r'(?i)((?:secret|api[_\-]?key|access[_\-]?token|auth[_\-]?token)'
            r'\s*[=:]\s*)["\']([A-Za-z0-9\-_./+=]{16,})["\']'
        ),
        r'\1"[SECRET_REDACTED]"',
        'generic secret/token in config',
    ),
    # JWT токены (три base64url части через точку)
    # 3-й сегмент (подпись) опциональный: unsigned JWT (alg=none) имеет пустой 3-й сегмент
    # \b в начале достаточно для якоря; \b в конце не работает после пустого сегмента
    (
        re.compile(
            r'\beyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*'
        ),
        '[JWT_REDACTED]',
        'JWT token',
    ),
    # Номера банковских карт (базовый паттерн по IIN-диапазонам Visa/MC/Amex)
    # Примечание: без проверки алгоритма Luhn — возможны false positives на числовых ID
    (
        re.compile(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b'),
        '[CARD_NUMBER_REDACTED]',
        'credit card number',
    ),
    # .env-формат: [export] VARNAME=значение (значение ≥20 символов)
    # Ловит: VAR=value и export VAR=value
    # Список суффиксов: SECRET, TOKEN, KEY, PASSWORD, PASSWD, PWD, PASS, APIKEY
    # Не ловит: VAR="${VAR}" (placeholder с ${...}) — исключён через lookahead
    # Не ловит: VAR=[ALREADY_MASKED] — исключён через lookahead
    (
        re.compile(
            r'(?m)^((?:export\s+)?[A-Z][A-Z0-9_]*'
            r'(?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|PWD|PASS|APIKEY)'
            r'[A-Z0-9_]*\s*=\s*)'
            r'(?!["\']?\$\{)'      # не маскировать ${VAR} плейсхолдеры
            r'(?!["\']?\[)'        # не перемаскировать уже замаскированные [...] и "[..." значения
            r'([^\s#\n]{20,})'
        ),
        r'\1[REDACTED]',
        '.env secret variable',
    ),
]

# Инструменты, в которых проверяем содержимое (не пути)
CONTENT_TOOLS = {'Write', 'Edit', 'MultiEdit', 'Bash'}

# Поля инструментов с текстовым содержимым для сканирования
# ВАЖНО: Edit.old_string — поисковый паттерн, маскировать нельзя (Edit провалится)
CONTENT_FIELDS = {
    'Write':     ['content'],
    'Edit':      ['new_string'],
    'Bash':      ['command'],
    # MultiEdit обрабатывается отдельно (вложенный массив edits)
}

# Директории хуков — не сканируем сами себя
EXCLUDE_DIRS = [
    '.claude-isolated/hooks',
    '.claude/hooks',
]


def is_excluded(path: str) -> bool:
    path_norm = path.replace('\\', '/')
    return any(excl in path_norm for excl in EXCLUDE_DIRS)


def redact_text(text: str) -> tuple[str, list[str]]:
    """
    Применяет все паттерны маскирования к тексту.
    Возвращает (новый_текст, список_описаний_найденных_секретов).
    """
    found: list[str] = []
    for pattern, replacement, description in REDACT_PATTERNS:
        new_text = pattern.sub(replacement, text)
        if new_text != text:
            found.append(description)
            text = new_text
    return text, found


def redact_fields(tool_input: dict, fields: list[str]) -> tuple[dict, list[str]]:
    """Маскирует секреты в указанных текстовых полях словаря."""
    result = dict(tool_input)
    all_found: list[str] = []
    for field in fields:
        value = tool_input.get(field)
        if isinstance(value, str):
            new_value, found = redact_text(value)
            if found:
                result[field] = new_value
                all_found.extend(found)
    return result, all_found


def redact_multiedit(tool_input: dict) -> tuple[dict, list[str]]:
    """Маскирует секреты в массиве edits инструмента MultiEdit.
    Маскируется только new_string — old_string является поисковым паттерном.
    """
    edits = tool_input.get('edits', [])
    if not isinstance(edits, list):
        return tool_input, []

    new_edits = []
    all_found: list[str] = []
    for edit in edits:
        if not isinstance(edit, dict):
            new_edits.append(edit)
            continue
        new_edit, found = redact_fields(edit, ['new_string'])
        new_edits.append(new_edit)
        all_found.extend(found)

    if all_found:
        result = dict(tool_input)
        result['edits'] = new_edits
        return result, all_found
    return tool_input, []


def main() -> None:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # fail-open

    tool = data.get('tool_name', '')
    # data.get('tool_input') or {} корректно обрабатывает и отсутствие ключа, и null
    tool_input = data.get('tool_input') or {}

    if tool not in CONTENT_TOOLS:
        sys.exit(0)

    # Не сканируем файлы самих хуков
    file_path = tool_input.get('file_path', '') or ''
    if file_path and is_excluded(file_path):
        sys.exit(0)

    # Маскирование по типу инструмента
    if tool == 'MultiEdit':
        new_input, found = redact_multiedit(tool_input)
    else:
        fields = CONTENT_FIELDS.get(tool, [])
        new_input, found = redact_fields(tool_input, fields)

    if not found:
        sys.exit(0)

    # Логируем что нашли (в stderr — видно пользователю, не Claude)
    unique_found = list(dict.fromkeys(found))  # порядок сохранён, дубли убраны
    print(
        f'[redact-secrets] {tool}: masked {len(found)} secret(s): '
        + ', '.join(unique_found),
        file=sys.stderr,
    )

    # Возвращаем модифицированные аргументы через toolInputOverride (CC v2.0.10+)
    print(json.dumps({
        'hookSpecificOutput': {
            'toolInputOverride': new_input,
        }
    }))

    sys.exit(0)


if __name__ == '__main__':
    main()
