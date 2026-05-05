# Wiki Log

<!-- Append-only лог. Новые записи добавляются в конец. -->

## 2026-05-05T00:00:00

**Операция:** init
**Домен:** архитектура

**Затронуто страниц:** 15

- СОЗДАНА: `.wiki/.config/domain-map.json` — конфигурация домена архитектура
- СОЗДАНА: `.wiki/архитектура/компоненты/слои-архитектуры.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/proxy-management.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/isolated-environment.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/oauth-token-management.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/router-management.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/microvm-launcher.md` (stub)
- СОЗДАНА: `.wiki/архитектура/компоненты/statusline.md` (developing)
- СОЗДАНА: `.wiki/архитектура/потоки/поток-настройки-прокси.md` (stub)
- СОЗДАНА: `.wiki/архитектура/потоки/поток-изолированной-установки.md` (stub)
- СОЗДАНА: `.wiki/архитектура/потоки/поток-обновления-oauth.md` (stub)
- СОЗДАНА: `.wiki/архитектура/потоки/поток-запуска-router.md` (stub)
- СОЗДАНА: `.wiki/архитектура/потоки/поток-запуска-microvm.md` (stub)
- СОЗДАНА: `.wiki/архитектура/концепции/prompt-caching.md` (developing)
- СОЗДАНА: `.wiki/архитектура/концепции/изолированное-окружение.md` (stub)
- СОЗДАНА: `.wiki/архитектура/концепции/lockfile.md` (stub)

**Примечание:** Первичная инициализация домена из docs/architecture (6 файлов: overview.yaml, statusline-architecture.md, diagrams/README.md, diagrams/data-flow-*.md)

---

## 2026-05-05T00:00:01

**Операция:** lint
**Домен:** архитектура

**Проверено страниц:** 15
**Ошибок:** 0
**Предупреждений:** 9

**CV-001 (источники без ingest) — 4 файла не отражены в wiki_sources:**
- `docs/architecture/diagrams/data-flow-isolated-installation.md` — не указан в wiki_sources у `поток-изолированной-установки`
- `docs/architecture/diagrams/data-flow-oauth-token-refresh.md` — не указан в wiki_sources у `поток-обновления-oauth`
- `docs/architecture/diagrams/data-flow-proxy-configuration.md` — не указан в wiki_sources у `поток-настройки-прокси`
- `docs/architecture/diagrams/data-flow-router-launch.md` — не указан в wiki_sources у `поток-запуска-router`

**ST-003 (wiki_status занижен) — 5 страниц:**
- `архитектура/компоненты/proxy-management` — stub → рекомендуется developing (2 источника, ≥10 предложений)
- `архитектура/компоненты/oauth-token-management` — stub → рекомендуется developing (2 источника, полные разделы)
- `архитектура/компоненты/router-management` — stub → рекомендуется developing (2 источника, полные разделы)
- `архитектура/компоненты/microvm-launcher` — stub → рекомендуется developing (3 источника, детальный контент)
- `архитектура/компоненты/isolated-environment` — stub → рекомендуется developing (2 источника, полные разделы)

---

## 2026-05-05T00:00:02

**Операция:** создание домена
**Домен:** библиотека

**Действие:** Добавлен новый домен «Библиотека модулей iclaude» в `domain-map.json`

- `source_paths`: `["lib"]`
- `entity_types`: модуль, функция, категория
- `wiki_subfolder`: `библиотека`

**Примечание:** Домен создан вручную. Источник — 49 bash-файлов в `lib/` + `lib/README.md`. Для наполнения wiki запустить `/llm-wiki bootstrap библиотека` или `/llm-wiki init библиотека`.

---

## 2026-05-05T12:00:00

**Операция:** init
**Домен:** библиотека

**Затронуто страниц:** 36

**Создано категорий (16):**
- СОЗДАНА: `.wiki/библиотека/категории/core.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/command.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/proxy.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/nvm.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/oauth.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/router.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/lsp.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/config.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/lockfile.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/update.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/launcher.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/statusline.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/chrome.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/ohmyposh.md` (stub)
- СОЗДАНА: `.wiki/библиотека/категории/pii-proxy.md` (developing)
- СОЗДАНА: `.wiki/библиотека/категории/sandbox.md` (developing)

**Создано функций (14):**
- СОЗДАНА: `.wiki/библиотека/функции/init-environment.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/launch-claude.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/print-functions.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/detect-nvm.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/get-nvm-claude-path.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/setup-isolated-nvm.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/check-oauth-token.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/configure-proxy-from-url.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/detect-router.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/detect-pii-proxy.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/start-pii-proxy-server.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/start-ccr-server.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/start-microvm.md` (developing)
- СОЗДАНА: `.wiki/библиотека/функции/alloc-microvm-slot.md` (developing)

**Создано паттернов (6):**
- СОЗДАНА: `.wiki/библиотека/паттерны/per-session-isolation.md` (developing)
- СОЗДАНА: `.wiki/библиотека/паттерны/detect-start-stop-lifecycle.md` (developing)
- СОЗДАНА: `.wiki/библиотека/паттерны/exec-vs-fork.md` (developing)
- СОЗДАНА: `.wiki/библиотека/паттерны/orphan-cleanup.md` (developing)
- СОЗДАНА: `.wiki/библиотека/паттерны/slot-based-resource-pools.md` (developing)
- СОЗДАНА: `.wiki/библиотека/паттерны/health-check-dev-tcp.md` (developing)

**Примечание:** Обработано 50 bash-файлов из lib/ (16 подкатегорий). Пропущены: autoresearch, docs (не входят в domain-map библиотека). Категории command/lsp/config/lockfile/update/statusline/chrome/ohmyposh — stub (достаточно информации для базового описания, но не для developing). Остальные — developing.

---

## 2026-05-05T15:00:00

**Операция:** init
**Домен:** функции
**Источники:** docs/functions/ (14 файлов)

**Создано страниц: 13**

**возможности (9):**
- СОЗДАНА: `.wiki/функции/возможности/proxy.md` (developing) — источник: docs/functions/PROXY.md
- СОЗДАНА: `.wiki/функции/возможности/router.md` (developing) — источник: docs/functions/ROUTER.md
- СОЗДАНА: `.wiki/функции/возможности/microvm.md` (developing) — источник: docs/functions/MICROVM.md
- СОЗДАНА: `.wiki/функции/возможности/pii-proxy.md` (developing) — источник: docs/functions/PII_MASKING.md
- СОЗДАНА: `.wiki/функции/возможности/autoresearch.md` (developing) — источник: docs/functions/AUTORESEARCH.md
- СОЗДАНА: `.wiki/функции/возможности/установка.md` (developing) — источник: docs/functions/INSTALLATION.md
- СОЗДАНА: `.wiki/функции/возможности/statusline.md` (developing) — источник: docs/functions/STATUSLINE.md
- СОЗДАНА: `.wiki/функции/возможности/telemetry.md` (stub) — источник: docs/functions/TELEMETRY.md
- СОЗДАНА: `.wiki/функции/возможности/обзор.md` (stub) — источник: docs/functions/README.md

**интеграции (1):**
- СОЗДАНА: `.wiki/функции/интеграции/обзор-интеграций.md` (developing) — источник: docs/functions/INTEGRATIONS.md

**сценарии (1):**
- СОЗДАНА: `.wiki/функции/сценарии/типичные-сценарии.md` (developing) — источник: docs/functions/USE_CASES.md

**конфигурация (2):**
- СОЗДАНА: `.wiki/функции/конфигурация/переменные-окружения.md` (developing) — источники: docs/functions/CLAUDE_CONFIG.md, docs/functions/CONFIGURATION.md
- СОЗДАНА: `.wiki/функции/конфигурация/quick-config.md` (stub) — источник: docs/functions/QUICK_CONFIG.md

**Примечание:** Первичная инициализация домена «функции» из docs/functions/ (14 файлов). domain-map.json обновлён — добавлен домен с id "функции". Структура .wiki/функции/ создана с 4 подпапками.

---

## 2026-05-05T16:00:00

**Операция:** lint
**Домен:** функции

**Проверено страниц:** 13
**Ошибок:** 1
**Предупреждений:** 6
**Info:** 0

**ST-006 (error) — domain-map.json содержит синтаксическую ошибку:**
- `domain-map.json` невалидный JSON (строка 124: незакрытый массив `domains` после второго элемента, лишняя `{` перед доменом "функции"). Домен "функции" находится вне массива `domains`.

**CT-003 (warning) — мёртвые WikiLinks (6 ссылок на несуществующие страницы):**
- `функции/возможности/proxy.md` → `[[функции/возможности/oauth]]` — страница не создана
- `функции/возможности/proxy.md` → `[[функции/конфигурация/переменные-прокси]]` — страница не создана
- `функции/возможности/router.md` → `[[функции/интеграции/claude-code-router]]` — страница не создана
- `функции/возможности/statusline.md` → `[[функции/интеграции/oh-my-posh]]` — страница не создана
- `функции/возможности/установка.md` → `[[функции/возможности/обновление]]` — страница не создана
- `функции/возможности/установка.md` → `[[функции/сценарии/deploy-новый-сервер]]` — страница не создана

**Проверки без нарушений:**
- FM-001/FM-002/FM-003: frontmatter корректен на всех 13 страницах
- FM-004: теги заполнены
- FM-005: все wiki_sources существуют в файловой системе (14 из 14)
- CT-001: нет пустых страниц
- CT-002: stub-страницы (telemetry, обзор, quick-config) свежие — 0 дней
- CT-004: все страницы упоминаются из других страниц (нет orphan)
- CT-005: нет placeholder-текста
- ST-001/ST-002: index.md синхронизирован с файлами
- ST-003: log.md обновлён сегодня
- CV-001: все 14 источников отражены в wiki_sources
- CV-002: 14 источников / 13 страниц — OK

---
