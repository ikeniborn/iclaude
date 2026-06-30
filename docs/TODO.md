# Task Log

One row per IDD→SDD chain `<topic>`. Upserted by the `check-*` commands.

| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |
|---|---|---|---|---|---|---|---|---|
| iwiki-content-hash-freshness-port | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Port content-hash freshness from ai-wiki-plugin into plugin/iwiki; spec opens the chain (no intent) |
| iwiki-engine-entrypoint | done | n/a | ✓ | ✓ | OK | 2026-06-30 | 2026-06-30 | Canonical IWIKI_ENGINE_DIR entrypoint; spec opens the chain (no intent); plan validated OK (5/5 phases passed, 0 findings) |
| iwiki-plugin-to-mcp | in-progress | n/a | ✓ | – | – | 2026-06-30 |  | Migrate iwiki usage to MCP server + decommission in-repo plugin integration; spec opens the chain (no intent); check-spec re-ran OK after body fixes (write-flow indexing resolved, .iwikiignore retained); 4/4 phases passed, 0 findings |
