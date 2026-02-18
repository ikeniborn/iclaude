---
name: adaptive-workflow
description: Автоматический выбор сложности workflow
user-invocable: false
context: fork
---
<!-- version: 2.2.0 | tags: workflow, complexity, adaptation, optimization, task-decomposition | dependencies: context-awareness, task-decomposition, phase-execution | files: templates: ./templates/*.json -->

# Adaptive Workflow

Автоматическое определение сложности задачи и выбор оптимального workflow.

## Когда использовать

- После context-awareness (Phase 0)
- Для каждой новой задачи

## Уровни сложности

| Level | Критерии | Workflow |
|-------|----------|----------|
| **minimal** | <3 файлов, 1 функция, нет breaking changes | Упрощённый |
| **standard** | 3-5 файлов, 1 компонент | Полный lite |
| **complex** | >5 файлов, несколько компонентов, breaking changes | Phase-based |

## Алгоритм определения

```
1. Подсчитать files_to_change
2. Определить количество компонентов
3. Проверить на breaking changes
4. Оценить estimated_complexity

complexity =
  if files < 3 AND components == 1 AND !breaking_changes:
    "minimal"
  elif files <= 5 AND components <= 2:
    "standard"
  else:
    "complex"
```

## Output

Используй шаблон: `@template:complexity-result`

## Skip Rules

```yaml
minimal:
  skip:
    - approval_gate
    - prd_compliance
    - code_review
    - changelog
  keep:
    - syntax_check
    - basic_validation

standard:
  skip: []
  optional:
    - code_review
    - prd_compliance (if has_prd)

complex:
  skip: []
  required:
    - all phases
    - code_review
    - prd_compliance (if has_prd)
```

## Quick Reference

```json
{
  "complexity_result": {
    "level": "minimal|standard|complex",
    "workflow": "lite|full|phase-based",
    "skip": ["approval_gate", "prd_compliance"],
    "required": ["syntax_check"],
    "reasoning": "why this level"
  }
}
```

---

## Task Decomposition Integration (Complex Tasks)

**Активируется когда:** `complexity_result.level == "complex"`

Когда задача классифицирована как complex, adaptive-workflow автоматически интегрируется с task-decomposition и phase-execution для систематической декомпозиции и пошагового выполнения.

### Workflow для Complex Tasks:

```
adaptive-workflow → complexity = "complex"
  ↓
task-decomposition → разбивает задачу на 2-5 фаз
  ↓
Создаёт:
  - master_plan.json (общий план всех фаз)
  - phase_1.json (детальный план фазы 1)
  - phase_2.json (детальный план фазы 2)
  - ...
  ↓
FOR EACH phase:
  phase-execution → выполняет одну фазу
    ↓
  Checkpoint после завершения фазы
    ↓
  Validation (tests, syntax, build)
    ↓
  IF validation fails:
    → rollback-recovery → откат к checkpoint
  ELSE:
    → Continue to next phase
```

### Алгоритм интеграции:

```python
IF complexity_result.level == "complex":
  1. Invoke task-decomposition skill
     Input: {
       "task_description": user_task,
       "estimated_files": files_count,
       "breaking_changes": has_breaking_changes
     }

  2. task-decomposition returns:
     {
       "master_plan": {...},
       "phases": [
         {"phase_id": 1, "description": "...", "files": [...], "dependencies": []},
         {"phase_id": 2, "description": "...", "files": [...], "dependencies": [1]},
         ...
       ],
       "total_phases": 3
     }

  3. FOR EACH phase in phases:
       a. Invoke phase-execution skill
          Input: {
            "phase_file": "phase_{phase_id}.json",
            "checkpoint_before": true
          }

       b. phase-execution executes:
          - Create checkpoint (rollback point)
          - Execute all actions in phase
          - Run validation (tests, syntax)
          - Update progress

       c. IF phase validation fails:
            → Invoke rollback-recovery
            → Restore checkpoint
            → Report error to user
            → STOP execution
          ELSE:
            → Mark phase as completed
            → Continue to next phase

  4. AFTER all phases completed:
       - Generate final summary
       - Aggregate metrics from all phases
       - Create consolidated commit (optional)
```

### Преимущества декомпозиции:

**1. Checkpoint между фазами:**
- Rollback point после каждой фазы
- Если phase 3 fails → rollback только фазы 3, фазы 1-2 сохранены

**2. Прогресс tracking:**
```
Phase 1/4: Backend API ..................... ✓ COMPLETED
Phase 2/4: Frontend integration ............ ⏳ IN PROGRESS
Phase 3/4: Testing & security .............. ⏸️  PENDING
Phase 4/4: Documentation ................... ⏸️  PENDING
```

**3. Параллельное выполнение независимых фаз:**
```json
{
  "phases": [
    {"phase_id": 1, "dependencies": []},        // No deps → can run first
    {"phase_id": 2, "dependencies": [1]},       // Depends on 1 → run after 1
    {"phase_id": 3, "dependencies": [1]},       // Depends on 1 → can run parallel with 2
    {"phase_id": 4, "dependencies": [2, 3]}     // Depends on 2,3 → run last
  ]
}

Execution order:
  Phase 1 → (Phase 2 || Phase 3) → Phase 4
            ↑ parallel execution ↑
```

**4. Лучшая организация:**
- Каждая фаза имеет чёткую цель
- Isolated changes (легче review)
- Incremental progress (видно продвижение)

### Пример декомпозиции:

**Task:** "Реализовать систему аутентификации с JWT"

**task-decomposition создаёт:**

```json
{
  "master_plan": {
    "task_name": "JWT Authentication System",
    "total_phases": 4,
    "estimated_duration": "4-6 hours"
  },
  "phases": [
    {
      "phase_id": 1,
      "description": "Backend API - JWT endpoints",
      "files": ["src/api/auth.py", "src/middleware/jwt.py"],
      "actions": ["Create login endpoint", "Implement JWT generation"],
      "validation": "pytest tests/test_auth.py",
      "dependencies": []
    },
    {
      "phase_id": 2,
      "description": "Frontend integration - Login form",
      "files": ["frontend/LoginForm.tsx", "frontend/api/auth.ts"],
      "actions": ["Create login form", "Add auth API client"],
      "validation": "npm test",
      "dependencies": [1]
    },
    {
      "phase_id": 3,
      "description": "Testing & security hardening",
      "files": ["tests/integration/test_auth_flow.py"],
      "actions": ["Add integration tests", "Security audit"],
      "validation": "pytest tests/integration/",
      "dependencies": [1, 2]
    },
    {
      "phase_id": 4,
      "description": "Documentation & deployment",
      "files": ["docs/authentication.md", "README.md"],
      "actions": ["Update API docs", "Add deployment guide"],
      "validation": "markdown-lint docs/",
      "dependencies": [3]
    }
  ]
}
```

**Execution flow:**
```
✓ Phase 1: Backend API (20 min) → Checkpoint created
✓ Phase 2: Frontend (25 min) → Checkpoint created
✓ Phase 3: Testing (30 min) → Checkpoint created
✓ Phase 4: Documentation (15 min) → Checkpoint created

Total: 90 minutes, 4 checkpoints, 0 rollbacks
```

### Escalation & Downgrade:

**Escalation (minimal/standard → complex):**
```
# Start: minimal workflow
Task: "Fix email validation"

# During execution: обнаружена complexity
❌ Found: 8 files need changes (was estimated 2)
❌ Found: Breaking API change

🔄 Escalating to COMPLEX workflow...
✓ Switching to task-decomposition
✓ Creating phases for systematic execution
```

**Downgrade (complex → standard):**
```
# Start: complex workflow (user requested)
Task: "Update README documentation"

# Analysis: simpler than expected
✓ Only 1 markdown file
✓ No code changes
✓ No dependencies

🔄 Downgrading to STANDARD workflow...
✓ Skipping task-decomposition (unnecessary overhead)
⏱️  Saving ~1 hour
```

### Backward Compatibility:

- task-decomposition и phase-execution опциональны
- Если skills не установлены → fallback to standard structured-planning
- Без декомпозиции complex tasks выполняются монолитно (как раньше)

## Extended Complexity Analysis (v2.1.0)

**Новое:** Для детального объяснения complexity classification, добавляется массив `complexity_factors[]`.

**Структура:**
```json
{
  "complexity_result": {
    "level": "complex",
    "workflow": "phase-based",
    "skip": [],
    "required": ["all phases", "code_review", "prd_compliance"],
    "reasoning": "Multiple components, breaking changes, and 8+ files",
    "complexity_factors": [
      {
        "factor_id": 1,
        "factor_name": "Files to change",
        "value": 8,
        "threshold": 5,
        "weight": 0.4,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 2,
        "factor_name": "Number of components",
        "value": 3,
        "threshold": 2,
        "weight": 0.3,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 3,
        "factor_name": "Breaking changes",
        "value": true,
        "threshold": false,
        "weight": 0.2,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 4,
        "factor_name": "Cross-domain changes",
        "value": true,
        "threshold": false,
        "weight": 0.1,
        "impact": "medium",
        "contributes_to": "complex"
      }
    ],
    "complexity_score": 0.85
  }
}
```

Используется когда:
- Требуется прозрачность complexity decision
- User challenges complexity classification
- Debugging workflow selection

---

## References

**TOON Format:**
- Спецификация: `@shared:TOON-REFERENCE.md`
- Применение к complexity_factors[]: см. Skill-specific TOON usage ниже

**Task Structure:**
- JSON schemas: `@shared:TASK-STRUCTURE.md#complexity-result`
- Adaptive schemas: `@shared:TASK-STRUCTURE.md#adaptive-behavior`

**Workflow Integration:**
- Universal workflow: `@shared:WORKFLOW-SKILLS-UNIVERSAL.md#phase-0-complexity`
- Skills matrix: `@shared:WORKFLOW-SKILLS-UNIVERSAL.md#skills-by-phase`

---

## Skill-Specific TOON Usage

**TOON генерируется для complexity_factors[] когда:**
- Extended complexity analysis активирован (complexity_factors.length >= 5)
- Debugging workflow classification
- User requested transparency

**Optimization pattern:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Complexity result with factors
const complexityResult = {
  level: "complex",
  workflow: "phase-based",
  complexity_factors: [...]  // 6+ factors
};

// Add TOON optimization (только для complexity_factors >= 5)
if (complexityResult.complexity_factors.length >= 5) {
  // Normalize boolean values для TOON consistency
  const factorsNormalized = complexityResult.complexity_factors.map(f => ({
    factor_id: f.factor_id,
    factor_name: f.factor_name,
    value: typeof f.value === 'boolean' ? f.value.toString() : f.value,
    threshold: typeof f.threshold === 'boolean' ? f.threshold.toString() : f.threshold,
    weight: f.weight,
    impact: f.impact,
    contributes_to: f.contributes_to
  }));

  complexityResult.toon = {
    complexity_factors_toon: arrayToToon('complexity_factors', factorsNormalized,
      ['factor_id', 'factor_name', 'value', 'threshold', 'weight', 'impact', 'contributes_to']),
    ...calculateTokenSavings({ complexity_factors: factorsNormalized })
  };
}
```

**Token savings:** ~20-30% для 5+ factors (см. @shared:TOON-REFERENCE.md#token-savings)

---

## Domain-Specific Examples

### Example 1: Minimal Complexity Task

**User task:** "Fix typo in README.md"

**Analysis:**
```json
{
  "files_to_change": 1,
  "components_affected": 0,
  "breaking_changes": false,
  "estimated_complexity": "minimal"
}
```

**Output:**
```json
{
  "complexity_result": {
    "level": "minimal",
    "workflow": "lite",
    "skip": ["approval_gate", "prd_compliance", "code_review", "changelog"],
    "required": ["syntax_check"],
    "reasoning": "Single file change, no code logic, documentation update"
  }
}
```

**Result:** Упрощённый workflow активирован. Skipped 4 phases (approval, PRD, code review, changelog). Estimated time saved: 15 minutes.

---

### Example 2: Standard Complexity Task

**User task:** "Add user registration endpoint with email validation"

**Analysis:**
```json
{
  "files_to_change": 4,
  "files": ["app/api/users.py", "app/services/email_validator.py", "app/models/user.py", "tests/test_user_registration.py"],
  "components_affected": 1,
  "breaking_changes": false,
  "estimated_complexity": "standard"
}
```

**Output:**
```json
{
  "complexity_result": {
    "level": "standard",
    "workflow": "full",
    "skip": [],
    "optional": ["code_review"],
    "required": ["syntax_check", "unit_tests", "acceptance_criteria_validation"],
    "reasoning": "3-5 files, single component (user registration), no breaking changes"
  }
}
```

**Result:** Full lite workflow активирован. All phases included (planning, execution, validation, git). Code review optional.

---

### Example 3: Complex Task with Task-Decomposition Integration

**User task:** "Migrate database from SQLite to PostgreSQL with schema changes"

**Analysis:**
```json
{
  "files_to_change": 12,
  "files": ["app/models/*.py", "migrations/*.sql", "app/database.py", "tests/*.py", "docker-compose.yml", "requirements.txt"],
  "components_affected": 3,
  "breaking_changes": true,
  "estimated_complexity": "complex"
}
```

**Output:**
```json
{
  "complexity_result": {
    "level": "complex",
    "workflow": "phase-based",
    "skip": [],
    "required": ["all phases", "code_review", "prd_compliance", "integration_tests"],
    "reasoning": "12+ files, 3 components (models, migrations, tests), breaking schema changes"
  }
}
```

**Integration with task-decomposition:**
```json
{
  "master_plan": {
    "task_name": "Database Migration SQLite → PostgreSQL",
    "total_phases": 3
  },
  "phases": [
    {
      "phase_id": 1,
      "description": "Schema migration scripts",
      "files": ["migrations/001_initial.sql", "migrations/002_schema_changes.sql"],
      "validation": "docker exec db psql -f migrations/001_initial.sql",
      "dependencies": []
    },
    {
      "phase_id": 2,
      "description": "Model updates and database connection",
      "files": ["app/models/user.py", "app/models/product.py", "app/database.py", "requirements.txt"],
      "validation": "pytest tests/test_models.py",
      "dependencies": [1]
    },
    {
      "phase_id": 3,
      "description": "Integration tests and rollback plan",
      "files": ["tests/integration/test_db_migration.py", "docs/rollback.md"],
      "validation": "pytest tests/integration/",
      "dependencies": [2]
    }
  ]
}
```

**Execution flow:**
```
✓ Phase 1: Schema migration (30 min) → Checkpoint created
✓ Phase 2: Model updates (45 min) → Checkpoint created
✓ Phase 3: Integration tests (25 min) → Checkpoint created

Total: 100 minutes, 3 checkpoints, systematic execution
```

**Result:** Complex workflow with task-decomposition. Incremental progress with rollback points after each phase.

---

### Example 4: Escalation (Minimal → Complex)

**User task (initial):** "Update email validation regex"

**Initial analysis:**
```json
{
  "files_to_change": 1,
  "files": ["app/validators/email.py"],
  "estimated_complexity": "minimal"
}
```

**Initial output:**
```json
{
  "complexity_result": {
    "level": "minimal",
    "workflow": "lite",
    "skip": ["approval_gate", "code_review"],
    "reasoning": "Single file change, simple regex update"
  }
}
```

**During execution - discovered complexity:**
```
❌ Found: email.py imported in 8 files (ripple effect)
❌ Found: Breaking change - old emails fail new regex
❌ Found: Need to update 3 test files
❌ Found: Need migration script for existing data
```

**Re-analysis:**
```json
{
  "files_to_change": 12,
  "breaking_changes": true,
  "components_affected": 2
}
```

**Escalation output:**
```json
{
  "complexity_result": {
    "level": "complex",
    "workflow": "phase-based",
    "skip": [],
    "required": ["all phases", "code_review", "integration_tests"],
    "reasoning": "ESCALATED: Initial estimate 1 file → actual 12 files with breaking changes",
    "escalation": {
      "from": "minimal",
      "to": "complex",
      "trigger": "Breaking changes detected during execution",
      "impact": "Switching to task-decomposition for systematic execution"
    }
  }
}
```

**Result:** Escalation triggered. Switched from minimal → complex workflow. Task-decomposition activated to handle complexity.

---

### Example 5: Downgrade (Complex → Standard)

**User task (user specified complex):** "Update API documentation for /users endpoint"

**User request:**
```json
{
  "user_requested_complexity": "complex",
  "reason": "Important API, want thorough review"
}
```

**Initial analysis:**
```json
{
  "files_to_change": 2,
  "files": ["docs/api/users.md", "README.md"],
  "components_affected": 0,
  "breaking_changes": false,
  "code_changes": false
}
```

**Analysis conclusion:**
```
✓ Only 2 markdown files
✓ No code changes
✓ No dependencies
✓ No breaking changes
→ Complex workflow is overkill
```

**Downgrade output:**
```json
{
  "complexity_result": {
    "level": "standard",
    "workflow": "full",
    "skip": [],
    "required": ["markdown_validation", "link_checking"],
    "reasoning": "DOWNGRADED: User requested complex, but analysis shows standard is sufficient",
    "downgrade": {
      "from": "complex",
      "to": "standard",
      "trigger": "No code changes, documentation-only update",
      "time_saved": "~45 minutes",
      "justification": "Task-decomposition unnecessary for 2 markdown files"
    }
  }
}
```

**Result:** Downgrade от complex к standard. Task-decomposition skipped. Estimated 45 minutes saved.

---

### Example 6: Extended Complexity Analysis with Factors

**User task:** "Implement payment processing with Stripe integration"

**Analysis:**
```json
{
  "files_to_change": 15,
  "components_affected": 4,
  "breaking_changes": true,
  "external_apis": ["Stripe API"],
  "security_critical": true,
  "database_migrations": true
}
```

**Output (with extended analysis):**
```json
{
  "complexity_result": {
    "level": "complex",
    "workflow": "phase-based",
    "skip": [],
    "required": ["all phases", "code_review", "security_audit", "prd_compliance"],
    "reasoning": "Large codebase changes with breaking API modifications, external integrations, and security considerations",
    "complexity_factors": [
      {
        "factor_id": 1,
        "factor_name": "Files to change",
        "value": 15,
        "threshold": 5,
        "weight": 0.35,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 2,
        "factor_name": "Number of components",
        "value": 4,
        "threshold": 2,
        "weight": 0.25,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 3,
        "factor_name": "Breaking changes",
        "value": true,
        "threshold": false,
        "weight": 0.15,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 4,
        "factor_name": "External API integration",
        "value": true,
        "threshold": false,
        "weight": 0.10,
        "impact": "medium",
        "contributes_to": "complex"
      },
      {
        "factor_id": 5,
        "factor_name": "Security critical",
        "value": true,
        "threshold": false,
        "weight": 0.10,
        "impact": "high",
        "contributes_to": "complex"
      },
      {
        "factor_id": 6,
        "factor_name": "Database migration required",
        "value": true,
        "threshold": false,
        "weight": 0.05,
        "impact": "medium",
        "contributes_to": "complex"
      }
    ],
    "complexity_score": 0.94
  }
}
```

**Interpretation:**
- **Complexity score: 0.94** (very high)
- **Top contributors:** Files (15), Components (4), Security critical
- **Required phases:** All phases + security audit
- **Estimated effort:** Phase-based decomposition essential

**Result:** Extended analysis shows 6 complexity factors with score 0.94. Task-decomposition mandatory for systematic execution with security checkpoints.

---

### Example 7: Complex Task with TOON Optimization

**User task:** "Refactor authentication system with OAuth2 and multi-provider support"

**Analysis:**
```json
{
  "files_to_change": 18,
  "components_affected": 5,
  "breaking_changes": true,
  "external_apis": ["Google OAuth", "GitHub OAuth", "Facebook OAuth"],
  "security_critical": true,
  "database_migrations": true,
  "cross_domain_changes": true,
  "performance_impact": true
}
```

**Output (with TOON for complexity_factors[]):**
```json
{
  "complexity_result": {
    "level": "complex",
    "workflow": "phase-based",
    "skip": [],
    "required": ["all phases", "code_review", "security_audit", "prd_compliance", "performance_testing"],
    "reasoning": "Comprehensive refactoring with 18 files, 5 components, breaking changes, and multiple external OAuth providers",
    "complexity_factors": [
      {"factor_id": 1, "factor_name": "Files to change", "value": 18, "threshold": 5, "weight": 0.30, "impact": "high", "contributes_to": "complex"},
      {"factor_id": 2, "factor_name": "Number of components", "value": 5, "threshold": 2, "weight": 0.20, "impact": "high", "contributes_to": "complex"},
      {"factor_id": 3, "factor_name": "Breaking changes", "value": true, "threshold": false, "weight": 0.15, "impact": "high", "contributes_to": "complex"},
      {"factor_id": 4, "factor_name": "External API integrations", "value": 3, "threshold": 1, "weight": 0.10, "impact": "high", "contributes_to": "complex"},
      {"factor_id": 5, "factor_name": "Security critical", "value": true, "threshold": false, "weight": 0.10, "impact": "high", "contributes_to": "complex"},
      {"factor_id": 6, "factor_name": "Database migrations", "value": true, "threshold": false, "weight": 0.05, "impact": "medium", "contributes_to": "complex"},
      {"factor_id": 7, "factor_name": "Cross-domain changes", "value": true, "threshold": false, "weight": 0.05, "impact": "medium", "contributes_to": "complex"},
      {"factor_id": 8, "factor_name": "Performance impact", "value": true, "threshold": false, "weight": 0.05, "impact": "low", "contributes_to": "complex"}
    ],
    "complexity_score": 0.97,
    "toon": {
      "complexity_factors_toon": "complexity_factors[8]{factor_id,factor_name,value,threshold,weight,impact,contributes_to}:\n  1,Files to change,18,5,0.30,high,complex\n  2,Number of components,5,2,0.20,high,complex\n  3,Breaking changes,true,false,0.15,high,complex\n  4,External API integrations,3,1,0.10,high,complex\n  5,Security critical,true,false,0.10,high,complex\n  6,Database migrations,true,false,0.05,medium,complex\n  7,Cross-domain changes,true,false,0.05,medium,complex\n  8,Performance impact,true,false,0.05,low,complex",
      "token_savings": "28.0%",
      "size_comparison": "JSON: 1680 tokens, TOON: 1210 tokens"
    }
  }
}
```

**Token optimization:**
- **JSON tokens:** 1680
- **TOON tokens:** 1210
- **Savings:** 28.0% (470 tokens saved)

**Interpretation:**
- **8 complexity factors** tracked (threshold >= 5, TOON activated)
- **Complexity score: 0.97** (extremely high)
- **Top contributors:** Files (18), Components (5), Breaking changes, External APIs (3)
- **Required:** All phases + security audit + performance testing

**Result:** Complex task with comprehensive factor analysis. TOON optimization applied for 28% token savings. Phase-based decomposition mandatory with security and performance checkpoints.

---

## Best Practices

### DO

1. **Use extended analysis для complex tasks** - track all factors для transparency
2. **Trust the algorithm** - don't force complexity level without justification
3. **Enable escalation detection** - monitor during execution для unexpected complexity
4. **Document downgrade reasons** - explain why simpler workflow is sufficient
5. **Activate TOON для 5+ factors** - significant token savings для detailed analysis

### DON'T

1. **Force complex workflow для simple tasks** - wastes time and resources
2. **Skip minimal workflow checks** - can save significant time
3. **Ignore escalation triggers** - risks incomplete execution
4. **Over-analyze simple tasks** - 3-4 factors sufficient для minimal/standard
5. **Generate TOON для <5 factors** - overhead не оправдан для small arrays

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md, @shared:WORKFLOW-SKILLS-UNIVERSAL.md

---

## Changelog

### v2.2.0 (2026-01-25)

- Удалено: TOON Format Support дублирование (~107 строк)
- Добавлено: References к @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md, @shared:WORKFLOW-SKILLS-UNIVERSAL.md
- Добавлено: 7 complete working examples (minimal, standard, complex, escalation, downgrade, extended analysis, TOON optimization)
- Добавлено: Skill-specific TOON usage notes для complexity_factors[]
