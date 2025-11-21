---
name: Isolated Environment
description: Управление изолированной установкой NVM и Claude Code в директории проекта
version: 1.0.0
author: init_claude Team
tags: [nvm, isolation, installation, versioning, portability]
dependencies: [bash-development]
---

# Isolated Environment

Автоматизация работы с изолированной установкой NVM и Claude Code в директории проекта. Позволяет избежать конфликтов с системными установками и передавать готовую среду через git репозиторий.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Установить init_claude с изолированным NVM в директорию проекта
- Избежать конфликтов с системным NVM
- Передать готовую установку через git (без необходимости системной установки на другой машине)
- Тестировать разные версии Claude Code без влияния на систему
- Использовать специфичную версию Node.js для Claude Code

Скил автоматически вызывается при запросах типа:
- "Установи Claude в изолированное окружение"
- "Как передать установку init_claude через git?"
- "Избежать конфликтов с системным NVM"
- "Cleanup изолированной установки"
- "Почему симлинки не работают после git clone?"
- "Исправь broken symlinks в изолированном окружении"
- "Проверь статус симлинков"

## Контекст проекта

### Архитектура изолированной установки

```
/home/user/Documents/Project/claude/
├── .nvm-isolated/                    # Изолированный NVM (в .gitignore)
│   ├── nvm.sh
│   └── versions/
│       └── node/
│           └── v18.x.x/
│               ├── bin/
│               │   ├── node
│               │   ├── npm
│               │   └── claude*      # Симлинк на cli.js
│               └── lib/
│                   └── node_modules/
│                       └── @anthropic-ai/
│                           └── claude-code/
│                               ├── cli.js
│                               └── package.json
│
├── .nvm-isolated-lockfile.json       # Версии для воспроизводства (в git)
│   {
│     "nodeVersion": "18.19.0",
│     "claudeCodeVersion": "1.2.3",
│     "installedAt": "2025-10-22T19:30:00Z"
│   }
│
├── .gitignore                        # Исключить .nvm-isolated/
└── init_claude.sh                    # Поддержка --isolated-install
```

### Почему изоляция в директории проекта?

**Преимущества:**
1. ✅ **Избежание конфликтов**: Не влияет на `~/.nvm` и системные установки
2. ✅ **Портативность**: Можно передать через git (lockfile) или скопировать целиком
3. ✅ **Версионирование**: Разные проекты могут использовать разные версии Node.js/Claude
4. ✅ **Воспроизводимость**: `--isolated-install` создаст идентичное окружение
5. ✅ **Безопасность**: Изоляция npm пакетов от системы

**Компромисс:**
- ⚠️ Размер: `.nvm-isolated/` занимает ~200-300 MB (можно коммитить в git или использовать lockfile)
- ⚠️ Симлинки: После git clone нужно восстановить симлинки (`--repair-isolated`)
  - Git хранит симлинки как blob references, не реальные symlinks
  - 4 критичных симлинка: npm, npx, corepack, claude
- ✅ Решение 1: Коммитим `.nvm-isolated/` и запускаем `--repair-isolated` после clone
- ✅ Решение 2: Коммитим только `.nvm-isolated-lockfile.json` и используем `--install-from-lockfile`

## Шаблоны кода

### Шаблон 1: Установка изолированного окружения

```bash
#######################################
# Setup isolated NVM environment in project directory
# Returns:
#   0 - success
#   1 - error
#######################################
setup_isolated_nvm() {
    local isolated_nvm_dir="${SCRIPT_DIR}/.nvm-isolated"

    # Create isolated NVM directory
    mkdir -p "$isolated_nvm_dir"

    # Export isolated environment
    export NVM_DIR="$isolated_nvm_dir"
    export NPM_CONFIG_PREFIX="$NVM_DIR/npm-global"
    export PATH="$NVM_DIR/npm-global/bin:$NVM_DIR/versions/node/*/bin:$PATH"

    print_success "Using isolated NVM: $NVM_DIR"
    return 0
}

#######################################
# Install NVM to isolated directory
#######################################
install_isolated_nvm() {
    setup_isolated_nvm

    # Check if NVM already installed
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        print_info "NVM already installed in isolated environment"
        return 0
    fi

    print_info "Installing NVM to isolated directory..."

    # Download and install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | \
        NVM_DIR="$NVM_DIR" bash

    if [[ $? -ne 0 ]]; then
        print_error "Failed to install NVM"
        return 1
    fi

    print_success "NVM installed to: $NVM_DIR"
    return 0
}

#######################################
# Install Node.js in isolated NVM
#######################################
install_isolated_nodejs() {
    local node_version=${1:-18}  # Default to Node 18 LTS

    setup_isolated_nvm

    # Source NVM
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    # Check if Node.js already installed
    if nvm ls "$node_version" &>/dev/null; then
        print_info "Node.js $node_version already installed"
        nvm use "$node_version"
        return 0
    fi

    print_info "Installing Node.js $node_version to isolated environment..."

    # Install and use Node.js
    nvm install "$node_version"
    nvm use "$node_version"

    print_success "Node.js $node_version installed"
    node --version
    npm --version

    return 0
}

#######################################
# Install Claude Code in isolated environment
#######################################
install_isolated_claude() {
    setup_isolated_nvm
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    # Ensure Node.js is available
    if ! command -v npm &>/dev/null; then
        print_error "Node.js not found in isolated environment"
        echo "Run: init_claude --isolated-install first"
        return 1
    fi

    print_info "Installing Claude Code to isolated environment..."

    # Install Claude Code globally (in isolated prefix)
    npm install -g @anthropic-ai/claude-code

    if [[ $? -ne 0 ]]; then
        print_error "Failed to install Claude Code"
        return 1
    fi

    # Verify installation
    local claude_version=$(claude --version 2>/dev/null | head -n 1)
    print_success "Claude Code installed: $claude_version"

    # Save lockfile for reproducibility
    save_isolated_lockfile

    return 0
}
```

### Шаблон 2: Сохранение lockfile для воспроизводства

```bash
#######################################
# Save lockfile with installed versions
#######################################
save_isolated_lockfile() {
    local lockfile="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"

    setup_isolated_nvm
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    # Get versions
    local node_version=$(node --version 2>/dev/null | sed 's/v//')
    local claude_version=$(claude --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+')
    local installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create lockfile
    cat > "$lockfile" << EOF
{
  "nodeVersion": "$node_version",
  "claudeCodeVersion": "$claude_version",
  "installedAt": "$installed_at",
  "nvmVersion": "0.39.7"
}
EOF

    chmod 644 "$lockfile"
    print_success "Lockfile saved: $lockfile"
    print_info "Commit this file to git for reproducibility"
}

#######################################
# Install from lockfile
#######################################
install_from_lockfile() {
    local lockfile="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"

    if [[ ! -f "$lockfile" ]]; then
        print_error "Lockfile not found: $lockfile"
        return 1
    fi

    print_info "Installing from lockfile..."

    # Parse lockfile (using grep/sed for portability)
    local node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$lockfile")
    local claude_version=$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$lockfile")

    print_info "Node.js version: $node_version"
    print_info "Claude Code version: $claude_version"

    # Install NVM if needed
    install_isolated_nvm

    # Install Node.js
    setup_isolated_nvm
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    nvm install "$node_version"
    nvm use "$node_version"

    # Install Claude Code with specific version
    npm install -g "@anthropic-ai/claude-code@$claude_version"

    print_success "Installation from lockfile complete"
}
```

### Шаблон 3: Cleanup изолированной установки

```bash
#######################################
# Cleanup isolated NVM installation
#######################################
cleanup_isolated_nvm() {
    local isolated_nvm_dir="${SCRIPT_DIR}/.nvm-isolated"

    if [[ ! -d "$isolated_nvm_dir" ]]; then
        print_info "No isolated installation found"
        return 0
    fi

    # Confirm cleanup
    echo ""
    print_warning "This will delete the isolated NVM installation:"
    echo "  Directory: $isolated_nvm_dir"
    echo "  Size: $(du -sh "$isolated_nvm_dir" 2>/dev/null | cut -f1)"
    echo ""
    read -p "Continue? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled"
        return 0
    fi

    # Remove directory
    rm -rf "$isolated_nvm_dir"

    print_success "Isolated installation removed"
    print_info "Lockfile preserved for reinstallation"
}
```

### Шаблон 4: Проверка изолированного окружения

```bash
#######################################
# Check isolated environment status
#######################################
check_isolated_status() {
    local isolated_nvm_dir="${SCRIPT_DIR}/.nvm-isolated"
    local lockfile="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Isolated Environment Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if isolated NVM exists
    if [[ -d "$isolated_nvm_dir" ]]; then
        print_success "Isolated NVM: INSTALLED"
        echo "  Location: $isolated_nvm_dir"
        echo "  Size: $(du -sh "$isolated_nvm_dir" 2>/dev/null | cut -f1)"

        # Check Node.js version
        setup_isolated_nvm
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

        if command -v node &>/dev/null; then
            echo "  Node.js: $(node --version)"
        fi

        if command -v claude &>/dev/null; then
            echo "  Claude Code: $(claude --version 2>/dev/null | head -n 1)"
        fi
    else
        print_warning "Isolated NVM: NOT INSTALLED"
    fi

    echo ""

    # Check if lockfile exists
    if [[ -f "$lockfile" ]]; then
        print_success "Lockfile: PRESENT"
        echo "  File: $lockfile"
        cat "$lockfile" | grep -E "(nodeVersion|claudeCodeVersion|installedAt)" | sed 's/^/  /'
    else
        print_warning "Lockfile: NOT FOUND"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
```

### Шаблон 5: Восстановление симлинков после git clone

```bash
#######################################
# Repair symlinks and permissions after git clone
# Returns:
#   0 - success (all symlinks repaired)
#   N - number of errors
#######################################
repair_isolated_environment() {
    local isolated_nvm_dir="${SCRIPT_DIR}/.nvm-isolated"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Repairing Isolated Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if isolated environment exists
    if [[ ! -d "$isolated_nvm_dir" ]]; then
        print_error "Isolated environment not found: $isolated_nvm_dir"
        echo "Run: ./init_claude.sh --isolated-install"
        return 1
    fi

    local errors=0
    local fixed=0

    # Find Node.js version directory
    local node_version_dir=$(find "$isolated_nvm_dir/versions/node" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)

    if [[ -z "$node_version_dir" ]]; then
        print_error "Node.js installation not found"
        return 1
    fi

    print_info "Node.js directory: $(basename "$node_version_dir")"
    echo ""

    # Check Node.js binary permissions
    local node_bin="$node_version_dir/bin/node"
    if [[ -f "$node_bin" ]]; then
        if [[ ! -x "$node_bin" ]]; then
            chmod +x "$node_bin"
            print_success "  ✓ Fixed: Made node binary executable"
            fixed=$((fixed + 1))
        else
            print_success "  ✓ OK: node binary is executable"
        fi
    else
        print_error "  ✗ MISSING: node binary not found"
        errors=$((errors + 1))
    fi

    # Symlinks to check/repair (path => target)
    declare -A symlinks=(
        ["$node_version_dir/bin/npm"]="../lib/node_modules/npm/bin/npm-cli.js"
        ["$node_version_dir/bin/npx"]="../lib/node_modules/npm/bin/npx-cli.js"
        ["$node_version_dir/bin/corepack"]="../lib/node_modules/corepack/dist/corepack.js"
    )

    echo ""
    print_info "Checking Node.js symlinks..."

    # Check and repair each symlink
    for link_path in "${!symlinks[@]}"; do
        local target="${symlinks[$link_path]}"
        local link_name=$(basename "$link_path")

        if [[ -L "$link_path" ]]; then
            # Symlink exists, verify target
            local current_target=$(readlink "$link_path")
            local target_full=$(dirname "$link_path")/$current_target

            if [[ "$current_target" == "$target" ]] && [[ -f "$target_full" ]]; then
                print_success "  ✓ OK: $link_name → $target"
            else
                # Wrong target or broken, recreate
                rm -f "$link_path"
                ln -s "$target" "$link_path"
                print_success "  ✓ Fixed: $link_name → $target"
                fixed=$((fixed + 1))
            fi
        elif [[ -e "$link_path" ]]; then
            # File exists but not a symlink, replace
            rm -f "$link_path"
            ln -s "$target" "$link_path"
            print_success "  ✓ Fixed: $link_name → $target (was a file)"
            fixed=$((fixed + 1))
        else
            # Missing, create
            ln -s "$target" "$link_path"
            print_success "  ✓ Created: $link_name → $target"
            fixed=$((fixed + 1))
        fi
    done

    # Check Claude Code symlink
    echo ""
    print_info "Checking Claude Code symlink..."

    local claude_link="$isolated_nvm_dir/npm-global/bin/claude"
    local claude_target="../lib/node_modules/@anthropic-ai/claude-code/cli.js"

    if [[ -L "$claude_link" ]]; then
        local current_target=$(readlink "$claude_link")
        local target_full=$(dirname "$claude_link")/$current_target

        if [[ "$current_target" == "$claude_target" ]] && [[ -f "$target_full" ]]; then
            print_success "  ✓ OK: claude → $claude_target"
        else
            rm -f "$claude_link"
            ln -s "$claude_target" "$claude_link"
            print_success "  ✓ Fixed: claude → $claude_target"
            fixed=$((fixed + 1))
        fi
    elif [[ -e "$claude_link" ]]; then
        rm -f "$claude_link"
        ln -s "$claude_target" "$claude_link"
        print_success "  ✓ Fixed: claude → $claude_target (was a file)"
        fixed=$((fixed + 1))
    else
        ln -s "$claude_target" "$claude_link"
        print_success "  ✓ Created: claude → $claude_target"
        fixed=$((fixed + 1))
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $errors -eq 0 ]]; then
        if [[ $fixed -gt 0 ]]; then
            print_success "Repair complete! Fixed $fixed issue(s)"
        else
            print_success "All checks passed! No repairs needed"
        fi
        echo ""
        print_info "Isolated environment is ready to use"
        return 0
    else
        print_error "Repair failed! $errors error(s) found"
        return $errors
    fi
}
```

**Использование:**
```bash
# After git clone - repair all symlinks
./init_claude.sh --repair-isolated

# Check symlink status first
./init_claude.sh --check-isolated
```

**Когда нужен repair:**
- ✅ После git clone репозитория с `.nvm-isolated/`
- ✅ После обновления через git pull
- ✅ После копирования директории между машинами
- ✅ При ошибках "command not found" для npm/claude
- ✅ Автоматически вызывается при `--update`

## Проверочный чеклист

После установки изолированного окружения проверь:

- [ ] Директория `.nvm-isolated/` создана в `${SCRIPT_DIR}`
- [ ] Node.js установлен и доступен через `node --version`
- [ ] npm установлен и доступен через `npm --version`
- [ ] Claude Code установлен и доступен через `claude --version`
- [ ] Lockfile `.nvm-isolated-lockfile.json` создан
- [ ] Все 4 симлинка работают (npm, npx, corepack, claude)
- [ ] `--check-isolated` показывает ✓ OK для всех симлинков
- [ ] `.gitignore` содержит `.nvm-isolated/` (если не коммитим) или настроен правильно
- [ ] Lockfile добавлен в git для воспроизводства
- [ ] `init_claude` запускается с использованием изолированной установки
- [ ] Системный NVM не затронут (если есть)
- [ ] После git clone `--repair-isolated` успешно восстанавливает симлинки (если коммитили)

## Связанные скилы

- **bash-development**: для добавления новых функций изоляции
- **proxy-management**: для работы с прокси в изолированном окружении

## Примеры использования

### Пример 1: Первая установка (с lockfile)

**Запрос:**
```
Установи init_claude с изолированным NVM. Сохрани lockfile для передачи через git.
```

**Claude использует isolated-environment skill:**

1. Создает `.nvm-isolated/` в директории проекта
2. Устанавливает NVM в изолированную директорию
3. Устанавливает Node.js 18 LTS
4. Устанавливает Claude Code
5. Создает `.nvm-isolated-lockfile.json`:
```json
{
  "nodeVersion": "18.19.0",
  "claudeCodeVersion": "1.2.3",
  "installedAt": "2025-10-22T19:30:00Z",
  "nvmVersion": "0.39.7"
}
```
6. Обновляет `.gitignore`:
```
.nvm-isolated/
.claude_proxy_credentials
```

### Пример 2: Установка на другой машине (из lockfile)

**Сценарий:** Разработчик клонировал репозиторий с lockfile

**Запрос:**
```
Установи init_claude из lockfile без системной установки
```

**Claude использует isolated-environment skill:**

1. Читает `.nvm-isolated-lockfile.json`
2. Устанавливает NVM в `.nvm-isolated/`
3. Устанавливает точную версию Node.js (18.19.0)
4. Устанавливает точную версию Claude Code (1.2.3)
5. Готово - init_claude работает без системной установки!

### Пример 3: Проверка статуса

**Запрос:**
```
Покажи статус изолированной установки init_claude
```

**Claude использует isolated-environment skill:**

Вывод:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Isolated Environment Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Isolated NVM: INSTALLED
  Location: /home/user/Documents/Project/claude/.nvm-isolated
  Size: 287M
  Node.js: v18.19.0
  Claude Code: 1.2.3

✓ Lockfile: PRESENT
  File: /home/user/Documents/Project/claude/.nvm-isolated-lockfile.json
  "nodeVersion": "18.19.0",
  "claudeCodeVersion": "1.2.3",
  "installedAt": "2025-10-22T19:30:00Z"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Пример 4: Cleanup

**Запрос:**
```
Удали изолированную установку init_claude, но сохрани lockfile
```

**Claude использует isolated-environment skill:**

1. Показывает размер директории (287M)
2. Запрашивает подтверждение
3. Удаляет `.nvm-isolated/`
4. Сохраняет `.nvm-isolated-lockfile.json` для переустановки

### Пример 5: Восстановление симлинков после git clone

**Сценарий:** Разработчик клонировал репозиторий с `.nvm-isolated/`, но симлинки не работают

**Запрос:**
```
Почему симлинки не работают после git clone?
```

**Claude использует isolated-environment skill:**

1. Объясняет проблему:
```
Git хранит symlinks как blob references (mode 120000), а не реальные symlinks.
После git clone они не восстанавливаются автоматически.
```

2. Проверяет статус:
```bash
./init_claude.sh --check-isolated

# Вывод:
Symlinks Status:
  ✗ npm (broken - target missing)
  ✗ npx (broken - target missing)
  ✗ corepack (missing)
  ✗ claude (missing)

Found 4 symlink issue(s)
Run: ./init_claude.sh --repair-isolated
```

3. Восстанавливает симлинки:
```bash
./init_claude.sh --repair-isolated

# Вывод:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Repairing Isolated Environment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Node.js directory: v18.20.8

  ✓ OK: node binary is executable

Checking Node.js symlinks...
  ✓ Fixed: npm → ../lib/node_modules/npm/bin/npm-cli.js
  ✓ Fixed: npx → ../lib/node_modules/npm/bin/npx-cli.js
  ✓ Created: corepack → ../lib/node_modules/corepack/dist/corepack.js

Checking Claude Code symlink...
  ✓ Created: claude → ../lib/node_modules/@anthropic-ai/claude-code/cli.js

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Repair complete! Fixed 4 issue(s)

Isolated environment is ready to use
```

4. Проверяет что все работает:
```bash
./init_claude.sh --check-isolated

# Все симлинки теперь ✓ OK
```

### Пример 6: Автоматический repair при обновлении

**Запрос:**
```
Обнови Claude Code в изолированном окружении
```

**Claude использует isolated-environment skill:**

1. Запускает обновление:
```bash
./init_claude.sh --update
```

2. После обновления автоматически:
   - Обновляет lockfile с новой версией
   - Вызывает `repair_isolated_environment()` для восстановления симлинков
   - Проверяет что все работает

3. Результат:
```
Updating Claude Code...
✓ Claude Code updated to 1.5.0

Updating lockfile...
✓ Lockfile saved

Repairing symlinks and permissions...
  ✓ OK: npm
  ✓ OK: npx
  ✓ OK: corepack
  ✓ OK: claude

✓ All checks passed! No repairs needed
```

## Часто задаваемые вопросы

**Q: Можно ли коммитить `.nvm-isolated/` в git?**

A: **Да, можно!** После недавних улучшений проект поддерживает коммит полного изолированного окружения.

**Вариант 1 (коммитим `.nvm-isolated/`):**
```bash
# .nvm-isolated/.gitignore настроен на исключение только cache/log файлов
# Коммитим полное окружение (~278MB)
git add .nvm-isolated/
git add .nvm-isolated-lockfile.json
git commit -m "Add isolated environment"
git push

# На другой машине после clone:
git clone <repo>
./init_claude.sh --repair-isolated  # Восстанавливаем симлинки
./init_claude.sh                     # Готово!
```

**Вариант 2 (только lockfile, легче для git):**
```bash
# .gitignore
.nvm-isolated/

# Коммитим только lockfile (~1KB)
git add .nvm-isolated-lockfile.json
git commit -m "Add isolated environment lockfile"

# На другой машине:
git clone <repo>
./init_claude.sh --install-from-lockfile  # Устанавливаем из lockfile
```

**Выбор варианта:**
- **Вариант 1**: Быстрее для других разработчиков (нет установки), но тяжелее для git
- **Вариант 2**: Легче для git, но требует установки на каждой машине

---

**Q: Почему симлинки не работают после git clone?**

A: **Git хранит symlinks как blob references (mode 120000), а не реальные symlinks.**

**Проблема:**
```bash
git clone <repo>
cd claude
./init_claude.sh
# Error: npm: command not found
# Error: claude: command not found
```

**Решение:**
```bash
# Проверить статус симлинков
./init_claude.sh --check-isolated

# Восстановить все симлинки
./init_claude.sh --repair-isolated

# Готово!
./init_claude.sh
```

**Что делает --repair-isolated:**
- ✅ Проверяет и восстанавливает 4 симлинка (npm, npx, corepack, claude)
- ✅ Исправляет permissions (chmod +x) для Node.js бинарника
- ✅ Показывает детальный статус (✓ OK / ✗ BROKEN)
- ✅ Безопасно (не удаляет данные, только восстанавливает симлинки)

**Автоматизация:**
Repair автоматически вызывается при `--update`, поэтому симлинки всегда актуальны.

**Windows:**
На Windows может потребоваться включить поддержку symlinks в git:
```bash
git config --global core.symlinks true
```

---

**Q: Как передать установку другому разработчику?**

A: **Вариант 1 (рекомендуется):** Через lockfile

```bash
# Разработчик 1 (создает lockfile)
init_claude --isolated-install
git add .nvm-isolated-lockfile.json
git push

# Разработчик 2 (устанавливает из lockfile)
git pull
init_claude --install-from-lockfile
```

**Вариант 2:** Прямая передача (ZIP архив)

```bash
# Создать архив (без git)
tar -czf init_claude-isolated.tar.gz .nvm-isolated/ init_claude.sh

# Передать через любой способ (email, cloud)
# На другой машине:
tar -xzf init_claude-isolated.tar.gz
./init_claude.sh
```

---

**Q: Какой размер занимает изолированная установка?**

A:
- **NVM:** ~10 MB
- **Node.js 18:** ~50 MB
- **Claude Code + dependencies:** ~150-200 MB
- **Итого:** ~200-300 MB

**Оптимизация:**
```bash
# Очистить npm cache в изолированном окружении
setup_isolated_nvm
npm cache clean --force
```

---

**Q: Как обновить Claude Code в изолированном окружении?**

A:
```bash
# Обновить до latest
init_claude --isolated-update

# Или вручную
setup_isolated_nvm
source "$NVM_DIR/nvm.sh"
npm update -g @anthropic-ai/claude-code

# Обновить lockfile
save_isolated_lockfile
git add .nvm-isolated-lockfile.json
git commit -m "Update Claude Code to X.Y.Z"
```

---

**Q: Что если у меня уже есть системный NVM?**

A: **Изолированная установка не конфликтует!**

```bash
# Системный NVM
export NVM_DIR="$HOME/.nvm"
nvm use 20  # Используется Node 20

# init_claude использует изолированный NVM
export NVM_DIR="/path/to/project/.nvm-isolated"
nvm use 18  # Используется Node 18

# Они полностью независимы
```

---

**Q: Можно ли использовать разные версии в разных проектах?**

A: **Да!** Каждый проект имеет свой `.nvm-isolated/`

```
project-A/
├── .nvm-isolated/  # Node 18 + Claude 1.2.3
└── init_claude.sh

project-B/
├── .nvm-isolated/  # Node 20 + Claude 1.5.0
└── init_claude.sh
```

---

**Q: Безопасно ли хранить lockfile в публичном репозитории?**

A: **Да, безопасно**. Lockfile содержит только:
- Версии Node.js и Claude Code
- Дату установки

**НЕ содержит:**
- Credentials
- Tokens
- Приватные данные

**Не путайте** с `.claude_proxy_credentials` (который в .gitignore)!

---

**Q: Как работает изоляция запуска Claude?**

A: **Изоляция запуска НЕ используется** (по дизайну).

**Что изолировано:**
- ✅ Установка npm пакетов (в `.nvm-isolated/`)
- ✅ Версии Node.js
- ✅ Глобальные npm пакеты

**Что НЕ изолировано:**
- ❌ Запуск Claude Code (полный доступ к системе)
- ❌ Проекты (Claude нужен доступ к файлам)
- ❌ Git (Claude использует system git)
- ❌ Сеть (Claude подключается к api.anthropic.com)

**Причина:** Claude Code требует полный доступ для работы с проектами, git, bash командами.
