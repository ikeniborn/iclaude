# Caveman Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в iclaude поддержку caveman — установщик JS-хуков для сжатия токенов (~65–75%) в изолированную среду `$CLAUDE_CONFIG_DIR`, минуя стандартный `~/.claude/`.

**Architecture:** Новый модуль `lib/caveman/install.sh` с тремя функциями (`install_caveman`, `remove_caveman`, `check_caveman`). Загружается в Phase 2-8 iclaude.sh. Три флага диспетчера (`--caveman-install`, `--caveman-remove`, `--check-caveman`) в Phase 14. Переменные `CAVEMAN_DEFAULT_MODE` и `CAVEMAN_STATUSLINE` из `.claude_config` экспортируются в `lib/launcher/launch.sh` перед `exec claude`. Badge `⛏` читает `~/.claude/.caveman-statusline-suffix` (туда пишет caveman-stats.js) и встраивается в `claude-statusline.sh` по паттерну SECURITY_ICON/PII_ICON.

**Tech Stack:** bash, Python 3 (inline скрипт для патча JSON), curl (скачивание хуков), git ls-remote (версионирование)

---

## Карта файлов

| Действие | Файл | Что меняется |
|---|---|---|
| Создать | `lib/caveman/install.sh` | Новый модуль: 3 функции |
| Изменить | `iclaude.sh` | +Phase 2-8 loader блок + 3 case-ветки в Phase 14 |
| Изменить | `lib/launcher/launch.sh` | +2 строки export перед exec (`CAVEMAN_DEFAULT_MODE` + `CAVEMAN_STATUSLINE`) |
| Изменить | `lib/command/usage.sh` | +3 строки help-текста |
| Изменить | `.claude_config.example` | +блок caveman в конец |
| Изменить | `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` | +CAVEMAN_ICON блок + включение в STATUS_LINE |

---

## Task 1: Создать lib/caveman/install.sh

**Files:**
- Create: `lib/caveman/install.sh`

- [ ] **Step 1.1: Создать файл с каркасом и функцией check_caveman()**

```bash
mkdir -p lib/caveman
```

Создать `lib/caveman/install.sh` со следующим содержимым:

```bash
#!/usr/bin/env bash
# lib/caveman/install.sh — caveman token-compression hooks for iclaude isolated env

_CAVEMAN_HOOKS_BASE="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks"
_CAVEMAN_HOOK_FILES=(caveman-activate.js caveman-config.js caveman-mode-tracker.js caveman-stats.js)

#######################################
# Show caveman installation status.
#######################################
check_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local version_file="$config_dir/caveman-version"

    echo ""
    echo "=== Caveman Status ==="

    local missing=0
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        if [[ -f "$hooks_dir/$f" ]]; then
            echo "  [OK]      $f"
        else
            echo "  [MISSING] $f"
            missing=$((missing + 1))
        fi
    done

    echo ""
    if [[ $missing -eq 0 ]]; then
        echo "  Status:  INSTALLED"
        [[ -f "$version_file" ]] && echo "  Version: $(cat "$version_file")"
    else
        echo "  Status:  NOT INSTALLED ($missing files missing)"
        echo "  Run:     ./iclaude.sh --caveman-install"
    fi

    local mode="${CAVEMAN_DEFAULT_MODE:-full (default)}"
    echo "  Mode:    $mode"
    echo ""
}
```

- [ ] **Step 1.2: Добавить функцию install_caveman()**

Дописать в конец `lib/caveman/install.sh`:

```bash
#######################################
# Download caveman hooks and patch settings.json.
# Idempotent: safe to run multiple times.
#######################################
install_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local settings_file="$config_dir/settings.json"

    if ! command -v curl &>/dev/null; then
        print_error "curl is required for --caveman-install"
        return 1
    fi

    # Download 4 hook files
    print_info "Downloading caveman hook files..."
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        print_info "  $f"
        if ! curl -fsSL "$_CAVEMAN_HOOKS_BASE/$f" -o "$hooks_dir/$f"; then
            print_error "Failed to download $f"
            return 1
        fi
    done

    # Patch settings.json (idempotent)
    print_info "Patching settings.json..."
    python3 - "$settings_file" "$hooks_dir" <<'PYEOF'
import sys, json

settings_file, hooks_dir = sys.argv[1], sys.argv[2]

with open(settings_file) as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})

activate_cmd  = f'node "{hooks_dir}/caveman-activate.js"'
tracker_cmd   = f'node "{hooks_dir}/caveman-mode-tracker.js"'

def already_has(hook_list, cmd):
    return any(
        any(h.get('command') == cmd for h in entry.get('hooks', []))
        for entry in hook_list
    )

def make_entry(cmd, msg):
    return {"hooks": [{"type": "command", "command": cmd,
                        "timeout": 5, "statusMessage": msg}]}

session = hooks.setdefault('SessionStart', [])
if not already_has(session, activate_cmd):
    session.append(make_entry(activate_cmd, "Loading caveman mode..."))

prompt = hooks.setdefault('UserPromptSubmit', [])
if not already_has(prompt, tracker_cmd):
    prompt.append(make_entry(tracker_cmd, "Tracking caveman mode..."))

with open(settings_file, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("settings.json patched")
PYEOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to patch settings.json"
        return 1
    fi

    # Save version via git ls-remote (no GitHub API rate limit)
    print_info "Fetching version..."
    local sha
    sha=$(git ls-remote https://github.com/JuliusBrussee/caveman.git main 2>/dev/null \
          | cut -f1 | cut -c1-12)
    echo "${sha:-unknown}" > "$config_dir/caveman-version"

    echo ""
    print_info "caveman installed (sha: ${sha:-unknown})"
    print_info "Restart iclaude to activate"
}
```

- [ ] **Step 1.3: Добавить функцию remove_caveman()**

Дописать в конец `lib/caveman/install.sh`:

```bash
#######################################
# Remove caveman hooks and clean settings.json.
#######################################
remove_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local settings_file="$config_dir/settings.json"

    print_info "Removing caveman hook files..."
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        local path="$hooks_dir/$f"
        if [[ -f "$path" ]]; then
            rm -f "$path"
            print_info "  Removed $f"
        fi
    done

    if [[ -f "$settings_file" ]]; then
        print_info "Cleaning settings.json..."
        python3 - "$settings_file" "$hooks_dir" <<'PYEOF'
import sys, json

settings_file, hooks_dir = sys.argv[1], sys.argv[2]
caveman_cmds = {
    f'node "{hooks_dir}/caveman-activate.js"',
    f'node "{hooks_dir}/caveman-mode-tracker.js"',
}

with open(settings_file) as f:
    s = json.load(f)

hooks = s.get('hooks', {})
for event in ('SessionStart', 'UserPromptSubmit'):
    if event not in hooks:
        continue
    hooks[event] = [
        e for e in hooks[event]
        if not any(h.get('command') in caveman_cmds for h in e.get('hooks', []))
    ]
    if not hooks[event]:
        del hooks[event]

with open(settings_file, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("settings.json cleaned")
PYEOF
    fi

    rm -f "$config_dir/caveman-version"
    print_info "caveman removed"
}
```

- [ ] **Step 1.4: Проверить синтаксис**

```bash
bash -n lib/caveman/install.sh
```

Ожидаемый вывод: пустой (exit 0). Любой вывод = синтаксическая ошибка, исправить перед продолжением.

- [ ] **Step 1.5: Коммит**

```bash
git add lib/caveman/install.sh
git commit -m "feat(caveman): добавить lib/caveman/install.sh с install/remove/check"
```

---

## Task 2: Подключить модуль в iclaude.sh (Phase 2-8 + Phase 14)

**Files:**
- Modify: `iclaude.sh:115` (после LSP блока)
- Modify: `iclaude.sh:513-516` (после --check-microvm)

- [ ] **Step 2.1: Добавить загрузчик модуля в Phase 2-8**

В `iclaude.sh` найти якорный блок `# Load Oh-My-Posh modules (Phase 8.3)` и вставить новый блок ПОСЛЕ его закрывающего `fi`:

```bash

#######################################
# Load Caveman modules (Phase 8.4)
#######################################
if [[ -d "$LIB_DIR/caveman" ]]; then
    source "${LIB_DIR}/caveman/install.sh"
fi
```

- [ ] **Step 2.2: Добавить dispatch-ветки в Phase 14**

В `iclaude.sh` найти якорный блок `--check-microvm)` и вставить сразу после его закрывающего `;;`:

```bash
            --caveman-install)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --caveman-install"
                    echo ""
                    echo "caveman is only available in isolated environment"
                    exit 1
                fi
                install_caveman
                exit $?
                ;;
            --caveman-remove)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --caveman-remove"
                    exit 1
                fi
                remove_caveman
                exit $?
                ;;
            --check-caveman)
                check_caveman
                exit 0
                ;;
```

- [ ] **Step 2.3: Проверить синтаксис iclaude.sh**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пустой (exit 0).

- [ ] **Step 2.4: Коммит**

```bash
git add iclaude.sh
git commit -m "feat(caveman): добавить --caveman-install/remove/check в iclaude.sh"
```

---

## Task 3: Экспортировать CAVEMAN_DEFAULT_MODE в lib/launcher/launch.sh

**Files:**
- Modify: `lib/launcher/launch.sh` (~строка 618, перед `read -ra claude_cmd_arr`)

- [ ] **Step 3.1: Добавить export CAVEMAN_DEFAULT_MODE и CAVEMAN_STATUSLINE**

В `lib/launcher/launch.sh` найти якорную строку `# Word-split claude_cmd into an array` и вставить перед ней:

```bash
    # Caveman: pass config to hook (process.env.CAVEMAN_DEFAULT_MODE) and statusline
    [[ -n "${CAVEMAN_DEFAULT_MODE:-}" ]] && export CAVEMAN_DEFAULT_MODE
    [[ -n "${CAVEMAN_STATUSLINE:-}" ]] && export CAVEMAN_STATUSLINE
```

Итоговый контекст должен выглядеть так:

```bash
    # Caveman: pass config to hook (process.env.CAVEMAN_DEFAULT_MODE) and statusline
    [[ -n "${CAVEMAN_DEFAULT_MODE:-}" ]] && export CAVEMAN_DEFAULT_MODE
    [[ -n "${CAVEMAN_STATUSLINE:-}" ]] && export CAVEMAN_STATUSLINE

    # Word-split claude_cmd into an array so multi-word commands like
    # "node /path/cli.js" (legacy pre-v2.1.114 fallback) execute correctly.
    local -a claude_cmd_arr
    read -ra claude_cmd_arr <<< "$claude_cmd"
```

- [ ] **Step 3.2: Проверить синтаксис launch.sh**

```bash
bash -n lib/launcher/launch.sh
```

Ожидаемый вывод: пустой (exit 0).

- [ ] **Step 3.3: Проверить синтаксис iclaude.sh ещё раз**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пустой (exit 0).

- [ ] **Step 3.4: Коммит**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(caveman): экспортировать CAVEMAN_DEFAULT_MODE перед exec claude"
```

---

## Task 4: Обновить usage.sh и .claude_config.example

**Files:**
- Modify: `lib/command/usage.sh:79` (после --check-microvm строки)
- Modify: `.claude_config.example` (конец файла)

- [ ] **Step 4.1: Добавить help-текст в usage.sh**

В `lib/command/usage.sh` после строки `  --check-microvm ...` (строка 76) и перед строкой `  --sandbox-microvm ...` (строка 77) вставить:

```bash
  --caveman-install                 Install caveman token-compression hooks (downloads 4 JS files to hooks/)
  --caveman-remove                  Remove caveman hooks and clean settings.json
  --check-caveman                   Show caveman installation status and active mode
```

- [ ] **Step 4.2: Добавить блок в .claude_config.example**

Дописать в конец файла `.claude_config.example`:

```bash

# ============================================================
#  CAVEMAN: TOKEN COMPRESSION (~65-75% output token savings)
# ============================================================
# Install first: ./iclaude.sh --caveman-install
# Remove:        ./iclaude.sh --caveman-remove
# Status:        ./iclaude.sh --check-caveman
#
# # Mode (default: full). Reads from process.env.CAVEMAN_DEFAULT_MODE in hook.
# # off | lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra
# CAVEMAN_DEFAULT_MODE=full
#
# # Show token savings badge in status line (default: false):
# CAVEMAN_STATUSLINE=true
```

- [ ] **Step 4.3: Проверить синтаксис**

```bash
bash -n iclaude.sh && bash -n lib/command/usage.sh
```

Ожидаемый вывод: пустой (exit 0).

- [ ] **Step 4.4: Коммит**

```bash
git add lib/command/usage.sh .claude_config.example
git commit -m "feat(caveman): добавить help-текст и .claude_config.example блок"
```

---

## Task 5: Добавить caveman badge в claude-statusline.sh

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`

**Контекст:** caveman-stats.js пишет суффикс `⛏ 5.2k` в `~/.claude/.caveman-statusline-suffix`. Statusline-скрипт читает этот файл и показывает badge если `CAVEMAN_STATUSLINE=true` экспортирована из launcher. Паттерн идентичен `SECURITY_ICON` и `PII_ICON`.

- [ ] **Step 5.1: Добавить блок CAVEMAN_ICON после блока SECURITY_ICON**

В файле `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` найти якорную строку:
```bash
# PII proxy detection — show when ICLAUDE_PII_ACTIVE=1 (set by launch.sh after proxy starts)
```
И вставить перед ней новый блок:

```bash
# Caveman badge — show ⛏ with savings when CAVEMAN_STATUSLINE is set
# caveman-stats.js writes ~/.claude/.caveman-statusline-suffix (e.g. "⛏ 5.2k")
CAVEMAN_ICON=""
if [[ "${CAVEMAN_STATUSLINE:-}" == "true" ]] || [[ "${CAVEMAN_STATUSLINE:-}" == "1" ]]; then
    _CAVEMAN_SUFFIX_FILE="${HOME}/.claude/.caveman-statusline-suffix"
    if [[ -f "$_CAVEMAN_SUFFIX_FILE" ]]; then
        _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_SUFFIX_FILE" 2>/dev/null | tr -d '\n\r')
        [[ -n "$_CAVEMAN_SUFFIX" ]] && CAVEMAN_ICON=" | ${_CAVEMAN_SUFFIX}" || CAVEMAN_ICON=" | ⛏"
    elif [[ -f "$CLAUDE_CONFIG_DIR/caveman-version" ]]; then
        CAVEMAN_ICON=" | ⛏"
    fi
fi

```

- [ ] **Step 5.2: Добавить `${CAVEMAN_ICON}` в STATUS_LINE assembly**

В том же файле найти `case "$DISPLAY_MODE" in` блок и добавить `${CAVEMAN_ICON}` в строки `full` и `compact` после `${SECURITY_ICON}`:

Было (full):
```bash
STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY}${BUFFER_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${PROVIDER_ICON}${STREAMING_ICON}${MICROVM_ICON}${RL_DISPLAY}${ROUTER_ICON}${PII_ICON}${SECURITY_ICON}${SESSION_LINK}${MEMORY_LINK}${GIT_INFO} |${PROXY_ICON}"
```

Стало (full):
```bash
STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY}${BUFFER_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${PROVIDER_ICON}${STREAMING_ICON}${MICROVM_ICON}${RL_DISPLAY}${ROUTER_ICON}${PII_ICON}${SECURITY_ICON}${CAVEMAN_ICON}${SESSION_LINK}${MEMORY_LINK}${GIT_INFO} |${PROXY_ICON}"
```

Было (compact):
```bash
STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${RL_DISPLAY}${MICROVM_ICON}${PII_ICON}${SECURITY_ICON}${MEMORY_LINK}"
```

Стало (compact):
```bash
STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${RL_DISPLAY}${MICROVM_ICON}${PII_ICON}${SECURITY_ICON}${CAVEMAN_ICON}${MEMORY_LINK}"
```

*(minimal mode не обновляем — там только критичные метрики)*

- [ ] **Step 5.3: Проверить синтаксис**

```bash
bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
```

Ожидаемый вывод: пустой (exit 0).

- [ ] **Step 5.4: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
git commit -m "feat(caveman): добавить badge ⛏ в статусную строку"
```

---

## Task 6: End-to-end тестирование

**Files:** нет изменений — только проверка

- [ ] **Step 6.1: Синтаксис всех изменённых файлов**

```bash
bash -n iclaude.sh && \
bash -n lib/caveman/install.sh && \
bash -n lib/launcher/launch.sh && \
bash -n lib/command/usage.sh && \
bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
echo "Syntax OK: $?"
```

Ожидаемый вывод: `Syntax OK: 0`

- [ ] **Step 6.2: --check-caveman до установки**

```bash
./iclaude.sh --check-caveman
```

Ожидаемый вывод (содержит):
```
Status:  NOT INSTALLED (4 files missing)
Run:     ./iclaude.sh --caveman-install
```

- [ ] **Step 6.3: Запустить установку**

```bash
./iclaude.sh --caveman-install
```

Ожидаемый вывод (содержит):
```
Downloading caveman hook files...
  caveman-activate.js
  caveman-config.js
  caveman-mode-tracker.js
  caveman-stats.js
Patching settings.json...
settings.json patched
Fetching version...
caveman installed (sha: <12-char-sha>)
```

- [ ] **Step 6.4: Проверить наличие файлов**

```bash
ls -la .nvm-isolated/.claude-isolated/hooks/caveman-*.js
```

Ожидаемый вывод: 4 файла — `caveman-activate.js`, `caveman-config.js`, `caveman-mode-tracker.js`, `caveman-stats.js`

- [ ] **Step 6.5: Проверить settings.json — хуки добавлены**

```bash
python3 -c "
import json
with open('.nvm-isolated/.claude-isolated/settings.json') as f:
    s = json.load(f)
h = s.get('hooks', {})
print('SessionStart entries:', len(h.get('SessionStart', [])))
print('UserPromptSubmit entries:', len(h.get('UserPromptSubmit', [])))
for e in h.get('SessionStart', []):
    for hook in e.get('hooks', []):
        print('  SessionStart cmd:', hook.get('command','')[:60])
for e in h.get('UserPromptSubmit', []):
    for hook in e.get('hooks', []):
        print('  UserPromptSubmit cmd:', hook.get('command','')[:60])
"
```

Ожидаемый вывод (содержит):
```
SessionStart entries: 1
UserPromptSubmit entries: 1
  SessionStart cmd: node ".../hooks/caveman-activate.js"
  UserPromptSubmit cmd: node ".../hooks/caveman-mode-tracker.js"
```

- [ ] **Step 6.6: Проверить что ~/.claude/settings.json НЕ изменён**

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
if not p.exists():
    print('~/.claude/settings.json не существует — OK')
else:
    s = json.loads(p.read_text())
    h = s.get('hooks', {})
    if 'SessionStart' not in h and 'UserPromptSubmit' not in h:
        print('~/.claude/settings.json не содержит caveman хуков — OK')
    else:
        print('ОШИБКА: caveman хуки найдены в ~/.claude/settings.json!')
"
```

Ожидаемый вывод: `~/.claude/settings.json не содержит caveman хуков — OK`  
(или "не существует")

- [ ] **Step 6.7: --check-caveman после установки**

```bash
./iclaude.sh --check-caveman
```

Ожидаемый вывод (содержит):
```
Status:  INSTALLED
Version: <sha>
Mode:    full (default)
```

- [ ] **Step 6.8: Тест idempotency — повторная установка**

```bash
./iclaude.sh --caveman-install
```

Затем проверить что в settings.json нет дублей:

```bash
python3 -c "
import json
with open('.nvm-isolated/.claude-isolated/settings.json') as f:
    s = json.load(f)
h = s.get('hooks', {})
print('SessionStart entries:', len(h.get('SessionStart', [])))
print('UserPromptSubmit entries:', len(h.get('UserPromptSubmit', [])))
"
```

Ожидаемый вывод: каждый счётчик остаётся `1` (не `2`).

- [ ] **Step 6.9: Тест удаления**

```bash
./iclaude.sh --caveman-remove
```

Ожидаемый вывод: `caveman removed`

Проверить:
```bash
ls .nvm-isolated/.claude-isolated/hooks/caveman-*.js 2>&1
```
Ожидаемый вывод: `No such file or directory`

```bash
python3 -c "
import json
with open('.nvm-isolated/.claude-isolated/settings.json') as f:
    s = json.load(f)
h = s.get('hooks', {})
print('SessionStart:', h.get('SessionStart', 'REMOVED — OK'))
print('UserPromptSubmit:', h.get('UserPromptSubmit', 'REMOVED — OK'))
"
```
Ожидаемый вывод:
```
SessionStart: REMOVED — OK
UserPromptSubmit: REMOVED — OK
```

- [ ] **Step 6.10: Финальный коммит (если тесты прошли)**

```bash
git add lib/caveman/install.sh iclaude.sh lib/launcher/launch.sh \
        lib/command/usage.sh .claude_config.example \
        .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
git commit -m "test(caveman): end-to-end verified — install/remove/check/idempotency OK"
```
