---
name: Approval Gates
description: Упрощённые approval gates для подтверждения плана
version: 2.1.0
tags: [approval, confirmation, user-interaction]
dependencies: [structured-planning]
files:
  templates: ./templates/*.md
user-invocable: false
---

# Approval Gates v2.0

Упрощённые, user-friendly approval gates.

## Когда использовать

- После создания плана (standard/complex only)
- **SKIP** для minimal complexity

## Шаблоны

### Lite (approval-lite)

Для standard complexity — компактный формат:

```markdown
## План готов

**Задача:** {task_name}
**Изменится:** {N} файлов
**Шагов:** {M}

**Изменения:**
- {file1} — {description}
- {file2} — {description}

---
Выполнить? [yes/no/modify]
```

### Full (approval-full)

Для complex/phase-based — детальный формат:

```markdown
## План готов

**Задача:** {task_name}
**Сложность:** complex
**Фаз:** {N}

### Фазы:
1. {phase1} — {N} шагов
2. {phase2} — {N} шагов

### Файлы ({total}):
- {file1} [{change_type}] — {description}
- {file2} [{change_type}] — {description}

### Риски:
- {risk1} → {mitigation}

---
Выполнить? [yes/no/modify]
```

## Response Handling

| Response | Action |
|----------|--------|
| `yes` | Proceed to execution |
| `no` | STOP, cancel task |
| `modify` | Return to planning |

## Output

```json
{
  "approval": {
    "response": "yes|no|modify",
    "timestamp": "ISO8601",
    "plan_hash": "md5 of plan"
  }
}
```

## Auto-Skip Rules

```yaml
skip_approval_when:
  - complexity == "minimal"
  - user_config.auto_approve == true
  - CI/CD environment detected
```

## Detailed Approval Output (v2.1.0)

**Новое:** Для complex tasks, расширенная структура approval с детализацией изменений.

**Структура:**
```json
{
  "approval": {
    "response": "yes",
    "timestamp": "2026-01-23T14:30:00Z",
    "plan_hash": "abc123def456",
    "task_summary": {
      "task_name": "Implement JWT Authentication System",
      "complexity": "complex",
      "total_phases": 3,
      "total_files": 12,
      "total_steps": 18
    },
    "files_to_change": [
      {
        "file_id": 1,
        "file_path": "backend/app/services/jwt_service.py",
        "change_type": "create",
        "phase": 1,
        "description": "JWT token generation and validation service",
        "estimated_lines": 45
      },
      {
        "file_id": 2,
        "file_path": "backend/app/api/v1/endpoints/auth.py",
        "change_type": "create",
        "phase": 1,
        "description": "Login, refresh, logout endpoints",
        "estimated_lines": 78
      },
      // ... more files
    ],
    "phase_details": [
      {
        "phase_id": 1,
        "phase_name": "Backend API + JWT Logic",
        "steps": 7,
        "files": 5,
        "dependencies": [],
        "estimated_duration": "20-30 min"
      },
      {
        "phase_id": 2,
        "phase_name": "Frontend Integration",
        "steps": 8,
        "files": 6,
        "dependencies": [1],
        "estimated_duration": "25-35 min"
      },
      {
        "phase_id": 3,
        "phase_name": "Testing & Documentation",
        "steps": 3,
        "files": 1,
        "dependencies": [1, 2],
        "estimated_duration": "15-20 min"
      }
    ]
  }
}
```

Используется когда:
- Complex/phase-based tasks
- User requested detailed approval
- Transparent planning требуется

## TOON Format Support (v2.1.0)

**Назначение:** Автоматическая оптимизация токенов для files_to_change[] и phase_details[] массивов.

### Threshold

TOON генерируется если **files_to_change[] >= 5** ИЛИ **phase_details[] >= 3**

### Target Arrays

**1. files_to_change[]**
- Обычно: 5-20 files per task
- Поля: file_id, file_path, change_type, phase, description, estimated_lines
- Token savings: ~28-35% для 5+ files

**2. phase_details[]**
- Обычно: 2-5 phases per complex task
- Поля: phase_id, phase_name, steps, files, dependencies, estimated_duration
- Token savings: ~25-30% для 3+ phases

### Output Structure

**Approval Output (с TOON):**
```json
{
  "approval": {
    "response": "yes",
    "timestamp": "2026-01-23T14:30:00Z",
    "plan_hash": "abc123def456",
    "task_summary": {
      "task_name": "Implement JWT Authentication System",
      "complexity": "complex",
      "total_phases": 3,
      "total_files": 12,
      "total_steps": 18
    },
    "files_to_change": [
      {"file_id": 1, "file_path": "backend/app/services/jwt_service.py", "change_type": "create", "phase": 1, "description": "JWT token generation and validation service", "estimated_lines": 45},
      {"file_id": 2, "file_path": "backend/app/api/v1/endpoints/auth.py", "change_type": "create", "phase": 1, "description": "Login, refresh, logout endpoints", "estimated_lines": 78},
      {"file_id": 3, "file_path": "backend/app/core/security.py", "change_type": "modify", "phase": 1, "description": "Add JWT configuration constants", "estimated_lines": 12},
      {"file_id": 4, "file_path": "backend/app/middleware/auth_middleware.py", "change_type": "create", "phase": 1, "description": "JWT authentication middleware", "estimated_lines": 34},
      {"file_id": 5, "file_path": "tests/services/test_jwt_service.py", "change_type": "create", "phase": 1, "description": "Unit tests for JWT service", "estimated_lines": 56},
      {"file_id": 6, "file_path": "frontend/src/services/AuthService.ts", "change_type": "create", "phase": 2, "description": "Frontend auth service", "estimated_lines": 67},
      {"file_id": 7, "file_path": "frontend/src/components/LoginForm.tsx", "change_type": "create", "phase": 2, "description": "Login form component", "estimated_lines": 89},
      {"file_id": 8, "file_path": "frontend/src/hooks/useAuth.ts", "change_type": "create", "phase": 2, "description": "Auth hook for state management", "estimated_lines": 45},
      {"file_id": 9, "file_path": "frontend/src/contexts/AuthContext.tsx", "change_type": "create", "phase": 2, "description": "Auth context provider", "estimated_lines": 78},
      {"file_id": 10, "file_path": "frontend/src/api/authApi.ts", "change_type": "create", "phase": 2, "description": "API client for auth endpoints", "estimated_lines": 56},
      {"file_id": 11, "file_path": "frontend/tests/AuthService.test.ts", "change_type": "create", "phase": 2, "description": "Auth service tests", "estimated_lines": 98},
      {"file_id": 12, "file_path": "docs/authentication.md", "change_type": "create", "phase": 3, "description": "Authentication documentation", "estimated_lines": 120}
    ],
    "phase_details": [
      {"phase_id": 1, "phase_name": "Backend API + JWT Logic", "steps": 7, "files": 5, "dependencies": [], "estimated_duration": "20-30 min"},
      {"phase_id": 2, "phase_name": "Frontend Integration", "steps": 8, "files": 6, "dependencies": [1], "estimated_duration": "25-35 min"},
      {"phase_id": 3, "phase_name": "Testing & Documentation", "steps": 3, "files": 1, "dependencies": [1, 2], "estimated_duration": "15-20 min"}
    ],
    "toon": {
      "files_to_change_toon": "files_to_change[12]{file_id,file_path,change_type,phase,description,estimated_lines}:\n  1,backend/app/services/jwt_service.py,create,1,JWT token generation and validation service,45\n  2,backend/app/api/v1/endpoints/auth.py,create,1,Login refresh logout endpoints,78\n  3,backend/app/core/security.py,modify,1,Add JWT configuration constants,12\n  4,backend/app/middleware/auth_middleware.py,create,1,JWT authentication middleware,34\n  5,tests/services/test_jwt_service.py,create,1,Unit tests for JWT service,56\n  6,frontend/src/services/AuthService.ts,create,2,Frontend auth service,67\n  7,frontend/src/components/LoginForm.tsx,create,2,Login form component,89\n  8,frontend/src/hooks/useAuth.ts,create,2,Auth hook for state management,45\n  9,frontend/src/contexts/AuthContext.tsx,create,2,Auth context provider,78\n  10,frontend/src/api/authApi.ts,create,2,API client for auth endpoints,56\n  11,frontend/tests/AuthService.test.ts,create,2,Auth service tests,98\n  12,docs/authentication.md,create,3,Authentication documentation,120",
      "phase_details_toon": "phase_details[3]{phase_id,phase_name,steps,files,dependencies,estimated_duration}:\n  1,Backend API + JWT Logic,7,5,[],20-30 min\n  2,Frontend Integration,8,6,[1],25-35 min\n  3,Testing & Documentation,3,1,\"[1,2]\",15-20 min",
      "token_savings": "31.5%",
      "size_comparison": "JSON: 3240 tokens, TOON: 2220 tokens"
    }
  }
}
```

### Implementation Pattern

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Approval output with detailed breakdown
const approval = {
  response: "yes",
  task_summary: {...},
  files_to_change: [...],  // 12 files
  phase_details: [...]     // 3 phases
};

// Add TOON optimization
const dataToConvert = {};

if (approval.files_to_change.length >= 5) {
  approval.toon = approval.toon || {};
  approval.toon.files_to_change_toon = arrayToToon('files_to_change', approval.files_to_change,
    ['file_id', 'file_path', 'change_type', 'phase', 'description', 'estimated_lines']);
  dataToConvert.files_to_change = approval.files_to_change;
}

if (approval.phase_details.length >= 3) {
  approval.toon = approval.toon || {};

  // Normalize dependencies array для TOON (convert to string)
  const phasesNormalized = approval.phase_details.map(p => ({
    ...p,
    dependencies: JSON.stringify(p.dependencies)
  }));

  approval.toon.phase_details_toon = arrayToToon('phase_details', phasesNormalized,
    ['phase_id', 'phase_name', 'steps', 'files', 'dependencies', 'estimated_duration']);
  dataToConvert.phase_details = phasesNormalized;
}

if (approval.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  approval.toon.token_savings = stats.savedPercent;
  approval.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}
```

### Token Savings Examples

| Scenario | JSON Tokens | TOON Tokens | Savings | Elements |
|----------|-------------|-------------|---------|----------|
| Medium task (7 files + 3 phases) | 2020 | 1450 | 28.2% | 10 |
| Large task (12 files + 3 phases) | 3240 | 2220 | 31.5% | 15 |
| Complex (20 files + 5 phases) | 5400 | 3560 | 34.1% | 25 |

**Typical use case:** Complex task с 12 files + 3 phases: **~31% token reduction**

### Backward Compatibility

- ✅ JSON format always present (primary format)
- ✅ TOON field optional (only when threshold met)
- ✅ Simple approval without details unchanged
- ✅ Zero breaking changes для downstream consumers

### When TOON is Generated

**Always generated:**
- Complex tasks (12+ files or 3+ phases)
- Detailed approval mode enabled
- User requested breakdown

**Not generated:**
- Simple tasks (< 5 files)
- Lite approval mode
- Auto-approved tasks

См. также: **toon-skill** для API документации, **_shared/TOON-PATTERNS.md** для integration patterns.

