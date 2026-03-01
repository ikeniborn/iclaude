#!/usr/bin/env bash
# view-tool-results.sh — просмотр результатов инструментов и агентов из сессии
#
# PostToolUse хук capture-tool-results.py записывает результаты всех
# инструментов в JSONL-лог рядом с транскриптом: {session_id}-tool-results.jsonl
#
# Использование:
#   view-tool-results.sh                     # самая новая сессия
#   view-tool-results.sh SESSION_ID          # конкретная сессия
#   view-tool-results.sh --list              # список сессий с логами
#   view-tool-results.sh --follow [SID]      # следить в реальном времени
#   view-tool-results.sh --tool Bash [SID]   # фильтр по инструменту
#   view-tool-results.sh --errors [SID]      # только ошибки
#   view-tool-results.sh --raw [SID]         # сырой JSONL

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PROJECTS_DIR="$CONFIG_DIR/projects"

# ANSI цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
    cat <<EOF
Просмотр результатов инструментов сессии Claude Code.

Использование: $(basename "$0") [ОПЦИИ] [SESSION_ID]

ОПЦИИ:
  --list             список сессий с логами результатов
  --follow           следить за логом в реальном времени (tail -f)
  --tool TOOL        фильтр по инструменту (Read, Bash, Task, Grep, ...)
  --errors           показать только ошибочные вызовы
  --raw              сырой JSONL без форматирования
  --stats            статистика вызовов по инструментам
  -h, --help         эта справка

АРГУМЕНТЫ:
  SESSION_ID         UUID сессии (по умолчанию: самая новая сессия)

ПРИМЕРЫ:
  $(basename "$0")                          # последняя сессия
  $(basename "$0") --list                   # список всех сессий
  $(basename "$0") --tool Task abc123       # результаты субагентов
  $(basename "$0") --tool Bash --errors     # ошибки в bash-командах
  $(basename "$0") --follow                 # мониторинг в реальном времени
  $(basename "$0") --stats abc123           # статистика инструментов

ЛОГ-ФАЙЛЫ:
  \$CLAUDE_CONFIG_DIR/projects/PROJECT/{session_id}-tool-results.jsonl
EOF
}

# Найти все файлы результатов (отсортированы по дате изменения)
find_results_files() {
    find "$PROJECTS_DIR" -name '*-tool-results.jsonl' 2>/dev/null \
        | xargs -I{} stat --format='%Y {}' {} 2>/dev/null \
        | sort -n \
        | awk '{print $2}' \
        || find "$PROJECTS_DIR" -name '*-tool-results.jsonl' 2>/dev/null | sort
}

# Найти файл результатов для session_id или последний
find_session_file() {
    local session_id="${1:-}"
    if [[ -n "$session_id" ]]; then
        find "$PROJECTS_DIR" -name "${session_id}-tool-results.jsonl" 2>/dev/null | head -1
    else
        find_results_files | tail -1
    fi
}

# Команда --list: перечислить сессии
cmd_list() {
    echo -e "${BOLD}Сессии с результатами инструментов:${RESET}"
    echo ""

    local count=0
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        local dir project session_id lines modified
        dir=$(dirname "$file")
        project=$(basename "$dir")
        session_id=$(basename "$file" '-tool-results.jsonl')
        lines=$(wc -l < "$file" 2>/dev/null || echo '?')
        modified=$(stat -c '%y' "$file" 2>/dev/null | cut -d. -f1 \
                   || stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$file" 2>/dev/null \
                   || echo 'unknown')

        # Кратко показать инструменты из лога
        local tools
        tools=$(python3 -c "
import json, sys, collections
counts = collections.Counter()
try:
    with open('$file') as f:
        for line in f:
            try:
                r = json.loads(line)
                counts[r.get('tool','?')] += 1
            except: pass
    print(', '.join(f'{t}×{n}' for t,n in counts.most_common(5)))
except: print('?')
" 2>/dev/null)

        echo -e "  ${CYAN}${session_id}${RESET}"
        echo -e "  ${DIM}Проект: ${project}${RESET}"
        echo -e "  ${DIM}Вызовов: ${lines} | ${tools}${RESET}"
        echo -e "  ${DIM}Изменён: ${modified}${RESET}"
        echo ""
        ((count++)) || true
    done < <(find_results_files)

    if [[ $count -eq 0 ]]; then
        echo -e "  ${DIM}Логов не найдено.${RESET}"
        echo -e "  ${DIM}Хук capture-tool-results.py должен быть активен в settings.json.${RESET}"
    fi
}

# Команда --stats: статистика по инструментам
cmd_stats() {
    local file="$1"
    echo -e "${BOLD}Статистика инструментов:${RESET} ${DIM}$(basename "$file")${RESET}"
    echo ""
    python3 - "$file" <<'PYEOF'
import json, sys, collections
from datetime import datetime, timezone

path = sys.argv[1]
counts = collections.Counter()
errors = collections.Counter()
total_chars = 0
first_ts = last_ts = None

try:
    with open(path, encoding='utf-8') as f:
        for line in f:
            try:
                r = json.loads(line)
                tool = r.get('tool', '?')
                counts[tool] += 1
                if r.get('error'):
                    errors[tool] += 1
                total_chars += len(r.get('content', ''))
                ts = r.get('ts', '')
                if ts:
                    if not first_ts:
                        first_ts = ts
                    last_ts = ts
            except:
                pass
except IOError as e:
    print(f'Ошибка чтения: {e}')
    sys.exit(1)

CYAN = '\033[0;36m'
RED = '\033[0;31m'
GREEN = '\033[0;32m'
DIM = '\033[2m'
BOLD = '\033[1m'
RESET = '\033[0m'

total = sum(counts.values())
print(f'  {DIM}Период: {first_ts[:19] if first_ts else "?"} → {last_ts[:19] if last_ts else "?"}{RESET}')
print(f'  {DIM}Всего вызовов: {total} | Данных: {total_chars:,} символов{RESET}')
print()
print(f'  {"Инструмент":<16} {"Вызовов":>8} {"Ошибок":>8}')
print(f'  {"-"*16} {"-"*8} {"-"*8}')

for tool, count in counts.most_common():
    err = errors.get(tool, 0)
    err_str = f'{RED}{err:>8}{RESET}' if err else f'{DIM}{0:>8}{RESET}'
    print(f'  {CYAN}{tool:<16}{RESET} {count:>8} {err_str}')
print()
PYEOF
}

# Форматировать одну запись JSONL (через python3 inline)
format_record() {
    local record="$1"
    local tool_filter="$2"
    local errors_only="$3"

    python3 - "$record" "$tool_filter" "$errors_only" <<'PYEOF'
import json, sys

record_str = sys.argv[1]
tool_filter = sys.argv[2].lower() if sys.argv[2] else ''
errors_only = sys.argv[3] == 'true'

try:
    r = json.loads(record_str)
except json.JSONDecodeError:
    sys.exit(0)

tool = r.get('tool', '?')
ts = r.get('ts', '')[:19].replace('T', ' ')
is_error = bool(r.get('error', False))
content = r.get('content', '')
inp = r.get('input', {})

# Фильтры
if tool_filter and tool.lower() != tool_filter:
    sys.exit(0)
if errors_only and not is_error:
    sys.exit(0)

# ANSI цвета
RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[0;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
RESET  = '\033[0m'

# Ключевой аргумент инструмента (первый значимый)
key_input = ''
for key in ('file_path', 'command', 'pattern', 'query', 'url', 'prompt',
            'glob_pattern', 'notebook_path'):
    val = inp.get(key)
    if val:
        key_input = f'{key}={str(val)[:100]}'
        break
if not key_input and inp:
    first_key = next(iter(inp))
    key_input = f'{first_key}={str(inp[first_key])[:100]}'

# Строка статуса
if is_error:
    status = f'{RED}✗ ERROR{RESET}'
else:
    status = f'{GREEN}✓{RESET}'

print(f'{DIM}{ts}{RESET}  {CYAN}{BOLD}{tool:<14}{RESET} {status}')
if key_input:
    print(f'  {DIM}↳ {key_input}{RESET}')

# Содержимое (первые 15 строк / 600 символов)
if content:
    lines = content.split('\n')
    shown = 0
    for line in lines[:15]:
        if shown > 600:
            break
        print(f'  {line}')
        shown += len(line) + 1
    total_lines = len(lines)
    if total_lines > 15 or len(content) > 600:
        print(f'  {DIM}…[ещё {total_lines - min(15, total_lines)} строк, {len(content)} chars]{RESET}')
else:
    print(f'  {DIM}(нет контента){RESET}')
print()
PYEOF
}

# Основной просмотр
cmd_view() {
    local session_id="$1"
    local tool_filter="$2"
    local errors_only="$3"
    local raw="$4"
    local follow="$5"
    local stats="$6"

    local file
    file=$(find_session_file "$session_id")

    if [[ -z "$file" || ! -f "$file" ]]; then
        echo -e "${RED}Файл результатов не найден.${RESET}"
        if [[ -n "$session_id" ]]; then
            echo -e "${DIM}Ожидался: */${session_id}-tool-results.jsonl${RESET}"
        else
            echo -e "${DIM}Нет ни одного лога. Запустите сессию с включённым хуком.${RESET}"
        fi
        exit 1
    fi

    if [[ "$stats" == "true" ]]; then
        cmd_stats "$file"
        return
    fi

    echo -e "${BOLD}Результаты инструментов:${RESET} ${DIM}$(basename "$(dirname "$file")")/${RESET}${CYAN}$(basename "$file")${RESET}"
    echo ""

    if [[ "$raw" == "true" ]]; then
        if [[ "$follow" == "true" ]]; then
            tail -f "$file"
        else
            cat "$file"
        fi
        return
    fi

    if [[ "$follow" == "true" ]]; then
        echo -e "${DIM}Мониторинг (Ctrl+C для выхода)…${RESET}"
        echo ""
        tail -n 0 -f "$file" | while IFS= read -r line; do
            format_record "$line" "$tool_filter" "$errors_only"
        done
        return
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        format_record "$line" "$tool_filter" "$errors_only"
    done < "$file"
}

# ---------------------------------------------------------------------------
# Парсинг аргументов
# ---------------------------------------------------------------------------
SESSION_ID=""
TOOL_FILTER=""
ERRORS_ONLY=false
RAW=false
FOLLOW=false
STATS=false
COMMAND="view"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)    COMMAND="list" ;;
        --follow)  FOLLOW=true ;;
        --tool)    TOOL_FILTER="${2:-}"; shift ;;
        --errors)  ERRORS_ONLY=true ;;
        --raw)     RAW=true ;;
        --stats)   STATS=true ;;
        --help|-h) usage; exit 0 ;;
        -*)        echo "Неизвестная опция: $1" >&2; usage >&2; exit 1 ;;
        *)         SESSION_ID="$1" ;;
    esac
    shift
done

case "$COMMAND" in
    list) cmd_list ;;
    view) cmd_view "$SESSION_ID" "$TOOL_FILTER" "$ERRORS_ONLY" "$RAW" "$FOLLOW" "$STATS" ;;
esac
