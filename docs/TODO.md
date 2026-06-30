# Task Log

One row per IDD→SDD chain `<topic>`. Upserted by the `check-*` commands.

| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |
|---|---|---|---|---|---|---|---|---|
| iwiki-content-hash-freshness-port | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Port content-hash freshness from ai-wiki-plugin into plugin/iwiki; spec opens the chain (no intent) |
| iwiki-engine-entrypoint | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Canonical IWIKI_ENGINE_DIR entrypoint; spec opens the chain (no intent); plan validated OK (5/5 phases passed, 0 findings) |
| iwiki-plugin-to-mcp | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Migrate iwiki usage to MCP server + decommission in-repo plugin; result_check OK (11/11 tasks, 47-file diff, 0 MISSING/0 EXCESS); final whole-branch review (opus) Ready-to-merge YES, 0 critical; plugin disabled (only plugin/iwiki/ kept); .iwikiignore + marketplace + uv retained; PR deferred per user |
