# TOON Protocol for Agent Pipeline

**Version:** 1.0.0
**Purpose:** Спецификация TOON-формата для межагентной коммуникации в системе Researcher → Planner → Executor

**Полная спецификация TOON:** `@shared:TOON-REFERENCE.md`

---

## Обзор

TOON (Token-Oriented Object Notation) используется для передачи структурированных массивов
между агентами с экономией 40-70% токенов по сравнению с чистым JSON.

**Правило:** TOON генерируется для массивов >= 5 элементов. JSON остаётся основным форматом.

---

## input.toon (Оркестратор → Researcher)

> **Примечание:** Для `input.toon` используется чистый JSON — массивов нет, TOON не нужен.

```json
{
  "task_input": {
    "task_description": "<описание задачи пользователя>",
    "focus_areas": ["codebase", "architecture", "risks", "external_docs"],
    "hints": {
      "language_hint": null,
      "skip_context7": false,
      "skip_local_docs": false
    }
  }
}
```

**Поля:**
- `task_description` — оригинальный запрос пользователя (строка)
- `focus_areas` — области исследования (все по умолчанию)
- `language_hint` — подсказка языка проекта (null = автоопределение)
- `skip_context7` — пропустить Context7 MCP (false = использовать если доступен)
- `skip_local_docs` — пропустить загрузку локальной документации (false = загружать docs/llms.txt)

---

## research.toon (Researcher → Planner)

Гибридный формат: JSON-объект с TOON-блоками для больших массивов.

### JSON-обёртка

```json
{
  "research_results": {
    "project_context": {
      "language": "bash",
      "framework": "none",
      "entry_point": "iclaude.sh",
      "architecture_style": "modular"
    },
    "codebase_analysis": {
      "relevant_files": "<<TOON:relevant_files>>",
      "reusable_components": [
        {
          "name": "parse_args()",
          "file": "lib/command/args.sh",
          "description": "CLI argument parsing — добавить новый case"
        }
      ],
      "existing_implementations": []
    },
    "architecture_analysis": {
      "affected_components": ["lib/command/", "lib/context/"],
      "integration_points": ["iclaude.sh entry point sources args.sh"],
      "dependency_chain": "iclaude.sh → lib/command/args.sh → lib/context/"
    },
    "risk_assessment": {
      "breaking_changes_potential": "low",
      "risks": [
        {
          "id": "R1",
          "description": "session-env/ may be empty",
          "severity": "low",
          "mitigation": "Print 'No active sessions' message"
        }
      ]
    },
    "external_docs": {
      "context7_status": "NO_LIBRARIES_DETECTED",
      "deep_research_status": "NOT_TRIGGERED",
      "docs_found": [],
      "key_findings_summary": []
    },
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
    },
    "recommendations": {
      "complexity_hint": "minimal",
      "key_insights": [
        "parse_args() в lib/command/args.sh — точка добавления флага",
        "lib/context/ содержит session management"
      ]
    }
  }
}
```

### TOON-блок: relevant_files

Генерируется если `relevant_files` >= 5 элементов:

```
TOON:relevant_files:v1
path|relevance|reason
lib/command/args.sh|high|CLI argument parsing module
lib/command/help.sh|medium|Help text needs updating
lib/context/sessions.sh|high|Session management source
iclaude.sh|medium|Entry point sources all lib/ modules
lib/launcher/launch.sh|low|Launch orchestration
```

**Поля:**
- `path` — путь к файлу относительно project root
- `relevance` — уровень релевантности: `high` | `medium` | `low`
- `reason` — краткое объяснение (< 60 символов)

**Threshold:** >= 5 файлов → TOON. < 5 файлов → JSON-массив объектов.

**Пороги для других полей research.toon:**

| Поле | Формат |
|------|--------|
| `relevant_files` | TOON если >= 5 файлов |
| `reusable_components` | всегда JSON (обычно < 5 элементов) |
| `local_docs.relevant_sections` | всегда JSON (массив обычно < 5 элементов) |
| `external_docs.docs_found` | всегда JSON (обычно < 5 элементов) |

### complexity_hint значения

| Значение | Число фаз | Описание |
|----------|-----------|----------|
| `minimal` | 1-2 | Одно место изменения, без рисков |
| `standard` | 2-3 | Несколько файлов, умеренная сложность |
| `complex` | 3-5 | Архитектурные изменения, высокие риски |

---

## plan.toon (Planner → Executor)

Гибридный формат: JSON-обёртка с TOON-блоком для steps.

### JSON-обёртка

```json
{
  "execution_plan": {
    "metadata": {
      "task_description": "<из input.toon>",
      "complexity": "minimal",
      "total_phases": 2,
      "estimated_steps": 3
    },
    "phases": [
      {
        "phase_number": 1,
        "phase_name": "CLI + Help",
        "risk": "low",
        "steps": "<<TOON:phase_1_steps>>",
        "files_to_change": ["lib/command/args.sh", "lib/command/help.sh"],
        "validation": "bash -n iclaude.sh",
        "commit_message": "feat(cli): add --list-sessions flag"
      }
    ],
    "files_to_change": "<<TOON:files_to_change>>",
    "research_references": {
      "reusable_components_used": ["parse_args() from lib/command/args.sh"],
      "risks_mitigated": ["R1: Empty session-env/ → print message"],
      "docs_consulted": ["API Reference: proxy/validate.md"]
    }
  }
}
```

### TOON-блок: phase_N_steps

Генерируется если steps в фазе >= 5:

```
TOON:phase_1_steps:v1
step_number|description|action|file|validation
1|Parse --list-sessions flag|add case to parse_args()|lib/command/args.sh|bash -n lib/command/args.sh
2|Implement session listing|read session-env/ directory|lib/context/sessions.sh|bash -n lib/context/sessions.sh
3|Update help text|add --list-sessions description|lib/command/help.sh|bash -n lib/command/help.sh
```

**Поля:**
- `step_number` — порядковый номер шага
- `description` — что делает шаг
- `action` — конкретное действие (глагол + детали)
- `file` — файл для изменения
- `validation` — команда проверки после шага

### TOON-блок: files_to_change

Генерируется если >= 5 файлов:

```
TOON:files_to_change:v1
file|action|phase
lib/command/args.sh|modify|1
lib/command/help.sh|modify|1
lib/context/sessions.sh|create|2
```

**Поля:**
- `file` — путь к файлу
- `action` — `create` | `modify` | `delete`
- `phase` — номер фазы

---

## report.md (Executor → пользователь)

Markdown-формат (не TOON — нарративный документ для ревью).

### Шаблон

```markdown
# Execution Report: {task_description}

**Session:** {session_id}
**Status:** ✅ COMPLETED | ❌ FAILED | ⚠️ PARTIAL

## Summary

{краткое описание что было сделано}

## Phase Results

### Phase {N}: {phase_name}
- **Status:** ✅ COMPLETED | ❌ FAILED
- **Files:** `{file1}`, `{file2}`
- **Validation:** `{validation_command}` → OK | FAILED
- **Commit:** `{commit_message}` ({short_hash})

## Risks Encountered

| Risk | Severity | Resolution |
|------|----------|------------|
| {risk_description} | {severity} | {how_resolved} |

## Next Steps

- [ ] {manual_action_1}
- [ ] {manual_action_2}
```

---

## Парсинг TOON в агентах

Агенты работают с TOON напрямую (читают и пишут строки).
Нет необходимости в JavaScript конвертерах — Claude понимает TOON-синтаксис нативно.

**Чтение research.toon:**
1. Прочитать файл как текст
2. Разобрать JSON-обёртку
3. Заменить `<<TOON:name>>` → прочитать соответствующий TOON-блок в файле
4. Использовать данные

**Запись research.toon:**
1. Сформировать данные
2. Если array >= 5 → сгенерировать TOON-блок (pipe-separated строки)
3. В JSON-обёртке поставить `<<TOON:name>>` или встроить массив напрямую
4. Записать файл

**Формат TOON-блока в файле:**

```
TOON:{array_name}:v1
{field1}|{field2}|{field3}
{value1}|{value2}|{value3}
{value4}|{value5}|{value6}
```

Первая строка: заголовок с именем массива и версией.
Вторая строка: названия полей через `|`.
Остальные строки: данные через `|`.

---

## Backwards Compatibility

Если агент получает research.toon без TOON-блоков (< 5 файлов):
- `relevant_files` содержит JSON-массив объектов — использовать напрямую
- Логика агента одинакова для обоих форматов
