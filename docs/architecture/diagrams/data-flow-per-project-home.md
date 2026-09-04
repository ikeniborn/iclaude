# Поток создания per-project дома и миграции

Показывает, как запуск в per-project режиме (по умолчанию с S5) строит дом проекта:
резолюция id, наполнение под локом, миграция среза общего состояния.

## Создаваемые артефакты

| Путь | Описание |
|------|----------|
| `.claude-homes/<project>-<hash>/` | Дом проекта (= `CLAUDE_CONFIG_DIR`) |
| `.claude-homes/<id>/home.json` | Маркер: корень проекта, дата, schema |
| `.claude-homes/<id>/skills, hooks, …` | Симлинки на общий стор (10 managed-имён) |
| `.claude-homes/<id>/settings.json` | Копия шаблона + зеркало машинных ключей |
| `.claude-homes/<id>/.claude.json` | Мигрированный срез (только своя запись projects) |
| `.claude-homes/<id>/.iclaude.lock` | Лок наполнения дома (flock, fail-soft) |

## Диаграмма

```mermaid
graph TD
    %% Per-Project Home Flow (S1-S8)
    USER[User] -->|1. iclaude launch| CFG[setup_isolated_config]
    CFG -->|2. ICLAUDE_HOME_MODE?| MODE{per-project<br/>default}
    MODE -->|shared| SHARED[.claude-isolated<br/>legacy escape hatch]
    MODE -->|per-project| RESOLVE[resolve_project_root<br/>git toplevel or pwd -P]

    RESOLVE -->|3. id = basename-sha256:12| HOME[.claude-homes/id/]
    HOME -->|4. flock .iclaude.lock 30s| POP[_populate_claude_home]

    POP -->|5. marker| MARKER[home.json<br/>project_root, created, schema]
    POP -->|6. symlinks| LINKS[link_shared_assets<br/>skills, hooks, plugins, mcp,<br/>CLAUDE.md, .credentials.json, ...]
    LINKS -.->|read-only| STORE[Общий стор<br/>.claude-isolated/]
    POP -->|7. seed + sync| SETTINGS[settings.json<br/>copy-once + machine-keys mirror]
    POP -->|8. first launch only| MIGRATE[migrate_home_from_store<br/>.claude.json slice, projects/,<br/>history.jsonl filtered]
    MIGRATE -.->|copy-only, store untouched| STORE

    POP -->|9. export| ENV[CLAUDE_CONFIG_DIR=home]
    ENV -->|10. startup checks| VERIFY[check_lockfile_changes +<br/>verify_claude_binary_hash warn-only]
    VERIFY -->|11. exec| CLAUDE[Claude Code<br/>sessions, history, state в доме]
```

## Ключевые свойства

- Стор никогда не мутируется путями запуска и миграции: откат = удаление дома
  (следующий запуск мигрирует заново).
- Все мутации дома идут под fail-soft `flock`: проблема с локом — предупреждение,
  не отказ.
- Уборка домов только явными командами `--list-homes` / `--clean-homes` /
  `--clean-home <id>` (сироты, с подтверждением) — launch-путь ничего не удаляет.
