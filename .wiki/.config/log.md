# Wiki Log

<!-- Append-only лог. Новые записи добавляются в конец. -->

## 2026-05-06T00:00:00

**Операция:** init
**Домен:** документация

**Затронуто страниц:** 15

- СОЗДАНА: `документация/функции/прокси.md` (developing) — источники: PROXY.md, CONFIGURATION.md, USE_CASES.md
- СОЗДАНА: `документация/функции/маршрутизатор-ccr.md` (developing) — источники: ROUTER.md, USE_CASES.md, CONFIGURATION.md
- СОЗДАНА: `документация/функции/pii-прокси.md` (developing) — источники: PII_MASKING.md, CONFIGURATION.md, TELEMETRY.md
- СОЗДАНА: `документация/функции/статуслайн.md` (developing) — источники: STATUSLINE.md, CONFIGURATION.md
- СОЗДАНА: `документация/функции/microvm-firecracker.md` (developing) — источники: MICROVM.md, USE_CASES.md, CONFIGURATION.md
- СОЗДАНА: `документация/команды/обзор-команд.md` (developing) — источники: CONFIGURATION.md, USE_CASES.md, QUICK_CONFIG.md
- СОЗДАНА: `документация/конфигурация/claude-config.md` (developing) — источники: CONFIGURATION.md, QUICK_CONFIG.md, MICROVM.md, PII_MASKING.md
- СОЗДАНА: `документация/интеграции/ollama.md` (developing) — источники: ROUTER.md, PII_MASKING.md, STATUSLINE.md
- СОЗДАНА: `документация/интеграции/deepseek.md` (stub) — источники: ROUTER.md, STATUSLINE.md
- СОЗДАНА: `документация/интеграции/presidio.md` (stub) — источники: PII_MASKING.md
- СОЗДАНА: `документация/безопасность/блокировка-секретов.md` (developing) — источники: PII_MASKING.md, TELEMETRY.md
- СОЗДАНА: `документация/безопасность/маскирование-содержимого.md` (developing) — источники: PII_MASKING.md
- СОЗДАНА: `документация/архитектура/модульная-структура.md` (developing) — источники: CONFIGURATION.md, STATUSLINE.md, MICROVM.md, ROUTER.md
- СОЗДАНА: `документация/архитектура/статуслайн-адаптеры.md` (stub) — источники: STATUSLINE.md
- СОЗДАНА: `документация/архитектура/телеметрия.md` (stub) — источники: TELEMETRY.md

**Примечание:** Bootstrap-анализ выполнен: прочитаны все 28 .md файлов из docs/. Entity_types определены и записаны в domain-map.json. Пропущены: docs/architecture/diagrams/ (Mermaid), docs/superpowers/plans/, docs/superpowers/specs/ (планы разработки, не документация функций).

---

## 2026-05-07T00:00:00

**Операция:** update (ingest/virtual-source)
**Домен:** документация
**Тема:** graphify-integration

**Затронуто страниц:** 1

- СОЗДАНА: `документация/архитектура/graphify-интеграция.md` (developing) — источник: commit-note/graphify-integration-2026-05-07 + skill-файлы

**Содержание изменения:** Skill-файлы graphify-context/SKILL.md, context-awareness/SKILL.md, graphify/SKILL.md более не содержат хардкода `.graphify/` в path-check инструкциях. Добавлен Step 0 (`GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")`) перед проверками пути в graphify-context и context-awareness. Паттерн соответствует существующему Step 0.5 в graphify/SKILL.md. Синхронизация GRAPHIFY_OUT в settings.json выполняется `_sync_graphify_env_to_settings()` в lib/launcher/launch.sh перед каждым запуском. Оставшиеся `.graphify/` ссылки: только `~/.graphify/repos/` (глобальный кэш клонов, корректно) и Example 4c в context-awareness (проектно-специфичный конфиг с комментарием).

---

## 2026-05-07T14:30:00

**Операция:** update (ingest)
**Домен:** документация
**Тема:** graphify-интеграция — явные пути CLI и патч watch.py

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` (developing) — источники: lib/graphify/install.sh, skills/graphify/SKILL.md, skills/graphify-context/SKILL.md

**Содержание изменения:**
1. `graphify-context/SKILL.md`: все CLI-вызовы (`query`, `path`, `explain`) теперь передают явный `--graph "${GRAPHIFY_OUT}/graph.json"`. Ранее использовался хардкод `graphify-out/graph.json` в CLI-бинаре при нестандартном GRAPHIFY_OUT.
2. `graphify/SKILL.md`: все `save-result` вызовы теперь передают явный `--memory-dir "${GRAPHIFY_OUT}/memory"`. Ранее дефолтный путь создавал паразитный `graphify-out/` при GRAPHIFY_OUT != graphify-out.
3. `lib/graphify/install.sh`: добавлена `_patch_graphify_watch()` — идемпотентный патч upstream-бага в `graphifyy.watch._rebuild_code()` (save_manifest без manifest_path). Вызывается после `uv install` и перед каждым `_graphify_rebuild_graph()`. При ошибке sed — предупреждение вместо молчаливого игнорирования.

---


## 2026-05-07T16:30:00

**Операция:** ingest (update)
**Домен:** документация

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` (developing) — добавлен раздел «Хук normalize-paths: портативность путей abs↔rel»; источники: `hooks/normalize-paths.py`, `settings.json` (commit 802fa66), `tests/test_normalize_paths.py`

**Контекст:** новые коммиты ed852cc, 802fa66, fec5c8f, 6f7980b, 29bb859 — feature normalize-paths hook для abs↔rel портативности `.graphify/` между разработчиками.

## 2026-05-07T16:10:00

**Операция:** refresh (ingest from commits)
**Домен:** документация

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` — добавлена секция «Дополнительная точка вызова: после auto-rebuild в install.sh» + сводная таблица точек нормализации; статус developing → mature
- Источники коммитов: 802fa66 (settings.json hooks), bc37604 (install.sh wiring), d736cab (нормализованные пути в .graphify/)
- Ключевые находки: normalize-paths имеет 3 точки вызова (Pre/Post hooks + автоматический rebuild через uv tool run), `< /dev/null` использован для standalone-вызова без hook-input JSON

## 2026-05-07T17:00:00

**Операция:** ingest (refresh)
**Домен:** документация

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` — добавлены секции «Сохранение локальных правок SKILL.md при reinstall» и «Symlink graphify в isolated bin/»; в wiki_sources добавлены `lib/graphify/detect.sh`, `lib/graphify/status.sh`; aliases дополнены (`SKILL.md preservation`, `graphify symlink`)
- Источники коммитов: c9a50e9 (preserve SKILL.md customizations), c3cd7ba (save upstream as .new), 967084b (--force not overwrite SKILL.md), 54d6915 (graphify symlink to isolated bin)
- Ключевые находки: `graphify install` запускается в `mktemp -d` при reinstall для diff с локальным SKILL.md; `which graphify` нужен для определения uv-managed Python 3.12 через shebang
