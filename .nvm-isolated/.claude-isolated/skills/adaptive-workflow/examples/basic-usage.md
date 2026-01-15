# Basic Usage Example - adaptive-workflow

## Scenario

Автоматический выбор workflow complexity (minimal/standard/complex) на основе анализа задачи, с адаптацией tools и validation под уровень сложности.

**Use cases:**
- Начало новой задачи (автоматический выбор workflow)
- Escalation с minimal → standard при обнаружении сложности
- Downgrade с complex → standard если задача проще

---

## Input

```json
{
  "task_description": "Fix validation bug in login form - email format check is too strict",
  "initial_analysis": {
    "files_affected_estimate": 2,
    "has_tests": true,
    "breaking_changes": false
  }
}
```

---

## Execution

adaptive-workflow skill выполняет следующие шаги:

### Step 1: Complexity Analysis
- **Files affected:** 2 (src/auth.py, tests/test_auth.py) → LOW
- **Breaking changes:** No → LOW
- **Dependencies impact:** None → LOW
- **Risk level:** Low → MINIMAL complexity

### Step 2: Workflow Selection
- **Decision:** MINIMAL workflow
- **Tools:** task-plan-lite (no JSON schema)
- **Approval:** approval-gates (упрощённый)
- **Validation:** Basic (syntax + tests)

### Step 3: Tool Configuration
- Skip thinking-framework (не нужен для minimal)
- Skip structured-planning (use task-plan-lite instead)
- Enable approval-gates для быстрого approval

---

## Output

```json
{
  "adaptive_workflow": {
    "selected_complexity": "minimal",
    "reasoning": "Bug fix в 2 файлах, no breaking changes, low risk",
    "workflow_config": {
      "planning": "task-plan-lite",
      "approval": "approval-gates",
      "execution": "direct",
      "validation": {
        "syntax_check": true,
        "type_check": false,
        "tests": true,
        "code_review": false
      }
    },
    "estimated_duration": "15-30 minutes"
  }
}
```

**Console output:**
```
🔍 Analyzing task complexity...

✓ Complexity: MINIMAL
  - 2 files affected
  - No breaking changes
  - Low risk

📋 Selected workflow: MINIMAL
  - Planning: task-plan-lite (быстрая)
  - Approval: approval-gates (упрощённая)
  - Validation: syntax + tests

⏱️  Estimated: 15-30 minutes
```

---

## Explanation

### Complexity Decision Matrix:

```
IF files_affected <= 3 AND breaking_changes == false AND risk == "low":
  → MINIMAL

ELSE IF files_affected <= 10 AND (tests OR low_risk):
  → STANDARD

ELSE:
  → COMPLEX
```

### Workflow Configurations:

**MINIMAL:**
```json
{
  "planning": "task-plan-lite",
  "approval": "approval-gates",
  "thinking": false,
  "validation": ["syntax", "tests"],
  "code_review": false
}
```

**STANDARD:**
```json
{
  "planning": "structured-planning",
  "approval": "approval-gates",
  "thinking": "implementation-thinking",
  "validation": ["syntax", "type_check", "tests"],
  "code_review": "automated"
}
```

**COMPLEX:**
```json
{
  "planning": "structured-planning + task-decomposition",
  "approval": "plan-mode",
  "thinking": "all-phases",
  "validation": ["full-suite"],
  "code_review": "detailed",
  "phases": "task-decomposition → phase-execution"
}
```

### Escalation Example:

```
# Start: MINIMAL workflow
Task: "Fix email validation"

# During execution: обнаружена complexity
❌ Found: 5 additional files need changes
❌ Found: Breaking change in API contract

🔄 Escalating to STANDARD workflow...

✓ Switching to structured-planning
✓ Enabling code-review
✓ Re-analyzing with full validation
```

**Updated workflow:**
```json
{
  "adaptive_workflow": {
    "selected_complexity": "standard",
    "escalation_reason": "More files affected than estimated, API contract change",
    "workflow_config": {
      "planning": "structured-planning",
      "validation": {
        "syntax_check": true,
        "type_check": true,
        "tests": true,
        "code_review": true
      }
    }
  }
}
```

### Downgrade Example:

```
# Start: COMPLEX workflow (user request)
Task: "Update documentation"

# Analysis: task simpler than expected
✓ Only markdown files affected
✓ No code changes
✓ No tests needed

🔄 Downgrading to MINIMAL workflow...

✓ Disabling unnecessary validation
✓ Using task-plan-lite
⏱️  Saving ~30 minutes
```

---

## Related

- [adaptive-workflow/SKILL.md](../SKILL.md)
- [structured-planning/SKILL.md](../structured-planning/SKILL.md)
- [task-decomposition/SKILL.md](../task-decomposition/SKILL.md)
