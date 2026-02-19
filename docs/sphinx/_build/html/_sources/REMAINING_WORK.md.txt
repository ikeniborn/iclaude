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
6. Phase 9.5: Update
7. Phase 9.6: Launcher ← **Финальная фаза**

### Вариант 2: По приоритету (быстрее к цели)
1. Phase 7: Router ⭐⭐⭐
2. Phase 9.5: Update ⭐⭐⭐
3. Phase 9.6: Launcher ⭐⭐⭐ ← **Финальная фаза**
4. Phase 8.1: LSP ⭐⭐
5. Phase 9.1: Sandbox ⭐⭐
6. Phase 8.2: Statusline ⭐
7. Phase 8.3: Oh-My-Posh ⭐

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
