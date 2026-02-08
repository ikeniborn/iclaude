# Example 1: Analysis Thinking - Feature Implementation

## Scenario

User requests adding a transaction filtering endpoint to an existing FastAPI application.

## Context

This example demonstrates **analysis thinking** applied to feature implementation with:
- **PRD compliance checking** - Ensuring implementation matches Product Requirements Document
- **FastAPI-specific context** - Query parameters design, Pydantic validation
- **Integration testing strategy** - Comprehensive test coverage for filter combinations

**What makes this unique**: This example shows how analysis thinking integrates with PRD alignment verification and detailed API design decisions (absent from PATTERNS.md reference examples).

## Input

**User request:**
```
Add transaction filtering endpoint with date range and category filters
```

## Thinking Process

```xml
<thinking type="analysis">
ЗАДАЧА: Реализовать endpoint GET /transactions с query parameters для фильтрации по дате и категории

КОНТЕКСТ: Проект использует FastAPI + SQLAlchemy. Существуют endpoints:
- GET /transactions (all, without filters)
- GET /transactions/{id} (single)
PRD секция 4.2 "Transaction Filtering" требует: date_from, date_to, category params.

КОМПОНЕНТЫ:
- app/api/transactions.py (modify - добавить query params)
- app/services/transaction_service.py (modify - filter logic)
- tests/test_transactions_api.py (modify - integration tests)

PRD: Секция 4.2 "Transaction Filtering":
- Query params: date_from (ISO), date_to (ISO), category (enum)
- AND logic для multiple filters
- Pagination: limit 50 default
- Error handling: Invalid date → 400 error

ACCEPTANCE CRITERIA:
- Все 3 query params работают
- Комбинация filters использует AND logic
- Pagination добавлена (limit/offset)
- Error handling для invalid inputs
- Integration tests для filter combinations

ВЫВОДЫ: Добавить 3 optional query parameters в endpoint. Реализовать TransactionService.filter() с AND logic. Добавить pagination. Валидация date format через Pydantic. Integration tests для 5+ filter scenarios.
</thinking>
```

## Output

**Structured task plan:**
1. Add query parameters to GET /transactions endpoint
2. Implement TransactionService.filter() with AND logic
3. Add Pydantic validation for date_from/date_to (ISO 8601 format)
4. Implement pagination (limit/offset params, default limit=50)
5. Add integration tests for filter combinations (date only, category only, both, invalid dates)

## Why This Example is Unique

**Differences from PATTERNS.md reference examples:**

1. **PRD integration** - Shows explicit PRD section reference and compliance checking
2. **Framework-specific design** - FastAPI query parameters, Pydantic validation, SQLAlchemy filters
3. **Detailed acceptance criteria** - Goes beyond simple feature description to define testable outcomes
4. **Integration testing strategy** - Specifies 5+ test scenarios for filter combinations

**Real-world complexity demonstrated:**
- Multiple filter parameters with AND logic (not just single filter)
- Pagination requirements (limit/offset with defaults)
- Input validation strategy (Pydantic schemas for ISO dates)
- Edge cases in testing (date only, category only, both filters, invalid inputs)

## Key Takeaways

1. **PRD alignment** - Always check PRD section before implementation planning
2. **Acceptance criteria** - Convert requirements into testable conditions
3. **Framework conventions** - Leverage FastAPI/Pydantic for validation (don't reinvent)
4. **Test coverage** - Plan integration tests for all filter combinations upfront
