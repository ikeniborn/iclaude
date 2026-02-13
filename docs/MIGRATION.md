# Migration to Native Installer

Roadmap for transitioning iclaude.sh from npm-based to native installer.

## Current Status

**iclaude.sh uses npm-based installation** (deprecated by Anthropic but continues to work normally)

Starting with Claude Code v2.1.0, Anthropic recommends using the native installer instead of npm for installing and updating Claude Code. The npm installation method is deprecated but **remains fully functional**.

**Current behavior** (no action required):
- iclaude.sh works normally with npm-based installation
- Claude Code v2.1.15 shows informational warning at launch
- All features (OAuth, proxy, router, LSP) function correctly
- Warning is informational only, not a critical error

**When you see the warning:**
```
Claude Code has switched from npm to native installer.
The npm package will continue to work, but is no longer recommended.
```

This is **expected behavior**. iclaude.sh acknowledges this deprecation but continues to use npm for the reasons outlined below.

## Background

### Why Anthropic Recommends Native Installer

**Benefits:**
- **Automatic updates**: No manual `npm update` commands required
- **System integration**: Better integration with system package managers (apt, brew, etc.)
- **Simplified setup**: Single command installation without Node.js/npm prerequisites
- **Consistent experience**: Same installation process across all platforms

**Official documentation**: https://code.claude.com/docs/en/setup

### Why iclaude.sh Continues Using npm

**Strategic reasons:**
1. **Zero breaking changes**: Existing users' workflows remain unchanged
2. **Version control**: Lockfile-based reproducibility for teams
3. **Isolated environment**: Self-contained installation in `.nvm-isolated/`
4. **Proxy compatibility**: Proven HTTP/HTTPS proxy support via npm
5. **LSP/Router integration**: Same npm-based toolchain for all components

**Technical guarantee**: npm installation will continue to work as long as `@anthropic-ai/claude-code` npm package exists.

## Migration Phases

### Phase 1: Documentation (Current) ✅

**Status**: Complete

**What's done:**
- Document native installer recommendation
- Add informational message to `--check-isolated`
- Explain npm deprecation status
- No changes to installation behavior

### Phase 2: Hybrid Support (Q2 2026)

**Goal**: Offer native installer as opt-in alternative

**Planned features:**
- New flag: `--install-native` for native installer setup
- Function: `detect_native_claude()` to find native installation
- Hybrid detection: Prefer native if exists, fall back to npm
- Preserve npm as default (backward compatibility)

**User experience:**
```bash
# Opt-in to native installer
./iclaude.sh --install-native

# Continue using npm (default)
./iclaude.sh --isolated-install
```

### Phase 3: Full Migration (If Needed)

**Trigger**: Anthropic discontinues `@anthropic-ai/claude-code` npm package

**Migration plan:**
1. Switch to native installer as default
2. Preserve lockfile for Node.js, LSP servers, Router versions
3. Migrate existing isolated environments to native
4. Provide migration guide with backward compatibility notes

**Breaking change**: Yes (major version bump to iclaude v2.0.0)

## FAQ

**Q: Should I switch to native installer now?**

A: Not required. npm installation works normally. iclaude.sh will add opt-in support in Phase 2.

**Q: Will iclaude.sh stop working?**

A: No. npm installation is deprecated but functional. Anthropic has not announced removal timeline.

**Q: Can I use native installer manually alongside iclaude.sh?**

A: Yes, but manage separately. iclaude.sh won't detect native installation in Phase 1.

**Q: How does this affect OAuth token refresh?**

A: No impact. OAuth mechanism is independent of installation method.

**Q: What about proxy configuration?**

A: Native installer should support same proxy environment variables (`HTTPS_PROXY`, etc.). Will be tested in Phase 2.

**Q: Will lockfile still work?**

A: Yes. Node.js, LSP servers, and Router versions remain in lockfile. Claude Code version tracking may change in Phase 3.

## Technical Comparison

| Feature | npm (Current) | Native Installer |
|---------|---------------|------------------|
| Auto-updates | Manual `npm update` | Automatic via installer |
| Prerequisites | Node.js + npm | None (self-contained) |
| Isolated install | Yes (`.nvm-isolated/`) | System-wide only |
| Version locking | Lockfile support | System package manager |
| Proxy support | `HTTPS_PROXY` env vars | TBD (likely same) |
| Team reproduction | `--install-from-lockfile` | Platform-specific packages |
| Integration | npm ecosystem | OS package managers |

## Developer Notes

**If implementing native installer support:**

1. Add `detect_native_claude()` function after `detect_router()` (iclaude.sh:~380)
2. Modify `get_nvm_claude_path()` to check native paths first
3. Update lockfile schema to include `installMethod: "npm" | "native"`
4. Test proxy compatibility with native binary
5. Document migration path in this section

**Native installer paths** (for future detection):
- **Linux**: `/usr/local/bin/claude` or `~/.local/bin/claude`
- **macOS**: `/usr/local/bin/claude` or `/Applications/Claude.app/Contents/MacOS/claude`
- **Windows**: `%LOCALAPPDATA%\Programs\Claude\claude.exe`

**Configuration directory** (native installer):
- Same as npm: `~/.claude/` or `$CLAUDE_DIR`
- iclaude.sh isolated config (`--isolated-config`) should work unchanged

## Related Documentation

- [Main README](../README.md) - Installation and usage guide
- [CLAUDE.md](../.nvm-isolated/.claude-isolated/CLAUDE.md) - Complete project documentation
- [Anthropic Setup Guide](https://code.claude.com/docs/en/setup) - Official native installer documentation
