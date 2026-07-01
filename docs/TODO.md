# Task Log

One row per IDD→SDD chain `<topic>`. Upserted by the `check-*` commands.

| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |
|---|---|---|---|---|---|---|---|---|
| iwiki-content-hash-freshness-port | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Port content-hash freshness from ai-wiki-plugin into plugin/iwiki; spec opens the chain (no intent) |
| iwiki-engine-entrypoint | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Canonical IWIKI_ENGINE_DIR entrypoint; spec opens the chain (no intent); plan validated OK (5/5 phases passed, 0 findings) |
| iwiki-plugin-to-mcp | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Migrate iwiki usage to MCP server + decommission in-repo plugin; result_check OK (11/11 tasks, 47-file diff, 0 MISSING/0 EXCESS); final whole-branch review (opus) Ready-to-merge YES, 0 critical; plugin disabled (only plugin/iwiki/ kept); .iwikiignore + marketplace + uv retained; PR deferred per user |
| iwiki-mcp-user-scope | in-progress | n/a | ✓ | – | – | 2026-07-01 | | Register iwiki MCP via tracked secret-free .mcp.json + --mcp-config; proxy IWIKI_* from .claude_config (ICLAUDE_ prefix); IWIKI_COMMAND via `command -v`; 11 env vars verified vs README/config.py (${VAR:-default} for optional); spec opens the chain (no intent), check-spec OK (4/4 phases, 0 findings) |
