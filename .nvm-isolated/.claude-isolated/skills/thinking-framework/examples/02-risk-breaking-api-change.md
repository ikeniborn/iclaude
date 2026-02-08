# Example 2: Risk Thinking - Breaking API Change

## Scenario

Refactoring API response format from flat array to nested object with pagination metadata (breaking change affecting mobile apps and third-party integrations).

## Context

This example demonstrates **risk thinking** applied to breaking API changes with:
- **API versioning strategy** - Running v1/v2 in parallel with gradual migration
- **Mobile app compatibility** - iOS/Android impact assessment and rollout plan
- **Third-party integrations** - Notification and support strategy for external consumers
- **Performance monitoring** - Load testing and auto-rollback triggers

**What makes this unique**: Enterprise-scale risk assessment covering multiple stakeholder groups (mobile users, integration partners), versioning strategy, and gradual rollout mechanics (not covered in PATTERNS.md examples).

## Input

**API refactoring plan:**
```
Change GET /transactions response:
- OLD (v1): Flat array [{"id": 1, "amount": 100}, ...]
- NEW (v2): Nested object {"data": [...], "pagination": {...}}
```

## Thinking Process

```xml
<thinking type="risk">
ОПЕРАЦИЯ: Refactor API response format - изменить GET /transactions response с flat array на nested object с pagination metadata. Breaking change для mobile apps.

РИСКИ:
  1. Mobile apps (iOS/Android) перестанут работать —
     Вероятность: High
     Impact: High (100K+ active users)
     Митигация:
     - API versioning: /api/v1/transactions (old format, deprecated) + /api/v2/transactions (new format)
     - Deprecated v1 через 6 months (notification via in-app banner)
     - Both versions live parallel first 3 months

  2. Third-party integrations break —
     Вероятность: Medium
     Impact: Medium (5 known integrations)
     Митигация:
     - Contact integration partners (2 weeks notice)
     - Provide migration guide with code examples
     - Offer support during transition period

  3. Performance degradation с nested structure —
     Вероятность: Low
     Impact: Medium (response size +15%)
     Митигация:
     - Load testing: verify p95 latency < 200ms
     - Monitor response times first 48h after deploy
     - Auto-rollback если p95 > 500ms

FALLBACK: Если critical issues - keep v1 as default, make v2 opt-in via header (Accept: application/vnd.api.v2+json). Gradual rollout.

ROLLBACK:
1. Switch default version back to v1 (config change, instant)
2. Keep v2 available для early adopters
3. Extend deprecation period на 3 more months
Estimated rollback time: < 5 minutes (config switch)
</thinking>
```

## Output

**API versioning strategy:**
1. Implement /api/v1/transactions (preserve old format, mark as deprecated)
2. Implement /api/v2/transactions (new nested format)
3. Run both versions in parallel for 6 months
4. Add deprecation notice to v1 responses (X-API-Deprecated header)
5. Contact integration partners with 2-week notice + migration guide
6. Load test v2 endpoint (verify p95 < 200ms)
7. Deploy with monitoring (auto-rollback trigger: p95 > 500ms)
8. In-app banner for mobile users about upcoming v1 shutdown
9. Sunset v1 after 6 months (hard cutoff)

## Why This Example is Unique

**Differences from PATTERNS.md reference examples:**

1. **Multi-stakeholder impact** - Considers mobile users, third-party integrations, performance separately
2. **Gradual migration strategy** - 6-month parallel operation, deprecation notices, communication plan
3. **Auto-rollback triggers** - Specific performance thresholds (p95 latency > 500ms)
4. **Enterprise-scale metrics** - 100K+ users, 5 integration partners, response size calculations

**Real-world complexity demonstrated:**
- API versioning (v1/v2 parallel operation, not just "create v2 and break v1")
- Deprecation timeline (6 months with communication plan)
- Stakeholder notification (integration partners get 2-week notice + migration guide)
- Performance guardrails (load testing + auto-rollback)
- Configuration-based rollback (instant switch without code deployment)

## Key Takeaways

1. **Breaking changes require versioning** - Never replace API format without parallel v1/v2 operation
2. **Communication is critical** - Notify all stakeholders (mobile users, integration partners) with migration guides
3. **Gradual rollout reduces risk** - 6-month transition period allows time for adoption and issue discovery
4. **Performance testing is mandatory** - Load test new format, set auto-rollback triggers
5. **Rollback strategy should be instant** - Configuration switch (not code redeployment)
