# OAuth Token Refresh & Tasks System

## OAuth Token Refresh

### Automatic Refresh (at launch)

**How it works:**
1. Check token expiration at every `iclaude.sh` launch
2. If expires within 7 days → attempt automatic refresh
3. Uses `claude setup-token` to generate long-lived token (~1 year)

**Configuration:**
- `TOKEN_REFRESH_THRESHOLD` constant (default: 604800 = 7 days)
- Token stored in `.credentials.json` with `expiresAt` timestamp (milliseconds)

### Manual Refresh

```bash
./iclaude.sh --refresh-token
```

### Behavior on Failure

- Does NOT delete credentials file (preserves `refreshToken`)
- Shows warning and directs user to run `/login` manually
- Claude Code may still use `refreshToken` internally

### ⚠️ Known Limitation

- `setup-token` requires interactive browser authentication
- Not suitable for fully headless/CI environments
- Solution: Use long-lived tokens or manual `/login` in CI

## Tasks System

### Automatic Activation

- iclaude.sh exports `CLAUDE_CODE_ENABLE_TASKS=true` by default
- New tasks system activates automatically
- Available tools: `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskOutput`

### Disable (temporary revert to old system)

```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

### Capabilities

- Create task lists for progress tracking
- Manage dependencies between tasks (blocks/blockedBy)
- Track background processes (bash shell, subagents)
- Share tasks between sessions (via `CLAUDE_CODE_TASK_LIST_ID`)

### ⚠️ Important Note

- `CLAUDE_CODE_TASK_LIST_ID` is process-specific
- Must be set manually for cross-session task sharing
- Not automatically shared between multiple Claude Code instances

**Source:** [claude-code/CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

## Symlink Management

### Why Symlinks Break

After `git clone`, symlinks in `.nvm-isolated/` break because:
- Git stores symlink targets as text (relative paths)
- After clone, Node.js version may differ
- Symlink targets point to wrong paths

### ✅ Fix Broken Symlinks

```bash
./iclaude.sh --repair-isolated
```

**What it recreates:**
```
.nvm-isolated/npm-global/bin/npm → ../../versions/node/v*/lib/node_modules/npm/bin/npm-cli.js
.nvm-isolated/npm-global/bin/npx → ../../versions/node/v*/lib/node_modules/npm/bin/npx-cli.js
.nvm-isolated/npm-global/bin/claude → ../../versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js
```

### When to Run

- ✅ After `git clone`
- ✅ After switching branches
- ✅ After `--update` (automatic but verify)
- ✅ When `command not found: claude` error occurs

## Update Behavior

### Update Process

When running `--update`, the script:
1. Runs `npm update -g @anthropic-ai/claude-code`
2. Cleans up `.claude-code-*` temporary folders
3. Recreates symlinks
4. Updates lockfile
5. Retries on ENOTEMPTY errors

### ✅ Verify Lockfile Update

```bash
./iclaude.sh --check-isolated
# Verify: Claude Code version matches lockfile claudeCodeVersion
```

### ⚠️ Temporary Folders

- npm creates `.claude-code-*` folders during updates
- Script auto-deletes these after successful update
- If ENOTEMPTY error: retry with exponential backoff

## Configuration Modes

### Isolated Config (default for isolated installation)

- Config in `.nvm-isolated/.claude-isolated/`
- Separate history/sessions from system installation
- Enabled automatically when using isolated environment

### Shared Config (default for system installation)

- Config in `~/.claude/`
- Shared between all installations
- Can be forced with `--shared-config`

### Switch Between Modes

```bash
./iclaude.sh --isolated-config  # Use isolated config
./iclaude.sh --shared-config    # Use shared config
```
