# Example: Верификация инструкций агента — режим verify

## Сценарий

Инструкции для code-review агента. Нужно только выявить нарушения без переработки документа.

## Входные данные

```json
{
  "prompt_verification": {
    "content": "# Code Review Agent\n\nYou are a code review agent. Your job is to review code changes.\n\n#### Review Checklist\n##### Security\n###### Authentication\nCheck auth carefully.\n\n##### Performance\nLook at performance issues.\n\n## Quality Assurance Verification Process\n\nMake sure code quality is good. Follow standards. Check for bugs. Ensure tests pass.",
    "mode": "verify"
  }
}
```

## Результат верификации

```json
{
  "verification": {
    "score": 2,
    "rules_passed": ["R1", "R3"],
    "violations": [
      {
        "rule": "R2",
        "rule_name": "Плоская иерархия заголовков",
        "severity": "critical",
        "fragment": "#### Review Checklist\n##### Security\n###### Authentication",
        "consequence": "Вложенность h4/h5/h6 конкурирует за внимание с h2-разделами. Агент теряет ориентацию: какой уровень является главным? При h6 агент уже работает с деталями реализации, не с ключевыми правилами.",
        "fix": "Уплостить до максимум 3 уровней: ## Review Checklist → ### Security → ### Performance. Если нужен h4 — вынести в отдельный файл."
      },
      {
        "rule": "R5",
        "rule_name": "Команды в блоках кода",
        "severity": "warning",
        "fragment": "Ensure tests pass",
        "consequence": "Нет конкретной команды запуска тестов — агент не знает, что именно выполнить.",
        "fix": "Добавить: `npm test` или `pytest` — запуск перед апрувом PR"
      },
      {
        "rule": "R6",
        "rule_name": "Стандартные имена разделов",
        "severity": "critical",
        "fragment": "## Quality Assurance Verification Process",
        "consequence": "Нестандартное имя раздела не распознаётся мгновенно. Агент обучен на `## Testing`, `## Quality`, `## Conventions` — эти имена несут встроенный контекст. Длинные кастомные названия — это шум.",
        "fix": "Переименовать в `## Quality` или `## Conventions`"
      },
      {
        "rule": "R7",
        "rule_name": "Выполнимые инструкции",
        "severity": "critical",
        "fragment": "Make sure code quality is good. Follow standards. Check for bugs.",
        "consequence": "Агент не может выполнить «make sure quality is good» прямо сейчас. Тест 'выполни немедленно' провален для каждой фразы в этом разделе.",
        "fix": "Заменить на чеклист: [ ] `eslint --max-warnings 0` — нет предупреждений линтера; [ ] Покрытие тестами >= 80%; [ ] Нет SQL-инъекций и XSS в user inputs"
      },
      {
        "rule": "R4",
        "rule_name": "Заголовки для разделов",
        "severity": "warning",
        "fragment": "Check auth carefully.\n\nLook at performance issues.",
        "consequence": "Подсекции без чётких заголовков — инструкции конкурируют за внимание. Агент обрабатывает весь блок как один, а не разделяет по темам.",
        "fix": "Каждая тема в собственном подразделе с конкретным заголовком"
      }
    ],
    "summary": "Score 2/7. Главные проблемы: глубокая вложенность h4-h6 (R2) дезориентирует агента, нестандартное имя раздела (R6) снижает сигнал, расплывчатые инструкции (R7) не поддаются выполнению. Режим verify: адаптация не выполнялась."
  }
}
```

## Ключевой вывод

Режим `verify` полезен когда нужен быстрый аудит без немедленного применения изменений — например, для code review самого CLAUDE.md в PR или для понимания приоритетов рефакторинга.
