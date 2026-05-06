# Reader: Bash

Правила извлечения сущностей из `.sh` файлов.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `functions` | `function имя()`, `имя()` в начале строки с `{` на той же или следующей строке |
| `flags` | `--flag` в `case $1`/`case $flag`, `getopts "..."`, строки вида `--flag\)` |
| `exports` | `export VAR=`, `export -f func_name` |
| `comments` | `# Комментарий` непосредственно перед функцией (≤ 3 строки выше) |

**Игнорировать:**
- Однострочные вспомогательные функции без комментария и длиной < 5 строк
- Функции с именами `_helper`, `__internal` (ведущий `_`)
- Строки в heredoc (`<<EOF ... EOF`)

## 2. Правила именования

| Код | Wiki-страница |
|-----|--------------|
| `function launch_claude()` | `launch-claude` |
| `setup_proxy()` | `setup-proxy` |
| `--sandbox-microvm)` | `flag-sandbox-microvm` |
| `--no-proxy)` | `flag-no-proxy` |
| `export ISOLATED_NVM_DIR=` | `var-isolated-nvm-dir` (только если значимая конфиг-переменная) |

Флаги группируются в одну wiki-страницу `{модуль}-flags` если их ≥ 5 в одном файле.
Exported переменные — wiki-страница только если ≥ 3 упоминания в других файлах или описаны в `# comment`.

## 3. Правила синтеза

**Для функции:**
```
# {имя-функции}

{Комментарий перед функцией или вывод из имени}

## Сигнатура
\`\`\`bash
имя_функции [аргументы]
\`\`\`

## Описание
{Развёрнутое описание из комментария + анализ тела}

## Параметры
| Позиция | Имя | Описание |
|---------|-----|---------|
| $1 | param_name | ... |

## Переменные окружения
{переменные, которые функция читает: $VAR, ${VAR:-default}}

## Вызывает
{WikiLinks на другие функции из source, вызываемые внутри тела}
```

**Для группы флагов (≥ 5 флагов в файле):**
```
# {модуль}-flags

Флаги CLI модуля {модуль}.

## Флаги
| Флаг | Описание | По умолчанию |
|------|---------|-------------|
| `--flag` | ... | ... |
```

## 4. Пример

**Вход** (`lib/launcher/launch.sh`):
```bash
# Launch Claude Code with configured environment.
# Applies proxy, NVM path, and CLAUDE_CONFIG_DIR before exec.
launch_claude() {
  local claude_path="$1"

  export CLAUDE_CONFIG_DIR="$ISOLATED_NVM_DIR/.claude-isolated"

  if [[ -n "$PROXY_URL" ]]; then
    setup_proxy
  fi

  exec "$claude_path" "${CLAUDE_ARGS[@]}"
}
```

**Выход** (`.wiki/архитектура/функции/launch-claude.md`):
```markdown
---
wiki_sources: ["[[lib/launcher/launch.sh]]"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# launch_claude

Запустить Claude Code с настроенным окружением: прокси, NVM path, CLAUDE_CONFIG_DIR.

## Сигнатура
\`\`\`bash
launch_claude claude_path
\`\`\`

## Параметры
| Позиция | Имя | Описание |
|---------|-----|---------|
| $1 | claude_path | Путь к исполняемому файлу claude |

## Переменные окружения
- `PROXY_URL` — если установлена, активирует прокси через `setup_proxy`
- `ISOLATED_NVM_DIR` — базовый путь изолированного окружения
- `CLAUDE_ARGS` — массив аргументов для передачи Claude

## Вызывает
[[архитектура/функции/setup-proxy]]
```
```
