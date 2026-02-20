# Интеграция Sphinx документации в агентный пайплайн

## Контекст

Проект iclaude имеет полноценный Sphinx сайт (`docs/sphinx/`) с API Reference для 19+ модулей,
индексный файл для AI агентов (`docs/llms.txt`, 98 строк) и полный контент (`docs/llms-full.txt`,
14 347 строк). Однако агентный пайплайн Researcher → Planner → Executor → Critic эту документацию
не использует.

**Текущий разрыв:**
- `Researcher Agent` имеет `external_docs` (Context7, внешние библиотеки), но не загружает
  **локальную** документацию проекта
- `Planning Agent` создаёт планы без знания задокументированных паттернов и API
- `Execution Agent` не сверяется с API Reference при реализации
- `Critic Agent` не проверяет, были ли docs консультированы

**Цель:** Агенты должны использовать `docs/llms.txt` и `docs/sphinx/api-reference/` как source of truth
при анализе, планировании и валидации изменений.

---

## Файлы для изменения

| Файл | Тип изменения |
|------|--------------|
| `agents/researcher-agent/AGENT.md` | Добавить Шаг 2b: Локальная документация |
| `agents/researcher-agent/schemas/output.schema.json` | Добавить поле `local_docs` |
| `agents/planning-agent/AGENT.md` | Добавить Шаг 1b: Использование local_docs |
| `agents/critic-agent/AGENT.md` | Добавить проверку docs_consultation в Рубрику A |
| `agents/_shared/toon-protocol.md` | Документировать `local_docs` в спецификации research.toon |

**Не изменяется:** `execution-agent/AGENT.md` (получает plan уже обогащённый docs-инсайтами),
scoring система остаётся 4×25=100.

---

## Шаг 1: Researcher Output Schema (`output.schema.json`)

Добавить поле `local_docs` в объект `research_results` параллельно с существующим `external_docs`.

**Добавить в `properties` объекта `research_results`:**
```json
"local_docs": {
  "type": "object",
  "required": ["docs_status"],
  "description": "Локальная документация проекта (Sphinx/llms.txt)",
  "properties": {
    "docs_status": {
      "type": "string",
      "enum": ["FOUND", "NOT_FOUND", "SKIPPED"],
      "description": "FOUND: docs/ есть и найдены релевантные секции. NOT_FOUND: docs/ отсутствует. SKIPPED: пропущено по hints."
    },
    "relevant_sections": {
      "type": "array",
      "description": "Релевантные секции документации для текущей задачи",
      "items": {
        "type": "object",
        "required": ["component", "source", "key_insights"],
        "properties": {
          "component": {
            "type": "string",
            "description": "Компонент из affected_components"
          },
          "source": {
            "type": "string",
            "description": "Путь к файлу документации"
          },
          "key_insights": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Ключевые факты для Planner: функции, паттерны, ограничения"
          }
        }
      }
    }
  }
}
```

Также добавить `local_docs` в массив `required` объекта `research_results`.

---

## Шаг 2: Researcher Agent (`AGENT.md`)

Добавить новый **Шаг 2b** между "Шаг 2: Запустить параллельные суб-агенты" и "Шаг 3: [Опционально] Context7":

```markdown
### Шаг 2b: Локальная документация проекта

Если `hints.skip_local_docs != true`:

1. Проверить наличие `docs/llms.txt`:
   ```
   Read(docs/llms.txt)
   ```

2. Если файл существует:
   - Из `architecture_analysis.affected_components` взять первые 3 компонента
   - Для каждого компонента найти соответствующую строку в llms.txt
   - Прочитать найденный API Reference файл (из `/_sources/sphinx/api-reference/{component}/`)
   - Извлечь: имена публичных функций, параметры, примеры использования, ограничения

3. Записать в `local_docs`:
   - `docs_status: "FOUND"` если найдено ≥1 релевантная секция
   - `relevant_sections` — массив найденных секций с key_insights
   - `docs_status: "NOT_FOUND"` если docs/llms.txt не существует
   - `docs_status: "SKIPPED"` если hints.skip_local_docs == true

**Правила:**
- Максимум 5 Read вызовов для docs (не замедлять пайплайн)
- Graceful skip если docs/ отсутствует → `docs_status: "NOT_FOUND"`
- key_insights: максимум 3 пункта на компонент, конкретные факты (< 60 символов каждый)
- Не читать llms-full.txt (слишком большой) — только llms.txt (индекс) + конкретные файлы
```

Также добавить `skip_local_docs` в `hints` в описании входных данных:
```
- `hints.skip_local_docs` — пропустить загрузку локальной документации (false = загружать)
```

---

## Шаг 3: Planning Agent (`AGENT.md`)

Добавить **Шаг 1b** после "Шаг 1: Прочитать входные файлы":

```markdown
### Шаг 1b: Использовать local_docs (если доступны)

Если `research_results.local_docs.docs_status == "FOUND"`:

- Для каждой секции из `local_docs.relevant_sections`:
  - Использовать `key_insights` при написании `description` и `action` шагов плана
  - Ссылаться на задокументированные функции (из insights) в поле `action`
  - Пример: `"action": "Extend validate_proxy_url() согласно docs/api-reference/proxy/validate.md"`

- Добавить в `research_references`:
  ```json
  "docs_consulted": ["API Reference: proxy/validate.md", "API Reference: core/json.md"]
  ```

Если `local_docs.docs_status != "FOUND"`:
- Продолжить без изменений (graceful degradation)
```

Обновить формат `research_references` в образце plan.toon (добавить опциональное поле `docs_consulted`):
```json
"research_references": {
  "reusable_components_used": [...],
  "risks_mitigated": [...],
  "docs_consulted": ["API Reference: proxy/validate.md"]
}
```

---

## Шаг 4: Critic Agent (`AGENT.md`)

Добавить проверку docs_consultation в **Рубрику A (Research Evaluation)**,
измерение 4 `Component Identification`:

```markdown
| Условие | Вычет |
|---------|-------|
| `reusable_components` пустой или содержит только пути (нет имён функций) | -10 |
| `affected_components` пустой | -8 |
| `dependency_chain` пустой | -7 |
| `docs/llms.txt` существует в проекте И `local_docs` отсутствует/пустой | -5 |
```

**Новое примечание в измерении 4:**
```markdown
**Docs consultation check (если проект имеет docs/):**
- Если в workspace доступен путь `docs/llms.txt` (проверить через Read) И
  `research_results.local_docs` отсутствует или `docs_status == "NOT_FOUND"` при наличии файла → -5 pts
- Это штраф за игнорирование доступной документации (Researcher должен был её загрузить)
```

---

## Шаг 5: _shared/toon-protocol.md

Обновить секцию `research.toon (Researcher → Planner)` → подраздел `JSON-обёртка`:

Добавить поле `local_docs` в пример JSON рядом с `external_docs`:

```json
"local_docs": {
  "docs_status": "FOUND",
  "relevant_sections": [
    {
      "component": "lib/proxy/",
      "source": "docs/sphinx/api-reference/proxy/validate.md",
      "key_insights": [
        "validate_proxy_url() validates HTTP/HTTPS only",
        "Returns 0 on success, 1 on failure",
        "No SOCKS5 support by design"
      ]
    }
  ]
}
```

Добавить строку в таблицу порога TOON:
```
local_docs: всегда JSON (массив relevant_sections обычно < 5 элементов)
```

---

## Связанные файлы (только чтение, не изменяются)

- `docs/llms.txt` — источник индекса (читается агентом во время работы)
- `docs/sphinx/api-reference/**/*.md` — источник API docs (читается агентом по мере необходимости)
- `agents/input.toon` схема — добавить `skip_local_docs` в hints (можно в отдельном PR)

---

## Верификация

1. Запустить `agent-orchestrator` с задачей затрагивающей proxy или core модуль
2. Проверить `research.toon` — должно содержать `local_docs.docs_status: "FOUND"` и `relevant_sections`
3. Проверить `plan.toon` — должно содержать `research_references.docs_consulted`
4. Проверить `research-critique.toon` — не должно содержать вычет за docs_consultation если docs были загружены
5. Тест graceful degradation: задача без docs/ в проекте → `docs_status: "NOT_FOUND"`, пайплайн продолжает

---

## Принципы (non-breaking design)

- Все изменения graceful degradation: отсутствие docs/ не ломает пайплайн
- Токенный бюджет: max 5 Read вызовов для docs (без llms-full.txt)
- Scoring 4×25=100 сохраняется, -5 embedded в Component Identification
- `skip_local_docs: true` в hints отключает полностью (для тестов без docs)
- Execution Agent не трогается — получает обогащённый план от Planning Agent
