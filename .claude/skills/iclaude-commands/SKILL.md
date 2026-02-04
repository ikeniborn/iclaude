# iclaude-commands

Reference guide for all iclaude.sh CLI commands organized by category (Testing, Installation, Running, Router, Chrome, LSP, Sandbox, Loop Mode).

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | On-demand reference (not auto-invoked) |
| **Purpose** | Provide command syntax and usage examples |
| **Categories** | 8 categories × 3-8 commands each |
| **Format** | Command → Description → Example → Notes |
| **Integration** | Referenced by other iclaude-* skills |

---

## When to Use

Use this skill when:
- User asks "how to test proxy?"
- User requests "list all --flags"
- Planning implementation that needs specific command
- Writing documentation/examples

**Manual reference only** (not auto-invoked)

---

## Command Categories

### 1. Testing and Validation

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--test` | Test proxy without launching Claude | `./iclaude.sh --test` | Tests HTTP + HTTPS requests |
| `--check-isolated` | Show isolated env status | `./iclaude.sh --check-isolated` | Versions, symlinks, lockfile |
| `--check-config` | Show config status | `./iclaude.sh --check-config` | Isolated vs shared config |
| `--refresh-token` | Refresh OAuth token | `./iclaude.sh --refresh-token` | Long-lived ~1 year token |
| `bash -n` | Validate script syntax | `bash -n iclaude.sh` | Pre-commit check |

### 2. Installation and Updates

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--isolated-install` | Install isolated environment | `./iclaude.sh --isolated-install` | Recommended for development |
| `--update` | Update Claude Code | `./iclaude.sh --update` | Updates isolated Claude only |
| `--install-from-lockfile` | Install from lockfile | `./iclaude.sh --install-from-lockfile` | Exact versions |
| `--repair-isolated` | Repair symlinks | `./iclaude.sh --repair-isolated` | After git clone |
| `--cleanup-isolated` | Clean up isolated env | `./iclaude.sh --cleanup-isolated` | Preserves lockfile |

### 3. Running the Script

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `./iclaude.sh` | Launch with saved proxy | `./iclaude.sh` | Default behavior |
| `--no-proxy` | Launch without proxy | `./iclaude.sh --no-proxy` | Bypass saved credentials |
| `--proxy URL` | Launch with custom proxy | `./iclaude.sh --proxy https://user:pass@proxy:8118` | Saves credentials |
| `--system` | Use system installation | `./iclaude.sh --system` | Instead of isolated |
| `-- ARGS` | Pass args to Claude | `./iclaude.sh -- --model opus` | After `--` separator |

### 4. Router Commands

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--install-router` | Install Router package | `./iclaude.sh --install-router` | npm install globally |
| `--check-router` | Check router status | `./iclaude.sh --check-router` | Version, config, providers |
| `--router` | Launch via router | `./iclaude.sh --router` | Opt-in activation |
| Default (no flag) | Launch native Claude | `./iclaude.sh` | Without router |

### 5. Chrome Integration

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| Default (no flag) | Chrome enabled | `./iclaude.sh` | Enabled by default |
| `--no-chrome` | Disable Chrome | `./iclaude.sh --no-chrome` | Reduce context usage |
| Combined | Proxy without Chrome | `./iclaude.sh --proxy https://proxy:8118 --no-chrome` | Multiple flags |

### 6. LSP Server Management

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--install-lsp` | Install default LSP | `./iclaude.sh --install-lsp` | TypeScript + Python |
| `--install-lsp python` | Install specific LSP | `./iclaude.sh --install-lsp python` | Python only |
| `--install-lsp typescript go` | Install multiple LSP | `./iclaude.sh --install-lsp typescript go` | Space-separated |
| `--check-lsp` | Check LSP status | `./iclaude.sh --check-lsp` | Installed servers |

### 7. Sandbox Commands

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--sandbox-check` | Check sandbox availability | `./iclaude.sh --sandbox-check` | Docker/bubblewrap |
| `--sandbox-install` | Install dependencies | `./iclaude.sh --sandbox-install` | Linux/WSL2 only |
| macOS | Check status | `./iclaude.sh --sandbox-check` | Always ready |
| `--install-from-lockfile` | Restore with sandbox | `./iclaude.sh --install-from-lockfile` | If sandboxAvailable: true |

### 8. Loop Mode Commands

| Command | Purpose | Example | Notes |
|---------|---------|---------|-------|
| `--loop task.md` | Execute sequentially | `./iclaude.sh --loop task.md` | With retry logic |
| `--loop-parallel task.md` | Execute in parallel | `./iclaude.sh --loop-parallel task.md` | Week 2 (not implemented) |
| `--max-parallel N` | Limit parallel agents | `./iclaude.sh --loop-parallel task.md --max-parallel 3` | Default: CPU count |

---

## Loop Mode Task Format

```markdown
# Task: Fix TypeScript errors

## Description
Fix all TypeScript compilation errors in src/

## Completion Promise
npm run type-check

## Validation Command
npm run type-check

## Max Iterations
5

## Git Config
Branch: fix/typescript-errors
Commit message: fix: resolve TypeScript errors
Auto-push: true
```

**Features:**
- Sequential execution with retry logic
- Exponential backoff (2s, 4s, 8s, 16s, 32s, capped at 60s)
- Completion promise verification
- Git integration (auto-commit + push)

**Example task files:**
- `examples/test-loop-simple.md` - Basic task
- `examples/test-loop-retry.md` - Retry logic test

---

## Command Combinations

### Development Workflow

```bash
# 1. Install isolated environment
./iclaude.sh --isolated-install

# 2. Test proxy
./iclaude.sh --test

# 3. Launch with proxy
./iclaude.sh --proxy https://proxy:8118

# 4. Check status
./iclaude.sh --check-isolated
```

### CI/CD Workflow

```bash
# 1. Restore from lockfile
./iclaude.sh --install-from-lockfile

# 2. Validate script
bash -n iclaude.sh

# 3. Run tests
./iclaude.sh --test

# 4. Check versions
./iclaude.sh --check-isolated
```

### Router Development

```bash
# 1. Install router
./iclaude.sh --install-router

# 2. Check status
./iclaude.sh --check-router

# 3. Launch with router
./iclaude.sh --router

# 4. Launch without router (native Claude)
./iclaude.sh
```

---

## Integration with Other Skills

### Input Dependencies

None (reference skill only)

### Output Consumers

Referenced by:
- `iclaude-validation` → Test commands
- `iclaude-best-practices` → Usage examples
- `iclaude-dev-tasks` → Command workflows

---

## Notes

- All commands assume current directory is iclaude project root
- Multiple flags can be combined (e.g., `--proxy --no-chrome`)
- Order matters: `--` separator must come last
- Router is opt-in: native Claude by default
- Chrome is opt-out: enabled by default
