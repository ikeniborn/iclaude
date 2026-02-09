# Level 1: Structural Validation (BLOCKING)

## Цель
Проверить наличие обязательных разделов в плане.

## Проверки для Minimal Plans

- ✅ `task_name` present
- ✅ `problem` present
- ✅ `solution` present
- ✅ `critical_files` present (>= 1 файл)
- ✅ `implementation_steps` present (>= 1 step)
- ✅ `verification` present

## Проверки для Standard Plans

Все из minimal + дополнительно:
- ✅ `git_info.branch_name` present and valid pattern
- ✅ `git_info.commit_type` present and valid enum

## Проверки для Complex Plans

Все из standard + дополнительно:
- ✅ `risks` section present
- ✅ `dependencies` section present

## Scoring

- **Max score:** 25 points
- **Blocking:** Любой missing required section → BLOCKING

## Блокирующие критерии

- Отсутствует обязательный раздел для данного plan_type → BLOCKING
- Пример: standard plan без git_info → BLOCKING

## Example Output

```json
{
  "structural_validation": {
    "passed": true,
    "score": 25,
    "checks": [
      {"check": "frontmatter_complete", "status": "passed"},
      {"check": "critical_files_present", "status": "passed", "count": 3},
      {"check": "implementation_steps_present", "status": "passed", "count": 5}
    ],
    "blocking_issues": []
  }
}
```
