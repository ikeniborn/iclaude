---
name: Validation Framework
description: Адаптивная валидация с поддержкой partial validation и TOON input
version: 2.2.0
tags: [validation, testing, acceptance-criteria, quality, toon]
dependencies: [structured-planning, architecture-documentation]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
changelog:
  - version: 2.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specification → @shared:TOON-REFERENCE.md"
      - "Удалено: ~333 строки TOON Format Support дубликатов"
      - "Добавлено: 7 полных примеров validation scenarios (simple, standard, full, failure, partial, architecture from TOON, performance)"
      - "Улучшено: Skill-specific TOON usage notes для validation input"
  - version: 2.1.0
    date: 2026-01-23
    changes:
      - "**TOON Input Support**: Added ability to consume TOON format from architecture-documentation"
      - "TOON parser integration via toon-converter.mjs"
      - "Architecture quality validation from TOON (circular dependencies, edge validation)"
      - "Fallback to YAML/JSON for backward compatibility"
      - "Token savings reporting in validation output"
      - "Comprehensive examples and troubleshooting guide"
  - version: 2.0.0
    date: 2025-11-XX
    changes:
      - "Адаптивная валидация с режимами lite/standard/full"
      - "Initial release"
---

# Validation Framework v2.2

Адаптивная валидация с выбором режима по сложности задачи.

## Когда использовать

- После выполнения задачи (Phase 4)
- Перед git commit

## Режимы валидации

| Mode | Checks | Blocking |
|------|--------|----------|
| **lite** | syntax only | syntax |
| **standard** | syntax + acceptance | syntax, acceptance |
| **full** | all checks | all |

## Выбор режима

```
if complexity == "minimal":
  mode = "lite"
elif complexity == "standard":
  mode = "standard"
else:
  mode = "full"
```

---

## References

### Task Structure
@shared:TASK-STRUCTURE.md#validation-result

**Skill-specific schemas:**
- `validation_lite` для minimal complexity
- `validation_results` для standard/full complexity

### TOON Format
@shared:TOON-REFERENCE.md

**Skill-specific TOON usage:**
- **Input consumption**: Чтение TOON output из architecture-documentation
- **Parser usage**: `toonToJson()` для конвертации TOON → JSON
- **Validation**: `validateToon()` перед parsing
- **Fallback**: YAML/JSON для backward compatibility

**TOON Integration Pattern:**
```javascript
import { toonToJson, validateToon } from '../toon-skill/converters/toon-converter.mjs';

// Try TOON first (token-efficient)
if (structuredOutput.architecture_documentation?.formats?.toon?.components_toon) {
  const validation = validateToon(toonString);
  if (validation.valid) {
    const data = toonToJson(toonString);
    // Use data.components for validation
  }
}

// Fallback to YAML/JSON (legacy)
else if (structuredOutput.architecture_documentation?.components) {
  // Use YAML components directly
}
```

---

## Шаблоны

### Lite (validation-lite)

```json
{
  "validation_lite": {
    "syntax_check": "passed|failed",
    "files_modified": ["file1.py"],
    "status": "PASSED|FAILED"
  }
}
```

### Full (validation-full)

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [...]
    },
    "prd_compliance": {
      "compliant": true,
      "conflicts": []
    },
    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0
    },
    "functional_checks": {
      "total": 1,
      "passed": 1,
      "failed": 0
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

## Validation Logic

```javascript
// Lite mode
status = syntax_check === "passed" ? "PASSED" : "FAILED"

// Full mode
overall_status = "PASSED" if (
  acceptance_criteria.not_met === 0 &&
  (prd_compliance.compliant || !has_prd) &&
  syntax_checks.failed === 0 &&
  functional_checks.failed === 0
)

can_proceed = overall_status === "PASSED"
```

---

## Domain-Specific Examples

### Example 1: Simple Validation (Lite Mode)

**Situation:** Typo fix in variable name

**Input:**
- Task: "Rename variable `usreName` to `userName` in user.py"
- Complexity: minimal
- Mode: lite

**Validation:**

```json
{
  "validation_lite": {
    "syntax_check": "passed",
    "files_modified": ["src/models/user.py"],
    "status": "PASSED"
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: PASSED
═══════════════════════════════════════════════════════════

SYNTAX: 1/1 ✓

FILES MODIFIED:
- src/models/user.py

═══════════════════════════════════════════════════════════
```

**Result:** Can proceed to commit (syntax check passed).

---

### Example 2: Standard Validation (Syntax + Acceptance Criteria)

**Situation:** Add new API endpoint

**Input:**
- Task: "Create GET /users/{id} endpoint with authentication"
- Complexity: standard
- Mode: standard
- Acceptance Criteria:
  - AC1: Endpoint returns user profile when valid JWT provided
  - AC2: Endpoint returns 401 when JWT missing
  - AC3: Endpoint returns 404 when user not found

**Validation:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 3,
      "met": 3,
      "not_met": 0,
      "details": [
        {
          "criterion": "AC1: Endpoint returns user profile when valid JWT provided",
          "met": true,
          "evidence": "curl -H 'Authorization: Bearer TOKEN' /users/1 → 200 OK with profile JSON"
        },
        {
          "criterion": "AC2: Endpoint returns 401 when JWT missing",
          "met": true,
          "evidence": "curl /users/1 → 401 Unauthorized"
        },
        {
          "criterion": "AC3: Endpoint returns 404 when user not found",
          "met": true,
          "evidence": "curl -H 'Authorization: Bearer TOKEN' /users/999 → 404 Not Found"
        }
      ]
    },
    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0,
      "details": [
        {"file": "src/api/users.py", "result": "passed"},
        {"file": "tests/test_users_api.py", "result": "passed"}
      ]
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: PASSED
═══════════════════════════════════════════════════════════

SYNTAX: 2/2 ✓
ACCEPTANCE: 3/3 ✓

DETAILS:
✓ AC1: Endpoint returns user profile when valid JWT
✓ AC2: Endpoint returns 401 when JWT missing
✓ AC3: Endpoint returns 404 when user not found

═══════════════════════════════════════════════════════════
```

**Result:** Can proceed to commit (all checks passed).

---

### Example 3: Full Validation (All Checks)

**Situation:** Implement new feature with PRD compliance

**Input:**
- Task: "Add two-factor authentication (2FA) for user login"
- Complexity: complex
- Mode: full
- PRD Section: "Security Requirements §7.2 - Two-Factor Authentication"
- Acceptance Criteria:
  - AC1: User can enable 2FA in settings
  - AC2: Login requires OTP when 2FA enabled
  - AC3: Backup codes generated on 2FA setup
  - AC4: User can disable 2FA

**Validation:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 4,
      "met": 4,
      "not_met": 0,
      "details": [
        {
          "criterion": "AC1: User can enable 2FA in settings",
          "met": true,
          "evidence": "Settings page has 'Enable 2FA' button → QR code displayed → TOTP verified"
        },
        {
          "criterion": "AC2: Login requires OTP when 2FA enabled",
          "met": true,
          "evidence": "Login with password → OTP prompt → valid OTP → login success"
        },
        {
          "criterion": "AC3: Backup codes generated on 2FA setup",
          "met": true,
          "evidence": "10 backup codes generated and displayed after QR code scan"
        },
        {
          "criterion": "AC4: User can disable 2FA",
          "met": true,
          "evidence": "Settings → Disable 2FA → password confirmation → 2FA disabled"
        }
      ]
    },
    "prd_compliance": {
      "compliant": true,
      "prd_section": "Security Requirements §7.2",
      "conflicts": [],
      "notes": "Implementation follows TOTP standard (RFC 6238) as specified in PRD"
    },
    "syntax_checks": {
      "total_files": 5,
      "passed": 5,
      "failed": 0,
      "details": [
        {"file": "src/models/user.py", "result": "passed"},
        {"file": "src/services/totp_service.py", "result": "passed"},
        {"file": "src/api/auth.py", "result": "passed"},
        {"file": "frontend/pages/settings.tsx", "result": "passed"},
        {"file": "tests/test_2fa.py", "result": "passed"}
      ]
    },
    "functional_checks": {
      "total": 3,
      "passed": 3,
      "failed": 0,
      "details": [
        {"test": "pytest tests/test_2fa.py", "result": "passed", "output": "15 passed in 2.3s"},
        {"test": "E2E: Enable 2FA flow", "result": "passed", "output": "Cypress test passed"},
        {"test": "Security: Brute force protection", "result": "passed", "output": "Account locked after 5 invalid OTP attempts"}
      ]
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: PASSED
═══════════════════════════════════════════════════════════

SYNTAX: 5/5 ✓
ACCEPTANCE: 4/4 ✓
PRD COMPLIANCE: ✓ (Security Requirements §7.2)
FUNCTIONAL: 3/3 ✓

DETAILS:
✓ AC1: User can enable 2FA in settings
✓ AC2: Login requires OTP when 2FA enabled
✓ AC3: Backup codes generated on 2FA setup
✓ AC4: User can disable 2FA

TESTS:
✓ pytest tests/test_2fa.py (15 passed)
✓ E2E: Enable 2FA flow (Cypress passed)
✓ Security: Brute force protection (passed)

═══════════════════════════════════════════════════════════
```

**Result:** Can proceed to commit (all checks passed, PRD compliant).

---

### Example 4: Validation Failure (Blocking Issues)

**Situation:** Implementation incomplete - missing acceptance criteria

**Input:**
- Task: "Add email notification for order status changes"
- Complexity: standard
- Mode: standard
- Acceptance Criteria:
  - AC1: Email sent when order status changes to "shipped"
  - AC2: Email contains tracking number
  - AC3: Email sent when order delivered

**Validation:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 3,
      "met": 1,
      "not_met": 2,
      "details": [
        {
          "criterion": "AC1: Email sent when order status changes to 'shipped'",
          "met": true,
          "evidence": "Manual test: Order status updated → email received"
        },
        {
          "criterion": "AC2: Email contains tracking number",
          "met": false,
          "evidence": "Email received but tracking number field empty",
          "missing": "Email template missing {{ tracking_number }} variable"
        },
        {
          "criterion": "AC3: Email sent when order delivered",
          "met": false,
          "evidence": "No email sent on 'delivered' status change",
          "missing": "Event handler for 'delivered' status not implemented"
        }
      ]
    },
    "syntax_checks": {
      "total_files": 3,
      "passed": 2,
      "failed": 1,
      "details": [
        {"file": "src/services/notification_service.py", "result": "passed"},
        {"file": "templates/email/order_shipped.html", "result": "failed", "error": "Syntax error line 42: unclosed <div> tag"},
        {"file": "tests/test_notifications.py", "result": "passed"}
      ]
    },
    "overall_status": "FAILED",
    "can_proceed": false,
    "blocking_issues": [
      "AC2 not met: Email template missing tracking number variable",
      "AC3 not met: No email sent on 'delivered' status",
      "Syntax error in templates/email/order_shipped.html line 42"
    ]
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: FAILED
═══════════════════════════════════════════════════════════

SYNTAX: 2/3 ✗
ACCEPTANCE: 1/3 ✗

🛑 BLOCKING ISSUES:
- AC2 not met: Email template missing tracking number variable
- AC3 not met: No email sent on 'delivered' status
- Syntax error in templates/email/order_shipped.html line 42

FAILED CHECKS:
✗ AC2: Email contains tracking number
  Missing: Email template missing {{ tracking_number }} variable

✗ AC3: Email sent when order delivered
  Missing: Event handler for 'delivered' status not implemented

✗ Syntax: templates/email/order_shipped.html
  Error: Syntax error line 42: unclosed <div> tag

═══════════════════════════════════════════════════════════

❌ CANNOT PROCEED TO COMMIT
Fix blocking issues before retrying validation.

═══════════════════════════════════════════════════════════
```

**Result:** CANNOT proceed to commit. Must fix:
1. Add `{{ tracking_number }}` to email template
2. Implement event handler for "delivered" status
3. Fix HTML syntax error (unclosed div tag)

---

### Example 5: Partial Validation (Some AC Met)

**Situation:** Feature partially implemented - some AC met, some not

**Input:**
- Task: "Implement shopping cart functionality"
- Complexity: standard
- Mode: standard
- Acceptance Criteria:
  - AC1: User can add items to cart
  - AC2: User can update item quantities
  - AC3: User can remove items from cart
  - AC4: Cart persists across sessions (saved to database)

**Validation:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 4,
      "met": 3,
      "not_met": 1,
      "details": [
        {
          "criterion": "AC1: User can add items to cart",
          "met": true,
          "evidence": "POST /cart/items → Item added, cart updated"
        },
        {
          "criterion": "AC2: User can update item quantities",
          "met": true,
          "evidence": "PATCH /cart/items/{id} → Quantity updated"
        },
        {
          "criterion": "AC3: User can remove items from cart",
          "met": true,
          "evidence": "DELETE /cart/items/{id} → Item removed"
        },
        {
          "criterion": "AC4: Cart persists across sessions (saved to database)",
          "met": false,
          "evidence": "Cart data stored in memory only, not persisted to database",
          "missing": "Database persistence not implemented (cart model exists but not used)"
        }
      ]
    },
    "syntax_checks": {
      "total_files": 3,
      "passed": 3,
      "failed": 0
    },
    "overall_status": "FAILED",
    "can_proceed": false,
    "blocking_issues": [
      "AC4 not met: Cart persistence not implemented"
    ]
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: FAILED (Partial)
═══════════════════════════════════════════════════════════

SYNTAX: 3/3 ✓
ACCEPTANCE: 3/4 ✗ (75% complete)

PASSED:
✓ AC1: User can add items to cart
✓ AC2: User can update item quantities
✓ AC3: User can remove items from cart

🛑 BLOCKING ISSUES:
- AC4 not met: Cart persistence not implemented

FAILED CHECKS:
✗ AC4: Cart persists across sessions
  Missing: Database persistence not implemented (cart model exists but not used)

═══════════════════════════════════════════════════════════

❌ CANNOT PROCEED TO COMMIT
Implement database persistence for cart data.

═══════════════════════════════════════════════════════════
```

**Result:** CANNOT proceed to commit. Core functionality works (75% AC met) but critical feature (persistence) missing.

---

### Example 6: Architecture Validation from TOON Input

**Situation:** Validate architecture quality using TOON input from architecture-documentation

**Input:**
- TOON from architecture-documentation skill
- Components: 15
- Dependencies: 42 edges
- Token savings: 42%

**Validation:**

```javascript
// Parse TOON input
import { toonToJson, validateToon } from '../toon-skill/converters/toon-converter.mjs';

const toonInput = {
  architecture_documentation: {
    formats: {
      toon: {
        components_toon: "components[15]{id,name,type,path,description,layer}:\n  proxy-mgmt,Proxy Management,module,iclaude.sh:1343-1666,Handle proxy URL validation and credential storage,infrastructure\n  isolated-env,Isolated Environment,module,iclaude.sh:361-978,Manage portable NVM+Node.js+Claude installation,infrastructure\n  ...",
        dependency_graph_toon: "dependency_graph:\n  nodes[15]{id,label,type,layer}:\n    proxy-mgmt,Proxy Management,component,infrastructure\n    isolated-env,Isolated Environment,component,infrastructure\n    ...\n  edges[42]{from,to,type,description}:\n    isolated-env,version-mgmt,required,Uses lockfile for version tracking\n    version-mgmt,update-mgmt,provides,Lockfile enables reproducible updates\n    ...",
        token_savings: "42.3%"
      }
    },
    component_count: 15,
    dependency_count: 42
  }
};

// Validate TOON syntax
const componentsValidation = validateToon(toonInput.architecture_documentation.formats.toon.components_toon);
const graphValidation = validateToon(toonInput.architecture_documentation.formats.toon.dependency_graph_toon);

if (!componentsValidation.valid || !graphValidation.valid) {
  throw new Error('Invalid TOON input');
}

// Parse TOON to JSON
const componentsData = toonToJson(toonInput.architecture_documentation.formats.toon.components_toon);
const graphData = toonToJson(toonInput.architecture_documentation.formats.toon.dependency_graph_toon);

// Extract nodes and edges
const { nodes, edges } = graphData.dependency_graph;

// Detect circular dependencies
function detectCircularDependencies(nodes, edges) {
  const visited = new Set();
  const recursionStack = new Set();
  const circularDeps = [];

  function hasCycle(nodeId) {
    visited.add(nodeId);
    recursionStack.add(nodeId);

    const outgoing = edges.filter(e => e.from === nodeId);
    for (const edge of outgoing) {
      if (!visited.has(edge.to)) {
        if (hasCycle(edge.to)) return true;
      } else if (recursionStack.has(edge.to)) {
        circularDeps.push(`${nodeId} ↔ ${edge.to}`);
        return true;
      }
    }

    recursionStack.delete(nodeId);
    return false;
  }

  for (const node of nodes) {
    if (!visited.has(node.id)) {
      hasCycle(node.id);
    }
  }

  return circularDeps;
}

const circularDeps = detectCircularDependencies(nodes, edges);

// Validate component count
const expectedCount = toonInput.architecture_documentation.component_count;
const actualCount = componentsData.components.length;

// Validate all edge references exist
const invalidEdges = [];
for (const edge of edges) {
  const fromExists = nodes.some(n => n.id === edge.from);
  const toExists = nodes.some(n => n.id === edge.to);

  if (!fromExists || !toExists) {
    invalidEdges.push(`${edge.from} → ${edge.to} (missing node)`);
  }
}
```

**Validation Output:**

```json
{
  "validation_results": {
    "input_format": "toon",
    "input_token_savings": "42.3%",
    "toon_validation": {
      "components_valid": true,
      "dependency_graph_valid": true,
      "round_trip_test": "passed"
    },
    "architecture_quality": {
      "component_count_matches": true,
      "expected_components": 15,
      "actual_components": 15,
      "circular_dependencies": 0,
      "invalid_edges": 0,
      "all_edges_valid": true
    },
    "overall_status": "PASSED",
    "can_proceed": true
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              ARCHITECTURE VALIDATION: PASSED
═══════════════════════════════════════════════════════════

INPUT FORMAT: TOON (token-efficient)
TOKEN SAVINGS: 42.3%

TOON VALIDATION: ✓
- Components parsed: 15
- Dependency graph parsed: 42 edges
- Round-trip test: PASSED

ARCHITECTURE QUALITY: ✓
- Circular dependencies: 0
- Component count matches: true (15/15)
- All edge references valid: true

═══════════════════════════════════════════════════════════
```

**Result:** Architecture valid (no circular dependencies, all edges valid, TOON parsed correctly).

---

### Example 7: Performance Validation (Load Testing)

**Situation:** Validate performance requirements for API endpoint

**Input:**
- Task: "Optimize GET /products endpoint for high load"
- Complexity: complex
- Mode: full
- Performance Requirements:
  - Response time p95 < 200ms
  - Throughput > 1000 req/sec
  - Error rate < 0.1%

**Validation:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [
        {"criterion": "AC1: Endpoint returns product list", "met": true},
        {"criterion": "AC2: Pagination works correctly", "met": true}
      ]
    },
    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0
    },
    "functional_checks": {
      "total": 2,
      "passed": 2,
      "failed": 0,
      "details": [
        {"test": "pytest tests/test_products_api.py", "result": "passed"},
        {"test": "Integration test: Pagination", "result": "passed"}
      ]
    },
    "performance_checks": {
      "total": 3,
      "passed": 3,
      "failed": 0,
      "details": [
        {
          "requirement": "Response time p95 < 200ms",
          "result": "passed",
          "actual": "147ms",
          "evidence": "locust load test: 1000 concurrent users → p95 = 147ms"
        },
        {
          "requirement": "Throughput > 1000 req/sec",
          "result": "passed",
          "actual": "1342 req/sec",
          "evidence": "locust load test: steady state throughput = 1342 req/sec"
        },
        {
          "requirement": "Error rate < 0.1%",
          "result": "passed",
          "actual": "0.03%",
          "evidence": "locust load test: 3 errors out of 10000 requests = 0.03%"
        }
      ]
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

**Markdown Output:**

```markdown
═══════════════════════════════════════════════════════════
              PERFORMANCE VALIDATION: PASSED
═══════════════════════════════════════════════════════════

SYNTAX: 2/2 ✓
ACCEPTANCE: 2/2 ✓
FUNCTIONAL: 2/2 ✓
PERFORMANCE: 3/3 ✓

PERFORMANCE RESULTS:
✓ Response time p95: 147ms (target: < 200ms)
✓ Throughput: 1342 req/sec (target: > 1000 req/sec)
✓ Error rate: 0.03% (target: < 0.1%)

LOAD TEST DETAILS:
- Concurrent users: 1000
- Total requests: 10000
- Errors: 3 (0.03%)
- p50 latency: 89ms
- p95 latency: 147ms
- p99 latency: 213ms (slightly above target, acceptable)

═══════════════════════════════════════════════════════════
```

**Result:** Performance requirements met (all metrics within targets).

---

## Syntax Commands

Используй: `@shared:syntax-commands`

## Markdown Output Template

```
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: {status}
═══════════════════════════════════════════════════════════

SYNTAX: {passed}/{total} ✓
ACCEPTANCE: {met}/{total} ✓

{если FAILED}
🛑 BLOCKING:
- {issue1}
- {issue2}

═══════════════════════════════════════════════════════════
```

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md для детальной документации
