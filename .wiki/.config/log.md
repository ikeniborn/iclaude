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

