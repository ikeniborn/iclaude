# Example: Claude API Research

**Scenario:** Исследование изменений и breaking changes в Claude API для обновления интеграции

## Input

```
/deep-research "Claude API claude-opus-4 breaking changes and new features 2026" --depth standard --focus api_changes,migration,deprecations
```

## Permission Gate

```
════════════════════════════════════════════
🔍 DEEP RESEARCH AGENT
════════════════════════════════════════════
Запрос: Claude API claude-opus-4 breaking changes and new features 2026
Глубина: standard
Ожидаемое время: ~3 мин
Поиски: ~5 WebSearch + ~10 WebFetch

Запустить исследование? [yes/no]
════════════════════════════════════════════
```

Пользователь отвечает: `yes`

## deep-research-request.toon

```json
{
  "deep_research_input": {
    "query": "Claude API claude-opus-4 breaking changes and new features 2026",
    "depth": "standard",
    "max_sources": 10,
    "focus_areas": ["api_changes", "migration", "deprecations"],
    "output_format": "structured",
    "caller": "user",
    "hints": {
      "prefer_official_docs": true,
      "recency_filter": "last 6 months",
      "language": "en",
      "exclude_domains": []
    }
  }
}
```

## Agent Search Strategy

Агент строит план поисков:
1. `"Claude API claude-opus-4 release notes breaking changes"`
2. `"Anthropic API deprecations 2026 migration guide"`
3. `"claude-opus-4 new features extended thinking API"`
4. `"site:docs.anthropic.com claude-opus-4"`
5. `"Anthropic SDK python update 2026"`

## deep-research-results.toon (вывод агента)

```
TOON:sources:v1
url|title|type|reliability|fetched|key_insights
https://docs.anthropic.com/claude/reference/release-notes|Claude API Release Notes|official_docs|high|true|claude-opus-4 added; thinking field required for extended thinking
https://docs.anthropic.com/claude/docs/migrating-to-claude-opus-4|Migration Guide|official_docs|high|true|max_tokens deprecated → use max_tokens_to_sample; New system prompt format
https://github.com/anthropics/anthropic-sdk-python/blob/main/CHANGELOG.md|Python SDK Changelog|github|high|true|SDK 0.25+ required; async client changes; new MessageStream API
https://www.anthropic.com/news/claude-opus-4|Claude Opus 4 Announcement|article|high|true|200K context; vision improvements; tool use v2
https://community.anthropic.com/t/migration-issues-opus-4/12345|Community Migration Thread|article|medium|true|Common issues: system prompt format; temperature default changed
https://pypi.org/project/anthropic/0.25.0|Anthropic SDK 0.25.0|official_docs|high|false|N/A
https://openrouter.ai/docs/models/claude-opus-4|OpenRouter Claude Opus 4|article|medium|true|Available via OpenRouter; same breaking changes apply
https://blog.example.com/claude-opus-4-tips|Claude Opus 4 Integration Tips|blog|low|false|N/A

---JSON---
{
  "deep_research_results": {
    "metadata": {
      "query": "Claude API claude-opus-4 breaking changes and new features 2026",
      "depth": "standard",
      "sources_found": 12,
      "sources_fetched": 6,
      "search_queries_used": 5,
      "timestamp": "2026-02-21T10:30:00Z",
      "duration_estimate": "~3 min"
    },
    "key_findings": [
      {
        "finding": "claude-opus-4 требует поле 'thinking' в запросе для использования Extended Thinking",
        "confidence": "high",
        "sources": ["https://docs.anthropic.com/claude/reference/release-notes"],
        "contested": false
      },
      {
        "finding": "Параметр max_tokens устарел в пользу max_tokens_to_sample (breaking change)",
        "confidence": "high",
        "sources": ["https://docs.anthropic.com/claude/docs/migrating-to-claude-opus-4", "https://github.com/anthropics/anthropic-sdk-python/blob/main/CHANGELOG.md"],
        "contested": false
      },
      {
        "finding": "Anthropic Python SDK версии 0.25+ обязателен для claude-opus-4",
        "confidence": "high",
        "sources": ["https://github.com/anthropics/anthropic-sdk-python/blob/main/CHANGELOG.md"],
        "contested": false
      },
      {
        "finding": "Значение temperature по умолчанию изменилось с 1.0 на 0.7 (потенциальный breaking change)",
        "confidence": "medium",
        "sources": ["https://community.anthropic.com/t/migration-issues-opus-4/12345"],
        "contested": true
      }
    ],
    "detailed_findings": {
      "api_changes": {
        "summary": "Несколько breaking changes в API параметрах и формате ответов",
        "key_points": [
          "max_tokens переименован в max_tokens_to_sample",
          "Поле 'thinking' стало обязательным для Extended Thinking режима",
          "Формат system prompt изменился (теперь отдельный параметр, не в messages[])",
          "Tool use API обновлён до v2 с новой структурой tool_choice"
        ],
        "sources": ["https://docs.anthropic.com/claude/reference/release-notes", "https://docs.anthropic.com/claude/docs/migrating-to-claude-opus-4"],
        "contested_points": []
      },
      "migration": {
        "summary": "Официальный migration guide покрывает основные изменения",
        "key_points": [
          "Обновить SDK: pip install anthropic>=0.25.0",
          "Заменить max_tokens → max_tokens_to_sample",
          "Переместить system из messages[0] в отдельный параметр",
          "Обновить tool definitions для tool use v2"
        ],
        "sources": ["https://docs.anthropic.com/claude/docs/migrating-to-claude-opus-4"],
        "contested_points": []
      },
      "deprecations": {
        "summary": "Несколько устаревших параметров с датами удаления",
        "key_points": [
          "max_tokens — deprecated, удалят в 2026 Q3",
          "Legacy /v1/complete endpoint — deprecated",
          "metadata.user_id — переименован в metadata.user"
        ],
        "sources": ["https://docs.anthropic.com/claude/reference/release-notes"],
        "contested_points": []
      }
    },
    "contradictions": [
      {
        "topic": "Значение temperature по умолчанию",
        "position_a": {
          "claim": "temperature по умолчанию изменилось с 1.0 на 0.7",
          "source": "https://community.anthropic.com/t/migration-issues-opus-4/12345"
        },
        "position_b": {
          "claim": "temperature по умолчанию остаётся 1.0",
          "source": "https://docs.anthropic.com/claude/reference/release-notes"
        },
        "resolution": "position_b_stronger"
      }
    ],
    "gaps": [
      "Нет информации о pricing изменениях для claude-opus-4",
      "Rate limits для нового модела не задокументированы публично"
    ],
    "sources": "<<TOON:sources>>",
    "recommendations": {
      "for_caller": "user",
      "action_items": [
        "Обновить anthropic SDK до >=0.25.0",
        "Заменить max_tokens на max_tokens_to_sample",
        "Проверить system prompt format в текущем коде",
        "Протестировать tool use если используется"
      ],
      "further_research_needed": [
        "Pricing для claude-opus-4 (проверить на console.anthropic.com)",
        "Rate limits для production использования"
      ],
      "confidence_overall": "high"
    }
  }
}
```

## Output к пользователю

```
════════════════════════════════════════════
📊 DEEP RESEARCH RESULTS
════════════════════════════════════════════
Запрос: Claude API claude-opus-4 breaking changes and new features 2026
Источников: 6/12 прочитано
Уверенность: high

Ключевые выводы:
  1. claude-opus-4 требует поле 'thinking' для Extended Thinking [high]
  2. max_tokens переименован в max_tokens_to_sample (breaking) [high]
  3. Python SDK >=0.25.0 обязателен [high]
  4. temperature default — противоречие: community vs official docs [medium] ⚠️

⚠️ Противоречия (1):
  - temperature default: "изменился на 0.7" (community) vs "остаётся 1.0" (official docs)
     → Рекомендация: доверять официальной документации

Пробелы в данных:
  - Нет информации о pricing изменениях
  - Rate limits не задокументированы публично

Источники (8, показаны ТОП-5):
  ★ Claude API Release Notes (official_docs)
  ★ Migration Guide to claude-opus-4 (official_docs)
  ★ Python SDK Changelog v0.25 (github)
  ★ Claude Opus 4 Announcement (article)
  ★ Community Migration Thread (article)

Рекомендации:
  → Обновить anthropic SDK до >=0.25.0
  → Заменить max_tokens на max_tokens_to_sample
  → Проверить system prompt format
  → Протестировать tool use если используется

Workspace: /path/to/project/.claude/workspace/2026-02-21T1030
════════════════════════════════════════════

Что дальше?
1. Сохранить результаты в docs/
2. Запустить глубже (--depth deep)
3. Исследовать конкретный аспект
4. Запустить полный пайплайн (/agent-orchestrator) с этими данными
5. Завершить
```

## Explanation

Этот пример показывает:
- Использование `--focus` для прицельного исследования конкретных областей
- Обработку противоречий между источниками (community vs official)
- TOON формат для >= 8 источников
- Вывод с четкими action items и пробелами в данных
