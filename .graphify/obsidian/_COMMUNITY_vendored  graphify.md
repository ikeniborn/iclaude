---
type: community
cohesion: 0.12
members: 22
---

# vendored / graphify

**Cohesion:** 0.12 - loosely connected
**Members:** 22 nodes

## Members
- [[._verify_patches_applied()]] - code - tests/test_graphify_patches.py
- [[.test_applied_marker_prevents_reapply()]] - code - tests/test_graphify_patches.py
- [[.test_cache_source_file_relative()]] - code - tests/test_graphify_patches.py
- [[.test_dry_run_fail_does_not_block()]] - code - tests/test_graphify_patches.py
- [[.test_graphify_root_is_dot()]] - code - tests/test_graphify_patches.py
- [[.test_manifest_keys_relative()]] - code - tests/test_graphify_patches.py
- [[.test_script_exists_and_executable()]] - code - tests/test_graphify_patches.py
- [[.test_skips_when_pkg_missing()]] - code - tests/test_graphify_patches.py
- [[End-to-end после apply_patches graphify update пишет relative paths.]] - rationale - tests/test_graphify_patches.py
- [[Idempotent после первого apply повторный — no-op.]] - rationale - tests/test_graphify_patches.py
- [[TestApplyPatchesBasic]] - code - tests/test_graphify_patches.py
- [[TestIdempotency]] - code - tests/test_graphify_patches.py
- [[TestPortabilityE2E]] - code - tests/test_graphify_patches.py
- [[_seed_real_targets()]] - code - tests/test_graphify_patches.py
- [[fake_pkg()]] - code - tests/test_graphify_patches.py
- [[graphify_bin()]] - code - tests/test_graphify_patches.py
- [[run_apply()]] - code - tests/test_graphify_patches.py
- [[test_graphify_patches.py]] - code - tests/test_graphify_patches.py
- [[Если dry-run patch fails — best-effort exit 0, fails counted.]] - rationale - tests/test_graphify_patches.py
- [[Проверяет что vendored graphifyy уже патчен (precondition).]] - rationale - tests/test_graphify_patches.py
- [[Скопировать реальные vendored файлы в fake_pkg для valid patch context.]] - rationale - tests/test_graphify_patches.py
- [[Создаёт минимальный faux graphify пакет для патчинга.]] - rationale - tests/test_graphify_patches.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/vendored_/_graphify
SORT file.name ASC
```
