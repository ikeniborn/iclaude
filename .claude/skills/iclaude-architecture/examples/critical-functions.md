# Critical Functions Reference

Detailed documentation for 7 most important functions in iclaude.sh.

## 1. validate_proxy_url() - line 56

**Purpose:** Validate proxy URL format and protocol.

**Signature:**
```bash
validate_proxy_url "$url"
```

**Returns:**
- `0`: Valid URL with IP address
- `1`: Invalid format (missing protocol, host, or port)
- `2`: Valid but contains domain (warning)

**Validated:**
- Protocol: http:// or https:// (SOCKS5 NOT supported)
- Host: IP address or domain name
- Port: 1-65535
- Credentials: optional user:pass@

**Example:**
```bash
# Valid with IP
validate_proxy_url "https://192.168.1.100:8118"
# Returns: 0

# Valid with domain (warning)
validate_proxy_url "https://proxy.example.com:8118"
# Returns: 2

# Invalid (SOCKS5 not supported)
validate_proxy_url "socks5://proxy:1080"
# Returns: 1
```

**IMPORTANT:** Only HTTP/HTTPS protocols supported. SOCKS5 crashes undici library.

## 2. resolve_domain_to_ip() - line 110

**Purpose:** Resolve domain names to IP addresses using fallback chain.

**Signature:**
```bash
resolve_domain_to_ip "$domain"
```

**Returns:**
- IP address on success (echoed to stdout)
- Empty string on failure

**Fallback Order:**
1. `getent` (most reliable)
2. `host`
3. `dig`
4. `nslookup`

**Example:**
```bash
# Resolve domain
IP=$(resolve_domain_to_ip "proxy.example.com")
echo "$IP"  # 192.168.1.100

# Handle failure
IP=$(resolve_domain_to_ip "invalid.domain")
if [ -z "$IP" ]; then
  echo "Resolution failed"
fi
```

**Note:** Only used for HTTP proxies (optional conversion). HTTPS proxies **ALWAYS** preserve domain names to maintain OAuth/TLS compatibility.

## 3. get_nvm_claude_path() - line 234

**Purpose:** Locate Claude Code installation in NVM environment.

**Signature:**
```bash
get_nvm_claude_path
```

**Returns:**
- Full path to claude binary (echoed to stdout)
- Empty string if not found

**Handles:**
- Standard `claude` binary in `$NVM_DIR/versions/node/*/bin/`
- Temporary `.claude-*` binaries (sorted by mtime, newest first)
- Direct cli.js in `node_modules/@anthropic-ai/claude-code/`
- Temporary `.claude-code-*` folders

**Example:**
```bash
CLAUDE_PATH=$(get_nvm_claude_path)
if [ -n "$CLAUDE_PATH" ]; then
  echo "Found: $CLAUDE_PATH"
  "$CLAUDE_PATH" --version
else
  echo "Claude not found"
  exit 1
fi
```

**Priority:**
1. Standard `bin/claude`
2. Temporary `.claude-*` (newest by mtime)
3. Direct cli.js

## 4. repair_isolated_environment() - line 812

**Purpose:** Fix broken symlinks after `git clone` or repository moves.

**Signature:**
```bash
repair_isolated_environment
```

**Returns:**
- `0` on success
- `1` on failure

**Recreates:**
- `npm` → `../../versions/node/v*/lib/node_modules/npm/bin/npm-cli.js`
- `npx` → `../../versions/node/v*/lib/node_modules/npm/bin/npx-cli.js`
- `corepack` → `../../versions/node/v*/lib/node_modules/corepack/dist/corepack.js`
- `claude` → `../../versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js`

**Example:**
```bash
# After git clone
git clone https://github.com/user/iclaude.git
cd iclaude

# Symlinks broken, fix them
./iclaude.sh --repair-isolated

# Output:
# Repairing symlinks...
# ✅ npm → versions/node/v18.20.8/.../npm-cli.js
# ✅ npx → versions/node/v18.20.8/.../npx-cli.js
# ✅ claude → versions/node/v18.20.8/.../@anthropic-ai/claude-code/cli.js
```

**When to run:**
- After `git clone`
- After switching branches
- After `--update` (if automatic repair fails)
- When `command not found: claude` error occurs

## 5. save_isolated_lockfile() - line 616

**Purpose:** Capture current versions to lockfile for reproducibility.

**Signature:**
```bash
save_isolated_lockfile
```

**Returns:** None (writes to `.nvm-isolated-lockfile.json`)

**Detects:**
- Node.js version via `node --version`
- Claude Code version via `get_cli_version()`
- Router version via `ccr --version`
- gh CLI version via `gh --version`
- LSP servers via `npm list -g --depth=0`
- LSP plugins via `claude plugin list`
- NVM version via `nvm --version`
- Installation timestamp (ISO 8601)

**Example:**
```bash
# After update
./iclaude.sh --update

# Lockfile auto-updates
cat .nvm-isolated-lockfile.json
# {
#   "nodeVersion": "18.20.8",
#   "claudeCodeVersion": "2.1.16",  # ← Updated
#   "routerVersion": "1.2.3",
#   ...
# }
```

**Critical for:**
- Team synchronization (same versions)
- CI/CD reproducibility
- Version tracking in git

## 6. detect_router() - line 324

**Purpose:** Check if Claude Code Router is available (NOT whether it should be used).

**Signature:**
```bash
detect_router
```

**Returns:**
- `0`: Router available (router.json exists AND ccr binary installed)
- `1`: Router not available (missing config or binary)

**Logic:**
1. Check if `router.json` exists in isolated or system config directory
2. Verify `ccr` binary available via `get_router_path()`
3. If config exists but binary missing, warns user to run `--install-router`

**Example:**
```bash
if detect_router; then
  echo "Router available"
  if [ "$USE_ROUTER_FLAG" = "true" ]; then
    echo "Launching via router"
    ccr code
  else
    echo "Launching native Claude (router not activated)"
    claude
  fi
else
  echo "Router not available"
  claude
fi
```

**Important:** This function only checks availability. Router is activated ONLY when `USE_ROUTER_FLAG=true` (set by `--router` flag). By default, native Claude is used even if router is available.

## 7. disable_auto_updates() - line 1982

**Purpose:** Disable Claude Code CLI auto-updates in configuration file.

**Signature:**
```bash
disable_auto_updates ["$config_dir"]
```

**Parameters:**
- `$1`: Optional config directory path (defaults to `$CLAUDE_CONFIG_DIR`)

**Returns:**
- `0`: Success or no action needed
- `1`: jq error (rarely happens)

**Logic:**
1. Takes optional config directory path
2. Checks if `.claude.json` exists (skips if missing)
3. Sets `autoUpdates: false` if currently `true`
4. Uses atomic update (temp file + mv) for safety

**Example:**
```bash
# Auto-invoked on every launch
disable_auto_updates "$CLAUDE_CONFIG_DIR"

# Manual check
jq '.autoUpdates' .nvm-isolated/.claude-isolated/.claude.json
# Output: false
```

**Automatic Invocation:**
- Called after `setup_isolated_config()` (both explicit and auto-detected)
- Called for shared config mode
- Runs on every `./iclaude.sh` launch

**Why Automatic:**
- Ensures consistent behavior across all machines
- Prevents Claude Code from self-updating
- Updates managed via CI/CD instead
- Team always works on same version from git

---

## Function Interaction Patterns

### Pattern 1: Proxy Configuration

```bash
validate_proxy_url "$url" || return 1
parse_proxy_url "$url"
resolve_domain_to_ip "$PROXY_HOST"  # Optional for HTTP
save_proxy_credentials "$PROXY_URL"
```

### Pattern 2: Environment Setup

```bash
detect_nvm || install_isolated_nvm
CLAUDE_PATH=$(get_nvm_claude_path)
setup_isolated_config
disable_auto_updates "$CLAUDE_CONFIG_DIR"
```

### Pattern 3: Update Flow

```bash
get_nvm_claude_path  # Get current binary
npm update -g @anthropic-ai/claude-code
cleanup_old_claude_installations
repair_isolated_environment  # Recreate symlinks
save_isolated_lockfile  # Update versions
```

### Pattern 4: Router Launch

```bash
detect_router || { echo "Router not available"; return 1; }
get_router_path || { echo "Router binary not found"; return 1; }
copy router.json to ~/.claude-code-router/config.json
ccr code  # Launch via router
```

---

## Debugging Tips

### Find function location
```bash
grep -n "^function_name()" iclaude.sh
# Or
grep -n "^function_name " iclaude.sh
```

### Test function in isolation
```bash
# Source script (load functions)
source iclaude.sh

# Call function
validate_proxy_url "https://proxy:8118"
echo $?  # Check return code
```

### Trace function calls
```bash
# Enable bash debug mode
bash -x ./iclaude.sh --test 2>&1 | grep "validate_proxy_url"
```

### Check function dependencies
```bash
# Find all functions called by validate_proxy_url
sed -n '/^validate_proxy_url()/,/^}/p' iclaude.sh | grep -E "^[[:space:]]+[a-z_]+\(\)"
```
