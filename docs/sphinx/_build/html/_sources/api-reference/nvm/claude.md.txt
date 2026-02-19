# claude

> **Module:** `nvm` | **File:** `lib/nvm/claude.sh`

Claude Code Management Module
Description: Install, update, and cleanup Claude Code

---

### `install_isolated_claude`

Install Claude Code in isolated environment

**Returns:**

-   0 - success
-   1 - error
- Note: Now uses install_npm_package_with_lockfile() for consistency

### `cleanup_old_claude_installations`

Cleanup old Claude Code installations Removes temporary .claude-code-* folders left by npm Side effects:   - Deletes .claude-code-* directories in node_modules/@anthropic-ai/

