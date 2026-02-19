# Оставшаяся работа по модуляризации iclaude.sh

**Дата анализа:** 2026-02-12
**Текущая ветка:** `refactor/phase-7-router-module`

---

## Текущий статус (Phase 0-7 завершены ✅)

**Выполнено:**
- ✅ **23 модуля** создано
- ✅ **58 функций** извлечено
- ✅ **3,529 строк** модулизировано (43.1% кодовой базы)
- ✅ **Zero breaking changes** - все тесты проходят

**Осталось:**
- ⏳ **108 функций**
- ⏳ **~4,666 строк** (56.9% кодовой базы)
- ⏳ **~25 модулей** для создания

---

## ~~Phase 7: Router Module~~ ✅ ЗАВЕРШЕНА

**Статус:** ✅ COMPLETE (2026-02-12)

**Создано:**
- `lib/router/detect.sh` - detect_router(), get_router_path()
- `lib/router/install.sh` - install_isolated_router()
- `lib/router/status.sh` - check_router_status()

**Результаты:**
- 3 модуля, 4 функции, ~228 строк извлечено
- 4 guards добавлено в iclaude-legacy.sh
- iclaude.sh v2.3 → v2.4
- Тесты: 4/4 функций из модулей ✓

**Документация:** `docs/phase7-summary.md`

---

## Phase 8: Feature Modules 🎨 (17 функций, ~530 строк)

### 8.1: LSP Module (3 функции, ~200 строк)

**Приоритет:** ⭐⭐ MEDIUM

**Модули:**
- `lib/lsp/install.sh` - LSP server/plugin installation
- `lib/lsp/repair.sh` - Plugin path repair
- `lib/lsp/status.sh` - LSP status checking

**Функции:**
1. `install_isolated_lsp_servers()` - Установка LSP servers (pyright, vtsls, etc.)
2. `repair_plugin_paths()` - Исправление путей плагинов после обновлений
3. `check_lsp_status()` - Статус LSP серверов и плагинов

**Сложность:** 🟡 Средняя

### 8.2: Statusline Module (4 функции, ~150 строк)

**Приоритет:** ⭐ LOW

**Модули:**
- `lib/statusline/detect.sh` - Statusline detection
- `lib/statusline/install.sh` - Statusline script installation
- `lib/statusline/status.sh` - Statusline status

**Функции:**
1. `detect_statusline()` - Проверка конфигурации statusline
2. `configure_statusline_in_settings()` - Настройка в settings.json
3. `install_statusline_script()` - Установка claude-statusline.sh
4. `check_statusline_status()` - Статус statusline

**Сложность:** 🟢 Низкая

### 8.3: Oh-My-Posh Module (5 функций, ~180 строк)

**Приоритет:** ⭐ LOW

**Модули:**
- `lib/ohmyposh/detect.sh` - Oh-My-Posh detection
- `lib/ohmyposh/install.sh` - Oh-My-Posh installation
- `lib/ohmyposh/status.sh` - Oh-My-Posh status

**Функции:**
1. `detect_ohmyposh_platform()` - Определение платформы (Linux/macOS)
2. `get_ohmyposh_path()` - Поиск oh-my-posh binary
3. `detect_ohmyposh()` - Проверка установки
4. `install_isolated_ohmyposh()` - Установка oh-my-posh
5. `check_ohmyposh_status()` - Статус oh-my-posh (версия, платформа)

**Сложность:** 🟢 Низкая

---

## Phase 9: Advanced Modules 🚀 (47+ функций, ~2,000 строк)

### 9.1: Sandbox Module (5 функций, ~200 строк)

**Приоритет:** ⭐⭐ MEDIUM

**Модули:**
- `lib/sandbox/detect.sh` - Sandbox platform detection
- `lib/sandbox/install.sh` - Sandbox dependencies installation
- `lib/sandbox/status.sh` - Sandbox status checking

**Функции:**
1. `detect_sandbox_platform()` - Определение платформы (Linux/WSL2/macOS)
2. `check_sandbox_dependencies()` - Проверка bubblewrap, socat
3. `install_sandbox_dependencies()` - Установка зависимостей
4. `get_sandbox_runtime_version()` - Версия sandbox-runtime
5. `check_sandbox_status()` - Статус sandbox (platform, deps, runtime)

**Сложность:** 🟡 Средняя

### 9.2: GH CLI Module (2 функции, ~100 строк)

**Приоритет:** ⭐⭐ MEDIUM

**Модули:**
- `lib/gh/install.sh` - GH CLI installation
- `lib/gh/status.sh` - GH CLI status

**Функции:**
1. `install_isolated_gh()` - Установка gh CLI в isolated environment
2. `check_gh_status()` - Статус gh CLI (версия, auth)

**Сложность:** 🟢 Низкая

### 9.3: Loop Mode Module (11 функций, ~400 строк)

**Приоритет:** ⭐ LOW (экспериментальная фича)

**Модули:**
- `lib/loop/parser.sh` - Task file parsing (Markdown → structured data)
- `lib/loop/execution.sh` - Task execution with retry logic
- `lib/loop/state.sh` - State management (save/load)

**Функции:**
1. `load_markdown_task()` - Парсинг task.md (Description, Completion Promise, etc.)
2. `validate_task_file_format()` - Валидация формата task file
3. `load_all_tasks()` - Загрузка всех задач из task file
4. `invoke_claude_iteration()` - Вызов Claude Code с задачей
5. `verify_completion_promise()` - Проверка completion promise (validation command)
6. `retry_task_with_backoff()` - Retry логика с exponential backoff (2s, 4s, 8s, ...)
7. `execute_single_iteration()` - Выполнение одной итерации
8. `git_commit_task_changes()` - Git commit после успешной задачи
9. `save_loop_state()` - Сохранение состояния (iteration count, last result)
10. `load_loop_state()` - Загрузка состояния
11. `execute_task_with_retry()` - Полный цикл с retry и git commit

**Сложность:** 🔴 Высокая

### 9.4: Context Module (21 функция, ~600 строк)

**Приоритет:** ⭐ LOW (экспериментальная фича)

**Модули:**
- `lib/context/directories.sh` - Context directory management
- `lib/context/worktree.sh` - Git worktree operations (для параллельных задач)
- `lib/context/commands.sh` - Context commands (export/import/sync/clean/backup)
- `lib/context/memory.sh` - Context memory operations (init/validate/organize/add)

**Функции для worktree (5):**
1. `create_task_worktree()` - Создание git worktree для параллельной задачи
2. `cleanup_worktree()` - Очистка worktree после завершения
3. `merge_worktree_changes()` - Merge изменений из worktree в main
4. `is_context_worktree()` - Проверка является ли текущая директория worktree
5. `get_context_main_worktree()` - Поиск main worktree

**Функции для directories (5):**
6. `init_context_directories()` - Инициализация context директорий
7. `get_context_project_name()` - Получение имени проекта
8. `get_context_project_hash()` - Hash проекта для идентификации
9. `get_context_project_memory_dir()` - Project-specific memory directory
10. `get_context_shared_memory_dir()` - Shared memory directory

**Функции для commands (6):**
11. `context_cmd_export()` - Экспорт контекста в tar.gz
12. `context_cmd_import()` - Импорт контекста из tar.gz
13. `context_cmd_sync()` - Синхронизация контекста между worktrees
14. `context_cmd_clean()` - Очистка старого контекста
15. `context_cmd_backup()` - Backup контекста
16. `context_cmd_status()` - Статус контекста (размер, файлы, worktrees)

**Функции для memory (5):**
17. `context_memory_init()` - Инициализация memory system
18. `context_memory_validate()` - Валидация memory структуры
19. `context_memory_organize()` - Организация memory (архивация старых данных)
20. `context_memory_add()` - Добавление entry в memory
21. `context_memory_status()` - Статус memory (размер, количество entries)

**Сложность:** 🔴 Высокая

### 9.5: Update Module (4 функции, ~200 строк)

**Приоритет:** ⭐⭐⭐ HIGH

**Модули:**
- `lib/update/claude.sh` - Claude Code updates (isolated environment)
- `lib/update/check.sh` - Update checking

**Функции:**
1. `update_isolated_claude()` - Обновление Claude в isolated env (npm update)
2. `check_update()` - Проверка доступных обновлений
3. `update_claude_code()` - Обновление Claude Code (system-wide)
4. `cleanup_old_claude_installations()` - Очистка .claude-code-* folders

**Зависимости:**
- Используется в `lib/nvm/claude.sh` (уже извлечена в Phase 3)
- Связана с `lib/lockfile/save.sh` (обновление lockfile после update)

**Сложность:** 🟡 Средняя

### 9.6: Launcher Module (3 функции, ~400 строк)

**Приоритет:** ⭐⭐⭐ HIGH (критическая функциональность)

**Модули:**
- `lib/launcher/launch.sh` - Claude Code launching logic
- `lib/launcher/main.sh` - Main entry point и argument parsing

**Функции:**
1. `launch_claude()` - Запуск Claude Code с proxy/router/chrome настройками
2. `main()` - Главная функция (парсинг --flags, orchestration всех модулей)
3. `show_usage()` - Показ help/usage (--help flag)

**Зависимости:**
- Вызывает ВСЕ модули (proxy, nvm, config, oauth, etc.)
- Центральная точка orchestration

**Сложность:** 🟡 Средняя (много интеграций)

**Примечание:** `main()` - последняя функция для извлечения, после неё iclaude-legacy.sh можно удалить!

---

## Итоговая таблица оценки

| Phase | Модули | Функции | Строки | Приоритет | Сложность |
|-------|---------|---------|--------|-----------|-----------|
| **Phase 7: Router** | 3 | 4 | ~150 | ⭐⭐⭐ HIGH | 🟢 Низкая |
| **Phase 8.1: LSP** | 3 | 3 | ~200 | ⭐⭐ MEDIUM | 🟡 Средняя |
| **Phase 8.2: Statusline** | 3 | 4 | ~150 | ⭐ LOW | 🟢 Низкая |
| **Phase 8.3: Oh-My-Posh** | 3 | 5 | ~180 | ⭐ LOW | 🟢 Низкая |
| **Phase 9.1: Sandbox** | 3 | 5 | ~200 | ⭐⭐ MEDIUM | 🟡 Средняя |
| **Phase 9.2: GH CLI** | 2 | 2 | ~100 | ⭐⭐ MEDIUM | 🟢 Низкая |
| **Phase 9.3: Loop Mode** | 3 | 11 | ~400 | ⭐ LOW | 🔴 Высокая |
| **Phase 9.4: Context** | 4 | 21 | ~600 | ⭐ LOW | 🔴 Высокая |
| **Phase 9.5: Update** | 2 | 4 | ~200 | ⭐⭐⭐ HIGH | 🟡 Средняя |
| **Phase 9.6: Launcher** | 2 | 3 | ~400 | ⭐⭐⭐ HIGH | 🟡 Средняя |
| **TOTAL** | **28** | **62** | **~2,580** | | |

**Примечание:** Оценки строк ±20% от реальных значений.

---

## Рекомендуемый порядок выполнения

### Вариант 1: Последовательный (рекомендуется для полноты)
1. Phase 7: Router
2. Phase 8.1: LSP
3. Phase 8.2: Statusline
4. Phase 8.3: Oh-My-Posh
5. Phase 9.1: Sandbox
6. Phase 9.2: GH CLI
7. Phase 9.5: Update
8. Phase 9.6: Launcher ← **Финальная фаза**
9. Phase 9.3: Loop Mode (опционально)
10. Phase 9.4: Context (опционально)

### Вариант 2: По приоритету (быстрее к цели)
1. Phase 7: Router ⭐⭐⭐
2. Phase 9.5: Update ⭐⭐⭐
3. Phase 9.6: Launcher ⭐⭐⭐ ← **Финальная фаза**
4. Phase 8.1: LSP ⭐⭐
5. Phase 9.1: Sandbox ⭐⭐
6. Phase 9.2: GH CLI ⭐⭐
7. Phase 8.2: Statusline ⭐
8. Phase 8.3: Oh-My-Posh ⭐
9. Phase 9.3-9.4: Loop/Context (опционально)

---

## Следующие шаги

**Immediate next (прямо сейчас):**
```bash
git checkout -b refactor/phase-7-router-module
# Создать lib/router/*.sh
# Извлечь 4 router функции
# Добавить guards в legacy
# Протестировать
# Commit и merge
```

**После Phase 7:**
- Продолжить с Phase 8 (LSP, Statusline, Oh-My-Posh)
- Или перейти к Phase 9.5-9.6 (Update, Launcher) для более быстрого завершения

**Финальная цель:**
- 48 модулей total (20 done + 28 remaining)
- 116 функций extracted (54 done + 62 remaining)
- 100% modularized codebase
- Delete iclaude-legacy.sh ✅

---

## Прогресс-бар

```
Phase 0-7: █████████████████░░░░░░░ 43.1% complete
           [====== 23 modules ======]

Phase 8-9: ░░░░░░░░░░░░░░░░░░░░░░░░ 56.9% remaining
           [=== 25 modules to go ===]

Total:     █████████████████░░░░░░░ 43.1% → 100%
```

**Estimated completion:** ~6-9 фаз (Phase 8 через Phase 9.6)

---

**Последнее обновление:** 2026-02-12
**Автор анализа:** Claude Sonnet 4.5
**Статус:** Phase 0-7 complete ✅, Phase 8+ pending ⏳
