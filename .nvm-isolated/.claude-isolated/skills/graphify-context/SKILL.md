---
name: graphify-context
description: Use when exploring project architecture, component relationships, or codebase structure — especially at brainstorming Step 1 or when the user asks how parts of the system connect. Reads .graphify/ knowledge graph without rebuilding it.
user-invocable: true
context: fork
# version: 1.1.0
# tags: graphify, knowledge-graph, context, architecture, brainstorming
# used-by: context-awareness, brainstorming
---

# Graphify Context

Query the project knowledge graph for component relationships, key abstractions, and architectural patterns. Complements llm-wiki: wiki gives synthesized prose, graph gives structural connectivity.

## Когда использовать

| Ситуация | Действие |
|----------|---------|
| Brainstorming Step 1 (Explore project context) | Читать GRAPH_REPORT.md + 1 targeted query |
| Пользователь спрашивает "как X связан с Y?" | `graphify path "X" "Y"` |
| Нужно понять роль компонента | `graphify explain "ClassName"` |
| Обзор архитектуры целиком | Читать god_nodes + communities из GRAPH_REPORT.md |
| Граф устарел (после изменений кода) | `graphify update .` (бесплатно для code-only) |

## Args интерфейс

```bash
# Без args — обзор архитектуры (используется context-awareness)
Skill(skill="graphify-context")

# С query — точечный запрос по теме
Skill(skill="graphify-context", args='query "как X связан с Y?"')
Skill(skill="graphify-context", args='query "entry points" --dfs')
Skill(skill="graphify-context", args='path "ComponentA" "ComponentB"')
Skill(skill="graphify-context", args='explain "ClassName"')
```

Без args → выполнить Phase 0 + Phase 1 (быстрый обзор + 1 query на архитектуру).
С `query "..."` → Phase 0 + targeted `graphify query "<вопрос>"`.
С `path A B` / `explain X` → Phase 0 + соответствующий graphify CLI вызов.

## Phase 0: Определение наличия графа

```
IF exists {CWD}/.graphify/GRAPH_REPORT.md:
  1. Прочитать GRAPH_REPORT.md
     → извлечь: god_nodes (топ-5), communities (N), suggested_questions
  2. Проверить свежесть:
     built_at_commit из GRAPH_REPORT.md == `git rev-parse HEAD`?
     Если нет → предупредить: "Граф устарел, запусти graphify update ."
  3. Перейти к Phase 1

ELSE:
  graph_initialized: false
  Сообщить: "Граф не найден. Запусти /graphify для построения."
  Остановиться.
```

## Phase 1: Запросы к графу

### Быстрый обзор (без CLI — бесплатно)

GRAPH_REPORT.md содержит готовый структурный обзор:
- **God Nodes** — ядро системы (самые связанные компоненты)
- **Communities** — кластеры (функциональные модули)
- **Surprising Connections** — неочевидные зависимости
- **Suggested Questions** — вопросы, которые граф готов ответить

Читай GRAPH_REPORT.md напрямую вместо CLI когда нужен быстрый обзор.

### Targeted Query (CLI)

```bash
# Широкий обзор компонентов (BFS)
graphify query "What are the core components and how do they connect?" --budget 1200

# Трассировка конкретного пути (DFS)
graphify query "How does <entry_point> reach <target>?" --dfs --budget 1000

# Связь между двумя конкретными узлами
graphify path "ComponentA" "ComponentB"

# Полный контекст одного узла
graphify explain "ClassName"

# Любой вопрос по архитектуре
graphify query "<вопрос от пользователя>" --budget 1500
```

**Выбор режима:**
- BFS (по умолчанию) → широкий контекст, все соседи
- `--dfs` → трассировка цепочки вызовов, глубокий путь
- `graphify path` → минимальный путь между двумя точками
- `graphify explain` → один узел со всеми рёбрами

## Output: graph_context

```json
{
  "graph_context": {
    "initialized": true,
    "fresh": true,
    "god_nodes": ["ComponentA (20 edges)", "ComponentB (13 edges)"],
    "communities": 8,
    "graph_summary": "2-3 предложения: ключевые компоненты, их роли, главные зависимости",
    "suggested_questions": ["...", "..."]
  }
}
```

## Интеграция с context-awareness

context-awareness вызывает этот навык в Phase 6 (аналогично тому, как Phase 5 вызывает llm-wiki):

```
IF exists {CWD}/.graphify/GRAPH_REPORT.md:
  Skill(skill="graphify-context")
  → добавить результат в project_context:
       graph_initialized: true
       graph_god_nodes: [из graph_context.god_nodes]
       graph_communities: graph_context.communities
       graph_summary: graph_context.graph_summary

ELSE:
  graph_initialized: false, graph_god_nodes: [], graph_communities: 0, graph_summary: null
```

`context: fork` изолирует работу навыка — чтение GRAPH_REPORT.md и вывод `graphify query` не попадают в основной контекст, только финальный `graph_context` JSON.

## Интеграция с brainstorming

На шаге 1 "Explore project context", ПОСЛЕ context-awareness:

1. Если `graph_initialized: true` → включить `graph_summary` в контекст проекта
2. Если тема brainstorming затрагивает конкретные компоненты → 1 дополнительный `graphify query` по теме
3. God nodes = вероятные точки интеграции → проверить на пересечение с дизайном

## Примеры использования

```bash
# При brainstorming "добавить новый модуль в iclaude"
graphify query "What are the module integration points in lib/?" --budget 1200

# При вопросе "как PII-прокси связан с тестами?"
graphify path "PIIProxyHandler" "TestShouldRedact"

# При обзоре архитектуры целиком
# → просто читать .graphify/GRAPH_REPORT.md, не вызывать CLI
```

## Когда НЕ использовать

- Граф отсутствует (`.graphify/` нет) — нечего запрашивать
- Проект < 20 файлов — граф добавит шум, не ценность
- Нужно ПЕРЕСТРОИТЬ граф — используй `/graphify` или `graphify-update`
- Вопрос не об архитектуре, а о бизнес-логике — используй `llm-wiki query`
