---
name: iclaude-best-practices
version: 1.0.0
description: Best practices, common pitfalls, and development guidelines for iclaude.sh
user-invocable: false
dependencies: []
tags: [reference, iclaude, best-practices, guidelines]
files:
  - path: SKILL.md
    type: markdown
  - path: examples/proxy-security.md
    type: markdown
  - path: examples/oauth-tasks.md
    type: markdown
  - path: examples/debugging-tips.md
    type: markdown
---

# iclaude-best-practices

Best practices, common pitfalls, and development guidelines for iclaude.sh development.

## When to Use

Use this skill when:
- Planning implementation of new features
- Reviewing code for best practices
- Debugging common issues
- Writing documentation

**Manual reference only** (not auto-invoked)

## Quick Guidelines

### Proxy Configuration

✅ **DO:** Use HTTPS proxy (preserves domains for OAuth)
❌ **DON'T:** Use SOCKS5 (crashes undici)

**См. подробнее:** `examples/proxy-security.md`

### Security

✅ **DO:** Prefer `--proxy-ca` over `--proxy-insecure`
⚠️ **WARNING:** `undici` ProxyAgent doesn't verify TLS certificates ([HackerOne #1583680](https://hackerone.com/reports/1583680))

**См. подробнее:** `examples/proxy-security.md`

### OAuth & Tasks

✅ **DO:** Run `--refresh-token` before expiration
⚠️ **LIMITATION:** `setup-token` requires interactive browser

**См. подробнее:** `examples/oauth-tasks.md`

### Symlinks

✅ **DO:** Run `--repair-isolated` after `git clone`
❌ **DON'T:** Manually edit `.nvm-isolated/` symlinks

### Testing

✅ **DO:** Use `--test` before committing proxy changes
✅ **DO:** Run `bash -n iclaude.sh` for syntax validation

**См. подробнее:** `examples/debugging-tips.md`

### Documentation

✅ **DO:** Update CLAUDE.md after code changes
✅ **DO:** Use `grep -n "function_name" iclaude.sh` for accurate line numbers

## Common Pitfalls

| Issue | Cause | Solution |
|-------|-------|----------|
| `command not found: claude` | Broken symlinks | `--repair-isolated` |
| `ENOTEMPTY` during update | NPM cleanup race | Wait 5s, retry |
| `OAuth token expired` | Token not refreshed | `--refresh-token` or `/login` |
| `Proxy connection failed` | Wrong URL/credentials | `--test --show-password` |
| `SOCKS5 protocol error` | Unsupported protocol | Use HTTPS proxy or Privoxy |

**См. подробнее:** `examples/debugging-tips.md`

## Development Tasks

### Adding New Command-Line Option

1. Add option parsing in `main()` (iclaude.sh:~3020)
2. Add flag variable initialization
3. Add to `show_usage()` help text (iclaude.sh:~2835)
4. Implement functionality in appropriate function

### Modifying Proxy Validation

- Edit `validate_proxy_url()` (iclaude.sh:56)
- Edit `parse_proxy_url()` (iclaude.sh:155)
- ⚠️ Be careful: Changes may affect saved credentials format

### Adding Environment Variables

- Add in `configure_proxy_from_url()` (iclaude.sh:1545)
- OR add in `setup_isolated_nvm()` (iclaude.sh:361)

**См. подробнее:** См. `@skill:iclaude-architecture` для component locations

## Debugging Commands

```bash
# Enable bash debug mode
bash -x ./iclaude.sh --test

# Check which Claude binary will be used
bash -c 'source ./iclaude.sh && get_nvm_claude_path'

# Verify environment setup
bash -c 'source ./iclaude.sh && setup_isolated_nvm && env | grep -E "(NVM|CLAUDE|PROXY)"'

# Check lockfile consistency
./iclaude.sh --check-isolated
```

**См. подробнее:** `examples/debugging-tips.md`

## Integration with Claude Code Skills

When developing iclaude.sh:

- Use `structured-planning` for breaking down complex features
- Use `git-workflow` for commit message generation
- Use `validation-framework` for testing new features
- Use `@skill:iclaude-validation` for multi-perspective analysis

## Security Considerations

1. **Credential Storage:** `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion:** Credentials NEVER committed to git (see .gitignore)
3. **Password Display:** Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy:** Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust:** Only use TRUSTED proxy servers (MitM risk)

**См. подробнее:** `examples/proxy-security.md`

## Examples

- **Proxy & Security:** `examples/proxy-security.md` - Proxy protocols, security, domain handling
- **OAuth & Tasks:** `examples/oauth-tasks.md` - OAuth token refresh, tasks system
- **Debugging:** `examples/debugging-tips.md` - Troubleshooting, common issues, debugging commands

## Notes

- Always test with `--test` before committing proxy changes
- Run `--check-isolated` to verify lockfile consistency
- Update CLAUDE.md function locations after refactoring
- Use shellcheck before committing bash changes
- Test on both macOS and Linux for portability
