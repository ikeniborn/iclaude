---
name: approval-gates
description: Упрощённые approval gates для подтверждения плана
user-invocable: false
---
<!-- version: 2.2.0 | tags: approval, confirmation, user-interaction | dependencies: structured-planning, plan-validation | files.templates: ./templates/*.md -->

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

## References

**TOON Format Specification:**
- Full spec: @shared:TOON-REFERENCE.md
- Integration patterns: @shared:TOON-REFERENCE.md#integration-patterns
- Token savings benchmarks: @shared:TOON-REFERENCE.md#token-savings

**Task Structure:**
- @shared:TASK-STRUCTURE.md#approval-gates

## Skill-Specific TOON Usage

**approval-gates генерирует TOON для:**
- `files_to_change[]` - когда >= 5 files
- `phase_details[]` - когда >= 3 phases

**Implementation:**
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

**Token Savings (Approval-Specific):**
- 7 files + 3 phases: **28.2% savings** (2020 → 1450 tokens)
- 12 files + 3 phases: **31.5% savings** (3240 → 2220 tokens)
- 20 files + 5 phases: **34.1% savings** (5400 → 3560 tokens)

---

## Examples

### Example 1: Lite Approval (Standard Task)

**Scenario:** Standard task - add search endpoint (3 files)

**Task plan:**
```json
{
  "task_name": "Add product search endpoint",
  "complexity": "standard",
  "files": 3,
  "steps": 5
}
```

**Approval request (user-facing):**
```markdown
## План готов

**Задача:** Add product search endpoint
**Изменится:** 3 файлов
**Шагов:** 5

**Изменения:**
- backend/api/products.py — Add GET /products/search endpoint
- backend/services/search_service.py — Implement search logic
- tests/test_products_api.py — Add endpoint tests

---
Выполнить? [yes/no/modify]
```

**Approval output:**
```json
{
  "approval": {
    "response": "yes",
    "timestamp": "2026-01-25T10:15:32Z",
    "plan_hash": "e4d909c290d0fb1ca068ffaddf22cbd0"
  }
}
```

**Result:** User approved, proceed to execution. No TOON (< 5 files).

---

### Example 2: Full Approval (Complex Task)

**Scenario:** Complex task - JWT authentication (12 files, 3 phases)

**Approval request (user-facing):**
```markdown
## План готов

**Задача:** Implement JWT Authentication System
**Сложность:** complex
**Фаз:** 3

### Фазы:
1. Backend API + JWT Logic — 7 шагов (5 files)
2. Frontend Integration — 8 шагов (6 files)
3. Testing & Documentation — 3 шагов (1 file)

### Файлы (12):
- backend/app/services/jwt_service.py [create] — JWT token generation and validation service
- backend/app/api/v1/endpoints/auth.py [create] — Login, refresh, logout endpoints
- backend/app/core/security.py [modify] — Add JWT configuration constants
- backend/app/middleware/auth_middleware.py [create] — JWT authentication middleware
- tests/services/test_jwt_service.py [create] — Unit tests for JWT service
- frontend/src/services/AuthService.ts [create] — Frontend auth service
- frontend/src/components/LoginForm.tsx [create] — Login form component
- frontend/src/hooks/useAuth.ts [create] — Auth hook for state management
- frontend/src/contexts/AuthContext.tsx [create] — Auth context provider
- frontend/src/api/authApi.ts [create] — API client for auth endpoints
- frontend/tests/AuthService.test.ts [create] — Auth service tests
- docs/authentication.md [create] — Authentication documentation

### Риски:
- Breaking change to existing auth → Митигация: Keep old auth for backward compatibility
- Token refresh race condition → Митигация: Implement mutex in frontend

---
Выполнить? [yes/no/modify]
```

**Approval output (with TOON):**
```json
{
  "approval": {
    "response": "yes",
    "timestamp": "2026-01-25T14:30:00Z",
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

**Result:** User approved, TOON optimization saves 31.5% tokens for 12 files + 3 phases.

---

### Example 3: TOON Optimization (Very Complex Task)

**Scenario:** Large refactor - 20 files across 5 phases

**Approval output (with TOON):**
```json
{
  "approval": {
    "response": "yes",
    "timestamp": "2026-01-25T16:45:00Z",
    "plan_hash": "xyz789abc123",
    "task_summary": {
      "task_name": "Refactor authentication module to microservices",
      "complexity": "complex",
      "total_phases": 5,
      "total_files": 20,
      "total_steps": 35
    },
    "files_to_change": [
      {"file_id": 1, "file_path": "auth-service/src/controllers/auth.controller.ts", "change_type": "create", "phase": 1, "description": "Auth controller", "estimated_lines": 120},
      {"file_id": 2, "file_path": "auth-service/src/services/jwt.service.ts", "change_type": "create", "phase": 1, "description": "JWT service", "estimated_lines": 89},
      {"file_id": 3, "file_path": "auth-service/src/repositories/user.repository.ts", "change_type": "create", "phase": 1, "description": "User repository", "estimated_lines": 78},
      {"file_id": 4, "file_path": "auth-service/src/models/user.model.ts", "change_type": "create", "phase": 1, "description": "User model", "estimated_lines": 45},
      {"file_id": 5, "file_path": "auth-service/src/config/database.ts", "change_type": "create", "phase": 2, "description": "Database config", "estimated_lines": 34},
      {"file_id": 6, "file_path": "auth-service/src/middleware/auth.middleware.ts", "change_type": "create", "phase": 2, "description": "Auth middleware", "estimated_lines": 56},
      {"file_id": 7, "file_path": "auth-service/tests/unit/jwt.service.test.ts", "change_type": "create", "phase": 3, "description": "JWT tests", "estimated_lines": 98},
      {"file_id": 8, "file_path": "auth-service/tests/integration/auth.test.ts", "change_type": "create", "phase": 3, "description": "Integration tests", "estimated_lines": 145},
      {"file_id": 9, "file_path": "gateway/src/middleware/auth-proxy.ts", "change_type": "modify", "phase": 4, "description": "Gateway auth proxy", "estimated_lines": 67},
      {"file_id": 10, "file_path": "gateway/src/config/services.ts", "change_type": "modify", "phase": 4, "description": "Service registry", "estimated_lines": 23},
      {"file_id": 11, "file_path": "frontend/src/services/api.service.ts", "change_type": "modify", "phase": 4, "description": "API client update", "estimated_lines": 45},
      {"file_id": 12, "file_path": "frontend/src/hooks/useAuth.ts", "change_type": "modify", "phase": 4, "description": "Auth hook update", "estimated_lines": 34},
      {"file_id": 13, "file_path": "shared/types/auth.types.ts", "change_type": "create", "phase": 5, "description": "Shared auth types", "estimated_lines": 56},
      {"file_id": 14, "file_path": "shared/constants/auth.constants.ts", "change_type": "create", "phase": 5, "description": "Auth constants", "estimated_lines": 23},
      {"file_id": 15, "file_path": "docs/architecture/auth-service.md", "change_type": "create", "phase": 5, "description": "Architecture docs", "estimated_lines": 234},
      {"file_id": 16, "file_path": "docker-compose.yml", "change_type": "modify", "phase": 2, "description": "Add auth service", "estimated_lines": 12},
      {"file_id": 17, "file_path": "kubernetes/auth-service-deployment.yml", "change_type": "create", "phase": 2, "description": "K8s deployment", "estimated_lines": 78},
      {"file_id": 18, "file_path": "auth-service/Dockerfile", "change_type": "create", "phase": 2, "description": "Service Dockerfile", "estimated_lines": 23},
      {"file_id": 19, "file_path": "auth-service/package.json", "change_type": "create", "phase": 1, "description": "Package config", "estimated_lines": 45},
      {"file_id": 20, "file_path": "auth-service/tsconfig.json", "change_type": "create", "phase": 1, "description": "TypeScript config", "estimated_lines": 34}
    ],
    "phase_details": [
      {"phase_id": 1, "phase_name": "Auth Service Core", "steps": 8, "files": 6, "dependencies": [], "estimated_duration": "40-60 min"},
      {"phase_id": 2, "phase_name": "Infrastructure Setup", "steps": 6, "files": 4, "dependencies": [1], "estimated_duration": "30-45 min"},
      {"phase_id": 3, "phase_name": "Testing", "steps": 7, "files": 2, "dependencies": [1, 2], "estimated_duration": "35-50 min"},
      {"phase_id": 4, "phase_name": "Gateway & Frontend Integration", "steps": 9, "files": 4, "dependencies": [1, 2], "estimated_duration": "45-60 min"},
      {"phase_id": 5, "phase_name": "Shared Types & Documentation", "steps": 5, "files": 4, "dependencies": [1, 2, 3, 4], "estimated_duration": "25-35 min"}
    ],
    "toon": {
      "files_to_change_toon": "files_to_change[20]{file_id,file_path,change_type,phase,description,estimated_lines}:\n  1,auth-service/src/controllers/auth.controller.ts,create,1,Auth controller,120\n  2,auth-service/src/services/jwt.service.ts,create,1,JWT service,89\n  3,auth-service/src/repositories/user.repository.ts,create,1,User repository,78\n  4,auth-service/src/models/user.model.ts,create,1,User model,45\n  5,auth-service/src/config/database.ts,create,2,Database config,34\n  6,auth-service/src/middleware/auth.middleware.ts,create,2,Auth middleware,56\n  7,auth-service/tests/unit/jwt.service.test.ts,create,3,JWT tests,98\n  8,auth-service/tests/integration/auth.test.ts,create,3,Integration tests,145\n  9,gateway/src/middleware/auth-proxy.ts,modify,4,Gateway auth proxy,67\n  10,gateway/src/config/services.ts,modify,4,Service registry,23\n  11,frontend/src/services/api.service.ts,modify,4,API client update,45\n  12,frontend/src/hooks/useAuth.ts,modify,4,Auth hook update,34\n  13,shared/types/auth.types.ts,create,5,Shared auth types,56\n  14,shared/constants/auth.constants.ts,create,5,Auth constants,23\n  15,docs/architecture/auth-service.md,create,5,Architecture docs,234\n  16,docker-compose.yml,modify,2,Add auth service,12\n  17,kubernetes/auth-service-deployment.yml,create,2,K8s deployment,78\n  18,auth-service/Dockerfile,create,2,Service Dockerfile,23\n  19,auth-service/package.json,create,1,Package config,45\n  20,auth-service/tsconfig.json,create,1,TypeScript config,34",
      "phase_details_toon": "phase_details[5]{phase_id,phase_name,steps,files,dependencies,estimated_duration}:\n  1,Auth Service Core,8,6,[],40-60 min\n  2,Infrastructure Setup,6,4,[1],30-45 min\n  3,Testing,7,2,\"[1,2]\",35-50 min\n  4,Gateway & Frontend Integration,9,4,\"[1,2]\",45-60 min\n  5,Shared Types & Documentation,5,4,\"[1,2,3,4]\",25-35 min",
      "token_savings": "34.1%",
      "size_comparison": "JSON: 5400 tokens, TOON: 3560 tokens"
    }
  }
}
```

**Result:** User approved very complex task, TOON optimization saves 34.1% tokens for 20 files + 5 phases.

---

## Integration with Other Skills

**With plan-validation (PHASE 1.5):**
- plan-validation runs BEFORE approval-gates
- If `plan_validation_result.passed == false` → BLOCK approval
- Show `plan_validation_result.blocking_issues` to user
- If `warnings.length > 0` → SHOW warnings, allow approval

**Used by:**
- `structured-planning` → Invokes approval gates after plan generation
- `adaptive-workflow` → Conditional approval based on complexity

**Uses:**
- `toon-skill` → TOON optimization for files_to_change[] и phase_details[] (см. `@shared:TOON-REFERENCE.md`)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT

## Changelog

### v2.2.0 (2026-01-25)
- Централизация: TOON specs → @shared:TOON-REFERENCE.md
- Добавлено: 3 примера (lite approval, full approval, TOON optimization)
- Skill-specific TOON usage notes для files_to_change[] и phase_details[]
- Обновлены references

### v2.1.0 (2026-01-23)
- TOON Format Support для files_to_change[] и phase_details[]
