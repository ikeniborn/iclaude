---
name: docs-builder
description: Build and update Sphinx documentation site with llms.txt for AI agents. Integrates with architecture-documentation and prd-generator.
user-invocable: true
context: fork
---
<!-- version: 1.0.0 | tags: documentation, sphinx, llms.txt, ai-agents, api-reference, bash-parser | dependencies: iclaude-architecture | author: iclaude Skills Team -->

# docs-builder Skill

Генерирует и обновляет Sphinx документацию проекта iclaude с AI-первым подходом через `llms.txt`.

## Назначение

- **Sphinx сборка** — генерирует HTML сайт из `docs/` + `lib/*.sh` комментариев
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

## Workflow (3 фазы)

### Phase 1: Check & Install

1. Проверить наличие Sphinx: `./iclaude.sh --check-docs`
2. Если не установлен: `./iclaude.sh --install-docs`
3. Проверить `docs/conf.py` и `docs/index.md`

### Phase 2: Generate API Reference

Вызвать bash-парсер через iclaude.sh или напрямую:

```bash
# Через модуль (если lib/docs/ загружен)
generate_api_reference lib/ docs/api-reference/
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

Выходные файлы: `docs/api-reference/<module>/<file>.md`

### Phase 3: Build Sphinx

```bash
./iclaude.sh --build-docs
```

**Результат:**
- `docs/_build/html/index.html` — HTML сайт
- `docs/_build/html/llms.txt` — индекс для AI агентов
- `docs/_build/html/llms-full.txt` — полный контент для LLM

## Интеграция с другими навыками

### После @skill:architecture-documentation

```yaml
# Шаг 5 в architecture-documentation workflow:
post_generation:
  - if: docs/conf.py exists
    action: "@skill:docs-builder rebuild"
    output: "docs/_build/html/llms.txt updated"
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
1. docs-builder добавляет `prd/` в `docs/index.md` toctree
2. Перестраивает Sphinx с PRD разделом
3. llms.txt включает PRD в индекс

## Добавление PRD в документацию

При получении сигнала от prd-generator, выполнить:

1. Добавить в `docs/index.md`:
```markdown
``{toctree}
:maxdepth: 1
:caption: Product Requirements

prd/README
``
```

2. Собрать: `./iclaude.sh --build-docs`

## Добавление архитектурного раздела

При получении нового YAML от architecture-documentation:

1. Файл автоматически включён через `architecture/README` в toctree
2. Если новый файл — добавить в `docs/index.md`
3. Пересобрать: `./iclaude.sh --build-docs`

## Команды

```bash
# Установка Sphinx
./iclaude.sh --install-docs

# Сборка документации
./iclaude.sh --build-docs

# Сборка с очисткой кэша
./iclaude.sh --build-docs --clean

# Просмотр в браузере (localhost:8000)
./iclaude.sh --serve-docs

# Статус
./iclaude.sh --check-docs
```

## Структура вывода

```
docs/
├── conf.py                    # Sphinx конфигурация
├── index.md                   # Корневой toctree
├── api-reference/             # Автогенерация из lib/*.sh
│   ├── index.md
│   ├── proxy/validate.md
│   ├── nvm/detect.md
│   └── ...
└── _build/
    └── html/
        ├── index.html         # Главная страница
        ├── llms.txt           # Индекс для AI (краткий)
        └── llms-full.txt      # Полный контент для LLM
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

Агент может прочитать `llms.txt` (малый размер) вместо всех 31 документов,
экономя значительное количество токенов при навигации по документации.
