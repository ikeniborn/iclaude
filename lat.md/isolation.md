# Isolation

`CLAUDE_CONFIG_DIR` isolation is always active. Claude Code stores state in `.nvm-isolated/.claude-isolated/` instead of `~/.claude/`, preventing config pollution of the user's global installation.

## CLAUDE_CONFIG_DIR Isolation

`CLAUDE_CONFIG_DIR` is exported to `$ISOLATED_CONFIG_DIR` before Claude launches. Claude Code reads this env var and uses it as its config root for:

- `settings.json` (hooks, permissions, env vars)
- `settings.local.json`
- OAuth tokens
- Session state (`session-env/`)
- Hook scripts

This isolation is unconditional — there is no flag to disable it except `--system` (which skips the isolated NVM environment but still uses `CLAUDE_CONFIG_DIR`).

## Session Isolation

Each iclaude invocation gets a unique `ICLAUDE_SESSION_ID` (12 hex chars from `/dev/urandom`). Session ID scopes:

- PII proxy PID and port files (`pii-proxy-pid/<SID>.pid`)
- microVM socket and run directory (`microvm-run/<SID>/`)
- OAuth token check state

Inherited by subshells (e.g. Claude's Bash tool launching `iclaude.sh`) so parent and child share the same proxy instead of spawning a second one.

## microVM Isolation

Full kernel-level isolation via Firecracker KVM. See [[sandbox]] for details.

## What Was Removed

**bubblewrap (bwrap)** was removed in 2026-03. It created 0-byte read-only stub files in `.claude/` of other concurrently open projects — a side effect caused by bwrap's bind-mount mechanism leaking into the host's other project directories.

## --system Flag

Uses host Node.js instead of isolated NVM. `CLAUDE_CONFIG_DIR` isolation remains active. PII proxy and microVM are unsupported in `--system` mode — both require the isolated venv — and abort with a clear error.
