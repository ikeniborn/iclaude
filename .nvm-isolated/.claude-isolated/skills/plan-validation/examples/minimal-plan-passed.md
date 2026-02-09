# Example: Minimal Plan - Passed

## Input Plan

```yaml
---
task_name: Fix JWT token expiry bug
complexity: minimal
---

**Problem:** JWT tokens expire after 15 minutes causing user logouts

**Solution:** Update token expiry to 1 hour in JWT service

**Critical Files:**
- src/auth/jwt_service.py (modify)

**Implementation Steps:**
1. Update JWT_EXPIRY constant from 900 to 3600 seconds
2. Add test to verify token validity for 1 hour

**Verification:**
- Acceptance Criteria:
  - Token remains valid for 1 hour
  - Existing tests pass
- Validation Commands:
  - pytest tests/test_jwt.py -v
```

## Validation Output

```json
{
  "plan_validation_result": {
    "plan_type": "minimal",
    "timestamp": "2026-02-09T15:00:00Z",
    "passed": true,
    "score": 100,
    "max_score": 100,
    "structural_validation": {
      "passed": true,
      "score": 25,
      "checks": [
        {"check": "frontmatter_complete", "status": "passed"},
        {"check": "critical_files_present", "status": "passed", "count": 1},
        {"check": "implementation_steps_present", "status": "passed", "count": 2}
      ],
      "blocking_issues": [],
      "warnings": []
    },
    "semantic_validation": {
      "passed": true,
      "score": 25,
      "checks": [
        {"check": "solution_addresses_problem", "status": "passed", "confidence": 0.9},
        {"check": "file_alignment", "status": "passed"}
      ],
      "blocking_issues": [],
      "warnings": []
    },
    "technical_validation": {
      "passed": true,
      "score": 0,
      "checks": [],
      "warnings": []
    },
    "completeness_validation": {
      "passed": true,
      "score": 0,
      "checks": [],
      "warnings": []
    },
    "blocking_issues": [],
    "warnings": [],
    "suggestions": [],
    "metrics": {
      "structural_score": 25,
      "semantic_score": 25,
      "technical_score": 0,
      "completeness_score": 0,
      "total_score": 100
    }
  }
}
```

## Explanation

✅ **Passed** - All required minimal checks passed
- Structural: All required sections present
- Semantic: Solution addresses problem (confidence 0.9), file alignment correct
- Technical: Skipped (minimal plan)
- Completeness: Skipped (minimal plan)
