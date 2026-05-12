# hook) / caveman-activate.js

> 30 nodes · cohesion 0.09

## Key Concepts

- **claude-statusline.sh** (17 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **caveman-stats.js** (13 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **caveman-mode-tracker.js (UserPromptSubmit hook)** (6 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-mode-tracker.js`
- **caveman-activate.js (SessionStart hook)** (4 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-activate.js`
- **getDefaultMode()** (3 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **caveman-config.js** (3 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **safeWriteFlag()** (3 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **.caveman-active (flag file)** (3 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-activate.js`
- **readFlag()** (2 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **CLAUDE_CONFIG_DIR (env var)** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **.caveman-statusline-suffix (flag file)** (2 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **appendFlag()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **readHistory()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **aggregateHistory()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **deriveSavings()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **formatStats()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **parseSession()** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- **format_ccr_model()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **format_tokens()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **get_display_mode()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **get_terminal_width()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **shorten_model_name()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **CAVEMAN_DEFAULT_MODE (env var)** (1 connections) — `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- **ICLAUDE_MICROVM_ACTIVE (env var)** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **ICLAUDE_ROUTER_ACTIVE (env var)** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- *... and 5 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `.nvm-isolated/.claude-isolated/hooks/caveman-activate.js`
- `.nvm-isolated/.claude-isolated/hooks/caveman-config.js`
- `.nvm-isolated/.claude-isolated/hooks/caveman-mode-tracker.js`
- `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
- `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/rate-limit.sh`
- `.nvm-isolated/.claude-isolated/scripts/view-tool-results.sh`

## Audit Trail

- EXTRACTED: 75 (97%)
- INFERRED: 2 (3%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*