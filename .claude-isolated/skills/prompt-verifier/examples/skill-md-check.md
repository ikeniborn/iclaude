# Example: Проверка SKILL.md с нестандартными именами разделов

## Сценарий

Разработчик написал SKILL.md для нового скилла. Нарушения в именах разделов и неинформативные имена файлов в документации.

## Входные данные

```json
{
  "prompt_verification": {
    "content": "# My Data Tool\n\nThis skill processes data.\n\n## Usage Guidelines and Operational Procedures\n\nTo use this skill, you need to provide input data. The tool will process it and return results. Make sure the data is valid JSON format and contains required fields.\n\n## Input/Output Documentation Reference\n\nSee guide.md for details on input format. Also check notes.md for examples.\n\n## Error Management and Recovery Procedures\n\nIf errors occur, check the logs. Contact support if issues persist.",
    "mode": "adapt",
    "rules_focus": ["R3", "R6", "R7"]
  }
}
```

Обратите внимание: `rules_focus` ограничивает проверку только тремя правилами — полезно для целевого рефакторинга.

## Результат

```json
{
  "verification": {
    "score": 4,
    "rules_passed": ["R1", "R2", "R4", "R5"],
    "violations": [
      {
        "rule": "R3",
        "rule_name": "Описательные имена файлов",
        "severity": "warning",
        "fragment": "See guide.md for details on input format. Also check notes.md for examples.",
        "consequence": "Когда агент просматривает список файлов проекта, guide.md и notes.md заставляют его открыть файл прежде чем понять его назначение. Это тратит tool calls и внимание.",
        "fix": "Переименовать: guide.md → data-input-format.md, notes.md → usage-examples.md"
      },
      {
        "rule": "R6",
        "rule_name": "Стандартные имена разделов",
        "severity": "critical",
        "fragment": "## Usage Guidelines and Operational Procedures\n## Input/Output Documentation Reference\n## Error Management and Recovery Procedures",
        "consequence": "Три раздела с нестандартными именами. Агент обучен на ## Usage, ## Input, ## Output, ## Errors — эти имена несут встроенный контекст. Длинные кастомные названия — шум, а не сигнал.",
        "fix": "## Usage → ## Input → ## Output → ## Errors"
      },
      {
        "rule": "R7",
        "rule_name": "Выполнимые инструкции",
        "severity": "critical",
        "fragment": "Make sure the data is valid JSON format and contains required fields.",
        "consequence": "«Make sure the data is valid» — агент не знает как именно это проверить прямо сейчас.",
        "fix": "Заменить на: Входные данные должны пройти валидацию: `jq . input.json` — проверить JSON; обязательные поля: `id`, `type`, `payload`"
      }
    ],
    "summary": "Score 4/7 (проверялись только R3, R6, R7). Критично: нестандартные имена разделов (R6) и расплывчатые инструкции (R7). Неинформативные имена файлов (R3) снижают навигацию агента."
  },
  "adaptation": {
    "adapted_document": "# My Data Tool\n\nПроцессинг структурированных данных.\n\n## Usage\n\nПередать JSON с обязательными полями `id`, `type`, `payload`.\n\n## Input\n\nСм. [data-input-format.md](data-input-format.md) — полная схема входных данных\n\nВалидация входных данных:\n```bash\njq . input.json\n```\n\n## Output\n\nСм. [usage-examples.md](usage-examples.md) — примеры результатов\n\n## Errors\n\nПроверить логи:\n```bash\njournalctl -u my-data-tool --since '1 hour ago'\n```\n\nЕсли ошибка повторяется — создать issue с текстом из логов.",
    "changes_made": [
      "R6: 'Usage Guidelines and Operational Procedures' → '## Usage'",
      "R6: 'Input/Output Documentation Reference' → '## Input' + '## Output'",
      "R6: 'Error Management and Recovery Procedures' → '## Errors'",
      "R7: 'make sure the data is valid' → конкретная команда jq с обязательными полями",
      "R7: 'check the logs, contact support' → конкретная команда journalctl",
      "R3: guide.md → data-input-format.md, notes.md → usage-examples.md"
    ],
    "word_count_before": 94,
    "word_count_after": 62,
    "reduction_percent": 34
  }
}
```

## Ключевой вывод

`rules_focus` позволяет сделать целевой аудит конкретных правил — удобно когда общая структура уже хорошая, но нужно точечно исправить имена разделов или выполнимость инструкций.
