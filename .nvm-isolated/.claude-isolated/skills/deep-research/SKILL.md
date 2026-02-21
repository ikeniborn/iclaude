---
name: deep-research
description: Агент глубокого веб-исследования с рекурсивным поиском, фетчингом и синтезом результатов. Используется напрямую или вызывается из Researcher Agent для сбора актуальных внешних данных.
user-invocable: true
context: fork
---
<!-- version: 1.0.0 | tags: research, web-search, web-fetch, synthesis, external-docs, recursive | dependencies: agent-orchestrator | agents: agents/deep-research-agent/AGENT.md -->

# Deep Research Skill

Скилл запускает Deep Research Agent для масштабного рекурсивного исследования через WebSearch и WebFetch.
Возвращает структурированные выводы с источниками, противоречиями и пробелами.

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | `/deep-research <query>` |
| **Agent** | `agents/deep-research-agent/AGENT.md` |
| **Duration** | shallow: ~1 мин, standard: ~3 мин, deep: ~8 мин |
| **Permission** | Всегда запрашивает разрешение пользователя перед запуском |
| **Output** | Структурированный отчёт с ключевыми выводами + источниками |
| **Integration** | Вызывается из Researcher Agent для внешних данных |

## When to Use

Используй этот скилл когда нужно:
- Исследовать актуальные внешние данные (API changes, best practices, новые технологии)
- Собрать и синтезировать информацию из множества веб-источников
- Проверить факты через несколько независимых источников
- Изучить документацию, которая не доступна через Context7
- Подготовить базу знаний для Researcher Agent перед планированием

**Не нужен когда:**
- Информация уже есть в кодовой базе
- Вопрос касается только локального кода
- Достаточно одного-двух поисков (используй WebSearch напрямую)

## Параметры

```
/deep-research <query> [--depth shallow|standard|deep] [--sources N] [--focus area1,area2]
```

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `query` | Вопрос или тема для исследования | обязательный |
| `--depth` | Глубина исследования | standard |
| `--sources` | Максимум источников | 10 |
| `--focus` | Конкретные области исследования | все |
| `--lang` | Язык источников | en |
| `--recent` | Фильтр по дате (e.g. "last 6 months") | нет |

## How It Works

### Шаг 1: Запрос разрешения

**ОБЯЗАТЕЛЬНО перед запуском** показать пользователю:

```
════════════════════════════════════════════
🔍 DEEP RESEARCH AGENT
════════════════════════════════════════════
Запрос: {query}
Глубина: {depth}
Ожидаемое время: {duration}
Веб-поиски: ~{N} запросов + фетчинг источников

Запустить исследование? [yes/no]
════════════════════════════════════════════
```

Если пользователь ответил `no` → STOP, объяснить что можно сделать вместо этого.

### Шаг 2: Подготовка Workspace

```bash
PROJECT_ROOT=$(pwd)
SESSION_ID=$(date +%Y-%m-%dT%H%M)
WORKSPACE="${PROJECT_ROOT}/.claude/workspace/${SESSION_ID}"
mkdir -p "${WORKSPACE}"

# Добавить в .gitignore если нужно
grep -q "^\.claude/workspace/" "${PROJECT_ROOT}/.gitignore" 2>/dev/null || \
  echo -e "\n# Claude Code Agent Workspace\n.claude/workspace/" >> "${PROJECT_ROOT}/.gitignore"
```

### Шаг 3: Записать deep-research-request.toon

```json
{
  "deep_research_input": {
    "query": "{query_from_user}",
    "depth": "{depth}",
    "max_sources": {max_sources},
    "focus_areas": [{focus_areas}],
    "output_format": "structured",
    "caller": "user",
    "hints": {
      "prefer_official_docs": true,
      "recency_filter": "{recent_filter_or_null}",
      "language": "{lang}",
      "exclude_domains": []
    }
  }
}
```

Записать в `{WORKSPACE}/deep-research-request.toon`.

### Шаг 4: Запустить Deep Research Agent

Прочитать:
```
AGENTS_DIR = {SKILL_BASE_DIR}/../../agents
agent_md = Read("{AGENTS_DIR}/deep-research-agent/AGENT.md")
```

Запустить субагент:
```
Task(
  subagent_type="general-purpose",
  prompt=agent_md + """

WORKSPACE: {WORKSPACE}
QUERY: {query}
DEPTH: {depth}
MAX_SOURCES: {max_sources}
CALLER: user
"""
)
```

Дождаться завершения.

### Шаг 5: Прочитать и показать результаты

```
Read({WORKSPACE}/deep-research-results.toon)
```

Вывести структурированный отчёт:

```
════════════════════════════════════════════
📊 DEEP RESEARCH RESULTS
════════════════════════════════════════════
Запрос: {query}
Источников: {sources_fetched}/{sources_found}
Уверенность: {confidence_overall}

Ключевые выводы:
  1. {finding_1} [{confidence}]
  2. {finding_2} [{confidence}]
  3. {finding_3} [{confidence}]

{если contradictions > 0:
"⚠️  Противоречия ({count}):
  - {topic}: {position_a.claim} vs {position_b.claim}"
}

{если gaps > 0:
"Пробелы в данных:
  - {gap_1}
  - {gap_2}"
}

Источники ({sources_count}):
  ★ {top_source_1_title} ({type})
  ★ {top_source_2_title} ({type})
  ...

Рекомендации:
  {action_items}

Workspace: {WORKSPACE}
════════════════════════════════════════════
```

### Шаг 6: Предложить дополнительные действия

```
Что дальше?
1. Сохранить результаты в docs/
2. Запустить глубже (--depth deep)
3. Исследовать конкретный аспект
4. Запустить полный пайплайн (/agent-orchestrator) с этими данными
5. Завершить

Выбор [1-5/no]:
```

## Интеграция с agent-orchestrator

Deep Research Agent автоматически вызывается из Researcher Agent когда:
1. `input.toon` содержит `focus_areas: ["web_research"]`
2. Context7 недоступен (`context7_status: "PLUGIN_NOT_AVAILABLE"`)
3. Задача требует актуальных внешних данных

**Протокол вызова в Researcher Agent:**

```
# Researcher Agent пишет запрос
Write({WORKSPACE}/deep-research-request.toon, {...})

# Запускает Deep Research субагент
Task(subagent_type="general-purpose", prompt=deep_research_agent_md + context)

# Читает результаты и интегрирует в research.toon
Read({WORKSPACE}/deep-research-results.toon)
→ research.toon.external_docs.deep_research_status = "COMPLETED"
→ research.toon.external_docs.key_findings_summary = [...]
```

## Output Format

### Минимальный (shallow, <8 источников)

```json
{
  "deep_research_results": {
    "metadata": {"query": "...", "depth": "shallow", "sources_fetched": 4},
    "key_findings": [{"finding": "...", "confidence": "high", "sources": [...]}],
    "detailed_findings": {},
    "gaps": [],
    "sources": [{"url": "...", "title": "...", "type": "official_docs", "reliability": "high"}],
    "recommendations": {"confidence_overall": "high", "action_items": [...]}
  }
}
```

### Полный (standard/deep, >=8 источников, TOON формат)

```
TOON:sources:v1
url|title|type|reliability|fetched|key_insights
https://...|Claude API Docs|official_docs|high|true|Breaking changes in v3; New endpoint added
https://...|Migration Guide|official_docs|high|true|Deprecated params listed
...

---JSON---
{
  "deep_research_results": {
    "metadata": {"query": "...", "depth": "standard", "sources_found": 15, "sources_fetched": 10},
    "key_findings": [...],
    "detailed_findings": {"api_changes": {...}, "best_practices": {...}},
    "contradictions": [...],
    "gaps": ["Нет информации о pricing изменениях"],
    "sources": "<<TOON:sources>>",
    "recommendations": {
      "confidence_overall": "high",
      "action_items": ["Обновить SDK до версии 3.x"],
      "further_research_needed": ["Тестирование новых endpoint"]
    }
  }
}
```

## Templates

- `@template:deep-research-request` — Входной запрос для агента
- `@template:deep-research-results` — Структура выходных данных

## Schemas

- `@schema:deep-research-request` — Валидация входного запроса
- `@schema:deep-research-results` — Валидация выходных данных

## Examples

- `@example:claude-api-research` — Исследование изменений в Claude API
- `@example:nvm-ci-best-practices` — Поиск best practices для NVM в CI/CD
- `@example:researcher-agent-integration` — Интеграция с Researcher Agent в пайплайне

## Rules

- Всегда запрашивать разрешение пользователя перед запуском (если CALLER=user)
- Не превышать токенный бюджет по depth уровню
- Проверять каждый ключевой факт минимум в 2 независимых источниках
- Явно помечать спорные утверждения `contested: true`
- Собственные выводы (синтез) помечать `synthesis: true`
- Никогда не изменять файлы проекта
