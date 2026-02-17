---
name: validation-framework
description: Адаптивная валидация execution results с partial validation support (PHASE 4)
user-invocable: false
agent: Validation
---
<!-- version: 1.0.0 | tags: validation, execution, acceptance-criteria, testing, post-execution | dependencies: thinking-framework, error-handling, toon-skill | files: templates=./templates/*.json, schemas=./schemas/*.json, examples=./examples/*.md, rules=./rules/*.md -->

# Validation Framework

Post-execution validation system для проверки результатов выполнения (PHASE 4).

## Table of Contents

- [Когда использовать](#когда-использовать)
- [Validators](#validators)
- [Output Schema](#output-schema)
- [Integration](#integration)
- [TOON Optimization](#toon-optimization)
- [Examples](#examples)

## Когда использовать

**PHASE 4** - После execution (phase-execution, docker-skill, skill-generator, etc.)

### Триггеры активации

1. **После execution** - execution steps завершены
2. **Checkpoint 2** - в phase-execution для валидации results
3. **Acceptance validation** - в docker-skill, prd-generator для проверки compliance

### Что проверяется

- **Acceptance criteria met** - все acceptance criteria выполнены
- **Tests passed** - unit/integration tests прошли
- **Completion status** - задача завершена (все files modified, steps done)
- **No blocking errors** - нет критических ошибок

### Интеграция в workflow

```
PHASE 3: execution
         ↓
PHASE 4: validation-framework (THIS SKILL)
         ↓ IF failed
         error-handling + rollback-recovery
         ↓ IF passed
PHASE 5: git-workflow + pr-automation
```

## Validators

Три типа validators для different aspects валидации.

### Validator 1: Acceptance Criteria Validator

**Цель:** Проверить, что все acceptance criteria из task_plan выполнены.

**Input:**
- `task_plan.verification.acceptance_criteria[]`
- `execution_results.modified_files[]`
- `execution_results.test_results`

**Algorithm:**
```
for criterion in acceptance_criteria:
    # Check if criterion is met
    met = verify_criterion(criterion, execution_results)

    if not met:
        errors.append(f"Acceptance criterion not met: {criterion}")

status = "passed" if errors.length == 0 else "failed"
```

**Examples:**
- ✅ "Login endpoint returns 200 OK with valid JWT" → Check response code
- ✅ "User model has email field" → Check file contains field definition
- ❌ "Performance < 100ms" → Measure execution time

**Output:**
```json
{
  "validator_name": "Acceptance Criteria",
  "status": "passed|failed",
  "errors": ["Criterion X not met"],
  "info": ["3/3 criteria met"]
}
```

### Validator 2: Test Suite Validator

**Цель:** Запустить validation commands и проверить test results.

**Input:**
- `task_plan.verification.validation_commands[]`

**Algorithm:**
```
for command in validation_commands:
    # Run command via Bash tool
    result = run_command(command)

    # Parse output (pytest, jest, npm test, etc.)
    parsed = parse_test_output(result.stdout, command)

    if parsed.failed > 0 or result.exit_code != 0:
        errors.append(f"Tests failed: {parsed.failed} failures")

status = "passed" if errors.length == 0 else "failed"
```

**Parsers:**
- **pytest:** `X passed, Y failed` → extract counts
- **jest:** `Tests: X failed, Y passed` → extract counts
- **npm test:** Check exit code (0 = success)
- **cargo test:** `test result: ok. X passed` → extract count

**Output:**
```json
{
  "validator_name": "Test Suite",
  "status": "passed|failed",
  "errors": ["3 tests failed"],
  "info": ["25 tests passed"]
}
```

### Validator 3: Completion Status Validator

**Цель:** Проверить, что задача завершена корректно.

**Checks:**
1. **All critical files modified** - все files из critical_files обновлены
2. **All steps completed** - все implementation_steps выполнены
3. **No blocking errors** - execution не завершен с критической ошибкой

**Algorithm:**
```
# Check files
for file in critical_files:
    if file.change_type == "modify":
        if not file_was_modified(file.file_path, execution_results):
            warnings.append(f"File {file.file_path} not modified")
    elif file.change_type == "create":
        if not file_was_created(file.file_path, execution_results):
            errors.append(f"File {file.file_path} not created")

# Check completion percentage
completion = calculate_completion(execution_results)
if completion < 1.0:
    warnings.append(f"Task only {completion*100}% complete")

status = "passed" if errors.length == 0 else "failed"
```

**Output:**
```json
{
  "validator_name": "Completion Status",
  "status": "passed|warning|failed",
  "errors": [],
  "warnings": ["1 file not modified"],
  "info": ["Task 80% complete"]
}
```

## Output Schema

Использует `validation_result` definition из `@shared:base-schema.json`.

### validation_result (уже в base-schema.json)

```json
{
  "validation_result": {
    "validator_name": "Acceptance Criteria|Test Suite|Completion Status",
    "status": "passed|failed|warning",
    "errors": ["error message 1", "error message 2"],
    "warnings": ["warning message 1"],
    "info": ["informational message"]
  }
}
```

### Aggregated Output

Для multiple validators:

```json
{
  "validation_results": [
    {
      "validator_name": "Acceptance Criteria",
      "status": "passed",
      "errors": [],
      "info": ["3/3 criteria met"]
    },
    {
      "validator_name": "Test Suite",
      "status": "failed",
      "errors": ["3 tests failed"],
      "info": []
    },
    {
      "validator_name": "Completion Status",
      "status": "warning",
      "warnings": ["1 file not modified"],
      "info": ["Task 80% complete"]
    }
  ],
  "overall_status": "failed",
  "summary": {
    "passed": 1,
    "failed": 1,
    "warnings": 1
  }
}
```

## Integration

### С phase-execution (checkpoint 2)

```
phase-execution executes steps
  ↓
validation-framework runs validators
  ↓ IF failed
error-handling triggered
  ↓ ELSE
checkpoint 2 passed
```

### С error-handling

```
validation_results → error-handling
  ↓ IF validation.status == "failed"
trigger rollback-recovery
  ↓ OR
retry execution with fixes
```

### С docker-skill, skill-generator, prd-generator

Эти skills используют validation-framework для acceptance validation:

```
# docker-skill
validation_results = validate_dockerfile(
    acceptance_criteria=[
        "Dockerfile builds successfully",
        "Image size < 500MB",
        "hadolint scan passes"
    ]
)

# skill-generator
validation_results = validate_skill(
    acceptance_criteria=[
        "SKILL.md has valid frontmatter",
        "All templates are valid JSON",
        "Schemas validate correctly"
    ]
)
```

## TOON Optimization

Когда применять: `validation_results.length >= 5`

**Формат TOON:**
```toon
validation_results[5]{validator,status,errors_count,warnings_count}:
  Acceptance Criteria,passed,0,0
  Test Suite,failed,3,0
  Completion Status,warning,0,1
  Schema Validation,passed,0,0
  File Structure,passed,0,0
```

**Token savings:** ~28% для 5+ validators

## Examples

### Example 1: Acceptance Passed
**File:** [examples/acceptance-passed.md](examples/acceptance-passed.md)
All acceptance criteria met, tests passed, completion 100%.

### Example 2: Tests Failed
**File:** [examples/tests-failed.md](examples/tests-failed.md)
3 tests failed → triggers error-handling.

### Example 3: Partial Validation
**File:** [examples/partial-validation.md](examples/partial-validation.md)
Completion 80%, warnings but passed.

## References

- `@shared:base-schema.json` - validation_result definition
- **thinking-framework** - Analytical reasoning for criterion verification
- **error-handling** - Retry logic when validation fails
- **toon-skill** - JSON ↔ TOON conversion

## Changelog

### v1.0.0 (2026-02-09)

- ✅ Initial release
- ✅ 3 validators (acceptance, tests, completion)
- ✅ Integration with phase-execution, error-handling
- ✅ TOON optimization for 5+ results
