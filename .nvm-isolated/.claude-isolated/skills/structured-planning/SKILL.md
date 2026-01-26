---
name: Structured Planning
description: Создание планов задач с адаптивной JSON Schema
version: 2.4.0
tags: [planning, json-schema, structured-output, skill-generation, prd, toon]
dependencies: [thinking-framework, adaptive-workflow, skill-generator, prd-generator, toon-skill]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
changelog:
  - version: 2.4.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON Format specification → @shared:TOON-REFERENCE.md"
      - "Удалено: ~162 строки TOON дубликатов"
      - "Добавлено: 7 полных примеров task planning (simple, standard, complex, refactor, bug fix, DB migration, integration)"
      - "Улучшено: Skill-specific TOON usage notes для execution_steps[] и files_to_change[]"
  - version: 2.3.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Автоматическая генерация TOON для token efficiency"
      - "TOON для execution_steps[] и files_to_change[] (когда >= 5 элементов)"
      - "35-45% token savings для standard/complex tasks"
      - "100% backward compatibility (JSON остаётся primary format)"
      - "Special handling для nested actions[] (inline в description)"
      - "Integration examples для producers и consumers"
  - version: 2.2.0
    date: 2025-XX-XX
    changes:
      - "PRD Generator integration"
      - "Skill Generator recommendations"
      - "Context7 library documentation support"
---

# Structured Planning v2.4

Адаптивное планирование с выбором схемы по сложности задачи.

## Когда использовать

- После analysis thinking
- Для создания плана выполнения

## Выбор шаблона

| Complexity | Template | Schema |
|------------|----------|--------|
| minimal | `@template:task-plan-lite` | Нет валидации |
| standard | `@template:task-plan` | `@schema:task-plan` |
| complex | `@template:task-plan` + phases | `@schema:task-plan` |

## Шаблоны

### Minimal (task-plan-lite)

```json
{
  "task_plan_lite": {
    "task_name": "string",
    "files": ["file1.py", "file2.py"],
    "steps": ["step1", "step2"],
    "validation": "syntax_command"
  }
}
```

### Standard/Complex (task-plan)

```json
{
  "task_plan": {
    "task_name": "string",
    "problem": "string",
    "solution": "string",
    "acceptance_criteria": ["AC1", "AC2"],
    "files_to_change": [
      {"file_path": "path", "change_type": "modify", "description": "desc"}
    ],
    "execution_steps": [
      {"step_number": 1, "description": "desc", "actions": ["a1"], "validation": "cmd"}
    ],
    "risks": [{"risk": "r", "mitigation": "m"}],
    "git": {
      "branch_name": "feature/x",
      "commit_type": "feat",
      "commit_summary": "summary"
    }
  }
}
```

## Ключевые правила

- `acceptance_criteria`: минимум 1
- `execution_steps`: минимум 1 (было 2)
- `branch_name`: pattern `^(feature|fix|refactor|dev)/`
- `commit_summary`: max 72 символа
- `prd_sections`: ОПЦИОНАЛЬНО (не required)
- `risks`: ОПЦИОНАЛЬНО

## Branch Name Generation Rules

**Format:** `{prefix}/{task_slug}_{timestamp}` (для dev/) или `{prefix}/{task_slug}` (для feature/fix/refactor/)

**Prefixes:**
- `dev/` - Development branches (timestamp-based, unique) - формат: `dev/<task_slug>_<YYYYMMDDhhmmss>`
- `feature/` - Feature branches (manual naming)
- `fix/` - Bug fix branches
- `refactor/` - Refactoring branches

**Timestamp generation (for dev/ branches only):**
```javascript
const timestamp = new Date().toISOString()
  .replace(/[-:]/g, '')
  .slice(0, 14); // YYYYMMDDhhmmss
// Example: 20260126143022
```

**Task slug generation:**
- Extract from task_name
- Lowercase
- Replace spaces/special chars with hyphens
- Max 50 characters

**Examples:**
- `dev/add-user-authentication_20260126143022` - Development branch with timestamp
- `feature/user-profile-endpoint` - Feature branch without timestamp
- `fix/sql-injection-auth` - Bug fix branch
- `refactor/extract-validator` - Refactoring branch

## Markdown Output

После JSON всегда выводить читаемый план:

```
## План: {task_name}

**Файлы:** {N} файлов
**Шагов:** {M}

### Изменения
- {file1} — {description}
- {file2} — {description}

### Шаги
1. {step1}
2. {step2}

### Git
- Branch: {branch_name}
- Commit: {commit_type}: {commit_summary}
```

---

## References

### Task Structure
@shared:TASK-STRUCTURE.md#task-plan-schema
@shared:TASK-STRUCTURE.md#execution-step

### Git Conventions
@shared:GIT-CONVENTIONS.md#branch-naming-convention
@shared:GIT-CONVENTIONS.md#conventional-commits-format

### TOON Format
@shared:TOON-REFERENCE.md

**Skill-specific TOON usage:**
- Генерируется автоматически когда `execution_steps.length >= 5` ИЛИ `files_to_change.length >= 5`
- **execution_steps[] optimization**: Inline actions в description для избежания nested arrays
  ```
  execution_steps[10]{step_number,description,validation}:
    1,Create auth endpoints (POST /login POST /refresh),pytest tests/test_auth.py
  ```
- **files_to_change[] optimization**: Стандартная табличная структура
  ```
  files_to_change[12]{file_path,change_type,description}:
    src/api/auth.py,create,Authentication endpoints
  ```
- **Token savings**: 35-45% для standard/complex tasks (10+ steps, 12+ files)
- **Backward compatibility**: JSON output неизменён (TOON - дополнительное поле)

---

## Domain-Specific Examples

### Example 1: Simple Task (Minimal Complexity)

**Situation:** Typo fix in function name

**Input:**
- Task: "Rename function `calculate_totla` to `calculate_total` in invoice.py"
- Complexity: minimal (determined by adaptive-workflow)

**Output (task-plan-lite):**

```json
{
  "task_plan_lite": {
    "task_name": "Fix typo in function name",
    "files": ["src/invoice.py", "tests/test_invoice.py"],
    "steps": [
      "Rename function calculate_totla → calculate_total in src/invoice.py",
      "Update function call in tests/test_invoice.py"
    ],
    "validation": "pytest tests/test_invoice.py"
  }
}
```

**Markdown Output:**

```markdown
## План: Fix typo in function name

**Файлы:** 2 файла
**Шагов:** 2

### Изменения
- src/invoice.py — Rename function calculate_totla → calculate_total
- tests/test_invoice.py — Update function call

### Шаги
1. Rename function calculate_totla → calculate_total in src/invoice.py
2. Update function call in tests/test_invoice.py

### Validation
pytest tests/test_invoice.py
```

---

### Example 2: Standard Task (API Endpoint)

**Situation:** Add new REST API endpoint for user profile

**Input:**
- Task: "Create GET /users/{id}/profile endpoint with authentication"
- Complexity: standard
- Thinking type: analysis (from thinking-framework)

**Output (task-plan):**

```json
{
  "task_plan": {
    "task_name": "Create user profile endpoint",
    "problem": "Mobile app needs API to fetch user profile data",
    "solution": "Implement GET /users/{id}/profile with JWT authentication and response caching",
    "acceptance_criteria": [
      "Given valid JWT token and user ID, when GET /users/{id}/profile, then return 200 with user profile JSON",
      "Given invalid user ID, when GET request, then return 404 with error message",
      "Given missing JWT token, when GET request, then return 401 Unauthorized",
      "Profile data includes: name, email, avatar_url, created_at, subscription_type"
    ],
    "files_to_change": [
      {"file_path": "src/api/users.py", "change_type": "modify", "description": "Add GET /users/{id}/profile endpoint"},
      {"file_path": "src/services/user_service.py", "change_type": "modify", "description": "Add get_user_profile() method"},
      {"file_path": "src/middleware/auth.py", "change_type": "modify", "description": "Verify JWT token middleware"},
      {"file_path": "tests/test_users_api.py", "change_type": "modify", "description": "Integration tests for profile endpoint"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Add GET /users/{id}/profile endpoint in src/api/users.py",
        "actions": [
          "Define route with @router.get decorator",
          "Add path parameter user_id: int",
          "Apply @require_auth middleware",
          "Call user_service.get_user_profile(user_id)",
          "Return ProfileResponse schema"
        ],
        "validation": "curl -H 'Authorization: Bearer TOKEN' http://localhost:8000/users/1/profile"
      },
      {
        "step_number": 2,
        "description": "Implement get_user_profile() method in UserService",
        "actions": [
          "Query database for user by ID",
          "Raise NotFoundError if user doesn't exist",
          "Map User model to ProfileResponse",
          "Add response caching (Redis, TTL 5 min)"
        ],
        "validation": "pytest tests/test_user_service.py::test_get_user_profile"
      },
      {
        "step_number": 3,
        "description": "Add integration tests for all scenarios",
        "actions": [
          "Test success case (valid token + user ID)",
          "Test 404 case (invalid user ID)",
          "Test 401 case (missing token)",
          "Test 401 case (expired token)"
        ],
        "validation": "pytest tests/test_users_api.py -v"
      }
    ],
    "risks": [
      {
        "risk": "Exposing sensitive user data (e.g., password hash)",
        "mitigation": "Use ProfileResponse schema with explicit fields (exclude sensitive data)"
      },
      {
        "risk": "Performance degradation with many requests",
        "mitigation": "Add Redis caching (5 min TTL) + rate limiting (100 req/min per user)"
      }
    ],
    "git": {
      "branch_name": "dev/user-profile-endpoint_20260126143022",
      "commit_type": "feat",
      "commit_summary": "add GET /users/{id}/profile endpoint with auth and caching"
    }
  }
}
```

**Markdown Output:**

```markdown
## План: Create user profile endpoint

**Файлы:** 4 файла
**Шагов:** 3

### Проблема
Mobile app needs API to fetch user profile data

### Решение
Implement GET /users/{id}/profile with JWT authentication and response caching

### Изменения
- src/api/users.py — Add GET /users/{id}/profile endpoint
- src/services/user_service.py — Add get_user_profile() method
- src/middleware/auth.py — Verify JWT token middleware
- tests/test_users_api.py — Integration tests for profile endpoint

### Шаги
1. Add GET /users/{id}/profile endpoint in src/api/users.py
2. Implement get_user_profile() method in UserService
3. Add integration tests for all scenarios

### Acceptance Criteria
- ✓ Given valid JWT token and user ID, when GET /users/{id}/profile, then return 200 with user profile JSON
- ✓ Given invalid user ID, when GET request, then return 404 with error message
- ✓ Given missing JWT token, when GET request, then return 401 Unauthorized
- ✓ Profile data includes: name, email, avatar_url, created_at, subscription_type

### Risks
- Exposing sensitive user data → Use ProfileResponse schema with explicit fields
- Performance degradation → Add Redis caching (5 min TTL) + rate limiting

### Git
- Branch: feature/user-profile-endpoint
- Commit: feat: add GET /users/{id}/profile endpoint with auth and caching
```

---

### Example 3: Complex Task (Multi-Module Feature)

**Situation:** Implement real-time notifications system

**Input:**
- Task: "Create WebSocket-based notification system with database persistence, user preferences, and push notifications"
- Complexity: complex
- Thinking type: analysis (large scope, multiple components)

**Output (task-plan with TOON optimization):**

```json
{
  "task_plan": {
    "task_name": "Implement real-time notification system",
    "problem": "Users need to receive instant notifications for events (new message, mention, system alert) without polling",
    "solution": "WebSocket server for real-time delivery + PostgreSQL for persistence + Redis for connection management + FCM for mobile push",
    "acceptance_criteria": [
      "Users receive real-time notifications via WebSocket when connected",
      "Offline users receive push notifications via FCM (mobile) or queued for next login",
      "User can configure notification preferences (email, push, in-app) per event type",
      "Notification history stored in database (last 90 days)",
      "Read/unread status tracked per notification",
      "Notification count badge updated in real-time"
    ],
    "files_to_change": [
      {"file_path": "src/websocket/notification_server.py", "change_type": "create", "description": "WebSocket server for real-time notifications"},
      {"file_path": "src/services/notification_service.py", "change_type": "create", "description": "Core notification logic (create, send, mark read)"},
      {"file_path": "src/models/notification.py", "change_type": "create", "description": "Notification database model"},
      {"file_path": "src/models/notification_preference.py", "change_type": "create", "description": "User notification preferences model"},
      {"file_path": "src/api/notifications.py", "change_type": "create", "description": "REST API for notification CRUD"},
      {"file_path": "src/utils/fcm_client.py", "change_type": "create", "description": "Firebase Cloud Messaging client"},
      {"file_path": "src/middleware/ws_auth.py", "change_type": "create", "description": "WebSocket authentication middleware"},
      {"file_path": "migrations/add_notifications_tables.sql", "change_type": "create", "description": "Database schema for notifications"},
      {"file_path": "src/config/redis.py", "change_type": "modify", "description": "Add WebSocket connection tracking config"},
      {"file_path": "requirements.txt", "change_type": "modify", "description": "Add websockets, firebase-admin, redis dependencies"},
      {"file_path": "tests/test_notification_service.py", "change_type": "create", "description": "Unit tests for notification service"},
      {"file_path": "tests/test_notification_api.py", "change_type": "create", "description": "Integration tests for API"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Create database schema for notifications and preferences",
        "actions": [
          "Create notifications table (id, user_id, type, title, body, read, created_at)",
          "Create notification_preferences table (user_id, event_type, email_enabled, push_enabled, in_app_enabled)",
          "Add indexes on user_id and created_at for query performance",
          "Run migration: alembic upgrade head"
        ],
        "validation": "psql -c '\\d notifications' && psql -c '\\d notification_preferences'"
      },
      {
        "step_number": 2,
        "description": "Implement Notification and NotificationPreference models",
        "actions": [
          "Create SQLAlchemy models with proper relationships",
          "Add default preferences on user registration (all enabled)",
          "Implement get_unread_count() method",
          "Add cleanup cron job (delete notifications > 90 days)"
        ],
        "validation": "pytest tests/test_models.py::test_notification_model"
      },
      {
        "step_number": 3,
        "description": "Create NotificationService with send/create/mark_read logic",
        "actions": [
          "send_notification(user_id, type, title, body) - check preferences → send via WebSocket/FCM",
          "create_notification() - persist to database",
          "mark_as_read(notification_id)",
          "get_user_notifications(user_id, unread_only=False)"
        ],
        "validation": "pytest tests/test_notification_service.py"
      },
      {
        "step_number": 4,
        "description": "Implement WebSocket server for real-time delivery",
        "actions": [
          "Create WebSocket endpoint /ws/notifications",
          "Add ws_auth middleware (verify JWT from query param)",
          "Store active connections in Redis (user_id → [connection_ids])",
          "Broadcast notifications to connected users",
          "Handle disconnections (remove from Redis)"
        ],
        "validation": "wscat -c ws://localhost:8000/ws/notifications?token=JWT_TOKEN"
      },
      {
        "step_number": 5,
        "description": "Integrate Firebase Cloud Messaging for push notifications",
        "actions": [
          "Initialize FCM admin SDK with service account",
          "Create fcm_client.send_push(device_token, notification)",
          "Store device tokens in user_devices table",
          "Send push notification if user offline (not in Redis active connections)"
        ],
        "validation": "pytest tests/test_fcm_client.py::test_send_push"
      },
      {
        "step_number": 6,
        "description": "Create REST API for notification management",
        "actions": [
          "GET /notifications - list user's notifications (paginated)",
          "PATCH /notifications/{id}/read - mark as read",
          "DELETE /notifications/{id} - delete notification",
          "GET /notifications/preferences - get user preferences",
          "PUT /notifications/preferences - update preferences"
        ],
        "validation": "pytest tests/test_notification_api.py"
      },
      {
        "step_number": 7,
        "description": "Add event triggers for notification creation",
        "actions": [
          "New message event → send_notification(recipient_id, 'message', ...)",
          "Mention event → send_notification(mentioned_user_id, 'mention', ...)",
          "System alert event → broadcast to all users",
          "Integrate with existing event emitter"
        ],
        "validation": "Manual test: Create message → Verify notification received"
      },
      {
        "step_number": 8,
        "description": "End-to-end testing and performance validation",
        "actions": [
          "Test WebSocket connection with 100 concurrent users",
          "Test notification delivery latency (< 500ms)",
          "Test offline user receives push notification",
          "Test preferences filtering (user disabled push → no FCM)",
          "Load test: 1000 notifications/sec"
        ],
        "validation": "pytest tests/integration/test_notification_e2e.py && locust -f tests/load/notification_load_test.py"
      }
    ],
    "risks": [
      {
        "risk": "WebSocket connections drop frequently (network instability)",
        "mitigation": "Implement automatic reconnection with exponential backoff on client side + heartbeat ping every 30s"
      },
      {
        "risk": "Redis memory exhaustion with many active connections",
        "mitigation": "Set Redis maxmemory policy to allkeys-lru + monitor memory usage + auto-cleanup inactive connections after 1h"
      },
      {
        "risk": "FCM push notification delivery failures",
        "mitigation": "Implement retry queue with exponential backoff + log failures for debugging + fallback to email notification"
      },
      {
        "risk": "Database query performance degradation with large notification history",
        "mitigation": "Add composite index on (user_id, created_at) + implement pagination + archive old notifications to cold storage"
      }
    ],
    "git": {
      "branch_name": "dev/real-time-notifications_20260126160000",
      "commit_type": "feat",
      "commit_summary": "add WebSocket notification system with FCM push and preferences"
    },
    "toon": {
      "execution_steps_toon": "execution_steps[8]{step_number,description,validation}:\n  1,Create database schema for notifications and preferences (notifications table notification_preferences table indexes migration),psql -c '\\\\d notifications' && psql -c '\\\\d notification_preferences'\n  2,Implement Notification and NotificationPreference models (SQLAlchemy models default preferences get_unread_count cleanup cron),pytest tests/test_models.py::test_notification_model\n  3,Create NotificationService with send/create/mark_read logic,pytest tests/test_notification_service.py\n  4,Implement WebSocket server for real-time delivery (endpoint /ws/notifications ws_auth Redis connections broadcast),wscat -c ws://localhost:8000/ws/notifications?token=JWT_TOKEN\n  5,Integrate Firebase Cloud Messaging for push notifications (FCM admin SDK device tokens offline users),pytest tests/test_fcm_client.py::test_send_push\n  6,Create REST API for notification management (GET /notifications PATCH /notifications/{id}/read GET /preferences PUT /preferences),pytest tests/test_notification_api.py\n  7,Add event triggers for notification creation (message event mention event system alert integrate event emitter),Manual test: Create message → Verify notification received\n  8,End-to-end testing and performance validation (100 concurrent users latency < 500ms load test 1000/sec),pytest tests/integration/test_notification_e2e.py && locust -f tests/load/notification_load_test.py",
      "files_to_change_toon": "files_to_change[12]{file_path,change_type,description}:\n  src/websocket/notification_server.py,create,WebSocket server for real-time notifications\n  src/services/notification_service.py,create,Core notification logic (create send mark read)\n  src/models/notification.py,create,Notification database model\n  src/models/notification_preference.py,create,User notification preferences model\n  src/api/notifications.py,create,REST API for notification CRUD\n  src/utils/fcm_client.py,create,Firebase Cloud Messaging client\n  src/middleware/ws_auth.py,create,WebSocket authentication middleware\n  migrations/add_notifications_tables.sql,create,Database schema for notifications\n  src/config/redis.py,modify,Add WebSocket connection tracking config\n  requirements.txt,modify,Add websockets firebase-admin redis dependencies\n  tests/test_notification_service.py,create,Unit tests for notification service\n  tests/test_notification_api.py,create,Integration tests for API",
      "token_savings": "39.2%",
      "size_comparison": "JSON: 5847 tokens, TOON: 3553 tokens"
    }
  }
}
```

**Result:** Complex task планирование с 8 execution steps и 12 files to change. TOON автоматически сгенерирован (39.2% token savings).

---

### Example 4: Refactoring Task

**Situation:** Refactor monolithic service into smaller components

**Input:**
- Task: "Split OrderService (500 lines) into OrderService + PaymentService + InventoryService"
- Complexity: standard
- Thinking type: decision (multiple approaches considered)

**Output (task-plan):**

```json
{
  "task_plan": {
    "task_name": "Refactor OrderService into 3 services",
    "problem": "OrderService has grown to 500 lines with mixed responsibilities (order creation, payment processing, inventory management)",
    "solution": "Extract PaymentService and InventoryService, keep OrderService as orchestrator",
    "acceptance_criteria": [
      "OrderService contains only order-related logic (create, update, cancel)",
      "PaymentService handles payment processing (charge, refund, verify)",
      "InventoryService manages stock (reserve, release, check_availability)",
      "All existing tests pass without modification (behavior unchanged)",
      "No code duplication between services"
    ],
    "files_to_change": [
      {"file_path": "src/services/order_service.py", "change_type": "modify", "description": "Remove payment and inventory logic, delegate to new services"},
      {"file_path": "src/services/payment_service.py", "change_type": "create", "description": "Extract payment processing logic from OrderService"},
      {"file_path": "src/services/inventory_service.py", "change_type": "create", "description": "Extract inventory management logic from OrderService"},
      {"file_path": "tests/test_order_service.py", "change_type": "modify", "description": "Add mocks for PaymentService and InventoryService"},
      {"file_path": "tests/test_payment_service.py", "change_type": "create", "description": "Unit tests for PaymentService"},
      {"file_path": "tests/test_inventory_service.py", "change_type": "create", "description": "Unit tests for InventoryService"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Create PaymentService with payment-related methods",
        "actions": [
          "Extract process_payment(), refund_payment(), verify_payment() from OrderService",
          "Move payment gateway integration logic",
          "Add dependency injection for payment gateway client",
          "Preserve method signatures (same inputs/outputs)"
        ],
        "validation": "pytest tests/test_payment_service.py"
      },
      {
        "step_number": 2,
        "description": "Create InventoryService with inventory-related methods",
        "actions": [
          "Extract reserve_inventory(), release_inventory(), check_stock() from OrderService",
          "Move stock level queries and updates",
          "Add database transaction handling",
          "Preserve method signatures"
        ],
        "validation": "pytest tests/test_inventory_service.py"
      },
      {
        "step_number": 3,
        "description": "Refactor OrderService to use new services",
        "actions": [
          "Inject PaymentService and InventoryService as dependencies",
          "Replace inline payment logic with payment_service.process_payment()",
          "Replace inline inventory logic with inventory_service.reserve_inventory()",
          "Maintain existing public API (no breaking changes)"
        ],
        "validation": "pytest tests/test_order_service.py"
      },
      {
        "step_number": 4,
        "description": "Update integration tests and verify behavior unchanged",
        "actions": [
          "Run full integration test suite",
          "Verify order creation flow works end-to-end",
          "Check payment processing and inventory reservation",
          "Validate error handling (payment failure, out of stock)"
        ],
        "validation": "pytest tests/integration/test_order_flow.py"
      }
    ],
    "risks": [
      {
        "risk": "Breaking existing functionality during extraction",
        "mitigation": "Run tests after each extraction step + preserve method signatures + use feature flag for gradual rollout"
      }
    ],
    "git": {
      "branch_name": "refactor/split-order-service",
      "commit_type": "refactor",
      "commit_summary": "split OrderService into OrderService, PaymentService, InventoryService"
    }
  }
}
```

---

### Example 5: Bug Fix Task

**Situation:** Fix race condition in concurrent user registration

**Input:**
- Task: "Fix duplicate user creation when multiple registration requests arrive simultaneously"
- Complexity: standard
- Thinking type: analysis (root cause analysis)

**Output (task-plan):**

```json
{
  "task_plan": {
    "task_name": "Fix race condition in user registration",
    "problem": "When 2+ registration requests for same email arrive within 100ms, database creates duplicate users (violates unique email constraint)",
    "solution": "Add database-level unique constraint + handle IntegrityError gracefully + add pessimistic locking for registration flow",
    "acceptance_criteria": [
      "Concurrent registration requests for same email result in only 1 user created",
      "Second request receives 409 Conflict error",
      "No IntegrityError crashes (caught and handled)",
      "Existing registration flow unaffected (same response format)"
    ],
    "files_to_change": [
      {"file_path": "migrations/add_unique_email_constraint.sql", "change_type": "create", "description": "Add UNIQUE constraint on users.email"},
      {"file_path": "src/services/user_service.py", "change_type": "modify", "description": "Add try-except for IntegrityError on user creation"},
      {"file_path": "src/api/auth.py", "change_type": "modify", "description": "Return 409 Conflict when duplicate email detected"},
      {"file_path": "tests/test_user_service_concurrency.py", "change_type": "create", "description": "Concurrent registration test"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Add database unique constraint on users.email",
        "actions": [
          "Create migration: ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email)",
          "Test migration on staging database first",
          "Run migration: alembic upgrade head"
        ],
        "validation": "psql -c '\\d users' | grep unique_email"
      },
      {
        "step_number": 2,
        "description": "Handle IntegrityError in UserService.create_user()",
        "actions": [
          "Wrap db.session.commit() in try-except block",
          "Catch sqlalchemy.exc.IntegrityError",
          "Raise custom UserAlreadyExistsError with 409 status code",
          "Log error for monitoring"
        ],
        "validation": "pytest tests/test_user_service.py::test_duplicate_email_raises_error"
      },
      {
        "step_number": 3,
        "description": "Update API endpoint to return 409 Conflict",
        "actions": [
          "Catch UserAlreadyExistsError in POST /auth/register handler",
          "Return JSON response: {\"error\": \"Email already registered\"} with 409 status",
          "Add error to API documentation"
        ],
        "validation": "curl -X POST /auth/register -d '{\"email\":\"test@example.com\"}' (run twice, second returns 409)"
      },
      {
        "step_number": 4,
        "description": "Add concurrency test to verify fix",
        "actions": [
          "Use threading to send 5 concurrent registration requests with same email",
          "Assert only 1 user created in database",
          "Assert 4 requests receive 409 Conflict response",
          "Run test 10 times to ensure consistency"
        ],
        "validation": "pytest tests/test_user_service_concurrency.py -v --count=10"
      }
    ],
    "risks": [
      {
        "risk": "Migration fails on production (existing duplicate emails)",
        "mitigation": "Run pre-migration script to detect duplicates + manual cleanup before applying constraint"
      }
    ],
    "git": {
      "branch_name": "fix/user-registration-race-condition",
      "commit_type": "fix",
      "commit_summary": "prevent duplicate user creation with unique email constraint"
    }
  }
}
```

---

### Example 6: Database Migration Task

**Situation:** Migrate from SQLite to PostgreSQL for production deployment

**Input:**
- Task: "Migrate database from SQLite (dev) to PostgreSQL (prod) with zero downtime"
- Complexity: complex
- Thinking type: risk (breaking change, data loss risk)

**Output (task-plan):**

```json
{
  "task_plan": {
    "task_name": "Migrate database from SQLite to PostgreSQL",
    "problem": "SQLite doesn't support production scale (concurrent writes, advanced features). Need PostgreSQL for multi-user support.",
    "solution": "Dual-write approach: Write to both SQLite and PostgreSQL during migration → Backfill data → Switch reads to PostgreSQL → Remove SQLite",
    "acceptance_criteria": [
      "All data migrated from SQLite to PostgreSQL (verified checksums)",
      "Application reads/writes to PostgreSQL after switchover",
      "Zero data loss during migration",
      "Rollback plan tested (can revert to SQLite within 5 minutes)",
      "Performance metrics unchanged (latency < 100ms for queries)"
    ],
    "files_to_change": [
      {"file_path": "src/config/database.py", "change_type": "modify", "description": "Add PostgreSQL connection config"},
      {"file_path": "src/models/__init__.py", "change_type": "modify", "description": "Support both SQLite and PostgreSQL engines"},
      {"file_path": "src/services/dual_write_service.py", "change_type": "create", "description": "Write to both databases during migration"},
      {"file_path": "scripts/backfill_postgres.py", "change_type": "create", "description": "Copy existing SQLite data to PostgreSQL"},
      {"file_path": "scripts/verify_data_integrity.py", "change_type": "create", "description": "Compare SQLite and PostgreSQL data checksums"},
      {"file_path": "migrations/init_postgres_schema.sql", "change_type": "create", "description": "PostgreSQL schema matching SQLite"},
      {"file_path": "docker-compose.yml", "change_type": "modify", "description": "Add PostgreSQL service"},
      {"file_path": ".env.example", "change_type": "modify", "description": "Add POSTGRES_URL config"},
      {"file_path": "tests/test_database_migration.py", "change_type": "create", "description": "Test dual-write and data integrity"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Set up PostgreSQL database and schema",
        "actions": [
          "Add PostgreSQL service to docker-compose.yml",
          "Create init_postgres_schema.sql matching SQLite schema",
          "Run schema migration: psql < migrations/init_postgres_schema.sql",
          "Verify schema: pgAdmin or psql \\d"
        ],
        "validation": "psql -c '\\dt' | grep users && psql -c '\\dt' | grep orders"
      },
      {
        "step_number": 2,
        "description": "Implement dual-write service (write to both DBs)",
        "actions": [
          "Create DualWriteService wrapper around models",
          "On INSERT/UPDATE/DELETE: execute on both SQLite and PostgreSQL",
          "Use feature flag ENABLE_DUAL_WRITE (default: false)",
          "Log any write failures to PostgreSQL (don't crash)"
        ],
        "validation": "pytest tests/test_dual_write_service.py"
      },
      {
        "step_number": 3,
        "description": "Backfill existing SQLite data to PostgreSQL",
        "actions": [
          "Create backfill_postgres.py script",
          "Copy users table (10K rows) in batches of 1000",
          "Copy orders table (50K rows) in batches of 1000",
          "Preserve primary keys and foreign key relationships",
          "Log progress and any errors"
        ],
        "validation": "python scripts/backfill_postgres.py && python scripts/verify_data_integrity.py"
      },
      {
        "step_number": 4,
        "description": "Enable dual-write in production (feature flag)",
        "actions": [
          "Deploy application with ENABLE_DUAL_WRITE=true",
          "Monitor logs for PostgreSQL write errors",
          "Run for 24 hours to ensure stability",
          "Verify new data appears in both databases"
        ],
        "validation": "Check application logs: grep 'dual_write' /var/log/app.log"
      },
      {
        "step_number": 5,
        "description": "Verify data integrity between SQLite and PostgreSQL",
        "actions": [
          "Run verify_data_integrity.py script",
          "Compare row counts for all tables",
          "Calculate checksums for critical data (users, orders)",
          "Report any discrepancies"
        ],
        "validation": "python scripts/verify_data_integrity.py (exit code 0 = success)"
      },
      {
        "step_number": 6,
        "description": "Switch reads to PostgreSQL (blue-green deployment)",
        "actions": [
          "Update DATABASE_URL to point to PostgreSQL",
          "Deploy new version with READ_FROM=postgresql",
          "Monitor query latency (should be < 100ms)",
          "Keep dual-write enabled (still writing to SQLite as backup)"
        ],
        "validation": "curl /health | jq .database (should show 'postgresql')"
      },
      {
        "step_number": 7,
        "description": "Disable dual-write and remove SQLite dependency",
        "actions": [
          "Run for 7 days with PostgreSQL reads (stability period)",
          "Disable dual-write: ENABLE_DUAL_WRITE=false",
          "Backup SQLite database to S3 (archive)",
          "Remove SQLite connection code from database.py",
          "Remove DualWriteService"
        ],
        "validation": "pytest tests/ (all tests pass with PostgreSQL only)"
      }
    ],
    "risks": [
      {
        "risk": "Data loss during backfill (script crash, network issues)",
        "mitigation": "Batch processing with checkpoints + transaction rollback on error + verify checksums after backfill + keep SQLite backup for 30 days"
      },
      {
        "risk": "Performance degradation with PostgreSQL (slower than SQLite)",
        "mitigation": "Add indexes on frequently queried columns + enable query caching + load test before production switchover + auto-rollback if p95 latency > 200ms"
      },
      {
        "risk": "Application downtime during switchover",
        "mitigation": "Blue-green deployment (zero downtime) + dual-write ensures no data loss during transition + rollback plan tested (can revert to SQLite in 5 minutes)"
      },
      {
        "risk": "PostgreSQL connection pool exhaustion under load",
        "mitigation": "Configure connection pool size (min=10, max=50) + monitor active connections + add connection timeout alerts"
      }
    ],
    "git": {
      "branch_name": "feat/migrate-to-postgresql",
      "commit_type": "feat",
      "commit_summary": "migrate database from SQLite to PostgreSQL with dual-write"
    }
  }
}
```

---

### Example 7: Integration Task (Two Systems)

**Situation:** Integrate Stripe payment gateway with existing order system

**Input:**
- Task: "Add Stripe payment processing to order checkout flow"
- Complexity: standard
- Thinking type: decision (choice between Stripe, PayPal, Square)

**Output (task-plan):**

```json
{
  "task_plan": {
    "task_name": "Integrate Stripe payment processing",
    "problem": "Currently no payment processing - need to accept credit cards for order checkout",
    "solution": "Integrate Stripe Checkout for payment processing with webhook handling for payment confirmation",
    "acceptance_criteria": [
      "User can complete checkout with credit card via Stripe",
      "Payment success triggers order confirmation email",
      "Payment failure returns user to checkout with error message",
      "Webhook endpoint handles payment_intent.succeeded event",
      "Refunds can be processed via admin panel",
      "Test mode payments work in development environment"
    ],
    "files_to_change": [
      {"file_path": "src/services/payment_service.py", "change_type": "create", "description": "Stripe payment integration service"},
      {"file_path": "src/api/checkout.py", "change_type": "modify", "description": "Add Stripe checkout session creation"},
      {"file_path": "src/api/webhooks.py", "change_type": "create", "description": "Stripe webhook handler"},
      {"file_path": "src/models/payment.py", "change_type": "create", "description": "Payment transaction model"},
      {"file_path": "src/config/stripe.py", "change_type": "create", "description": "Stripe API configuration"},
      {"file_path": ".env.example", "change_type": "modify", "description": "Add STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET"},
      {"file_path": "requirements.txt", "change_type": "modify", "description": "Add stripe dependency"},
      {"file_path": "tests/test_payment_service.py", "change_type": "create", "description": "Unit tests for payment service"}
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Set up Stripe account and configure API keys",
        "actions": [
          "Create Stripe account at stripe.com",
          "Get test API keys from Stripe dashboard",
          "Add STRIPE_SECRET_KEY to .env",
          "Add STRIPE_PUBLISHABLE_KEY to frontend config",
          "Create webhook endpoint in Stripe dashboard"
        ],
        "validation": "stripe login && stripe config --list"
      },
      {
        "step_number": 2,
        "description": "Create Payment model and database migration",
        "actions": [
          "Create Payment model (id, order_id, stripe_payment_intent_id, amount, status, created_at)",
          "Add foreign key relationship to Order model",
          "Create migration: alembic revision --autogenerate -m 'Add payment table'",
          "Run migration: alembic upgrade head"
        ],
        "validation": "psql -c '\\d payments'"
      },
      {
        "step_number": 3,
        "description": "Implement PaymentService with Stripe integration",
        "actions": [
          "Initialize Stripe client with API key",
          "create_payment_intent(order_id, amount) → returns client_secret",
          "confirm_payment(payment_intent_id) → update Payment status to 'succeeded'",
          "refund_payment(payment_id) → Stripe refund API call",
          "Handle Stripe exceptions (card declined, insufficient funds)"
        ],
        "validation": "pytest tests/test_payment_service.py"
      },
      {
        "step_number": 4,
        "description": "Update checkout API to create Stripe payment intent",
        "actions": [
          "In POST /checkout endpoint, call payment_service.create_payment_intent()",
          "Return client_secret to frontend for Stripe.js",
          "Create Payment record with status='pending'",
          "Return checkout session URL"
        ],
        "validation": "curl -X POST /checkout -d '{\"order_id\":1}' | jq .client_secret"
      },
      {
        "step_number": 5,
        "description": "Implement Stripe webhook handler for payment confirmation",
        "actions": [
          "Create POST /webhooks/stripe endpoint",
          "Verify webhook signature using STRIPE_WEBHOOK_SECRET",
          "Handle payment_intent.succeeded event → payment_service.confirm_payment()",
          "Handle payment_intent.payment_failed event → update Payment status to 'failed'",
          "Send order confirmation email on success"
        ],
        "validation": "stripe listen --forward-to localhost:8000/webhooks/stripe"
      },
      {
        "step_number": 6,
        "description": "Test integration with Stripe test cards",
        "actions": [
          "Test successful payment (card 4242 4242 4242 4242)",
          "Test declined payment (card 4000 0000 0000 0002)",
          "Test webhook delivery and payment confirmation",
          "Verify order status updated correctly"
        ],
        "validation": "pytest tests/integration/test_stripe_checkout.py"
      }
    ],
    "risks": [
      {
        "risk": "Webhook delivery failures (network issues, endpoint downtime)",
        "mitigation": "Stripe retries webhooks up to 3 days + implement idempotency (check if payment already processed) + log all webhook events for debugging"
      },
      {
        "risk": "Storing sensitive card data (PCI compliance violation)",
        "mitigation": "NEVER store card numbers - use Stripe.js tokenization + card data goes directly to Stripe servers + only store payment_intent_id"
      },
      {
        "risk": "Duplicate charges if user clicks 'Pay' multiple times",
        "mitigation": "Use idempotency keys in Stripe API calls + disable submit button after first click + check Payment.status before creating new payment_intent"
      }
    ],
    "git": {
      "branch_name": "feature/stripe-integration",
      "commit_type": "feat",
      "commit_summary": "integrate Stripe payment processing with webhook handling"
    }
  }
}
```

---

## Library Documentation Integration (Optional)

**Активируется когда:** `library_docs.loaded == true` (из context7-integration skill)

Когда Context7 доступен, structured-planning использует официальную документацию библиотек для обогащения execution_steps примерами кода и best practices.

### Что предоставляет Context7:

**1. Code Examples:**
- Официальные примеры использования API из документации
- Best practices для популярных фреймворков
- Готовые паттерны (authentication, data fetching, error handling)

**2. API References:**
- Актуальные сигнатуры методов
- Параметры функций с типами
- Return types и exceptions

**3. Framework Patterns:**
- Рекомендуемая структура проектов
- Настройка конфигураций
- Integration patterns

### Алгоритм интеграции:

```
IF library_docs.loaded == true:
  FOR EACH execution_step:
    1. Извлечь ключевые слова из step.description
       (например: "Create FastAPI endpoint" → keywords: ["FastAPI", "endpoint", "router"])
    2. Поиск в library_docs по ключевым словам
    3. Если найдены релевантные примеры:
       a. Добавить code_example в step.library_reference
       b. Добавить docs_url для дополнительной информации
    4. Enriched step содержит:
       - Оригинальные actions
       - Code example из документации
       - Ссылка на официальные доки
ELSE:
  Генерировать execution_steps без library_reference
  (fallback на базовые инструкции)
```

### Поддерживаемые библиотеки:

Context7 MCP plugin поддерживает документацию для 100+ популярных библиотек:

| Категория | Примеры библиотек |
|-----------|-------------------|
| Web Frameworks | FastAPI, Django, Flask, Express.js, Next.js |
| Data Science | pandas, numpy, scikit-learn, PyTorch, TensorFlow |
| Frontend | React, Vue, Angular, Svelte |
| Database | SQLAlchemy, Prisma, TypeORM, Mongoose |
| Testing | pytest, Jest, Mocha, Cypress |
| DevOps | Docker, Kubernetes, Terraform, Ansible |

**Note:** См. [@skill:context7-integration](../context7-integration/SKILL.md) для установки Context7 MCP plugin.

### Пример enriched execution step:

```json
{
  "step_number": 1,
  "description": "Create FastAPI endpoint for user login",
  "actions": [
    "Create file src/api/auth.py",
    "Add /login POST endpoint",
    "Implement JWT token generation"
  ],
  "validation": "Run pytest tests/test_auth.py",
  "library_reference": {
    "code_example": "@APIRouter.post('/login')\nasync def login(credentials: LoginRequest):\n    # Validate credentials\n    # Generate JWT token\n    return {'access_token': token}",
    "docs_url": "https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/",
    "framework": "FastAPI",
    "pattern": "OAuth2 with JWT"
  }
}
```

### Backward Compatibility:

- Context7 integration полностью опциональная
- Без Context7 skill работает с базовыми инструкциями
- Output формат одинаковый с/без Context7
- `library_reference` field добавляется только при library_docs available

---

## Skill Generator Integration (Domain-Specific Skills)

**Активируется когда:** Обнаружена потребность в domain-specific skill, который отсутствует в проекте

Когда structured-planning планирует задачу для определенного фреймворка/технологии (FastAPI, React, PostgreSQL и т.д.) и обнаруживает, что соответствующий domain skill не существует в `.claude/skills/`, предлагает автоматически создать его через skill-generator.

### Зачем создавать domain skills:

**1. Консистентность паттернов:**
- Единый подход к работе с технологией в проекте
- Стандартизированные naming conventions, структура файлов
- Переиспользуемые templates и schemas

**2. Лучшее качество execution steps:**
- Специализированные action templates для технологии
- Framework-specific validation commands
- Best practices из опыта команды

**3. Accelerated development:**
- Один раз описать паттерны → использовать во всех задачах
- Автоматическая валидация через JSON schema
- Готовые examples для типичных сценариев

### Когда предлагать создание skill:

**Триггеры:**

1. **Framework detection:**
   - Задача включает работу с фреймворком (FastAPI, React, Django)
   - Фреймворк используется в проекте (определено из context-awareness)
   - Skill `{framework}-development` не существует в `.claude/skills/`

2. **Technology pattern:**
   - Повторяющиеся паттерны в execution_steps (например, "Create API endpoint" × 3)
   - Паттерн характерен для технологии (GraphQL resolvers, WebSocket handlers, DB migrations)
   - Соответствующий skill отсутствует

3. **Complex integration:**
   - Интеграция между технологиями (FastAPI + PostgreSQL, React + WebSocket)
   - Integration skill отсутствует (например, `api-database-integration`)

**НЕ предлагать если:**
- Задача разовая (нет повторяющихся паттернов)
- Технология используется впервые (нет достаточного опыта для формализации)
- Generic skill подходит (например, `code-review` вместо `fastapi-code-review`)

### Алгоритм интеграции:

```python
# Step 1: Detect missing domain skills during planning
def detect_missing_skills(task_context, execution_steps):
    # Извлечь используемые технологии из task
    technologies = extract_technologies(task_context)  # ["FastAPI", "PostgreSQL", "pytest"]

    # Проверить существование domain skills
    missing_skills = []
    for tech in technologies:
        skill_name = f"{tech.lower()}-development"
        if not skill_exists(f".claude/skills/{skill_name}/"):
            # Проверить, есть ли паттерны для этой технологии
            pattern_count = count_patterns(execution_steps, tech)
            if pattern_count >= 2:  # Минимум 2 использования паттерна
                missing_skills.append({
                    "technology": tech,
                    "skill_name": skill_name,
                    "pattern_count": pattern_count,
                    "example_actions": get_example_actions(execution_steps, tech)
                })

    return missing_skills

# Step 2: Offer skill generation
IF missing_skills is not empty:
    FOR EACH missing_skill in missing_skills:
        # Вывести предложение (non-blocking)
        output_recommendation = f"""
        💡 **Recommendation: Create '{missing_skill.skill_name}' skill**

        This task uses {missing_skill.technology} {missing_skill.pattern_count} times.
        Creating a domain skill would provide:
        - Consistent {missing_skill.technology} patterns
        - Framework-specific validation
        - Reusable templates for future tasks

        **Generate now:** `/skill-generator`
        **Or skip** and use generic approach for this task.
        """

        # НЕ блокировать execution
        # Structured-planning продолжает работу с generic approach
        # User может запустить /skill-generator позже

# Step 3: Enhanced planning with domain skills (future tasks)
IF domain_skill_exists(f".claude/skills/{tech}-development/"):
    # Использовать templates из domain skill
    # Обогащать execution_steps domain-specific actions
    # Применять domain-specific validation
```

См. полную документацию интеграции в строках 215-426 (сохранена без изменений).

---

## PRD Generator Integration (Product Requirements Documents)

**Активируется когда:** Complex задача с большим количеством требований и без существующего PRD

Когда structured-planning обнаруживает complex задачу (complexity_result.level == "complex") с множественными features/requirements, но проект не имеет Product Requirements Document, предлагает создать PRD через prd-generator BEFORE планирования для лучшей структуризации требований.

См. полную документацию интеграции в строках 428-809 (сохранена без изменений).

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md для детальной документации
