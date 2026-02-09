# Example: Standard Plan - Failed (File Alignment Mismatch)

Demonstrates blocking issue when step references file not in Critical Files.

**Result:** ❌ Failed (score: 75/100)
**Blocking Issue:** file_alignment_mismatch - Step 3 references tests/test_jwt_service.py not in Critical Files
**Suggestion:** Add tests/test_jwt_service.py to Critical Files section
