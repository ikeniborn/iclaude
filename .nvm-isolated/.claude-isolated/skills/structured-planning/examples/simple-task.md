# Пример: Добавление метода в сервис

## Контекст
- **Задача:** Добавить метод `calculate_total` в `BudgetService`
- **Сложность:** minimal
- **Файлов:** 1

## План (task_plan_lite)

```json
{
  "task_plan_lite": {
    "task_name": "Добавить calculate_total",
    "files": ["backend/app/services/budget_service.py"],
    "steps": [
      "Добавить метод calculate_total в класс BudgetService",
      "Реализовать логику суммирования"
    ],
    "validation": "python -m py_compile backend/app/services/budget_service.py"
  }
}
```

## Результат

```python
# backend/app/services/budget_service.py

class BudgetService:
    # ... existing methods ...

    def calculate_total(self, facts: list[BudgetFact]) -> Decimal:
        """Calculate total amount from budget facts."""
        return sum(fact.amount for fact in facts)
```

## Валидация
```bash
$ python -m py_compile backend/app/services/budget_service.py
# No output = success
```
