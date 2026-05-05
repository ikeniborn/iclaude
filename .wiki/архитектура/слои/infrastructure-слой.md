---
wiki_sources:
  - "docs/architecture/overview.yaml"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - iclaude
aliases:
  - "Infrastructure Layer"
  - "Слой инфраструктуры"
---

# Infrastructure-слой (Слой инфраструктуры)

Нижний слой архитектуры iclaude, предоставляющий низкоуровневые утилиты: хранение учётных данных, конфигурацию git-прокси, файловые операции и форматирование вывода.

## Основные характеристики

**Ответственности:**
- Безопасное хранение учётных данных прокси (chmod 600)
- Управление настройками git-прокси (backup + restore)
- Файловые операции (чтение, запись)
- Валидация зависимостей (curl, git, jq)
- Форматированный вывод сообщений (цвета)

**Компоненты слоя:**

| Компонент | Строки | Назначение |
|-----------|--------|-----------|
| `credential-storage` | 1587–1745 | Хранение прокси-credentials (chmod 600) |
| `git-proxy-config` | 1875–1938 | Настройка git-прокси с backup/restore |
| `file-operations` | — | Файловые утилиты |
| `jq-validator` | 3185–3198 | Проверка наличия jq |
| `dependency-checker` | 2699–2802 | Проверка curl, git, jq |
| `output-formatters` | 41–55 | `print_info`, `print_success`, `print_warning`, `print_error` |

## Связанные концепции

- [[core-слой]]
- [[защита-данных-доступа]]
