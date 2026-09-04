# Example: Basic CLAUDE.md Verification — 3 нарушения, режим adapt

## Сценарий

Разработчик написал CLAUDE.md для Python-проекта. Агент периодически игнорирует правило запуска тестов и использует `rm -rf` в скриптах очистки.

## Входные данные

```json
{
  "prompt_verification": {
    "content": "# My Project\n\nThis project is a data pipeline tool. When working on this project always run tests before committing any changes. The command is pytest and it should be run from the root directory before committing. Also never use rm -rf because it can delete important files. You should follow best practices for code quality.\n\n## Setup\n\nRun setup.sh to get started with the project.",
    "mode": "adapt"
  }
}
```

## Результат верификации

```json
{
  "verification": {
    "score": 2,
    "rules_passed": ["R2", "R4"],
    "violations": [
      {
        "rule": "R1",
        "rule_name": "Обоснование запретов",
        "severity": "critical",
        "fragment": "never use rm -rf because it can delete important files",
        "consequence": "Агент понимает запрет, но не знает системных последствий. Без понимания «почему» агент может применять схожие опасные команды (find -delete, git clean -fdx) без ограничений.",
        "fix": "Никогда не используйте `rm -rf` — это безвозвратно удаляет файлы без корзины, включая untracked git-файлы, что приводит к потере данных. Вместо этого используйте `git clean -n` (dry-run) перед очисткой."
      },
      {
        "rule": "R5",
        "rule_name": "Команды в блоках кода",
        "severity": "critical",
        "fragment": "The command is pytest and it should be run from the root directory",
        "consequence": "pytest написан в прозе — агент воспринимает это как описание, а не исполняемую инструкцию. Именно поэтому правило игнорируется.",
        "fix": "Оформить как: `pytest` — запуск из корня проекта перед коммитом"
      },
      {
        "rule": "R7",
        "rule_name": "Выполнимые инструкции",
        "severity": "warning",
        "fragment": "You should follow best practices for code quality.",
        "consequence": "Агент не может выполнить инструкцию «follow best practices» — это пожелание, не инструкция. Что именно делать прямо сейчас?",
        "fix": "Заменить на конкретное: `ruff check --fix && ruff format` — запускать перед коммитом; аннотации типов для всех публичных функций."
      }
    ],
    "summary": "Score 2/7. Критические нарушения: команды в прозе (R5) объясняют игнорирование pytest агентом. Нет обоснования запрета rm -rf (R1) — агент не обобщит его на схожие команды. Расплывчатые инструкции качества (R7)."
  },
  "adaptation": {
    "adapted_document": "# My Project\n\nData pipeline tool.\n\n## Setup\n\n`bash setup.sh` — первоначальная настройка проекта\n\n## Testing\n\n`pytest` — запуск из корня проекта\n\n- Запускать перед каждым коммитом — CI блокирует PR с failing tests\n\n## Commands\n\n`ruff check --fix && ruff format` — форматирование и линтинг\n\n## Conventions\n\n- Аннотации типов для всех публичных функций\n- Не используйте `rm -rf` — безвозвратно удаляет файлы без корзины, включая untracked git-файлы. Используйте `git clean -n` (dry-run) для проверки перед очисткой.",
    "changes_made": [
      "R5: pytest перенесён в блок кода в раздел ## Testing",
      "R5: bash setup.sh оформлен в backticks",
      "R1: к запрету rm -rf добавлено обоснование и альтернатива",
      "R7: 'follow best practices' заменено на конкретные команды ruff",
      "R6: добавлены стандартные разделы ## Testing, ## Commands, ## Conventions",
      "R4: инструкции структурированы заголовками вместо прозы"
    ],
    "word_count_before": 82,
    "word_count_after": 57,
    "reduction_percent": 30
  }
}
```

## Ключевой вывод

Инструкция `pytest` выполнялась агентом ненадёжно именно из-за нарушения R5 — команда была написана в прозе. После оформления в блок кода и добавления в стандартный раздел `## Testing` агент начинает выполнять её стабильно.
