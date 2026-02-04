---
name: iclaude-validation
version: 1.0.0
description: Multi-perspective analysis and validation loop for iclaude.sh development
user-invocable: false
dependencies: [context-awareness, lsp-integration]
tags: [validation, iclaude, bash, multi-perspective]
files:
  - path: SKILL.md
    type: markdown
  - path: examples/add-flag.md
    type: markdown
  - path: examples/multi-perspective.md
    type: markdown
  - path: examples/validation-checkpoints.md
    type: markdown
---

# iclaude-validation

Применение многоперспективного анализа и validation loop для разработки iclaude.sh.

## When to Use

**Auto-invoked** when `project_context.type == "bash-wrapper"` (detected by context-awareness).

Применяется для:
- Анализа изменений bash-скрипта с точки зрения 5 ролей
- Планирования validation checkpoints на каждой фазе
- Интеграции LSP/code-review/тестов в validation flow

## How It Works

### Step 1: Multi-Perspective Analysis

Рассматривает задачу с точки зрения 5 ключевых ролей:
- **System Architect** - инфраструктура, масштабируемость, отказоустойчивость
- **Backend Developer** - обработка данных, ресурсы, API эффективность
- **Security Specialist** - уязвимости, защита данных, best practices
- **DevOps Engineer** - портируемость, CI/CD, reproducibility
- **Technical Writer** - актуальность документации, синхронизация с кодом

Для каждой роли выводит:
- Concerns (потенциальные проблемы)
- Recommendations (рекомендации по решению)

**См. подробный пример:** `examples/multi-perspective.md`

### Step 2: Validation Loop Planning

Определяет checkpoints для валидации на каждой фазе:

| Phase | Tools | Example |
|-------|-------|---------|
| PHASE 0 | LSP (shellcheck) | SC2086, SC2155, SC2181 |
| PHASE 1 | bash -n | Syntax errors |
| PHASE 3 | @skill:code-review | Security, performance |
| PHASE 4 | Integration tests | `--test`, `--isolated-install` |
| PHASE 5 | Documentation sync | CLAUDE.md locations |

**См. подробный пример:** `examples/validation-checkpoints.md`

### Step 3: Execute Validation Loop

Выполняет все checkpoints последовательно:
1. LSP (blocking) → если ошибки, stop
2. Syntax check (blocking) → если ошибки, stop
3. Code review (warnings OK)
4. Предлагает integration test команды
5. Напоминает о documentation sync

## Output Format

```json
{
  "multi_perspective_analysis": {
    "system_architect": {"concerns": [...], "recommendations": [...]},
    "backend_developer": {"concerns": [...], "recommendations": [...]},
    "security_specialist": {"concerns": [...], "recommendations": [...]},
    "devops_engineer": {"concerns": [...], "recommendations": [...]},
    "technical_writer": {"concerns": [...], "recommendations": [...]}
  },
  "validation_plan": {
    "phase_0_lsp": {"tool": "shellcheck", "blocking": true},
    "phase_1_syntax": {"tool": "bash -n", "blocking": true},
    "phase_3_code_review": {"tool": "@skill:code-review", "blocking": false},
    "phase_4_integration": {"test_cases": [...]},
    "phase_5_documentation": {"updates": [...]}
  },
  "validation_results": {
    "phase_0_lsp": {"status": "passed", "errors": []},
    "phase_1_syntax": {"status": "passed"},
    "phase_3_code_review": {"status": "passed_with_warnings"},
    "phase_4_integration": {"status": "pending"},
    "phase_5_documentation": {"status": "pending"}
  }
}
```

## Integration

**Input:** `task_description`, `project_context` (from context-awareness)
**Output:** `validation_plan`, `multi_perspective_analysis`, `validation_results`

**Consumers:**
- code-review → Security/performance checks
- git-workflow → Pre-commit validation
- User → Test commands to run

## Examples

- **Adding --flag:** `examples/add-flag.md` - Complete workflow (multi-perspective → validation → testing)
- **Multi-perspective analysis:** `examples/multi-perspective.md` - Analyzing refactoring task
- **Validation checkpoints:** `examples/validation-checkpoints.md` - Planning test strategy

## Best Practices

✅ **DO:**
- Ask specific questions for each role
- Consider edge cases (network failures, partial installations)
- Run LSP/syntax checks FIRST (blocking)
- Update CLAUDE.md after code changes

❌ **DON'T:**
- Skip perspectives (all 5 required)
- Ignore shellcheck warnings (SC2086, SC2155 are critical)
- Commit without documentation update

## Notes

- This skill is **iclaude-specific** (not applicable to other projects)
- Multi-perspective analysis is **mandatory** (not optional)
- Integrates with lsp-integration (shellcheck) and code-review
