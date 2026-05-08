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

## 2026-05-07T17:45:00

**Операция:** ingest (update)
**Домен:** документация
**Тема:** PII shared-proxy detach от master PG/session

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/функции/pii-прокси.md` (developing) — добавлен раздел «Detach от process group мастера (fix 2026-05-07)» с описанием проблемы, idiom-fix (`setsid` + `</dev/null`), таблицей сценариев и регрессионным тестом; в wiki_sources добавлены spec/plan/launch.sh/test; aliases дополнены (`shared proxy detach`, `setsid pii`)
- Источники коммитов: fb744b81 (regression test), 33d05a73 (restore inline comments), e52fc28f (fix launch.sh shared-start)
- Ключевые находки: `disown` НЕ создаёт новую сессию/PG — нужен `setsid`; reference-counting layer не меняется и остаётся единственным триггером shutdown; assertion A теста ловит revert через grep, assertion B верифицирует detach реально работает на ядре через `ps -o sid=`

## 2026-05-07T20:35:00

**Операция:** ingest (update)
**Домен:** документация
**Тема:** перемещение трекера upstream issues

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` (mature) — источник `lib/graphify/UPSTREAM_ISSUE.md` заменён на `docs/functions/UPSTREAM_ISSUE.md` (файл перемещён без изменения содержания); обновлена ссылка-трекер в секции «Upstream issues и PR»; добавлено поле `wiki_relocations` в frontmatter

**Контекст:** файл-трекер upstream issues #756/#777/#722 перемещён из `lib/graphify/` в `docs/functions/`. Содержание совпадает с уже задокументированным в wiki — новых сущностей не извлечено. Обновлены только ссылки на источник.

## 2026-05-07T23:59:00

**Операция:** ingest
**Домен:** документация
**Тема:** добавление функций graphify и caveman

**Затронуто страниц:** 2

- СОЗДАНА: `документация/функции/graphify.md` (developing) — feature-страница graphify (зачем, архитектура `lib/graphify/`, флаги `--install-graphify`/`--graphify`/`--check-graphify`, конфигурация `GRAPHIFY_OUT`/`GRAPHIFY_EXTRA_ARGS`, 4 патча портативности, SKILL.md preservation, диагностика). Источник: `docs/functions/GRAPHIFY.md`. Outgoing link на существующую `[[graphify-интеграция]]` (архитектурные детали runtime-нормализации не дублируются).
- СОЗДАНА: `документация/функции/caveman.md` (developing) — feature-страница caveman (token compression hooks, изоляция от `~/.claude/`, флаги `--install-caveman`/`--check-caveman`/`--uninstall-caveman`, конфигурация `CAVEMAN_DEFAULT_MODE`/`CAVEMAN_STATUSLINE`, режимы off/lite/full/ultra/wenyan-*/commit/review/compress, auto-clarity, диагностика). Источник: `docs/functions/CAVEMAN.md`. Полностью новая сущность — wiki-страниц про caveman не было.

**Ключевые находки:**
- graphify-интеграция (архитектура) и graphify (функция) — два дополняющих документа: feature-страница описывает CLI/конфиг/4 патча, архитектурная — runtime-механизмы (`_sync_graphify_env_to_settings`, `normalize-paths.py` abs↔rel, `_patch_graphify_watch`).
- Caveman несовместим с `--system`: только изолированная среда. `CAVEMAN_DEFAULT_MODE` приоритет: env → JSON → дефолт `full`.
- Auto-clarity у caveman автоматически отключает компрессию для security warnings, irreversible actions (`git push`, `rm -rf`, `drop table`), multi-step sequences.

---

## 2026-05-08T13:00:00

**Операция:** ingest
**Источник:** .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
**Домен:** документация

**Затронуто страниц:** 1

- СОЗДАНА: `.wiki/документация/скиллы/llm-wiki.md` (stub) — entity_type: скилл, новый поддомен `документация/скиллы/`

**Примечание:** Первая страница в поддомене «скиллы». Источник описывает сам skill `llm-wiki` (v2.2.0): фазы Phase 0–3, операции ingest/query/lint/init, multi-language readers (markdown/python/typescript/javascript/bash), bootstrap-анализ при пустых entity_types, структура `.wiki/.config/`. Другие entity_types домена (функция, команда, конфигурационная-переменная, интеграция, механизм-безопасности, архитектурный-компонент) в источнике не встречаются — SKILL.md описывает один скилл.

---

## 2026-05-08T07:50:00

**Операция:** ingest (update)
**Домен:** функции
**Тема:** PII proxy + microVM DNAT hardening (P1+P2+P5)

**Затронуто страниц:** 2

- ОБНОВЛЕНА: `документация/функции/microvm-firecracker.md` (developing) — добавлена секция «Интеграция с PII proxy: DNAT hardening (2026-05-08)»: устранены P1 (silent sudo failure), P2 (stale rules после crash), P5 (route_localnet leak). Описаны `_pii_dnat_preflight`, `_pii_dnat_sweep_stale`, comment marker `iclaude-pii-dnat:<tap>`, тестовая пирамида L1/L2/L3, E2E-флаги `--e2e-exit-after-boot`/`--e2e-kill-after-boot`. Источник: spec `2026-05-08-pii-microvm-dnat-hardening-design.md`, plan `2026-05-08-pii-microvm-dnat-hardening.md`, commits `63c0909e..dd81791c`.
- ОБНОВЛЕНА: `документация/функции/pii-прокси.md` (developing) — кросс-ссылка на microvm hardening section в строке про `--sandbox-microvm`.

**Ключевые находки:**
- Comment marker `iclaude-pii-dnat:<tap>` заменяет зависимость от внешнего state (PID, port files) — cleanup устойчив к partial state и port mismatches.
- `_pii_dnat_sweep_stale` использует guard cap=20 для защиты от pathological iptables (rule never disappears).
- Тестовая пирамида self-gates: L1 на любом Linux, L2 требует sudo+dummy module, L3 требует KVM+sudo+firecracker — каждый уровень skip без прерывания runner.
- `iptables -F` запрещён в L2/L3 cleanup — только targeted marker-based deletion (защита host iptables от тестового мусора).
- E2E-флаги gated `ICLAUDE_E2E_HEADLESS=1` — невозможно случайно crash сессию через `--e2e-kill-after-boot` без env var.

## 2026-05-08T16:50:00

**Операция:** lint
**Домен:** документация

**Проверено страниц:** 19
**Итого:** 0 errors, 5 warnings, 9 info

- WARN: FM-005 (2) — несуществующие источники в `graphify-интеграция.md`: `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py`, `tests/test_normalize_paths.py`
- WARN: CT-003 (2) — мёртвые WikiLinks: `[[redact-secrets]]` (правильно `[[маскирование-содержимого]]`), `[[конфигурационные-переменные-прокси]]` (страница не существует)
- WARN: CV-002 (1) — 8 SKILL.md без покрытия: mermaid-obsidian, git-workflow, prd-generator, compact-session, toon-skill, prompt-verifier, agent-builder, architecture-documentation
- INFO: CT-004 (6) — orphan-страницы: статуслайн-адаптеры, телеметрия, маскирование-содержимого, обзор-команд, llm-wiki, caveman
- INFO: CV-001 (33) — некоторые docs/ файлы (superpowers/specs|plans, architecture/diagrams) без покрытия

## 2026-05-08T17:15:00

**Операция:** ingest
**Источник:** `docs/functions/UPSTREAM_ISSUE.md`
**Домен:** документация

**Создано страниц:** 0
**Обновлено страниц:** 1

- ОБНОВЛЕНА: `документация/архитектура/graphify-интеграция.md` (mature) — добавлены секции «Cleanup-цикл после merge #777 + релиза» (пошаговый план: pin lockfile, удаление `lib/graphify/patches/`, `apply_patches.sh`, `tests/test_graphify_patches.py`, пересмотр `_patch_graphify_watch`) и «Out-of-scope для upstream: Patch 04» (явная фиксация дублирования между патч-файлом 04 и runtime-shim `_patch_graphify_watch` для разных runtime-окружений: uv tool dir vs uv tool run cache). Источник уже присутствовал в `wiki_sources` от предыдущего ingest — добавлены только недостающие детали из исходника.

**Пропущено сущностей:** 0
- Issues #756, #758, #777, #722 уже задокументированы в существующей секции «Upstream issues и PR в safishamsi/graphify» с тем же уровнем детализации, что и исходник.
- Workaround `normalize-paths.py` + `_patch_graphify_watch` уже задокументирован в секциях «Хук normalize-paths» и «Патч watch.py: auto-patch при каждом rebuild».

**Ключевые находки:**
- Дублирование Patch 04 (файл-патч в `lib/graphify/patches/`) и runtime-shim `_patch_graphify_watch` (`sed` правка в uv tool run cache) — намеренное: покрывают **два разных Python-окружения** для одного графифая. Консолидация отложена до релиза upstream-fix.

## 2026-05-08T00:00:00

**Операция:** ingest
**Домен:** документация
**Источник:** `docs/functions/GRAPHIFY.md`

**Затронуто страниц:** 0

**Решение:** SKIP — источник уже полностью учтён в `документация/функции/graphify.md` (ingested 2026-05-07). Сравнение секций Зачем/Архитектура/Флаги/Конфигурация/Патчи/SKILL.md/Диагностика показало 1:1 соответствие; новой информации в источнике относительно текущей wiki-страницы нет.

**Связанные страницы:**
- `документация/функции/graphify.md` (wiki_status: developing) — feature-страница, не изменена
- `документация/архитектура/graphify-интеграция.md` (wiki_status: mature) — runtime-уровень (normalize-paths, _patch_graphify_watch, GRAPHIFY_OUT sync), также не затронут

**Следующий шаг:** `/llm-wiki lint документация` (опционально) для проверки актуальности существующих страниц.

## 2026-05-08T17:30:00

**Операция:** ingest
**Источник:** docs/functions/MICROVM.md
**Домен:** документация

**Затронуто страниц:** 2

- ОБНОВЛЕНА: `документация/функции/microvm-firecracker.md` (developing → mature) — добавлены 7 конфиг-переменных (MICRO_VM_INSECURE_DOWNLOAD, MICRO_VM_ROOTFS_SIZE_MB, MICRO_VM_WORKSPACE_SIZE_MB, MICRO_VM_NET_SUBNET, MICRO_VM_SYNC_INTERVAL, MICRO_VM_SYNC_EXCLUDE, MICRO_VM_SNAPSHOT_DIR), разделы Linux Capabilities, IPv6 SLAAC, Troubleshooting (ALT Linux sudo/TLS, TAP)
- ОБНОВЛЕНА: `документация/конфигурация/claude-config.md` — расширен microVM-блок до 13 переменных (добавлены WORKSPACE_SIZE_MB, ROOTFS_SIZE_MB, NET_SUBNET, SYNC_INTERVAL, SYNC_EXCLUDE, SNAPSHOT_DIR, INSECURE_DOWNLOAD)

**Примечание:** Источник уже в wiki_sources, обнаружено новое содержимое не отражённое на странице (config-переменные, troubleshooting, security notes). Создание новых страниц не требовалось. wiki_status microvm-firecracker.md повышен stub→mature: 4 источника, все основные разделы заполнены.

---

## 2026-05-08T17:15:00

**Операция:** ingest
**Источник:** docs/functions/CAVEMAN.md
**Домен:** документация

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/функции/caveman.md` (developing) — детализировано описание `CAVEMAN_STATUSLINE` (badge `⛏`, счётчик `⛏ 5.2k`, обновление через `/caveman-stats`); добавлен раздел "Связанные документы" со ссылками на spec и plan

**Примечание:** Источник уже в wiki_sources, обнаружены два минорных delta (детали статуслайн-badge и ссылки spec/plan). wiki_status оставлен developing — у страницы один источник (`docs/functions/CAVEMAN.md`), для повышения до mature нужно ≥ 4.

---

---

## 2026-05-08T00:00:00

**Операция:** ingest (внешний источник)
**Домен:** документация
**Тема:** superpowers-context-reset

**Затронуто страниц:** 1

- СОЗДАНА: `документация/скиллы/superpowers-context-reset.md` (stub) — источник: GitHub issue obra/superpowers#1503 + связанные #1490, #931, #478

**Примечание:** Внешний источник (GitHub issue в стороннем репозитории), аналогично прецеденту `graphify-интеграция.md`. Сущность относится к типу "скилл" (extraction_cues: skill, superpowers, workflow). Связь с локальными скиллами `.nvm-isolated/.claude-isolated/skills/superpowers/`.

## 2026-05-08T21:32:04 (commit 0dba184)

**Операция:** ingest
**Домен:** документация
**Источники:** 9 SKILL.md (skills routing audit) + docs/audits/2026-05-08-skills-description-audit.md

**Затронуто страниц:** 1

- ОБНОВЛЕНА: `документация/скиллы/llm-wiki.md` — добавлен раздел «Маршрутизация (frontmatter description)» с канонической формулировкой description и границами vs graphify / graphify-context / context-awareness; в `wiki_sources` добавлен audit-документ.

**Пропущено:** 8 SKILL.md (agent-builder, architecture-documentation, context-awareness, git-workflow, graphify, mermaid-obsidian, prd-generator, prompt-verifier) — нет существующих wiki-страниц, single-source каждой из этих сущностей даёт только 1 упоминание (min_mentions_for_page=2 для типа «скилл»), CREATE не сработает.

**Примечание:** Коммит 0dba184 — переписывание `description:` frontmatter в 9 SKILL.md для устранения triggers overlap (audit от 2026-05-08). Функциональность скиллов не менялась — только метаданные маршрутизации. Для llm-wiki это UPDATE (изменился источник, страница есть). Для остальных — SKIP до накопления второго источника. Если в будущем потребуется отдельная страница «skills-маршрутизация», audit-документ достаточен как HLD-источник.
