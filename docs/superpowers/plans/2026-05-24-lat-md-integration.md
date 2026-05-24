---
review:
  plan_hash: c6cdcec457081a76
  spec_hash: 86da028d5ffcc884
  last_run: 2026-05-24
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  section_hashes:
    Task 1: 99671fc265ec03b6
    Task 2: c981944f73afca0a
    Task 3: f17d4b81ca58c5ee
    Task 4: 7a4e5f161dd72203
    Task 5: 2d15d62aa7e0ffe3
    Task 6: de19b9e5338ebafb
    Task 7: df22adb578967e7e
    Task 8: 70a2337e142c63b7
    Task 9: 10855bad763db202
  findings:
    - id: F-001
      phase: structure
      severity: WARNING
      section: Task 6
      section_hash: de19b9e5338ebafb
      text: "Step 5 header says 'Add `_check_lat_status()` function' but defines `check_lat_status` (no underscore). Step 4 handler calls `_check_lat_status` — undefined until Step 5 update. Self-correcting but misleading."
      verdict: fixed
      verdict_at: 2026-05-24
---
# lat.md Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate lat.md as a documentation graph layer in iclaude, replacing llm-wiki with a proper `lib/lat/` module, MCP server injection, and pre-commit hook.

**Architecture:** New `lib/lat/` module (4 files) mirrors `lib/graphify/` pattern. `LAUNCH_DIR` captured at top of `init_environment()`. MCP auto-injected on each launch when lat CLI + `lat.md/` both present. `settings.json` updated via Python3 json module.

**Tech Stack:** Bash, Node 22 (via nvm), npm (lat.md package), Python3 (json module for settings.json).

---

## File Structure

**New files:**
- `lib/lat/detect.sh` — `detect_lat()`, `detect_lat_project()`
- `lib/lat/mcp.sh` — `inject_lat_mcp()`
- `lib/lat/install.sh` — `install_lat()`
- `lib/lat/check.sh` — `run_lat_check()`, `install_lat_precommit()`, `remove_lat_precommit()`
- `tests/test_lat_module.sh` — bash unit tests for lat functions

**Modified files:**
- `lib/core/init.sh` — add `LAUNCH_DIR`, `LAT_ENABLED`, `LAT_BIN`, `LAT_PROJECT_ROOT` to `init_environment()`
- `iclaude.sh` — load `lib/lat/` modules; add flag handlers; call detect+inject on launch
- `lib/command/usage.sh` — add 4 new flag descriptions

**Updated docs:**
- `.nvm-isolated/.claude-isolated/commands/update-docs.md` — replace llm-wiki with lat phases
- `CLAUDE.md` — update Features table + Maintenance section
- `.nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/MEMORY.md` — update lat.md entry

**Deleted:**
- `.nvm-isolated/.claude-isolated/skills/llm-wiki/` (whole directory)

---

### Task 1: Add lat variables to `lib/core/init.sh`

**Files:**
- Modify: `lib/core/init.sh`

- [ ] **Step 1: Write the failing syntax test**

```bash
# tests/test_lat_module.sh (create it)
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1] Syntax check: lib/core/init.sh"
bash -n "$SCRIPT_DIR/lib/core/init.sh"
echo "✓ lib/core/init.sh syntax OK"

echo "[2] LAUNCH_DIR captured in init_environment()"
# Source init.sh in a subshell from a known directory, verify LAUNCH_DIR is set
(
  cd /tmp
  # Minimal stubs so init_environment() doesn't error
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  [[ "$LAUNCH_DIR" == "/tmp" ]] || { echo "FAIL: LAUNCH_DIR='$LAUNCH_DIR', expected '/tmp'"; exit 1; }
  [[ "$LAT_ENABLED" == "false" ]] || { echo "FAIL: LAT_ENABLED not false"; exit 1; }
  [[ -z "$LAT_BIN" ]] || { echo "FAIL: LAT_BIN not empty"; exit 1; }
  [[ -z "$LAT_PROJECT_ROOT" ]] || { echo "FAIL: LAT_PROJECT_ROOT not empty"; exit 1; }
)
echo "✓ lat vars initialized correctly"
echo "All Task 1 tests PASSED"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL on test [2] — `LAUNCH_DIR` not set yet.

- [ ] **Step 3: Add variables to `lib/core/init.sh`**

In `init_environment()`, add `LAUNCH_DIR="$PWD"` as the **very first line** (before `SCRIPT_DIR` computation), then add lat vars after the graphify block:

```bash
# In init_environment(), first line:
LAUNCH_DIR="${LAUNCH_DIR:-$PWD}"
export LAUNCH_DIR
```

After the existing graphify block (after `export GRAPHIFY_EXTRA_ARGS`), add:

```bash
    # lat.md (Documentation Graph)
    LAT_ENABLED=false
    LAT_BIN=""
    LAT_PROJECT_ROOT=""

    export LAT_ENABLED LAT_BIN LAT_PROJECT_ROOT
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: All tests PASSED.

- [ ] **Step 5: Commit**

```bash
git add lib/core/init.sh tests/test_lat_module.sh
git commit -m "feat(lat): add LAUNCH_DIR + lat vars to init_environment()"
```

---

### Task 2: Create `lib/lat/detect.sh`

**Files:**
- Create: `lib/lat/detect.sh`
- Modify: `tests/test_lat_module.sh`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_lat_module.sh`:

```bash
echo "[3] detect_lat() returns 1 when lat binary missing"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  NPM_CONFIG_PREFIX="/nonexistent"
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat && { echo "FAIL: should return 1"; exit 1; } || true
)
echo "✓ detect_lat() returns 1 for missing binary"

echo "[4] detect_lat_project() returns 1 when lat.md/ missing"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  LAUNCH_DIR="/tmp"  # no lat.md/ there
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat_project && { echo "FAIL: should return 1"; exit 1; } || true
)
echo "✓ detect_lat_project() returns 1 for missing lat.md/"

echo "[5] detect_lat_project() returns 0 when lat.md/ exists"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/lat.md"
  source "$SCRIPT_DIR/lib/core/init.sh"
  LAUNCH_DIR="$tmpdir"
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat_project || { echo "FAIL: should return 0"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ detect_lat_project() returns 0 when lat.md/ present"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL — `lib/lat/detect.sh` not found.

- [ ] **Step 3: Create `lib/lat/detect.sh`**

```bash
#!/bin/bash
# lat.md detection module
# Provides: detect_lat(), detect_lat_project()

#######################################
# Check if lat CLI is installed in isolated npm.
# Sets LAT_BIN to the binary path on success.
# Returns: 0 if installed, 1 otherwise
#######################################
detect_lat() {
    local bin="${NPM_CONFIG_PREFIX}/bin/lat"
    [[ -x "$bin" ]] || return 1
    LAT_BIN="$bin"
    export LAT_BIN
    return 0
}

#######################################
# Check if current project has lat.md/ directory.
# Sets LAT_PROJECT_ROOT on success.
# Returns: 0 if found, 1 otherwise
#######################################
detect_lat_project() {
    local lat_dir="${LAUNCH_DIR}/lat.md"
    [[ -d "$lat_dir" ]] || return 1
    LAT_PROJECT_ROOT="$lat_dir"
    export LAT_PROJECT_ROOT
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: All tests PASSED including tests [3], [4], [5].

- [ ] **Step 5: Commit**

```bash
git add lib/lat/detect.sh tests/test_lat_module.sh
git commit -m "feat(lat): add detect.sh — detect_lat() and detect_lat_project()"
```

---

### Task 3: Create `lib/lat/mcp.sh`

**Files:**
- Create: `lib/lat/mcp.sh`
- Modify: `tests/test_lat_module.sh`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_lat_module.sh`:

```bash
echo "[6] inject_lat_mcp() writes mcpServers.lat to settings.json"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  # Minimal settings.json
  echo '{"permissions": {}}' > "$tmpdir/settings.json"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  LAUNCH_DIR="/home/user/myproject"
  source "$SCRIPT_DIR/lib/lat/mcp.sh"
  inject_lat_mcp
  # Verify mcpServers.lat.command and cwd
  python3 -c "
import json, sys
with open('$tmpdir/settings.json') as f:
    s = json.load(f)
assert 'mcpServers' in s, 'mcpServers missing'
assert 'lat' in s['mcpServers'], 'lat server missing'
lat = s['mcpServers']['lat']
assert lat['command'] == '/usr/local/bin/lat', f'wrong command: {lat[\"command\"]}'
assert lat['cwd'] == '/home/user/myproject', f'wrong cwd: {lat[\"cwd\"]}'
assert lat['args'] == ['mcp'], f'wrong args: {lat[\"args\"]}'
assert lat['type'] == 'stdio', f'wrong type: {lat[\"type\"]}'
print('JSON structure OK')
"
  rm -rf "$tmpdir"
)
echo "✓ inject_lat_mcp() writes correct settings.json"

echo "[7] inject_lat_mcp() is idempotent (safe to call twice)"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  echo '{"permissions": {}}' > "$tmpdir/settings.json"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  LAUNCH_DIR="/home/user/myproject"
  source "$SCRIPT_DIR/lib/lat/mcp.sh"
  inject_lat_mcp
  inject_lat_mcp
  python3 -c "
import json
with open('$tmpdir/settings.json') as f:
    s = json.load(f)
assert len([k for k in s['mcpServers']]) == 1, 'duplicate entries'
print('Idempotent OK')
"
  rm -rf "$tmpdir"
)
echo "✓ inject_lat_mcp() idempotent"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL — `lib/lat/mcp.sh` not found.

- [ ] **Step 3: Create `lib/lat/mcp.sh`**

```bash
#!/bin/bash
# lat.md MCP integration module
# Provides: inject_lat_mcp()

#######################################
# Inject lat MCP server into settings.json.
# Called on each launch when LAT_ENABLED=true.
# Idempotent — overwrites existing lat entry.
# Returns: 0 on success, 1 on failure
#######################################
inject_lat_mcp() {
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"

    if [[ ! -f "$settings_file" ]]; then
        print_warning "settings.json not found at $settings_file — skipping lat MCP inject"
        return 1
    fi

    if ! python3 - "$settings_file" "$LAT_BIN" "$LAUNCH_DIR" << 'PYEOF'
import json, sys
settings_path, lat_bin, launch_dir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(settings_path) as f:
    s = json.load(f)
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': lat_bin,
    'args': ['mcp'],
    'cwd': launch_dir
}
with open(settings_path, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
PYEOF
    then
        print_warning "Failed to inject lat MCP config into settings.json"
        return 1
    fi
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: All tests PASSED including [6], [7].

- [ ] **Step 5: Commit**

```bash
git add lib/lat/mcp.sh tests/test_lat_module.sh
git commit -m "feat(lat): add mcp.sh — inject_lat_mcp() writes mcpServers.lat to settings.json"
```

---

### Task 4: Create `lib/lat/install.sh`

**Files:**
- Create: `lib/lat/install.sh`
- Modify: `tests/test_lat_module.sh`

- [ ] **Step 1: Write failing test**

Add to `tests/test_lat_module.sh`:

```bash
echo "[8] Syntax check: lib/lat/install.sh"
bash -n "$SCRIPT_DIR/lib/lat/install.sh"
echo "✓ lib/lat/install.sh syntax OK"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL — `lib/lat/install.sh` not found.

- [ ] **Step 3: Create `lib/lat/install.sh`**

```bash
#!/bin/bash
# lat.md installation module
# Provides: install_lat()

#######################################
# Install lat.md in isolated environment.
# Upgrades Node to 22 via nvm, installs lat.md globally.
# Returns: 0 on success, 1 on failure
#######################################
install_lat() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  lat.md: Install Documentation Graph Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # Step 1: Load nvm and upgrade to Node 22
    print_info "Loading nvm from $ISOLATED_NVM_DIR ..."
    # shellcheck source=/dev/null
    if ! source "${ISOLATED_NVM_DIR}/nvm.sh" --no-use 2>/dev/null; then
        print_error "Failed to load nvm"
        return 1
    fi

    print_info "Installing Node.js 22 (required by lat.md) ..."
    if ! NVM_DIR="$ISOLATED_NVM_DIR" nvm install 22; then
        print_error "Failed to install Node 22"
        return 1
    fi

    print_info "Setting Node 22 as default ..."
    if ! NVM_DIR="$ISOLATED_NVM_DIR" nvm alias default 22; then
        print_warning "Failed to set Node 22 as default (non-fatal)"
    fi
    print_success "Node 22 set as default"

    # Reload nvm so npm uses Node 22
    NVM_DIR="$ISOLATED_NVM_DIR" nvm use 22 &>/dev/null || true

    # Step 2: Install lat.md globally
    print_info "Installing lat.md globally (npm install -g lat.md) ..."
    local npm_bin="${NPM_CONFIG_PREFIX}/bin/npm"
    if [[ ! -x "$npm_bin" ]]; then
        npm_bin="$(NVM_DIR="$ISOLATED_NVM_DIR" nvm which current 2>/dev/null | sed 's|/node$|/npm|')"
    fi

    if ! NPM_CONFIG_PREFIX="$NPM_CONFIG_PREFIX" "$npm_bin" install -g lat.md; then
        print_error "Failed to install lat.md"
        return 1
    fi

    if ! detect_lat; then
        print_error "lat binary not found after install (expected: $NPM_CONFIG_PREFIX/bin/lat)"
        return 1
    fi

    print_success "lat.md installed: $LAT_BIN"

    echo ""
    print_success "lat.md installed successfully!"
    echo ""
    print_info "MCP server wires automatically on each launch when lat.md/ is found."
    print_info "Next steps:"
    print_info "  Status:       ./iclaude.sh --check-lat"
    print_info "  Init project: ./iclaude.sh --lat-init"
    print_info "  Check refs:   ./iclaude.sh --lat-check"
    echo ""
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: test [8] PASSED.

- [ ] **Step 5: Commit**

```bash
git add lib/lat/install.sh tests/test_lat_module.sh
git commit -m "feat(lat): add install.sh — install_lat() with Node 22 upgrade"
```

---

### Task 5: Create `lib/lat/check.sh`

**Files:**
- Create: `lib/lat/check.sh`
- Modify: `tests/test_lat_module.sh`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_lat_module.sh`:

```bash
echo "[9] Syntax check: lib/lat/check.sh"
bash -n "$SCRIPT_DIR/lib/lat/check.sh"
echo "✓ lib/lat/check.sh syntax OK"

echo "[10] install_lat_precommit() creates idempotent hook"
(
  tmpdir=$(mktemp -d)
  git init -q "$tmpdir"
  LAUNCH_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  source "$SCRIPT_DIR/lib/lat/check.sh"
  install_lat_precommit
  hook="$tmpdir/.git/hooks/pre-commit"
  [[ -x "$hook" ]] || { echo "FAIL: hook not executable"; rm -rf "$tmpdir"; exit 1; }
  grep -q "LAT-PRECOMMIT-BEGIN" "$hook" || { echo "FAIL: marker missing"; rm -rf "$tmpdir"; exit 1; }
  # Idempotent: call again, no duplicate
  install_lat_precommit
  count=$(grep -c "LAT-PRECOMMIT-BEGIN" "$hook")
  [[ "$count" -eq 1 ]] || { echo "FAIL: duplicate marker ($count)"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ install_lat_precommit() idempotent"

echo "[11] remove_lat_precommit() removes lat section only"
(
  tmpdir=$(mktemp -d)
  git init -q "$tmpdir"
  LAUNCH_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  source "$SCRIPT_DIR/lib/lat/check.sh"
  # Add existing content + lat section
  hook="$tmpdir/.git/hooks/pre-commit"
  printf '#!/bin/bash\necho "other hook"\n' > "$hook"
  chmod +x "$hook"
  install_lat_precommit
  remove_lat_precommit
  grep -q "LAT-PRECOMMIT-BEGIN" "$hook" && { echo "FAIL: marker still present"; rm -rf "$tmpdir"; exit 1; }
  grep -q "other hook" "$hook" || { echo "FAIL: other content removed"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ remove_lat_precommit() removes only lat section"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL — `lib/lat/check.sh` not found.

- [ ] **Step 3: Create `lib/lat/check.sh`**

```bash
#!/bin/bash
# lat.md check and pre-commit hook module
# Provides: run_lat_check(), install_lat_precommit(), remove_lat_precommit()

_LAT_HOOK_BEGIN="# === LAT-PRECOMMIT-BEGIN ==="
_LAT_HOOK_END="# === LAT-PRECOMMIT-END ==="

#######################################
# Run lat check in project.
# Installs pre-commit hook if not present.
# Returns: 0 if all refs valid, 1 on broken refs or missing project
#######################################
run_lat_check() {
    if ! detect_lat_project; then
        print_error "lat.md/ not found in $LAUNCH_DIR"
        print_info "Initialize with: ./iclaude.sh --lat-init"
        return 1
    fi

    print_info "Running lat check in $LAUNCH_DIR ..."
    if (cd "$LAUNCH_DIR" && "$LAT_BIN" check); then
        print_success "All references valid ✓"
        install_lat_precommit
        return 0
    else
        print_error "Broken references found (see above)"
        install_lat_precommit
        return 1
    fi
}

#######################################
# Install lat check as pre-commit hook.
# Idempotent — no-op if already installed.
# Returns: 0 always
#######################################
install_lat_precommit() {
    local git_dir
    git_dir=$(cd "$LAUNCH_DIR" && git rev-parse --git-dir 2>/dev/null) || {
        print_warning "Not a git repo at $LAUNCH_DIR — skipping pre-commit hook"
        return 0
    }
    local hook_file="${LAUNCH_DIR}/${git_dir}/hooks/pre-commit"
    mkdir -p "$(dirname "$hook_file")"

    # Already installed — skip
    grep -qF "LAT-PRECOMMIT-BEGIN" "$hook_file" 2>/dev/null && return 0

    # Create or append
    if [[ ! -f "$hook_file" ]]; then
        printf '#!/bin/bash\n' > "$hook_file"
        chmod +x "$hook_file"
    fi

    cat >> "$hook_file" << HOOKEOF

${_LAT_HOOK_BEGIN}
# lat.md reference integrity check — installed by iclaude --lat-check
if command -v "${LAT_BIN}" &>/dev/null; then
    "${LAT_BIN}" check || exit 1
fi
${_LAT_HOOK_END}
HOOKEOF

    print_success "lat pre-commit hook installed: $hook_file"
    return 0
}

#######################################
# Remove lat section from pre-commit hook.
# Idempotent — no-op if not present.
# Returns: 0 always
#######################################
remove_lat_precommit() {
    local git_dir
    git_dir=$(cd "$LAUNCH_DIR" && git rev-parse --git-dir 2>/dev/null) || return 0
    local hook_file="${LAUNCH_DIR}/${git_dir}/hooks/pre-commit"

    [[ -f "$hook_file" ]] || return 0
    grep -qF "LAT-PRECOMMIT-BEGIN" "$hook_file" || return 0

    # Remove lines between markers (inclusive)
    python3 - "$hook_file" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out, skip = [], False
for line in lines:
    if 'LAT-PRECOMMIT-BEGIN' in line:
        skip = True
    if not skip:
        out.append(line)
    if 'LAT-PRECOMMIT-END' in line:
        skip = False
with open(path, 'w') as f:
    f.writelines(out)
PYEOF

    print_info "lat pre-commit hook removed"
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: All tests [9], [10], [11] PASSED.

- [ ] **Step 5: Commit**

```bash
git add lib/lat/check.sh tests/test_lat_module.sh
git commit -m "feat(lat): add check.sh — run_lat_check(), install_lat_precommit(), remove_lat_precommit()"
```

---

### Task 6: Wire `lib/lat/` modules into `iclaude.sh`

**Files:**
- Modify: `iclaude.sh`

- [ ] **Step 1: Write failing test**

Add to `tests/test_lat_module.sh`:

```bash
echo "[12] iclaude.sh --check-lat exits 0"
bash -n "$SCRIPT_DIR/iclaude.sh" || { echo "FAIL: iclaude.sh syntax error"; exit 1; }
echo "✓ iclaude.sh syntax OK"
```

Run first to confirm syntax is currently OK (baseline).

- [ ] **Step 2: Add module loading block to `iclaude.sh`**

After the existing graphify loading block (after `fi` that closes `if [[ -d "$LIB_DIR/graphify" ]]`), add:

```bash
#######################################
# Load lat.md modules (Phase 8.5)
#######################################
if [[ -d "$LIB_DIR/lat" ]]; then
    source "${LIB_DIR}/lat/detect.sh"
    source "${LIB_DIR}/lat/install.sh"
    source "${LIB_DIR}/lat/mcp.sh"
    source "${LIB_DIR}/lat/check.sh"
fi
```

- [ ] **Step 3: Add lat flag variable initialization**

In the flag initialization section (near `USE_GRAPHIFY_FLAG=false` around line 222), add:

```bash
    USE_LAT_CHECK_FLAG=false
    USE_LAT_INIT_FLAG=false
```

- [ ] **Step 4: Add flag handlers in the case statement**

After the `--check-graphify)` handler block, add:

```bash
            --install-lat)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-lat"
                    exit 1
                fi
                [[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"
                install_lat
                exit $?
                ;;
            --lat-init)
                if ! detect_lat; then
                    print_error "lat not installed. Run: ./iclaude.sh --install-lat"
                    exit 1
                fi
                (cd "$LAUNCH_DIR" && "$LAT_BIN" init)
                exit $?
                ;;
            --lat-check)
                if ! detect_lat; then
                    print_error "lat not installed. Run: ./iclaude.sh --install-lat"
                    exit 1
                fi
                run_lat_check
                exit $?
                ;;
            --check-lat)
                check_lat_status
                exit 0
                ;;
```

- [ ] **Step 5: Add `check_lat_status()` function**

Add this function near the other status functions (e.g., after the graphify section in `iclaude.sh`, or inline before the case statement). Add it inside `iclaude.sh` (not in a lib file, consistent with how `check_graphify_status` is in a lib file — actually it IS in a lib file, so add to `lib/lat/check.sh` instead):

Add to `lib/lat/check.sh`:

```bash
#######################################
# Display lat.md installation and project status.
# Returns: 0 always
#######################################
check_lat_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  lat.md: Documentation Graph Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # lat CLI
    if detect_lat; then
        local lat_ver
        lat_ver=$("$LAT_BIN" --version 2>/dev/null || echo "unknown")
        print_success "lat CLI: $LAT_BIN ($lat_ver)"
    else
        print_warning "lat CLI: not installed"
        echo "  Run: ./iclaude.sh --install-lat"
        echo ""
        return 0
    fi

    # lat.md/ in project
    if detect_lat_project; then
        print_success "lat.md/: found at $LAT_PROJECT_ROOT"
    else
        print_warning "lat.md/: not found in $LAUNCH_DIR"
        echo "  Run: ./iclaude.sh --lat-init"
    fi

    # MCP config
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"
    if python3 -c "
import json, sys
with open('$settings_file') as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
" 2>/dev/null; then
        print_success "MCP: configured in settings.json"
    else
        print_warning "MCP: not configured (auto-injects on next launch when lat.md/ present)"
    fi

    echo ""
    return 0
}
```

And update the `--check-lat` handler in `iclaude.sh` to call `check_lat_status` (not `_check_lat_status`):

```bash
            --check-lat)
                check_lat_status
                exit 0
                ;;
```

- [ ] **Step 6: Add auto-detect + MCP inject on launch**

After the `_graphify_rebuild_graph` block (around line 763), add:

```bash
    # Auto-detect lat.md and inject MCP config if both CLI and project present
    if declare -F detect_lat &>/dev/null; then
        if detect_lat && detect_lat_project; then
            LAT_ENABLED=true
            export LAT_ENABLED
            inject_lat_mcp || print_warning "lat MCP inject failed — continuing"
        fi
    fi
```

- [ ] **Step 7: Run syntax check**

```bash
bash -n iclaude.sh
echo "✓ iclaude.sh syntax OK"
bash tests/test_lat_module.sh
```
Expected: All tests PASSED including [12].

- [ ] **Step 8: Integration test**

```bash
./iclaude.sh --check-lat
```
Expected: Shows lat.md status (installed or not), no errors.

- [ ] **Step 9: Commit**

```bash
git add iclaude.sh lib/lat/check.sh tests/test_lat_module.sh
git commit -m "feat(lat): wire lib/lat/ modules into iclaude.sh — flags + auto-detect on launch"
```

---

### Task 7: Update `lib/command/usage.sh`

**Files:**
- Modify: `lib/command/usage.sh`

- [ ] **Step 1: Write failing test**

Add to `tests/test_lat_module.sh`:

```bash
echo "[13] --help output contains lat flags"
help_out=$("$SCRIPT_DIR/iclaude.sh" --help 2>&1)
for flag in "--install-lat" "--lat-init" "--lat-check" "--check-lat"; do
    echo "$help_out" | grep -qF "$flag" || { echo "FAIL: $flag missing from --help"; exit 1; }
done
echo "✓ All lat flags in --help"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh
```
Expected: FAIL — lat flags not in `--help` yet.

- [ ] **Step 3: Add flag descriptions to `lib/command/usage.sh`**

In `show_usage()`, after the `--check-graphify` line, add:

```
  --install-lat                Install lat.md documentation graph tool (Node 22 + MCP)
  --lat-init                   Initialize lat.md knowledge graph in current project
  --lat-check                  Check documentation link integrity (lat check) + install pre-commit hook
  --check-lat                  Show lat.md installation and project status
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh
```
Expected: test [13] PASSED.

- [ ] **Step 5: Commit**

```bash
git add lib/command/usage.sh tests/test_lat_module.sh
git commit -m "feat(lat): add lat flags to --help"
```

---

### Task 8: Update skill layer and documentation

**Files:**
- Delete: `.nvm-isolated/.claude-isolated/skills/llm-wiki/` (whole dir)
- Modify: `.nvm-isolated/.claude-isolated/commands/update-docs.md`
- Modify: `CLAUDE.md` (project root)
- Modify: `.nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/MEMORY.md`

- [ ] **Step 1: Delete llm-wiki skill**

```bash
rm -rf .nvm-isolated/.claude-isolated/skills/llm-wiki/
ls .nvm-isolated/.claude-isolated/skills/
```
Expected: `llm-wiki/` no longer listed.

- [ ] **Step 2: Rewrite `update-docs.md`**

Replace entire content of `.nvm-isolated/.claude-isolated/commands/update-docs.md`:

```markdown
Обнови граф знаний (по коду) и документацию (по lat.md) по итогам доработок. Используется graphify и lat.

## Разделение ответственности

| Инструмент | Домен | Файлы |
|------------|-------|-------|
| `graphify` | Код, архитектура, зависимости | `*.sh`, `*.py`, `*.js`, `*.ts` и любые не-md изменения |
| `lat` | Архитектурные решения, WHY, `[[ссылки]]` | `lat.md/`, связанные секции |

## Алгоритм

1. **Определи scope изменений**
   - `git diff HEAD --name-only` → список всех изменённых файлов
   - Если передан путь в `$ARGUMENTS` — работай только с ним
   - Если нет изменений — сообщи: «Нет изменений. Укажи путь явно или убедись в наличии diff.»

2. **Phase 1: Обнови граф кода** — вызови skill `graphify`
   - Scope: изменённые файлы кода (не-md)
   - Дождись завершения

3. **Phase 2: Проверь целостность документации** — запусти `lat check` в проекте
   - `Bash(lat check)` в директории проекта
   - exit 0 → continue; exit 1 → выведи broken refs, предупреди пользователя

4. **Phase 3: Обнови затронутые секции в lat.md/**
   - Для каждого изменённого файла: `lat section <file> --update`
   - DoD: все секции, связанные с изменёнными файлами, актуализированы; `lat check` возвращает exit 0

5. **Отчёт**

```
## Обновление знаний [дата]

### Scope
- Код (graphify): <список файлов или "нет изменений">
- Документация (lat): <список файлов или "нет изменений">

### Граф кода (graphify)
- Статус: обновлён / пропущен / ошибка

### Документация (lat)
- Phase 2 (lat check): OK / broken refs: <список>
- Phase 3 (lat section --update): обновлено <N> секций / пропущено
```

$ARGUMENTS
```

- [ ] **Step 3: Update `CLAUDE.md` — Features table**

In `CLAUDE.md` (project root), in the Features table, replace the graphify row to add lat alongside it, and remove any llm-wiki references:

Find and replace in Features table:
```
| Graphify Knowledge Graph (uv, Python 3.12, graphifyy) | `lib/graphify/` |
```
Replace with:
```
| Graphify Knowledge Graph (uv, Python 3.12, graphifyy) | `lib/graphify/` |
| lat.md Documentation Graph (Node 22, MCP server) | `lib/lat/` |
```

Also add lat commands to the daily commands section, after `--install-graphify`:
```bash
./iclaude.sh --install-lat         # Install lat.md (Node 22 + MCP)
./iclaude.sh --lat-init            # Initialize lat.md/ in current project
./iclaude.sh --lat-check           # Check doc link integrity + install pre-commit hook
./iclaude.sh --check-lat           # Show lat.md status
```

- [ ] **Step 4: Update `CLAUDE.md` — Maintenance section**

Find:
```
After completing any feature, bugfix, or refactor:
1. Run `graphify` → rebuilds knowledge graph.
2. Run `llm-wiki` → syncs affected wiki entries.
```

Replace with:
```
After completing any feature, bugfix, or refactor:
1. Run `graphify` → rebuilds knowledge graph.
2. Run `update-docs` → runs lat check + updates lat.md/ sections.
```

Remove any other references to `llm-wiki` in CLAUDE.md (including "Getting Started" section if it mentions llm-wiki).

- [ ] **Step 5: Update MEMORY.md**

In `.nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/MEMORY.md`, find and remove any `llm-wiki` references. Add lat.md entry if not present.

Check current MEMORY.md for llm-wiki entries:
```bash
grep -n "llm-wiki\|llm_wiki" \
  .nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/MEMORY.md
```

Remove or update those lines to reference lat instead.

- [ ] **Step 6: Verify no llm-wiki references remain**

```bash
grep -r "llm-wiki\|llm_wiki" \
  CLAUDE.md \
  .nvm-isolated/.claude-isolated/commands/ \
  .nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/ \
  2>/dev/null
```
Expected: no output (zero matches).

- [ ] **Step 7: Commit**

```bash
git add \
  .nvm-isolated/.claude-isolated/commands/update-docs.md \
  CLAUDE.md \
  .nvm-isolated/.claude-isolated/projects/-home-ikeniborn-Documents-Project-iclaude/memory/MEMORY.md
git commit -m "docs(lat): replace llm-wiki with lat.md in update-docs, CLAUDE.md, MEMORY.md"
```

For the deleted llm-wiki directory (untracked deletion), stage it:
```bash
git rm -r .nvm-isolated/.claude-isolated/skills/llm-wiki/ 2>/dev/null || true
git add .nvm-isolated/.claude-isolated/skills/
git commit -m "feat(lat): remove llm-wiki skill (replaced by lat.md doc graph)"
```

---

### Task 9: Regression test + full integration smoke test

**Files:**
- Modify: `tests/regression-phase0.sh`

- [ ] **Step 1: Add lat regression tests to `tests/regression-phase0.sh`**

Add at end of file:

```bash
# Test 8: Check lat status
echo "[8/8] Testing --check-lat..."
./iclaude.sh --check-lat > /dev/null
echo "✓ --check-lat works"

echo ""
echo "=== All regression tests (including lat) passed! ==="
```

- [ ] **Step 2: Run full regression suite**

```bash
bash tests/regression-phase0.sh
```
Expected: All 8 tests pass, including `--check-lat`.

- [ ] **Step 3: Run full lat test suite**

```bash
bash tests/test_lat_module.sh
```
Expected: All 13 tests PASSED.

- [ ] **Step 4: Validate iclaude.sh syntax**

```bash
bash -n iclaude.sh && echo "✓ iclaude.sh syntax OK"
bash -n lib/lat/detect.sh && echo "✓ detect.sh syntax OK"
bash -n lib/lat/install.sh && echo "✓ install.sh syntax OK"
bash -n lib/lat/mcp.sh && echo "✓ mcp.sh syntax OK"
bash -n lib/lat/check.sh && echo "✓ check.sh syntax OK"
```
Expected: all 5 syntax checks pass.

- [ ] **Step 5: Commit**

```bash
git add tests/regression-phase0.sh
git commit -m "test(lat): add lat regression tests to phase0 suite"
```
