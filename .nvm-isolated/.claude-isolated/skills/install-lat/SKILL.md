---
name: install-lat
description: >-
  Full lat.md setup guide for iclaude — install, initialize, configure semantic
  search, and verify. Use when the user wants to set up lat.md from scratch or
  troubleshoot the installation.
---

# install-lat

Complete lat.md setup in iclaude. Covers installation, project init, and all related skills.

## Step 1: Install lat binary

```bash
./iclaude.sh --install-lat
```

Installs `lat.md` globally into the isolated npm environment (`NPM_CONFIG_PREFIX/bin/lat`).
Also patches `provider.js` for ollama/`LAT_LLM_BASE_URL` support.

Verify:
```bash
./iclaude.sh --check-lat
```

## Step 2: Initialize project

In the target project directory:

```bash
./iclaude.sh --lat-init
```

Creates `lat.md/` scaffold. Cleans up per-project artifacts (skill, MCP, hooks) — iclaude manages them centrally.

→ Use `lat-init` skill for details.

## Step 3: Configure semantic search (optional)

Add to `.claude_config`:

```bash
export LAT_LLM_KEY="sk-..."          # OpenAI key, or vck_... for Vercel AI Gateway
export LAT_LLM_BASE_URL="..."        # Optional: custom OpenAI-compatible endpoint
export LAT_LLM_MODEL="..."           # Optional: override model
```

For ollama (local):
```bash
export LAT_LLM_KEY="ollama"
export LAT_LLM_BASE_URL="http://localhost:11434/v1"
export LAT_LLM_MODEL="nomic-embed-text"
```

## Step 4: Install pre-commit hook (optional)

```bash
./iclaude.sh --lat-check
```

Installs portable pre-commit hook that runs `lat check` before each commit.

## Related skills

| Skill | Purpose |
|-------|---------|
| `lat-init` | Initialize `lat.md/` in a project |
| `lat-check` | Run `lat check` portably (validate links/refs) |
| `lat-search` | Run `lat search`, `locate`, `refs`, `expand` portably |
| `lat-md` | Write and maintain `lat.md/` documentation files |

## Troubleshooting

**lat binary not found after install:**
```bash
./iclaude.sh --repair-isolated   # re-downloads native binary + repairs symlinks
./iclaude.sh --install-lat       # retry
```

**MCP server not wiring:**
- Check `lat.md/` exists in `$LAUNCH_DIR`
- Restart iclaude — MCP wires on each launch when `lat.md/` is detected
