# Graphify Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Встроить graphify как нативный модуль iclaude с флагами `--install-graphify`, `--check-graphify`, `--graphify` и командой `commands/graphiffy`.

**Architecture:** Три bash-модуля в `lib/graphify/` по образцу `lib/pii-proxy/`. Установка через `uv` (Python-менеджер) в изолированную директорию `.nvm-isolated/.claude-isolated/graphify/`. Пересборка графа запускается перед claude при флаге `--graphify`.

**Tech Stack:** Bash, `uv` (Python packager, самостоятельно скачивает Python 3.12), `graphifyy` (PyPI), `bash -n` для проверки синтаксиса.

---

## Карта файлов

| Файл | Действие | Ответственность |
|------|----------|-----------------|
| `lib/graphify/detect.sh` | Создать | `detect_graphify()` — проверка uv + binary |
| `lib/graphify/install.sh` | Создать | `install_graphify()`, `_graphify_rebuild_graph()` |
| `lib/graphify/status.sh` | Создать | `check_graphify_status()` |
| `lib/core/init.sh` | Изменить:95-160 | Добавить graphify-переменные в `init_environment()` |
| `iclaude.sh` | Изменить:99-106, 194-196, 202-216, 481-500, 607-611 | Загрузка модулей, флаги, dispatch, rebuild |
| `lib/command/usage.sh` | Изменить:59-62 | Добавить описание трёх флагов |
| `.claude_config.example` | Изменить:241-260 | Добавить секцию GRAPHIFY |
| `CLAUDE.md` | Изменить:52-60 | Добавить graphify в Features + daily команды |

---

## Task 1: Переменные в `lib/core/init.sh`

**Files:**
- Modify: `lib/core/init.sh:95` (после блока PII proxy, перед блоком CCR)

- [ ] **Step 1: Вставить блок graphify-переменных в `init_environment()`**

В `lib/core/init.sh` найти строку 95 (начало блока CCR после экспортов PII proxy) и вставить перед ней:

```bash
    # Graphify (Knowledge Graph)
    GRAPHIFY_UV_BIN="${ISOLATED_NVM_DIR}/bin/uv"
    GRAPHIFY_TOOL_DIR="${ISOLATED_CONFIG_DIR}/graphify"
    GRAPHIFY_PYTHON_DIR="${ISOLATED_CONFIG_DIR}/graphify/python"
    GRAPHIFY_OUTPUT_DIR="${GRAPHIFY_OUTPUT_DIR:-}"
    GRAPHIFY_EXTRA_ARGS="${GRAPHIFY_EXTRA_ARGS:-}"

    export GRAPHIFY_UV_BIN GRAPHIFY_TOOL_DIR GRAPHIFY_PYTHON_DIR
    export GRAPHIFY_OUTPUT_DIR GRAPHIFY_EXTRA_ARGS

```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n lib/core/init.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add lib/core/init.sh
git commit -m "feat(graphify): add graphify env vars to lib/core/init.sh"
```

---

## Task 2: `lib/graphify/detect.sh`

**Files:**
- Create: `lib/graphify/detect.sh`

- [ ] **Step 1: Создать файл**

```bash
#!/bin/bash
# Graphify detection module
# Provides: detect_graphify()

#######################################
# Check if graphify is installed in isolated environment.
# Tests uv binary and graphify binary existence.
# Returns: 0 if installed, 1 otherwise
#######################################
detect_graphify() {
    [[ -x "$GRAPHIFY_UV_BIN" ]] || return 1
    [[ -x "${GRAPHIFY_TOOL_DIR}/bin/graphify" ]]
}
```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n lib/graphify/detect.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add lib/graphify/detect.sh
git commit -m "feat(graphify): add lib/graphify/detect.sh"
```

---

## Task 3: `lib/graphify/status.sh`

**Files:**
- Create: `lib/graphify/status.sh`

- [ ] **Step 1: Создать файл**

```bash
#!/bin/bash
# Graphify status module
# Provides: check_graphify_status()

#######################################
# Display graphify installation status.
# Shows uv, graphifyy version, Python, disk usage, output dir.
# Returns: 0 always
#######################################
check_graphify_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Graphify: Knowledge Graph Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # uv binary
    if [[ -x "$GRAPHIFY_UV_BIN" ]]; then
        local uv_ver
        uv_ver=$("$GRAPHIFY_UV_BIN" --version 2>/dev/null || echo "unknown")
        print_success "uv: $GRAPHIFY_UV_BIN ($uv_ver)"
    else
        print_warning "uv: not found at $GRAPHIFY_UV_BIN"
        echo "  Run: ./iclaude.sh --install-graphify"
        echo ""
        return 0
    fi

    # graphify binary
    local graphify_bin="${GRAPHIFY_TOOL_DIR}/bin/graphify"
    if [[ -x "$graphify_bin" ]]; then
        local gfy_ver
        gfy_ver=$("$graphify_bin" --version 2>/dev/null || echo "unknown")
        print_success "graphifyy: $graphify_bin ($gfy_ver)"
    else
        print_warning "graphifyy: not installed"
        echo "  Run: ./iclaude.sh --install-graphify"
    fi

    # Python version (read from installed path — no network, no download)
    local py_bin py_ver
    py_bin=$(find "$GRAPHIFY_PYTHON_DIR" -name "python3.12" -maxdepth 4 -type f 2>/dev/null | head -1 || true)
    if [[ -n "$py_bin" ]]; then
        py_ver=$("$py_bin" --version 2>/dev/null || echo "unknown")
        print_success "Python: $py_ver"
    else
        print_warning "Python 3.12: not yet downloaded (installed on first --install-graphify)"
    fi

    # Disk usage
    if [[ -d "$GRAPHIFY_TOOL_DIR" ]]; then
        local disk_size
        disk_size=$(du -sh "$GRAPHIFY_TOOL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR ($disk_size)"
    else
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR (not created yet)"
    fi

    # Output dir
    if [[ -n "$GRAPHIFY_OUTPUT_DIR" ]]; then
        print_info "Output dir: $GRAPHIFY_OUTPUT_DIR (from GRAPHIFY_OUTPUT_DIR)"
    else
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repo — will use \$PWD)")
        print_info "Output dir: $git_root (git root, default)"
    fi

    echo ""
    return 0
}
```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n lib/graphify/status.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add lib/graphify/status.sh
git commit -m "feat(graphify): add lib/graphify/status.sh"
```

---

## Task 4: `lib/graphify/install.sh`

**Files:**
- Create: `lib/graphify/install.sh`

- [ ] **Step 1: Создать файл**

```bash
#!/bin/bash
# Graphify installation module
# Provides: install_graphify(), _graphify_rebuild_graph()

#######################################
# Resolve proxy URL from environment
# Outputs: proxy URL string (or empty)
#######################################
_graphify_resolve_proxy() {
    echo "${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
}

#######################################
# Rebuild knowledge graph for current project.
# Called by --graphify flag before launching claude.
# Returns: 0 on success, 1 on failure
#######################################
_graphify_rebuild_graph() {
    if ! detect_graphify; then
        print_error "graphify not installed. Run: ./iclaude.sh --install-graphify"
        return 1
    fi

    local output_dir
    if [[ -n "$GRAPHIFY_OUTPUT_DIR" ]]; then
        output_dir="$GRAPHIFY_OUTPUT_DIR"
    else
        output_dir=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
    fi

    print_info "Building knowledge graph → $output_dir"

    # Build args array to handle extra args safely
    local -a graphify_args=(".")
    [[ -n "$output_dir" ]] && graphify_args+=("--output-dir" "$output_dir")
    # Split GRAPHIFY_EXTRA_ARGS on whitespace (intentional word splitting for flag list)
    # shellcheck disable=SC2086
    [[ -n "$GRAPHIFY_EXTRA_ARGS" ]] && read -ra _extra <<< "$GRAPHIFY_EXTRA_ARGS" && graphify_args+=("${_extra[@]}")

    local proxy
    proxy=$(_graphify_resolve_proxy)
    local proxy_env=()
    if [[ -n "$proxy" ]]; then
        proxy_env=(env UV_HTTP_PROXY="$proxy" UV_HTTPS_PROXY="$proxy")
    fi

    UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "${proxy_env[@]}" \
        "$GRAPHIFY_UV_BIN" tool run graphify "${graphify_args[@]}"
}

#######################################
# Install graphify in isolated environment.
# Installs uv, then graphifyy via uv tool install.
# Args: [--force] — remove existing tool dir before install
# Returns: 0 on success, 1 on failure
#######################################
install_graphify() {
    local force=false
    [[ "${1:-}" == "--force" ]] && force=true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Graphify: Install Knowledge Graph Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check isolated environment
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # Force: remove existing tool dir
    if [[ "$force" == true ]] && [[ -d "$GRAPHIFY_TOOL_DIR" ]]; then
        print_info "Force reinstall: removing $GRAPHIFY_TOOL_DIR"
        rm -rf "$GRAPHIFY_TOOL_DIR"
    fi

    local proxy
    proxy=$(_graphify_resolve_proxy)
    local proxy_env=()
    if [[ -n "$proxy" ]]; then
        proxy_env=(env UV_HTTP_PROXY="$proxy" UV_HTTPS_PROXY="$proxy")
    fi

    # Step 1: Install uv if missing
    if [[ ! -x "$GRAPHIFY_UV_BIN" ]]; then
        print_info "Installing uv to ${ISOLATED_NVM_DIR}/bin/ ..."
        if ! "${proxy_env[@]}" \
            env INSTALLER_NO_MODIFY_PATH=1 UV_INSTALL_DIR="${ISOLATED_NVM_DIR}/bin" \
            sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"; then
            print_error "Failed to install uv"
            return 1
        fi
        print_success "uv installed: $GRAPHIFY_UV_BIN"
    else
        local uv_ver
        uv_ver=$("$GRAPHIFY_UV_BIN" --version 2>/dev/null || echo "unknown")
        print_success "uv already present ($uv_ver)"
    fi

    # Step 2: Install graphifyy via uv tool
    print_info "Installing graphifyy (Python 3.12) ..."
    if ! UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        UV_PYTHON_INSTALL_DIR="$GRAPHIFY_PYTHON_DIR" \
        "${proxy_env[@]}" \
        "$GRAPHIFY_UV_BIN" tool install graphifyy --python 3.12; then
        print_error "Failed to install graphifyy"
        return 1
    fi
    print_success "graphifyy installed"

    # Step 3: graphify install (Claude Code skill setup)
    print_info "Setting up Claude Code skill ..."
    if UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "$GRAPHIFY_UV_BIN" tool run graphify install 2>/dev/null; then
        print_success "Claude Code skill configured"
    else
        print_warning "graphify install returned non-zero (skill setup optional — continuing)"
    fi

    # Step 4: Create commands/graphiffy
    _graphify_install_command || return 1

    echo ""
    print_success "Graphify installed successfully!"
    echo ""
    print_info "Next steps:"
    print_info "  Status:           ./iclaude.sh --check-graphify"
    print_info "  Build graph:      ./iclaude.sh --graphify"
    print_info "  Manual rebuild:   .nvm-isolated/.claude-isolated/commands/graphiffy"
    echo ""
    return 0
}

#######################################
# Create commands/graphiffy standalone script.
# Returns: 0 on success, 1 on failure
#######################################
_graphify_install_command() {
    local commands_dir="${ISOLATED_CONFIG_DIR}/commands"
    local cmd_path="${commands_dir}/graphiffy"

    mkdir -p "$commands_dir"

    cat > "$cmd_path" << 'GRAPHIFFY_SCRIPT'
#!/usr/bin/env bash
# commands/graphiffy — ручная пересборка graphify-графа (без запуска claude).
# Использует GRAPHIFY_OUTPUT_DIR, GRAPHIFY_EXTRA_ARGS из .claude_config или окружения.

ICLAUDE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

# Загрузить пользовательские переменные из .claude_config (если есть)
[[ -f "$ICLAUDE_DIR/.claude_config" ]] && source "$ICLAUDE_DIR/.claude_config"

GRAPHIFY_TOOL_DIR="${ICLAUDE_DIR}/.nvm-isolated/.claude-isolated/graphify"
GRAPHIFY_UV_BIN="${ICLAUDE_DIR}/.nvm-isolated/bin/uv"

if [[ ! -x "$GRAPHIFY_UV_BIN" ]] || [[ ! -x "${GRAPHIFY_TOOL_DIR}/bin/graphify" ]]; then
    echo "ERROR: graphify not installed. Run: ./iclaude.sh --install-graphify" >&2
    exit 1
fi

# Определить output_dir
if [[ -n "${GRAPHIFY_OUTPUT_DIR:-}" ]]; then
    output_dir="$GRAPHIFY_OUTPUT_DIR"
else
    output_dir=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
fi

# Build args array
args=(".")
[[ -n "$output_dir" ]] && args+=("--output-dir" "$output_dir")
[[ -n "${GRAPHIFY_EXTRA_ARGS:-}" ]] && read -ra _extra <<< "$GRAPHIFY_EXTRA_ARGS" && args+=("${_extra[@]}")

# Proxy support
proxy_env=()
_proxy="${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
[[ -n "$_proxy" ]] && proxy_env=(env UV_HTTP_PROXY="$_proxy" UV_HTTPS_PROXY="$_proxy")

UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
    "${proxy_env[@]}" \
    "$GRAPHIFY_UV_BIN" tool run graphify "${args[@]}"
GRAPHIFFY_SCRIPT

    chmod +x "$cmd_path"
    print_success "Command created: $cmd_path"
}
```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n lib/graphify/install.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add lib/graphify/install.sh
git commit -m "feat(graphify): add lib/graphify/install.sh with install_graphify and _graphify_rebuild_graph"
```

---

## Task 5: Загрузка модулей в `iclaude.sh`

**Files:**
- Modify: `iclaude.sh:106` (после блока `# Load PII proxy modules`)

- [ ] **Step 1: Вставить блок загрузки graphify после строки 106 (после `fi` PII proxy)**

Найти в `iclaude.sh`:
```bash
if [[ -d "$LIB_DIR/pii-proxy" ]]; then
    source "${LIB_DIR}/pii-proxy/detect.sh"
    source "${LIB_DIR}/pii-proxy/install.sh"
    source "${LIB_DIR}/pii-proxy/status.sh"
fi

#######################################
# Load LSP modules (Phase 8.1)
```

Вставить между `fi` и `# Load LSP modules`:
```bash
#######################################
# Load Graphify modules
#######################################
if [[ -d "$LIB_DIR/graphify" ]]; then
    source "${LIB_DIR}/graphify/detect.sh"
    source "${LIB_DIR}/graphify/install.sh"
    source "${LIB_DIR}/graphify/status.sh"
fi

```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add iclaude.sh
git commit -m "feat(graphify): load lib/graphify/ modules in iclaude.sh"
```

---

## Task 6: Переменная флага и чтение конфига в `iclaude.sh`

**Files:**
- Modify: `iclaude.sh:194-216` (блок инициализации флагов в `main()`)

- [ ] **Step 1: Добавить `USE_GRAPHIFY_FLAG=false` в список флагов (строка ~196)**

Найти:
```bash
    USE_ROUTER_FLAG=false
    USE_PII_PROXY_FLAG=false
    USE_MICRO_VM_FLAG=false
```

Заменить на:
```bash
    USE_ROUTER_FLAG=false
    USE_PII_PROXY_FLAG=false
    USE_MICRO_VM_FLAG=false
    USE_GRAPHIFY_FLAG=false
```

- [ ] **Step 2: Добавить чтение `GRAPHIFY_OUTPUT_DIR` из конфига (после блока microvm ~строка 216)**

Найти:
```bash
        [[ -n "$_cfg_microvm" ]] && USE_MICRO_VM_FLAG=true
        unset _cfg_microvm
```

Вставить после:
```bash
        # Match: GRAPHIFY_OUTPUT_DIR=/some/path
        _cfg_graphify_out=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?GRAPHIFY_OUTPUT_DIR[[:space:]]*=[[:space:]]*['\"]?[^'\"[:space:]]" \
            "$CREDENTIALS_FILE" 2>/dev/null | head -1 || true)
        if [[ -n "$_cfg_graphify_out" ]]; then
            GRAPHIFY_OUTPUT_DIR=$(echo "$_cfg_graphify_out" | \
                sed 's/.*GRAPHIFY_OUTPUT_DIR[[:space:]]*=[[:space:]]*//' | tr -d "\"'")
            export GRAPHIFY_OUTPUT_DIR
        fi
        unset _cfg_graphify_out

        # Match: GRAPHIFY_EXTRA_ARGS="--no-video"
        _cfg_graphify_args=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?GRAPHIFY_EXTRA_ARGS[[:space:]]*=" \
            "$CREDENTIALS_FILE" 2>/dev/null | head -1 || true)
        if [[ -n "$_cfg_graphify_args" ]]; then
            GRAPHIFY_EXTRA_ARGS=$(echo "$_cfg_graphify_args" | \
                sed 's/.*GRAPHIFY_EXTRA_ARGS[[:space:]]*=[[:space:]]*//' | tr -d "\"'")
            export GRAPHIFY_EXTRA_ARGS
        fi
        unset _cfg_graphify_args
```

- [ ] **Step 3: Проверить синтаксис**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 4: Коммит**

```bash
git add iclaude.sh
git commit -m "feat(graphify): add USE_GRAPHIFY_FLAG and config reading in iclaude.sh"
```

---

## Task 7: Dispatch флагов в `iclaude.sh`

**Files:**
- Modify: `iclaude.sh` — case-блок разбора аргументов (~строки 481-500)

- [ ] **Step 1: Добавить dispatch для трёх флагов**

Найти в `iclaude.sh` (внутри `while [[ $# -gt 0 ]]; do ... case "$1" in`):
```bash
            --pii-proxy)
                USE_PII_PROXY_FLAG=true
                shift
                ;;
            --install-pii-proxy)
```

Вставить перед `--pii-proxy)`:
```bash
            --graphify)
                USE_GRAPHIFY_FLAG=true
                shift
                ;;
            --install-graphify)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-graphify"
                    echo ""
                    echo "Graphify is only available in isolated environment"
                    exit 1
                fi
                _gfy_install_force=""
                [[ "${2:-}" == "--force" ]] && { _gfy_install_force="--force"; shift; }
                [[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"
                install_graphify "$_gfy_install_force"
                exit $?
                ;;
            --check-graphify)
                check_graphify_status
                exit 0
                ;;
```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Коммит**

```bash
git add iclaude.sh
git commit -m "feat(graphify): add --graphify/--install-graphify/--check-graphify dispatch"
```

---

## Task 8: Вызов `_graphify_rebuild_graph` в потоке запуска

**Files:**
- Modify: `iclaude.sh` — участок между разбором аргументов и `launch_claude` (~строка 607-612)

- [ ] **Step 1: Добавить вызов rebuild перед `launch_claude`**

Найти в `iclaude.sh` (после блока combined-mode PII+router, ~строка 607):
```bash
    if [[ "$USE_PII_PROXY_FLAG" == "true" ]] && [[ "$USE_ROUTER_FLAG" == "true" ]]; then
        print_info "Combined mode detected: PII proxy + CCR router chain will be activated"
        print_info "Traffic chain: claude → PII proxy(:${PII_PROXY_PORT:-9000}) → CCR(:${CCR_PORT:-3456}) → providers"
        echo ""
    fi
```

Вставить после блока `fi`:
```bash
    # Rebuild graphify knowledge graph if --graphify flag is set
    if [[ "$USE_GRAPHIFY_FLAG" == true ]]; then
        _graphify_rebuild_graph || print_warning "Graph rebuild failed — continuing without updated graph"
    fi

```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Smoke-тест (graphify не установлен — ожидаем предупреждение, а не crash)**

```bash
# Имитировать USE_GRAPHIFY_FLAG без установленного graphify — функция должна вернуть 1 (warning, не crash)
bash -c '
set -euo pipefail
SCRIPT_DIR="$(pwd)"
source lib/core/init.sh
init_environment
source lib/graphify/detect.sh
source lib/graphify/install.sh
source lib/core/logging.sh
USE_GRAPHIFY_FLAG=true
_graphify_rebuild_graph || echo "OK: rebuild returned non-zero, warning shown"
'
```

Ожидаемый вывод: строка с `ERROR:` и `OK: rebuild returned non-zero, warning shown`.

- [ ] **Step 4: Коммит**

```bash
git add iclaude.sh
git commit -m "feat(graphify): call _graphify_rebuild_graph in launch flow when --graphify"
```

---

## Task 9: Текст флагов в `lib/command/usage.sh`

**Files:**
- Modify: `lib/command/usage.sh:59-62`

- [ ] **Step 1: Добавить описание трёх флагов после блока PII proxy**

Найти:
```
  --install-pii-proxy               Install PII proxy (Python venv + Presidio NLP)
  --check-pii-proxy                 Show PII proxy status (venv, models, running PID)
  --pii-proxy                       Launch with PII/secrets masking proxy (overrides USE_PII_PROXY config)
```

Вставить после:
```
  --install-graphify                Install graphify knowledge graph tool (uv + Python 3.12 + graphifyy)
                                    Creates commands/graphiffy for standalone graph rebuild
  --install-graphify --force        Force reinstall (removes existing graphify tool dir)
  --check-graphify                  Show graphify status (uv, graphifyy version, Python, paths)
  --graphify                        Rebuild knowledge graph before launching claude
                                    Output: GRAPHIFY_OUTPUT_DIR or git root (default)
```

- [ ] **Step 2: Проверить синтаксис**

```bash
bash -n lib/command/usage.sh
```

Ожидаемый вывод: пусто (exit 0).

- [ ] **Step 3: Smoke-тест флагов в help**

```bash
./iclaude.sh --help | grep -A2 "install-graphify"
```

Ожидаемый вывод:
```
  --install-graphify                Install graphify knowledge graph tool (uv + Python 3.12 + graphifyy)
                                    Creates commands/graphiffy for standalone graph rebuild
  --install-graphify --force        Force reinstall (removes existing graphify tool dir)
```

- [ ] **Step 4: Коммит**

```bash
git add lib/command/usage.sh
git commit -m "feat(graphify): add --install-graphify/--check-graphify/--graphify to usage.sh"
```

---

## Task 10: Секция GRAPHIFY в `.claude_config.example`

**Files:**
- Modify: `.claude_config.example` — после секции PII proxy (строка ~311), перед секцией MICRO-VM

- [ ] **Step 1: Вставить секцию GRAPHIFY**

Найти строку:
```bash
# ============================================================
#  MICRO-VM SANDBOX (Firecracker — изоляция на уровне ядра)
```

Вставить перед ней:
```bash
# ============================================================
#  GRAPHIFY (граф знаний кодовой базы)
# ============================================================
# Graphify строит queryable-граф из кода, документов, схем.
# Используется как Claude Code skill (/graphify query "...").
#
# Установка:         ./iclaude.sh --install-graphify
# Статус:            ./iclaude.sh --check-graphify
# Запуск с графом:   ./iclaude.sh --graphify
# Ручная пересборка: .nvm-isolated/.claude-isolated/commands/graphiffy
#
# Папка для graph.html, GRAPH_REPORT.md, graph.json.
# Если не задана — используется корень git-репозитория ($PWD если не git-репо).
# Пример: GRAPHIFY_OUTPUT_DIR=/home/user/graphs/my-project
# GRAPHIFY_OUTPUT_DIR=

# Дополнительные аргументы к `graphify .` (через пробел).
# Пример: --no-video (пропустить видеофайлы), --no-office (без .docx/.xlsx)
# GRAPHIFY_EXTRA_ARGS=

```

- [ ] **Step 2: Коммит**

```bash
git add .claude_config.example
git commit -m "feat(graphify): add GRAPHIFY section to .claude_config.example"
```

---

## Task 11: Обновить `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md:7,44-47,52-61,142`

- [ ] **Step 1: Обновить однострочное описание проекта (строка 7)**

Найти:
```
**iclaude** is a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy (Presidio NLP), and microVM sandbox (Firecracker).
```

Заменить на:
```
**iclaude** is a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy (Presidio NLP), microVM sandbox (Firecracker), and Graphify knowledge graph.
```

- [ ] **Step 2: Добавить graphify в таблицу Features (после строки microVM)**

Найти:
```
| microVM Sandbox (Firecracker, virtio-blk+SSH, KVM) | [docs/MICROVM.md](docs/MICROVM.md) |
```

Вставить после:
```
| Graphify Knowledge Graph (uv, Python 3.12, graphifyy) | `lib/graphify/` |
```

- [ ] **Step 3: Добавить команду установки в секцию ### Installation**

Найти:
```bash
./iclaude.sh --install-pii-proxy      # Install PII proxy (Python venv + Presidio NLP)
```

Вставить после:
```bash
./iclaude.sh --install-graphify       # Install Graphify (uv + Python 3.12 + graphifyy)
```

- [ ] **Step 4: Обновить счётчик модулей в Architecture (строка ~142)**

Найти:
```
**Version 4.0** — modular bash in `lib/` (16 modules: core, command, proxy, nvm, oauth, router, lsp, config, lockfile, update, launcher, statusline, chrome, ohmyposh, pii-proxy, sandbox).
```

Заменить на:
```
**Version 4.0** — modular bash in `lib/` (17 modules: core, command, proxy, nvm, oauth, router, lsp, config, lockfile, update, launcher, statusline, chrome, ohmyposh, pii-proxy, sandbox, graphify).
```

- [ ] **Step 5: Коммит**

```bash
git add CLAUDE.md
git commit -m "docs: add graphify to CLAUDE.md features, description, installation, architecture"
```

---

## Task 12: Финальная проверка синтаксиса и smoke-тест

- [ ] **Step 1: Полная проверка синтаксиса всех затронутых файлов**

```bash
bash -n iclaude.sh && \
bash -n lib/core/init.sh && \
bash -n lib/graphify/detect.sh && \
bash -n lib/graphify/install.sh && \
bash -n lib/graphify/status.sh && \
bash -n lib/command/usage.sh && \
echo "ALL SYNTAX OK"
```

Ожидаемый вывод: `ALL SYNTAX OK`

- [ ] **Step 2: Проверить, что существующие тесты не сломаны**

```bash
python3 -m pytest tests/test_patterns_examples.py -v --tb=short 2>&1 | tail -10
```

Ожидаемый вывод: все тесты `PASSED`, `0 failed`.

- [ ] **Step 3: Smoke-тест --help**

```bash
./iclaude.sh --help | grep -E "graphify|graphiffy"
```

Ожидаемый вывод (минимум 3 строки):
```
  --install-graphify                Install graphify knowledge graph tool ...
  --check-graphify                  Show graphify status ...
  --graphify                        Rebuild knowledge graph before launching claude
```

- [ ] **Step 4: Финальный коммит**

```bash
git status   # убедиться, что нет случайных неотслеживаемых изменений
```

---

## Итог

После Task 12 модуль graphify полностью интегрирован:

```bash
./iclaude.sh --install-graphify          # установить
./iclaude.sh --check-graphify            # проверить статус
./iclaude.sh --graphify                  # собрать граф + запустить claude
.nvm-isolated/.claude-isolated/commands/graphiffy  # ручная пересборка
```
