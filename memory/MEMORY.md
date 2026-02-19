# Project Memory: iclaude sphinx branch

## Sphinx Integration (добавлено 2026-02-19)

### Что реализовано
- **lib/docs/** — модуль Phase 16 (install, build, serve, bash-parser, status)
- **docs/conf.py** — Sphinx + MyST + Furo + sphinx-llms-txt конфигурация
- **docs/index.md** — корневой toctree для всех 31 документов
- **Новые флаги:** `--install-docs`, `--build-docs`, `--serve-docs`, `--check-docs`
- **Навык:** `.claude/skills/docs-builder/` (интегрирован в architecture-documentation и prd-generator)

### Python venv
- Путь: `.nvm-isolated/.python-docs/` (в .gitignore)
- Установка: `./iclaude.sh --install-docs`
- Требует: `python3`, `python3-venv`

### llms.txt для AI агентов
- Генерируется при `./iclaude.sh --build-docs` (если sphinx-llms-txt установлен)
- Путь: `docs/_build/html/llms.txt`
- AI агенты читают его вместо навигации по 31 документу

### Интеграция навыков
- `architecture-documentation` v1.4.0 → после генерации YAML триггерит docs-builder
- `prd-generator` v1.3.0 → после создания PRD триггерит docs-builder

### Bash-парсер
- `lib/docs/bash-parser.sh` — парсит `#######` блоки из lib/*.sh
- Генерирует `docs/api-reference/<module>/<file>.md`
- Функция: `generate_api_reference lib/ docs/api-reference/`
