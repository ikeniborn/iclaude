# Basic Usage Example - approval-gates

## Scenario

Упрощённая система approval gates для подтверждения плана перед выполнением без создания полноценного plan file.

**Use cases:**
- Быстрое подтверждение простых планов (minimal complexity)
- Approval без перехода в plan mode
- Inline confirmation для стандартных задач

---

## Input

```json
{
  "task_plan_lite": {
    "task_name": "Fix login validation bug",
    "files": ["src/auth.py", "tests/test_auth.py"],
    "steps": [
      "Add email format validation",
      "Add unit tests for invalid emails",
      "Update error messages"
    ],
    "validation": "pytest tests/test_auth.py"
  }
}
```

---

## Execution

approval-gates skill выполняет следующие шаги:

### Step 1: Plan Summary
- Показать task_name, files, steps
- Оценка complexity: minimal (3 steps, 2 files)

### Step 2: User Approval Prompt
- Display plan в читаемом формате
- Ask: "Proceed with this plan? (y/n)"

### Step 3: Разрешения (allowedPrompts)
- Request permission для bash commands:
  - "run tests" (for pytest)
  - "modify files" (for src/auth.py, tests/test_auth.py)

---

## Output

**Approval prompt:**
```
📋 Plan: Fix login validation bug

📂 Files to change (2):
  - src/auth.py
  - tests/test_auth.py

📝 Steps (3):
  1. Add email format validation
  2. Add unit tests for invalid emails
  3. Update error messages

✅ Validation: pytest tests/test_auth.py

─────────────────────────────
Proceed with this plan? (y/n)
```

**After approval:**
```json
{
  "approval_status": "approved",
  "allowed_prompts": [
    {"tool": "Bash", "prompt": "run tests"},
    {"tool": "Bash", "prompt": "modify files in src/ and tests/"}
  ],
  "timestamp": "2026-01-15T14:45:00Z"
}
```

**Console output:**
```
✅ Plan approved by user
✓ Granted permissions:
  - run tests
  - modify files in src/ and tests/

🚀 Starting execution...
```

---

## Explanation

### Approval Gates vs Plan Mode:

**approval-gates (упрощённый):**
- Для minimal/standard tasks
- Inline approval (no plan file)
- Быстрее (1 prompt)
- Ограниченные permissions (только allowedPrompts)

**Plan Mode (полноценный):**
- Для complex tasks
- Создаёт plan file (`.claude-isolated/plans/`)
- Детальная проверка (risk analysis, execution steps)
- Granular permissions

### When to use approval-gates:

```
IF task_complexity == "minimal":
  Use approval-gates
ELSE IF task_complexity == "standard":
  Use approval-gates (optional)
ELSE:  # complex
  Use Plan Mode (EnterPlanMode tool)
```

### User rejection example:

```
Proceed with this plan? (y/n) → n

❌ Plan rejected by user

💬 User feedback: "Add integration tests too"

🔄 Updating plan...
```

**Updated plan:**
```
📝 Steps (4):
  1. Add email format validation
  2. Add unit tests for invalid emails
  3. Add integration tests for login flow  ← NEW
  4. Update error messages
```

### Permission scope:

```json
{
  "allowed_prompts": [
    {"tool": "Bash", "prompt": "run tests"},  // Matches: pytest, npm test, go test
    {"tool": "Bash", "prompt": "modify files in src/"}  // Scope: только src/
  ]
}
```

---

## Related

- [approval-gates/SKILL.md](../SKILL.md)
- [adaptive-workflow/SKILL.md](../adaptive-workflow/SKILL.md)
