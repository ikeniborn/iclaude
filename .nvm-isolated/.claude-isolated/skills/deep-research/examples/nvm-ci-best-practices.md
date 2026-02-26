# Example: NVM CI/CD Best Practices Research

**Scenario:** Поиск актуальных best practices для изоляции NVM environments в CI/CD системах (прямой вызов shallow depth)

## Input

```
/deep-research "NVM isolated environments CI/CD best practices 2025 2026" --depth shallow --sources 5
```

## Permission Gate

```
════════════════════════════════════════════
🔍 DEEP RESEARCH AGENT
════════════════════════════════════════════
Запрос: NVM isolated environments CI/CD best practices 2025 2026
Глубина: shallow
Ожидаемое время: ~1 мин
Поиски: ~2-3 WebSearch + ~5 WebFetch

Запустить исследование? [yes/no]
════════════════════════════════════════════
```

Пользователь: `yes`

## deep-research-request.toon

```json
{
  "deep_research_input": {
    "query": "NVM isolated environments CI/CD best practices 2025 2026",
    "depth": "shallow",
    "max_sources": 5,
    "focus_areas": [],
    "output_format": "structured",
    "caller": "user",
    "hints": {
      "prefer_official_docs": true,
      "recency_filter": "last 12 months",
      "language": "en",
      "exclude_domains": []
    }
  }
}
```

## Agent Search Strategy (shallow)

Только 2-3 поиска:
1. `"NVM node version manager isolated environment CI/CD 2025"`
2. `"GitHub Actions Node.js NVM isolation best practices"`

## deep-research-results.toon (shallow, <8 источников — чистый JSON)

```
---JSON---
{
  "deep_research_results": {
    "metadata": {
      "query": "NVM isolated environments CI/CD best practices 2025 2026",
      "depth": "shallow",
      "sources_found": 6,
      "sources_fetched": 4,
      "search_queries_used": 2,
      "timestamp": "2026-02-21T11:00:00Z",
      "duration_estimate": "~1 min"
    },
    "key_findings": [
      {
        "finding": "Использование .nvmrc файла в репозитории обеспечивает воспроизводимость версии Node.js в CI",
        "confidence": "high",
        "sources": ["https://github.com/nvm-sh/nvm#nvmrc", "https://docs.github.com/en/actions/use-cases-and-examples/building-and-testing/building-and-testing-nodejs"],
        "contested": false
      },
      {
        "finding": "Кэширование ~/.nvm/versions/ сокращает время CI на 60-80% при повторных запусках",
        "confidence": "medium",
        "sources": ["https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows"],
        "contested": false
      },
      {
        "finding": "NVM_DIR=~/.nvm-isolated позволяет изолировать окружение без влияния на системный Node.js",
        "confidence": "high",
        "sources": ["https://github.com/nvm-sh/nvm#installation-and-update"],
        "contested": false
      }
    ],
    "detailed_findings": {
      "isolation_strategies": {
        "summary": "Несколько подходов к изоляции NVM в CI: custom NVM_DIR, Docker, или встроенные actions",
        "key_points": [
          "Custom NVM_DIR: NVM_DIR=/project/.nvm nvm install → полная изоляция",
          "Docker: official node:18-alpine image без NVM → проще но менее гибко",
          "actions/setup-node@v4 + cache: 'npm' → рекомендуется для GitHub Actions",
          "nvm use автоматически подхватывает .nvmrc если файл в репозитории"
        ],
        "sources": [
          "https://github.com/nvm-sh/nvm#installation-and-update",
          "https://docs.github.com/en/actions/use-cases-and-examples/building-and-testing/building-and-testing-nodejs"
        ],
        "contested_points": []
      }
    },
    "contradictions": [],
    "gaps": [
      "Нет сравнительных benchmarks NVM isolation vs Docker для конкретных случаев",
      "Мало информации о NVM в GitLab CI / Azure Pipelines"
    ],
    "sources": [
      {
        "url": "https://github.com/nvm-sh/nvm#nvmrc",
        "title": "NVM Documentation: .nvmrc",
        "type": "official_docs",
        "reliability": "high",
        "fetched": true,
        "key_insights": [".nvmrc содержит версию Node.js", "nvm use автоопределяет версию из файла"]
      },
      {
        "url": "https://docs.github.com/en/actions/use-cases-and-examples/building-and-testing/building-and-testing-nodejs",
        "title": "GitHub Actions: Building and testing Node.js",
        "type": "official_docs",
        "reliability": "high",
        "fetched": true,
        "key_insights": ["actions/setup-node рекомендован для GHA", "Кэширование npm через cache: 'npm'"]
      },
      {
        "url": "https://github.com/nvm-sh/nvm#installation-and-update",
        "title": "NVM Installation and Environment Variables",
        "type": "official_docs",
        "reliability": "high",
        "fetched": true,
        "key_insights": ["NVM_DIR переменная контролирует расположение NVM", "Изменение NVM_DIR изолирует окружение"]
      },
      {
        "url": "https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows",
        "title": "Caching dependencies in GitHub Actions",
        "type": "official_docs",
        "reliability": "high",
        "fetched": true,
        "key_insights": ["Кэшировать ~/.nvm/versions/ для ускорения", "cache-key: hashFiles('.nvmrc')"]
      }
    ],
    "recommendations": {
      "for_caller": "user",
      "action_items": [
        "Добавить .nvmrc файл с версией Node.js в репозиторий",
        "Использовать actions/setup-node@v4 с cache: 'npm' для GitHub Actions",
        "Установить NVM_DIR в изолированную директорию для параллельных builds"
      ],
      "further_research_needed": [
        "Сравнение NVM vs Docker для CI изоляции (если нужно)"
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
Запрос: NVM isolated environments CI/CD best practices 2025 2026
Источников: 4/6 прочитано
Уверенность: high

Ключевые выводы:
  1. .nvmrc в репозитории = воспроизводимость версии [high]
  2. Кэширование ~/.nvm/versions/ сокращает CI на 60-80% [medium]
  3. NVM_DIR кастомный — полная изоляция без влияния на систему [high]

Пробелы в данных:
  - Нет benchmarks NVM vs Docker
  - Мало данных по GitLab CI / Azure Pipelines

Источники (4, все официальные):
  ★ NVM Documentation: .nvmrc (official_docs)
  ★ GitHub Actions: Building Node.js (official_docs)
  ★ NVM Installation and Environment Variables (official_docs)
  ★ Caching dependencies in GitHub Actions (official_docs)

Рекомендации:
  → Добавить .nvmrc с версией Node.js
  → Использовать actions/setup-node@v4 + cache: 'npm'
  → Установить кастомный NVM_DIR для изоляции

Workspace: /path/to/project/.claude/workspace/2026-02-21T1100
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
- Использование `shallow` depth для быстрого обзора (1-2 мин)
- JSON формат без TOON (менее 8 источников)
- Отсутствие противоречий (только официальная документация)
- Конкретные action items с практическими рекомендациями
- Честное указание пробелов (GitLab CI не покрыт)
