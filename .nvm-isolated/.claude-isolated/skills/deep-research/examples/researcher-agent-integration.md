# Example: Integration with Researcher Agent

**Scenario:** Researcher Agent автоматически вызывает Deep Research Agent когда Context7 недоступен и задача требует актуальных внешних данных (CALLER=researcher, без запроса разрешения у пользователя)

## Context

Оркестратор запустил Researcher Agent для задачи:
```
TASK: "Добавить поддержку claude-opus-4 в iclaude.sh через --model флаг"
```

Researcher нашёл в кодовой базе флаг `--model` и файл `lib/config/model.sh`, но
Context7 недоступен, а задача требует проверки актуального API модели.

## Что делает Researcher Agent

```
# В Шаге 3 AGENT.md Researcher проверяет Context7
mcp__context7__resolve_library_id({libraryName: "anthropic"})
→ ERROR: "Context7 plugin not available"

# Решает запустить Deep Research Agent вместо
# БЕЗ запроса разрешения (CALLER=researcher — разрешение уже получено от пользователя)
```

## Запись deep-research-request.toon (Researcher пишет)

```json
{
  "deep_research_input": {
    "query": "claude-opus-4 model ID string Anthropic API 2026 official documentation",
    "depth": "standard",
    "max_sources": 8,
    "focus_areas": ["model_id", "api_compatibility", "pricing"],
    "output_format": "structured",
    "caller": "researcher",
    "hints": {
      "prefer_official_docs": true,
      "recency_filter": "last 3 months",
      "language": "en",
      "exclude_domains": ["reddit.com", "stackoverflow.com"]
    }
  }
}
```

## Запуск Deep Research из Researcher Agent

```
# Researcher Agent читает AGENT.md Deep Research
AGENTS_DIR = /home/user/.nvm-isolated/.claude-isolated/agents
deep_research_md = Read("{AGENTS_DIR}/deep-research-agent/AGENT.md")

# Запускает субагент
Task(
  subagent_type="general-purpose",
  prompt=deep_research_md + """

WORKSPACE: /path/to/project/.claude/workspace/2026-02-21T1200
QUERY: claude-opus-4 model ID string Anthropic API 2026 official documentation
DEPTH: standard
MAX_SOURCES: 8
CALLER: researcher
"""
)
```

Агент начинает работу немедленно (без запроса у пользователя, т.к. CALLER=researcher).

## deep-research-results.toon (агент возвращает)

```
TOON:sources:v1
url|title|type|reliability|fetched|key_insights
https://docs.anthropic.com/claude/docs/models-overview|Models Overview|official_docs|high|true|claude-opus-4-5 model ID confirmed; claude-opus-4-0 deprecated
https://docs.anthropic.com/claude/reference/models|API Models Reference|official_docs|high|true|List of valid model strings; claude-opus-4-5 is latest
https://github.com/anthropics/anthropic-sdk-python/blob/main/src/anthropic/types.py|SDK Type Definitions|github|high|true|Model literal type includes claude-opus-4-5
https://console.anthropic.com/docs/api|API Console Docs|official_docs|high|false|Paywall
https://www.anthropic.com/pricing|Anthropic Pricing|official_docs|medium|true|claude-opus-4-5: $15/$75 per MTok input/output
https://openrouter.ai/anthropic/claude-opus-4-5|OpenRouter Model Info|article|medium|true|Available; same model string

---JSON---
{
  "deep_research_results": {
    "metadata": {
      "query": "claude-opus-4 model ID string Anthropic API 2026 official documentation",
      "depth": "standard",
      "sources_found": 8,
      "sources_fetched": 5,
      "search_queries_used": 4,
      "timestamp": "2026-02-21T12:05:00Z",
      "duration_estimate": "~2 min"
    },
    "key_findings": [
      {
        "finding": "Официальный model ID для Claude Opus 4: 'claude-opus-4-5'",
        "confidence": "high",
        "sources": [
          "https://docs.anthropic.com/claude/docs/models-overview",
          "https://docs.anthropic.com/claude/reference/models",
          "https://github.com/anthropics/anthropic-sdk-python/blob/main/src/anthropic/types.py"
        ],
        "contested": false
      },
      {
        "finding": "claude-opus-4-0 устарел и был заменён claude-opus-4-5",
        "confidence": "high",
        "sources": ["https://docs.anthropic.com/claude/docs/models-overview"],
        "contested": false
      },
      {
        "finding": "Pricing: $15 per MTok input, $75 per MTok output",
        "confidence": "medium",
        "sources": ["https://www.anthropic.com/pricing"],
        "contested": false
      }
    ],
    "detailed_findings": {
      "model_id": {
        "summary": "Корректный model ID для использования в API",
        "key_points": [
          "claude-opus-4-5 — актуальный идентификатор",
          "Также доступны: claude-sonnet-4-5, claude-haiku-4-5",
          "Формат: claude-{family}-{generation}"
        ],
        "sources": ["https://docs.anthropic.com/claude/docs/models-overview"],
        "contested_points": []
      },
      "api_compatibility": {
        "summary": "Совместимость с Messages API",
        "key_points": [
          "Поддерживает Messages API v1",
          "Extended thinking доступно",
          "Tool use поддерживается"
        ],
        "sources": ["https://docs.anthropic.com/claude/reference/models"],
        "contested_points": []
      }
    },
    "contradictions": [],
    "gaps": [
      "Rate limits не задокументированы публично (paywall на console.anthropic.com)"
    ],
    "sources": "<<TOON:sources>>",
    "recommendations": {
      "for_caller": "researcher",
      "action_items": [
        "Использовать 'claude-opus-4-5' как default model ID в --model флаге",
        "Добавить валидацию model string в lib/config/model.sh",
        "Рассмотреть список валидных моделей из SDK для validation"
      ],
      "further_research_needed": [],
      "confidence_overall": "high"
    }
  }
}
```

## Интеграция результатов в research.toon (Researcher Agent)

После получения результатов Researcher интегрирует их:

```json
{
  "research_results": {
    "project_context": { "..." : "..." },
    "codebase_analysis": { "..." : "..." },
    "architecture_analysis": { "..." : "..." },
    "risk_assessment": { "..." : "..." },
    "external_docs": {
      "context7_status": "PLUGIN_NOT_AVAILABLE",
      "deep_research_status": "COMPLETED",
      "docs_found": [
        {
          "source": "https://docs.anthropic.com/claude/docs/models-overview",
          "topic": "Claude model IDs",
          "key_insights": [
            "claude-opus-4-5 is the correct model ID",
            "claude-opus-4-0 deprecated"
          ]
        }
      ],
      "key_findings_summary": [
        "Официальный model ID: 'claude-opus-4-5'",
        "Pricing: $15/$75 per MTok",
        "Все три Messages API features поддерживаются"
      ]
    },
    "local_docs": { "..." : "..." },
    "recommendations": {
      "complexity_hint": "minimal",
      "key_insights": [
        "lib/config/model.sh — точка изменения для --model флага",
        "Default model ID должен быть 'claude-opus-4-5' (подтверждено веб-исследованием)"
      ]
    }
  }
}
```

## Completion Signal в Researcher Agent

```
════════════════════════════════════════════
✅ RESEARCH COMPLETE
════════════════════════════════════════════
Файл: /path/to/.claude/workspace/2026-02-21T1200/research.toon

Ключевые находки:
- Язык: bash
- Релевантных файлов: 4
- Сложность: minimal
- Ключевые insights:
  • lib/config/model.sh — точка изменения
  • Default model ID: 'claude-opus-4-5' (из Deep Research)
  • Нет breaking changes в аргументах API

Deep Research: COMPLETED (5 источников, уверенность: high)
Risks: 1 (all low)
════════════════════════════════════════════
```

## Explanation

Этот пример показывает:
- Автоматический вызов из Researcher Agent без запроса разрешения (CALLER=researcher)
- Корректную интеграцию результатов в `external_docs` секцию research.toon
- Как Planning Agent использует эти данные (default model ID известен до планирования)
- Важность поля `caller` для управления permission gate
- Graceful fallback когда Context7 недоступен
