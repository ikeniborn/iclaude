# Plan: Архивация .claude/sessions/ по датам

## Context

`.claude/sessions/` накапливает плоский список файлов `readable-{UUID}.toon.tmp.{PID}`.
Один session_id может иметь десятки PID-файлов. Без структуры по датам каталог
трудно анализировать. Задача — применить тот же паттерн `{YYYY-MM-DD}/` что уже
используется в `.claude/tools/`.

**До:**
```
.claude/sessions/
├── readable-05656169-....toon.tmp.141005
├── readable-05656169-....toon.tmp.187570
├── readable-c650e570-....toon.tmp.142793
└── ...
```

**После:**
```
.claude/sessions/
├── readable-{ACTIVE-UUID}.toon.tmp.{PID}   ← только живые
└── 2026-03-03/
    ├── readable-05656169-....toon.tmp.141005
    ├── readable-05656169-....toon.tmp.187570
    └── readable-c650e570-....toon.tmp.142793
```

## Архитектура

Два механизма — дополняют друг друга:

### 1. Stop hook `archive-sessions.py`
Срабатывает при завершении Claude Code сессии. Архивирует файлы завершённой сессии.

- **Trigger:** Stop hook в settings.json
- **Входные данные stdin:** `{"transcript_path": "...", "session_id": "..."}`
- **Логика:**
  1. Получить `session_id` из stdin (или из `transcript_path`)
  2. Найти project_dir через `CLAUDE_PROJECT_DIR` → поиск `.claude/` вверх по дереву
  3. Найти все `sessions/readable-{session_id}.toon.tmp.*` (только flat, не в подпапках)
  4. Для каждого файла: проверить PID через `os.kill(pid, 0)` — если мёртв, переместить
  5. Создать `sessions/{mtime_date}/` и переместить туда
  6. Exit 0 (fail-open — не блокировать завершение)

### 2. Cleanup при запуске в `launch.sh`
Подбирает "осиротевшие" файлы от прошлых сессий (Stop hook мог не сработать при crash).

- **Trigger:** вызов в `launch_claude()` перед запуском claude, после `CLAUDE_PROJECT_DIR`
- **Логика bash-функции `archive_stale_sessions()`:**
  1. Найти `sessions/readable-*.toon.tmp.*` (только в корне, не в подпапках `*/`)
  2. Для каждого файла: извлечь PID из имени → `kill -0 $PID` → если мёртв
  3. Определить дату: `date -r "$file" +%Y-%m-%d` (mtime файла)
  4. Переместить в `sessions/{date}/`

## Файлы для изменения

| Файл | Действие |
|------|----------|
| `.nvm-isolated/.claude-isolated/hooks/archive-sessions.py` | СОЗДАТЬ (Stop hook) |
| `.nvm-isolated/.claude-isolated/settings.json` | ИЗМЕНИТЬ (добавить Stop hook) |
| `lib/launcher/launch.sh` | ИЗМЕНИТЬ (добавить `archive_stale_sessions()`) |

## Stop hook — ключевые детали

**settings.json:**
```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/archive-sessions.py\""
      }
    ]
  }
]
```

**Получение session_id из stdin:**
```python
data = json.load(sys.stdin)
# Из поля session_id (если Claude Code передаёт)
session_id = data.get("session_id")
# Из transcript_path: ".../.claude/sessions/readable-{UUID}.toon"
if not session_id:
    tp = data.get("transcript_path", "")
    m = re.search(r"readable-([a-f0-9-]{36})\.toon", tp)
    if m:
        session_id = m.group(1)
```

**Проверка живого PID:**
```python
def is_pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # процесс есть, нет прав — считаем живым
```

**Дата из mtime файла:**
```python
mtime = os.path.getmtime(filepath)
date_str = datetime.fromtimestamp(mtime, tz=timezone.utc).strftime("%Y-%m-%d")
```

## Паттерн поиска файлов (только flat, не в подпапках)

```python
# Только файлы в корне sessions/ — не рекурсивно
for f in sessions_dir.glob("readable-*.toon.tmp.*"):
    if f.parent == sessions_dir:  # не в подпапке
        ...
```

## Bash cleanup в launch.sh

```bash
archive_stale_sessions() {
    local sessions_dir="${1}/.claude/sessions"
    [[ -d "$sessions_dir" ]] || return 0

    # Только flat файлы (не в подпапках дат)
    while IFS= read -r -d '' f; do
        local filename
        filename="$(basename "$f")"
        # Извлечь PID из имени: readable-{UUID}.toon.tmp.{PID}
        local pid="${filename##*.}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue

        # Если PID мёртв — архивировать
        if ! kill -0 "$pid" 2>/dev/null; then
            local date_str
            date_str="$(date -r "$f" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
            local target_dir="${sessions_dir}/${date_str}"
            mkdir -p "$target_dir"
            mv "$f" "$target_dir/" 2>/dev/null || true
        fi
    done < <(find "$sessions_dir" -maxdepth 1 -name "readable-*.toon.tmp.*" -print0)
}
```

Вызов: `archive_stale_sessions "${CLAUDE_PROJECT_DIR}"` — перед запуском claude.

## Gitignore

`.claude/sessions/*/` уже покрыто правилом `.claude/*` в `.gitignore`.
Также `.claude/sessions` уже явно перечислена в `.gitignore:127`.
Дополнительных изменений не требуется.

## Верификация

```bash
# 1. Проверить синтаксис archive-sessions.py
python3 -m py_compile .nvm-isolated/.claude-isolated/hooks/archive-sessions.py

# 2. Тест Stop hook с синтетическим stdin
echo '{"session_id":"05656169-7431-4a7b-a2b2-246ca7e10b64","transcript_path":".claude/sessions/readable-05656169-7431-4a7b-a2b2-246ca7e10b64.toon"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .nvm-isolated/.claude-isolated/hooks/archive-sessions.py; echo "exit: $?"

# 3. Проверить что файлы перемещены в подпапку даты
ls -la .claude/sessions/2026-*/

# 4. Тест bash cleanup
archive_stale_sessions "$(pwd)"
ls -la .claude/sessions/

# 5. Проверить синтаксис launch.sh
bash -n lib/launcher/launch.sh
```
