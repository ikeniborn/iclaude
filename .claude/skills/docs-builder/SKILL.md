---
name: docs-builder
description: Build and update Sphinx documentation site with llms.txt for AI agents. Integrates with architecture-documentation and prd-generator.
user-invocable: true
context: fork
---
<!-- version: 2.0.0 | tags: documentation, sphinx, llms.txt, ai-agents, api-reference, bash-parser | dependencies: iclaude-architecture | author: iclaude Skills Team -->

# docs-builder Skill

Генерирует и обновляет Sphinx документацию для любого проекта с AI-первым подходом через `llms.txt`.

## Назначение

- **Per-project Sphinx** — работает в любом проекте (не только iclaude)
- **Изолированная поддиректория** — `docs/sphinx/` (не захламляет `docs/`)
- **API Reference** — автоматически извлекает bash функции из `lib/**/*.sh`
- **llms.txt** — создаёт файл для AI-агентов (индекс документации)
- **Интеграция** — принимает вывод `architecture-documentation` и `prd-generator`

## Когда использовать

**Manual invocation:**
```
/docs-builder
@skill:docs-builder
```

**Auto-invocation triggers:**
- После вызова `@skill:architecture-documentation` — документация обновлена
- После вызова `@skill:prd-generator` — новый PRD создан
- После изменений в `lib/**/*.sh` — функции обновлены
- "Собери документацию", "Обнови llms.txt", "Rebuild docs"

## Workflow (4 фазы)

### Phase 0: Init (первый раз)

```bash
# Инициализировать Sphinx в docs/sphinx/ (один раз на проект)
./iclaude.sh --init-docs                     # текущий проект (CWD)
./iclaude.sh --init-docs /path/to/project    # другой проект
```

Создаёт:
- `docs/sphinx/conf.py` — настройки Sphinx (с типом проекта)
- `docs/sphinx/index.md` — корневой toctree (ссылки через `../` на `docs/*.md`)
- Добавляет `docs/sphinx/_build/` в `.gitignore`

### Phase 1: Check & Install

1. Проверить наличие Sphinx: `./iclaude.sh --check-docs`
2. Если не установлен: `./iclaude.sh --install-docs`
3. Проверить `docs/sphinx/conf.py` и `docs/sphinx/index.md`

### Phase 2: Generate API Reference

Вызвать bash-парсер через iclaude.sh или напрямую:

```bash
# Через модуль (если lib/docs/ загружен)
generate_api_reference lib/ docs/sphinx/api-reference/
```

Парсер обрабатывает `#######...#######` комментарии из `lib/**/*.sh`:
```bash
#######################################
# Function description
# Arguments:
#   $1 - description
# Returns:
#   0 - success
# Example: func_name arg
#######################################
```

Выходные файлы: `docs/sphinx/api-reference/<module>/<file>.md`

### Phase 3: Build Sphinx

```bash
./iclaude.sh --build-docs                    # текущий проект
./iclaude.sh --build-docs /path/to/project   # другой проект
```

**Результат:**
- `docs/sphinx/_build/html/index.html` — HTML сайт
- `docs/sphinx/_build/html/llms.txt` — индекс для AI агентов
- `docs/sphinx/_build/html/llms-full.txt` — полный контент для LLM

## Интеграция с другими навыками

### После @skill:architecture-documentation

```yaml
# Шаг 5 в architecture-documentation workflow:
post_generation:
  - if: docs/sphinx/conf.py exists
    action: "@skill:docs-builder rebuild"
    output: "docs/sphinx/_build/html/llms.txt updated"
```

Когда architecture-documentation генерирует новый `docs/architecture/overview.yaml`:
1. docs-builder автоматически включает его в Sphinx build
2. Mermaid диаграммы рендерятся в HTML
3. llms.txt обновляется с новой архитектурой

### После @skill:prd-generator

```yaml
# Шаг 8 в prd-generator workflow:
post_generation:
  - if: docs/prd/ created
    action: "@skill:docs-builder add-prd"
    output: "PRD included in Sphinx documentation"
```

Когда prd-generator создаёт `docs/prd/`:
1. docs-builder добавляет `../prd/` в `docs/sphinx/index.md` toctree
2. Перестраивает Sphinx с PRD разделом
3. llms.txt включает PRD в индекс

## Добавление PRD в документацию

При получении сигнала от prd-generator, выполнить:

1. Добавить в `docs/sphinx/index.md`:
```markdown
``{toctree}
:maxdepth: 1
:caption: Product Requirements

../prd/README
``
```

2. Собрать: `./iclaude.sh --build-docs`

## Добавление архитектурного раздела

При получении нового YAML от architecture-documentation:

1. Файл автоматически включён через `../architecture/README` в toctree
2. Если новый файл — добавить в `docs/sphinx/index.md`
3. Пересобрать: `./iclaude.sh --build-docs`

## Команды

```bash
# Инициализация Sphinx в проекте
./iclaude.sh --init-docs                     # текущий проект (CWD)
./iclaude.sh --init-docs /path/to/project    # другой проект

# Установка Sphinx (глобально, один раз)
./iclaude.sh --install-docs

# Статус
./iclaude.sh --check-docs                    # текущий проект
./iclaude.sh --check-docs /path/to/project   # другой проект

# Сборка документации
./iclaude.sh --build-docs                    # текущий проект
./iclaude.sh --build-docs /path/to/project   # другой проект

# Сборка с очисткой кэша
./iclaude.sh --build-docs $(pwd) --clean

# Просмотр в браузере (localhost:8000)
./iclaude.sh --serve-docs                    # текущий проект
./iclaude.sh --serve-docs /path/to/project 9000  # другой проект + порт
```

## Структура вывода

```
<любой-проект>/
└── docs/
    ├── README.md            ← существующая документация (без изменений)
    ├── STATUSLINE.md        ←    "          "
    ├── ...
    └── sphinx/              ← ВСЁ Sphinx-специфичное здесь
        ├── conf.py          ← генерируется --init-docs
        ├── index.md         ← корневой toctree (ссылается через ../  на docs/*.md)
        ├── api-reference/   ← автогенерация из lib/*.sh (bash-проекты)
        │   ├── index.md
        │   ├── proxy/validate.md
        │   ├── nvm/detect.md
        │   └── ...
        └── _build/
            └── html/
                ├── index.html         ← Главная страница
                ├── llms.txt           ← Индекс для AI (краткий)
                └── llms-full.txt      ← Полный контент для LLM
```

## llms.txt формат

AI агенты используют `llms.txt` для навигации:

```
# iclaude Documentation

> Bash wrapper for Claude Code with proxy, isolated env, AI agents

## Getting Started
- [Installation](installation.md): Install isolated environment
- [Configuration](configuration.md): Proxy and environment setup

## API Reference
- [lib/proxy](api-reference/proxy/index.md): Proxy management functions
- [lib/nvm](api-reference/nvm/index.md): NVM/Node.js detection
```

Агент может прочитать `llms.txt` (малый размер) вместо всех документов,
экономя значительное количество токенов при навигации по документации.

## Python venv (глобальный)

Один venv для всех проектов (~50MB):
- С isolated env: `$ISOLATED_NVM_DIR/.python-docs/`
- Без isolated env: `$HOME/.local/share/sphinx-docs/`

Установить один раз: `./iclaude.sh --install-docs`
