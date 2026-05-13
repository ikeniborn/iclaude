---
wiki_sources:
  - "docs/functions/CONFIGURATION.md"
  - "docs/functions/QUICK_CONFIG.md"
  - "docs/functions/MICROVM.md"
  - "docs/functions/PII_MASKING.md"
wiki_updated: 2026-05-08
wiki_status: developing
wiki_outgoing_links:
  - "[[прокси|Прокси]]"
  - "[[microvm-firecracker|microVM Firecracker]]"
  - "[[pii-прокси|PII-прокси]]"
  - "[[маршрутизатор-ccr|Claude Code Router]]"
wiki_external_links: []
tags:
  - iclaude
  - documentation
aliases:
  - ".claude_config"
  - "claude_proxy_credentials"
  - "конфигурационный файл"
  - "env vars"
---

# Конфигурационный файл (.claude_config)

Основной файл конфигурации iclaude. Хранится в корне проекта, chmod 600, никогда не коммитится в git. Содержит переменные окружения, которые загружаются при каждом запуске `./iclaude.sh`.

## Основные характеристики

### Ключевые группы переменных

**Прокси:**

| Переменная | Описание |
|------------|----------|
| `PROXY_URL` | URL прокси-сервера |
| `PROXY_INSECURE` | Отключить проверку TLS (`false`) |
| `NO_PROXY` | Список исключений |

**Claude Code:**

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 32000 | Лимит output токенов (макс: 128000) |
| `CLAUDE_CODE_ENABLE_TASKS` | `true` | Tasks system |
| `CLAUDE_CODE_NO_CHROME` | `false` | Отключить Chrome integration |
| `CLAUDE_CODE_MODEL` | — | Выбор модели |

**microVM:**

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `MICRO_VM_ENABLED` | `false` | Автоматически использовать microVM |
| `MICRO_VM_MEM_MB` | `2048` | RAM guest VM в МБ |
| `MICRO_VM_VCPU` | `2` | vCPU |
| `MICRO_VM_WORKSPACE_MODE` | `full` | `full` или `isolated` |
| `MICRO_VM_WORKSPACE_PATH` | — | Путь к проекту (по умолчанию `$PWD`) |
| `MICRO_VM_WORKSPACE_SIZE_MB` | `2048` | Размер workspace-диска (vdc, sparse) |
| `MICRO_VM_ROOTFS_SIZE_MB` | `2048` | Размер rootfs-образа (vda) с авто-расширением |
| `MICRO_VM_NET_ENABLED` | `true` | TAP-сеть |
| `MICRO_VM_NET_SUBNET` | `172.16.0.0/26` | Подсеть IP-пула слотов |
| `MICRO_VM_SYNC_INTERVAL` | `0` | Периодический sync guest→host (секунды) |
| `MICRO_VM_SYNC_EXCLUDE` | — | Дополнительные паттерны исключений |
| `MICRO_VM_SNAPSHOT_ENABLED` | `false` | Именованные снэпшоты |
| `MICRO_VM_SNAPSHOT_DIR` | `microvm-snapshots/` | Каталог снэпшотов |
| `MICRO_VM_INSECURE_DOWNLOAD` | `false` | TLS workaround для ALT Linux 10 при `--install-microvm` |

**PII proxy:**

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `USE_PII_PROXY` | `false` | Автоматически включать PII proxy |
| `PII_PROXY_MASKING_LEVEL` | `standard` | `off` / `secrets` / `standard` |
| `PII_PROXY_LOG_LEVEL` | `info` | `info` или `debug` |
| `PII_PROXY_PORT` | `0` (авто) | Фиксированный порт |

**Router:**

| Переменная | Описание |
|------------|----------|
| `DEEPSEEK_API_KEY` | API ключ DeepSeek (`export DEEPSEEK_API_KEY=...`) |
| `OPENROUTER_API_KEY` | API ключ OpenRouter |

### Важные правила

- Только **раскомментированные** переменные экспортируются. Закомментированные (`#`) игнорируются.
- Файл должен быть chmod 600 и находится в `.gitignore`.
- Шаблон: `.claude_config.example` (безопасен для коммита).

### Пример файла

```bash
# Proxy settings
PROXY_URL=https://[CREDENTIALS]@proxy.example.com:8118
NO_PROXY=localhost,127.0.0.1

# Claude Code configuration
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# Router API keys (экспортировать для CCR)
export DEEPSEEK_API_KEY=sk-...
```

## Иерархия settings.json

| Приоритет | Файл | В git |
|-----------|------|:-----:|
| Высокий | `.claude/settings.local.json` | Нет |
| Средний | `.claude/settings.json` | Да |
| Низкий | `.nvm-isolated/.claude-isolated/settings.json` | Да |

`plansDirectory` (хранение планов) задаётся в `settings.json`. Текущее значение: `"docs/plans"`.
