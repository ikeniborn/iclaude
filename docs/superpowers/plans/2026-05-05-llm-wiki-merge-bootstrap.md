# llm-wiki: интеграция bootstrap в init

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать `bootstrap` как отдельную команду — интегрировать его логику в `init` (автозапуск при пустых `entity_types`) и добавить guard-предупреждение в `ingest`.

**Architecture:** Единственный изменяемый файл — `SKILL.md` навыка `llm-wiki`. Изменения хирургические: удаление секций bootstrap, вставка bootstrap-фазы внутрь операции `init`, добавление guard-проверки в `ingest`.

**Tech Stack:** Markdown (SKILL.md — декларативный навык для LLM)

---

## Файловая карта

| Файл | Действие |
|------|---------|
| `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` | Modify: удалить bootstrap-секции, расширить init |

---

### Task 1: Убрать bootstrap из таблицы «Когда использовать» и Quick Reference

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки 29–49

- [ ] **Шаг 1: Удалить строку bootstrap из таблицы «Когда использовать»**

Найти и удалить строку:
```
| Создал новый домен, нужно настроить entity_types автоматически | `bootstrap` |
```

- [ ] **Шаг 2: Удалить строку bootstrap из Quick Reference**

Найти и удалить строку:
```
/llm-wiki bootstrap здоровье
```

- [ ] **Шаг 3: Проверить визуально**

Открыть файл, убедиться что таблица и Quick Reference не упоминают bootstrap.

- [ ] **Шаг 4: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "refactor(llm-wiki): убрать bootstrap из quick reference и таблицы"
```

---

### Task 2: Убрать bootstrap из Phase 0 (первый запуск + парсинг аргументов)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки 96–180

- [ ] **Шаг 0: Исправить сообщения первого запуска (Phase 0, шаг 0.1)**

Найти два места в блоке `IF NOT exists {wiki_root}/`:

Место А — строку:
```
"Следующий шаг: /llm-wiki bootstrap <domain-id> — настроить домены"
```
Заменить на:
```
"Следующий шаг: /llm-wiki init <domain-id> — настроить домены и создать wiki"
```

Место Б — строку:
```
→ Если текущая операция не init/bootstrap: предложить запустить bootstrap
```
Заменить на:
```
→ Если текущая операция не init: предложить запустить /llm-wiki init <domain-id>
```

- [ ] **Шаг 1: Удалить bootstrap из списка операций AskUserQuestion (Phase 0, шаг 0.2)**

Найти блок:
```
AskUserQuestion:
    Вопрос: "Что вы хотите сделать с LLM Wiki?"
    Варианты:
      • ingest     — добавить файл/заметку в wiki
      • query      — задать вопрос по теме
      • lint       — проверить качество wiki
      • init       — первичная инициализация раздела
      • bootstrap  — сгенерировать entity_types для нового домена
```

Удалить последнюю строку `• bootstrap  — ...`.

- [ ] **Шаг 2: Удалить bootstrap-ветку из парсинга аргументов**

Найти и удалить блок (строки ~171–177):
```
   - bootstrap без domain-id → AskUserQuestion: "Выберите домен для bootstrap"
                                 Варианты: все домены из domain-map у которых entity_types: []
                                 Если таких нет → сообщить "Все домены уже настроены"
   - bootstrap с domain-id у которого entity_types уже непусты →
       AskUserQuestion: "Домен «{id}» уже содержит {N} типов сущностей. Перезаписать?"
       Варианты: да, перезаписать | нет, отменить
       При отмене — завершить выполнение
       При --dry-run — пропустить это подтверждение и перейти к Phase 1
```

- [ ] **Шаг 3: Удалить bootstrap из второй AskUserQuestion (пункт 2)**

В пункте 2 Phase 0 (выбор операции для домена без операции) убрать bootstrap из вариантов, если он там упомянут.

- [ ] **Шаг 4: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "refactor(llm-wiki): убрать bootstrap из Phase 0"
```

---

### Task 2.5: Убрать bootstrap-исключение из Phase 1

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки ~186–198

- [ ] **Шаг 1: Найти и удалить bootstrap-исключение в Phase 1**

Найти строку:
```
   Для операции bootstrap: шаги 2 и 3 пропустить — wiki-файлы ещё не существуют для нового домена.
```

Удалить эту строку целиком.

- [ ] **Шаг 2: Убедиться что Phase 1 остальные шаги (1–4) корректны**

Шаги Phase 1 должны выглядеть:
```
1. Читать {wiki_dir}/domain-map.json
2. Читать {wiki_dir}/schema.md
3. Читать {wiki_dir}/index.md
4. Определить операцию из аргументов пользователя
```

- [ ] **Шаг 3: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "refactor(llm-wiki): убрать bootstrap-исключение из Phase 1"
```

---

### Task 3: Удалить секцию «Операция: bootstrap» из Phase 2

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки 322–399

- [ ] **Шаг 1: Найти границы секции**

Секция начинается с:
```
### Операция: bootstrap <domain-id>
```
и заканчивается перед:
```
---

## Phase 3: Валидация и отчёт
```

- [ ] **Шаг 2: Удалить всю секцию bootstrap**

Удалить от `### Операция: bootstrap <domain-id>` до конца секции (включая финальный `---` секции, но не `## Phase 3`).

- [ ] **Шаг 3: Проверить**

Убедиться что Phase 3 на месте и файл не сломан.

- [ ] **Шаг 4: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "refactor(llm-wiki): удалить секцию bootstrap из Phase 2"
```

---

### Task 4: Добавить bootstrap-фазу внутрь операции init

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки ~292–318

- [ ] **Шаг 1: Найти начало секции «Операция: init»**

```
### Операция: init <section>
```

- [ ] **Шаг 2: Вставить bootstrap-проверку между шагом 1 и шагом 2 init**

После текущего шага 1 init:
```
1. Из domain-map получить source_paths домена
```

Вставить новый блок (Phase 1.5 автобутстрап):

```
1а. Проверить entity_types домена:
    IF entity_types пусты:
      → Сообщить: "Домен «{id}» не имеет entity_types. Запускаю анализ источников..."
      → Выполнить bootstrap-анализ (шаги ниже):

      [bootstrap-анализ]
      а) Glob "**/*.md" по source_paths, исключить *.excalidraw.md
         Если 0 файлов → ошибка: "Файлы не найдены в source_paths"
         Если файлов ≥ 50 → AskUserQuestion:
           "Найдено {N} файлов. Анализ займёт много токенов. Продолжить?"
           Варианты: да, продолжить | нет, отменить

      б) Прочитать ВСЕ найденные файлы (Read tool)
         Собрать: #теги из frontmatter и тела, заголовки H1/H2/H3,
                  повторяющиеся именованные существительные и ключевые понятия

      в) Сгенерировать черновик entity_types — 3–7 типов:
         - type: короткий id в kebab-case
         - description: одно предложение
         - extraction_cues: 5–10 ключевых слов
         - min_mentions_for_page: 1 или 2–3
         - wiki_subfolder: "{domain-id}/{type}s"
         Также: tags (если текущее значение []), language_notes (если "")

      г) Показать черновик через AskUserQuestion:
         "Проанализировано {N} файлов. Черновик entity_types для домена «{name}»:
          {список типов с описаниями}
          Подтвердить перед запуском init?"
         Варианты:
           • подтвердить и продолжить init
           • исключить типы — указать id через запятую
           • отменить init

         Если "исключить типы":
           → AskUserQuestion: "Введите id типов для удаления (через запятую)"
           → Удалить, показать обновлённый черновик, снова запросить подтверждение
           → Если entity_types стал пустым → сообщить и предложить только "отменить"

         Если "отменить":
           → завершить выполнение init

      д) Записать entity_types (и tags/language_notes если были пустыми)
         в {wiki_dir}/domain-map.json (Write tool)
         Сообщить: "entity_types сохранены. Продолжаю init..."
      [/bootstrap-анализ]

    ELSE (entity_types непусты):
      → Продолжить как обычно
```

- [ ] **Шаг 2б: Оптимизировать — переиспользовать список файлов из bootstrap-анализа**

После записи entity_types в domain-map (шаг д bootstrap-анализа) добавить:
```
      е) Сохранить список файлов из шага а как $source_files_list
         (используется на шаге 2 init — повторный Glob не нужен)
```

А шаг 2 init изменить с:
```
2. Glob все .md файлы в source_paths
   Исключить: .excalidraw.md файлы
```
на:
```
2. Получить список .md файлов:
   IF $source_files_list уже собран (после bootstrap-анализа) → использовать его
   ELSE → Glob "**/*.md" по source_paths, исключить *.excalidraw.md
```

- [ ] **Шаг 3: Проверить нумерацию шагов init**

После вставки шага 1а убедиться что шаги 2–5 init сохранили правильную нумерацию.

- [ ] **Шаг 4: Обновить примечание в конце секции init**

Найти строку:
```
**Использовать один раз.** При повторном запуске без --force — пропускает уже ingested файлы.
```

Добавить после неё:
```
**Bootstrap-анализ** запускается автоматически если `entity_types` домена пусты. При повторном `init` на уже настроенном домене этот шаг пропускается.
```

- [ ] **Шаг 5: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "feat(llm-wiki): интегрировать bootstrap-анализ в init (auto при пустых entity_types)"
```

---

### Task 5: Добавить guard-проверку в ingest при пустых entity_types

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки ~205–237

- [ ] **Шаг 1: Найти шаг 1 операции ingest**

```
1. Определить домен по пути (сопоставить с domain-map.source_paths)
   Если источник в !Daily/ или домен не определён → определять по содержимому
```

- [ ] **Шаг 2: Добавить guard-проверку entity_types после определения домена**

После шага 1 вставить:
```
1а. Проверить entity_types домена:
    IF entity_types пусты:
      → Предупредить: "Домен «{id}» не настроен (entity_types пусты).
        Для корректного извлечения сущностей сначала запустите:
        /llm-wiki init {domain-id}
        Продолжить ingest без entity_types? (сущности не будут извлечены)"
      → AskUserQuestion:
          Варианты: продолжить без извлечения сущностей | отменить
      Если продолжить: выполнить только шаги 2, 6, 7, 8 (без шага 3 извлечения)
      Если отменить: завершить
```

- [ ] **Шаг 3: Коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "feat(llm-wiki): guard в ingest при пустых entity_types"
```

---

### Task 6: Финальная проверка и обновление changelog в frontmatter

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` строки 1–13

- [ ] **Шаг 1: Прочитать файл целиком и проверить**

Убедиться:
- Слово `bootstrap` встречается только внутри описания `init` (как "bootstrap-анализ") и в примечании
- Нигде нет отдельной команды `/llm-wiki bootstrap`
- Quick Reference содержит только: ingest, query, lint, init
- Phase 0 AskUserQuestion содержит только: ingest, query, lint, init
- Операция init содержит шаг 1а с bootstrap-анализом

- [ ] **Шаг 2: Обновить версию и changelog в frontmatter**

Найти:
```yaml
# version: 2.0.0 | updated: 2026-05-05
# changelog: 2.0.0 — локальная wiki в .wiki/.config/, domain-map перенесён из shared/
#             1.1.0 — bootstrap: автогенерация entity_types из source_paths
#             1.0.0 — initial release
```

Заменить на:
```yaml
# version: 2.1.0 | updated: 2026-05-05
# changelog: 2.1.0 — bootstrap интегрирован в init (автозапуск при пустых entity_types)
#             2.0.0 — локальная wiki в .wiki/.config/, domain-map перенесён из shared/
#             1.1.0 — bootstrap: автогенерация entity_types из source_paths
#             1.0.0 — initial release
```

- [ ] **Шаг 3: Финальный коммит**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "chore(llm-wiki): bump version 2.1.0, обновить changelog"
```

---

## Self-Review

**Покрытие требований:**
- ✅ bootstrap убран как самостоятельная команда
- ✅ bootstrap-логика интегрирована в init (Task 4)
- ✅ ingest получил guard при пустых entity_types (Task 5)
- ✅ lint не требует изменений — он работает с уже созданными wiki-файлами, entity_types не нужны
- ✅ Quick Reference, таблица «Когда использовать», Phase 0 (сообщения первого запуска + парсинг аргументов), Phase 1 (bootstrap-исключение), Phase 2 — все очищены
- ✅ Двойной Glob устранён (Task 4, шаг 2б)

**Placeholders:** отсутствуют — все шаги содержат конкретный текст для вставки.

**Согласованность:** термин «bootstrap-анализ» используется консистентно внутри init-секции.
