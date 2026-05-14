# GSD Framework Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--install-gsd` optional command to iclaude with lockfile pinning and auto-update via `--update`.

**Architecture:** New `lib/gsd/` module (3 files) mirrors `lib/graphify/` pattern. GSD installs via `npx get-shit-done-cc@latest --global` with `CLAUDE_CONFIG_DIR` isolation. Version is persisted in `.gsd-version` marker for offline lockfile reads.

**Tech Stack:** bash, npx (isolated npm), jq (lockfile JSON), `find` (nullglob-safe detection).

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/gsd/detect.sh` | **create** | `detect_gsd()` — check `skills/gsd-*` dirs exist |
| `lib/gsd/install.sh` | **create** | `install_gsd([--force])`, `update_gsd_if_installed()` |
| `lib/gsd/status.sh` | **create** | `check_gsd_status()` — print version + skill dirs |
| `iclaude.sh` | **modify** | Phase 8.5 source block; `--install-gsd`, `--check-gsd` dispatch |
| `lib/update/isolated.sh` | **modify** | call `update_gsd_if_installed()` before `save_isolated_lockfile` |
| `lib/lockfile/save.sh` | **modify** | read `.gsd-version` marker, add `gsdVersion` to JSON output |
| `lib/lockfile/install.sh` | **modify** | install GSD from lockfile when `gsdVersion` present |
| `CLAUDE.md` | **modify** | add GSD to features table and commands section |

---

### Task 1: Create `lib/gsd/detect.sh`

**Files:**
- Create: `lib/gsd/detect.sh`

- [ ] **Step 1: Write the test**

```bash
# In terminal (no test framework — use manual smoke test):
# After creating the file, source it and run:
#   CLAUDE_CONFIG_DIR=/tmp/test-gsd-detect
#   mkdir -p "$CLAUDE_CONFIG_DIR/skills/gsd-core"
#   source lib/gsd/detect.sh && detect_gsd && echo PASS || echo FAIL
#   rm -rf /tmp/test-gsd-detect
```

- [ ] **Step 2: Verify test fails (function doesn't exist yet)**

```bash
bash -c 'source lib/gsd/detect.sh 2>/dev/null && detect_gsd && echo PASS || echo FAIL'
```

Expected: error or FAIL (file doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```bash
cat > lib/gsd/detect.sh << 'EOF'
#!/bin/bash
# GSD detection module
# Provides: detect_gsd()

#######################################
# Check if GSD is installed in isolated environment.
# GSD installs skills to ${CLAUDE_CONFIG_DIR}/skills/gsd-*/
# Returns: 0 if installed, 1 otherwise
#######################################
detect_gsd() {
    local skills_dir="${CLAUDE_CONFIG_DIR}/skills"
    [[ -d "$skills_dir" ]] || return 1
    local found
    found=$(find "$skills_dir" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | head -1)
    [[ -n "$found" ]]
}
EOF
```

- [ ] **Step 4: Run the smoke test**

```bash
CLAUDE_CONFIG_DIR=/tmp/test-gsd-detect
mkdir -p "$CLAUDE_CONFIG_DIR/skills/gsd-core"
bash -c "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR source lib/gsd/detect.sh && detect_gsd && echo PASS || echo FAIL"
rm -rf /tmp/test-gsd-detect
```

Expected: `PASS`

Also verify no-install case:
```bash
CLAUDE_CONFIG_DIR=/tmp/test-gsd-empty
mkdir -p "$CLAUDE_CONFIG_DIR/skills"
bash -c "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR source lib/gsd/detect.sh && detect_gsd && echo PASS || echo FAIL"
rm -rf /tmp/test-gsd-empty
```

Expected: `FAIL` (returns 1)

- [ ] **Step 5: Validate bash syntax**

```bash
bash -n lib/gsd/detect.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 6: Commit**

```bash
git add lib/gsd/detect.sh
git commit -m "feat(gsd): add detect_gsd() module"
```

---

### Task 2: Create `lib/gsd/status.sh`

**Files:**
- Create: `lib/gsd/status.sh`
- Depends on: `lib/gsd/detect.sh` (Task 1)

- [ ] **Step 1: Write the implementation**

```bash
cat > lib/gsd/status.sh << 'EOF'
#!/bin/bash
# GSD status module
# Provides: check_gsd_status()

#######################################
# Display GSD installation status.
# Shows installed/not-installed, version from marker, skill dirs.
# Returns: 0 always
#######################################
check_gsd_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  GSD: Get Shit Done Framework Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! detect_gsd; then
        print_warning "GSD: not installed"
        echo "  Run: ./iclaude.sh --install-gsd"
        echo ""
        return 0
    fi

    print_success "GSD: installed"

    local marker="${CLAUDE_CONFIG_DIR}/.gsd-version"
    if [[ -f "$marker" ]]; then
        local ver
        ver=$(cat "$marker" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
        print_info "Version: $ver"
    else
        print_info "Version: unknown (marker absent)"
    fi

    echo ""
    print_info "Installed skills:"
    find "${CLAUDE_CONFIG_DIR}/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null \
        | sort \
        | while IFS= read -r dir; do
            echo "  $(basename "$dir")"
        done

    echo ""
    return 0
}
EOF
```

- [ ] **Step 2: Smoke test**

```bash
CLAUDE_CONFIG_DIR=/tmp/test-gsd-status
mkdir -p "$CLAUDE_CONFIG_DIR/skills/gsd-core"
echo "1.40.0" > "$CLAUDE_CONFIG_DIR/.gsd-version"
bash -c "
  CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR
  source lib/core/colors.sh 2>/dev/null || true
  source lib/core/print.sh 2>/dev/null || true
  # minimal stubs for print_* if not sourced:
  print_success() { echo \"✓ \$*\"; }
  print_warning() { echo \"⚠ \$*\"; }
  print_info() { echo \"  \$*\"; }
  source lib/gsd/detect.sh
  source lib/gsd/status.sh
  check_gsd_status
"
rm -rf /tmp/test-gsd-status
```

Expected: shows GSD installed, version 1.40.0, skills dir `gsd-core`

- [ ] **Step 3: Validate syntax**

```bash
bash -n lib/gsd/status.sh && echo "syntax OK"
```

- [ ] **Step 4: Commit**

```bash
git add lib/gsd/status.sh
git commit -m "feat(gsd): add check_gsd_status() module"
```

---

### Task 3: Create `lib/gsd/install.sh`

**Files:**
- Create: `lib/gsd/install.sh`
- Depends on: `lib/gsd/detect.sh` (Task 1)

- [ ] **Step 1: Write the implementation**

```bash
cat > lib/gsd/install.sh << 'EOF'
#!/bin/bash
# GSD installation module
# Provides: install_gsd(), update_gsd_if_installed()

#######################################
# Install GSD (Get Shit Done) framework in isolated environment.
# Args: [--force] — remove existing gsd-* skill dirs and version marker
# Returns: 0 on success, 1 on failure
#######################################
install_gsd() {
    local force=false
    [[ "${1:-}" == "--force" ]] && force=true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  GSD: Install Get Shit Done Framework"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    setup_isolated_nvm

    if [[ "$force" == true ]]; then
        print_info "Force reinstall: removing existing GSD skill dirs and version marker..."
        find "${CLAUDE_CONFIG_DIR}/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null \
            | xargs -r rm -rf
        rm -f "${CLAUDE_CONFIG_DIR}/.gsd-version"
    fi

    print_info "Installing GSD via npx..."
    if ! CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global; then
        print_error "Failed to install GSD"
        return 1
    fi

    # Record installed version from registry (npm cache warm after preceding npx install)
    local ver
    ver=$(npm view get-shit-done-cc version 2>/dev/null || echo "unknown")
    echo "$ver" > "${CLAUDE_CONFIG_DIR}/.gsd-version"
    print_success "GSD installed: version $ver"

    echo ""
    print_info "Next steps:"
    print_info "  Status:  ./iclaude.sh --check-gsd"
    print_info "  Use:     Start a Claude Code session and run /gsd"
    echo ""
    return 0
}

#######################################
# Update GSD if installed. No-op if not installed.
# Returns: 0 always
#######################################
update_gsd_if_installed() {
    if ! detect_gsd; then
        print_info "GSD not installed, skipping update"
        return 0
    fi
    print_info "Updating GSD..."
    install_gsd || print_warning "GSD update failed (non-critical)"
}
EOF
```

- [ ] **Step 2: Validate syntax**

```bash
bash -n lib/gsd/install.sh && echo "syntax OK"
```

- [ ] **Step 3: Dry-run structure check (no real npm call)**

```bash
bash -c '
  ISOLATED_NVM_DIR=/tmp/fake-nvm
  CLAUDE_CONFIG_DIR=/tmp/test-gsd-install
  mkdir -p "$ISOLATED_NVM_DIR" "$CLAUDE_CONFIG_DIR/skills"
  setup_isolated_nvm() { echo "[stub] setup_isolated_nvm called"; }
  print_error() { echo "ERROR: $*"; }
  print_info() { echo "  $*"; }
  print_success() { echo "✓ $*"; }
  # Override npx to simulate success without network
  npx() { echo "[stub] npx $*"; return 0; }
  npm() { echo "1.40.0"; }
  source lib/gsd/detect.sh
  source lib/gsd/install.sh
  install_gsd
  echo "marker: $(cat $CLAUDE_CONFIG_DIR/.gsd-version)"
  rm -rf /tmp/fake-nvm /tmp/test-gsd-install
'
```

Expected: shows install steps, marker contains `1.40.0`

- [ ] **Step 4: Commit**

```bash
git add lib/gsd/install.sh
git commit -m "feat(gsd): add install_gsd() and update_gsd_if_installed() module"
```

---

### Task 4: Add Phase 8.5 source block in `iclaude.sh`

**Files:**
- Modify: `iclaude.sh` (Phase 8.4/8.5 boundary, lines ~144-149)

- [ ] **Step 1: Locate insertion point**

```bash
grep -n "Phase 8.4\|Phase 9.1" iclaude.sh
```

Expected output (line numbers will vary):
```
144:#######################################
145:# Load Caveman modules (Phase 8.4)
...
151:#######################################
152:# Load Sandbox modules (Phase 9.1)
```

- [ ] **Step 2: Insert Phase 8.5 block after Phase 8.4 block**

Find the exact line where Phase 8.4 block ends (the `fi` after `source "${LIB_DIR}/caveman/install.sh"`), then add after it:

```bash
# In iclaude.sh, after the caveman block:
# if [[ -d "$LIB_DIR/caveman" ]]; then
#     source "${LIB_DIR}/caveman/install.sh"
# fi
# ← insert here
```

The insertion (between Phase 8.4 `fi` and Phase 9.1 comment):

```bash
#######################################
# Load GSD modules (Phase 8.5)
#######################################
if [[ -d "$LIB_DIR/gsd" ]]; then
    source "${LIB_DIR}/gsd/detect.sh"
    source "${LIB_DIR}/gsd/install.sh"
    source "${LIB_DIR}/gsd/status.sh"
fi
```

- [ ] **Step 3: Verify iclaude.sh syntax**

```bash
bash -n iclaude.sh && echo "syntax OK"
```

- [ ] **Step 4: Commit**

```bash
git add iclaude.sh
git commit -m "feat(gsd): load GSD modules as Phase 8.5 in iclaude.sh"
```

---

### Task 5: Add `--install-gsd` and `--check-gsd` CLI flags in `iclaude.sh`

**Files:**
- Modify: `iclaude.sh` (command dispatch, after `--check-graphify` block)

- [ ] **Step 1: Locate insertion point**

```bash
grep -n "\-\-check-graphify\|\-\-pii-proxy" iclaude.sh
```

Expected: `--check-graphify)` block followed by `--pii-proxy)` block.

- [ ] **Step 2: Insert GSD flags after `--check-graphify` block**

Insert between `--check-graphify` exit and `--pii-proxy`:

```bash
            --install-gsd)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-gsd"
                    echo ""
                    echo "GSD is only available in isolated environment"
                    exit 1
                fi
                _gsd_install_force=""
                [[ "${2:-}" == "--force" ]] && { _gsd_install_force="--force"; shift; }
                [[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"
                install_gsd "$_gsd_install_force"
                _gsd_rc=$?
                [[ $_gsd_rc -eq 0 ]] && save_isolated_lockfile
                exit $_gsd_rc
                ;;
            --check-gsd)
                check_gsd_status
                exit 0
                ;;
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n iclaude.sh && echo "syntax OK"
```

- [ ] **Step 4: Smoke test help/flag parsing (no real install)**

```bash
./iclaude.sh --check-gsd 2>&1 | head -5
```

Expected: GSD status output (installed or not installed message)

- [ ] **Step 5: Test --system guard**

```bash
./iclaude.sh --system --install-gsd 2>&1
```

Expected: `ERROR: --system cannot be used with --install-gsd` and non-zero exit

- [ ] **Step 6: Commit**

```bash
git add iclaude.sh
git commit -m "feat(gsd): add --install-gsd and --check-gsd CLI flags"
```

---

### Task 6: Add GSD update call in `lib/update/isolated.sh`

**Files:**
- Modify: `lib/update/isolated.sh` (after `repair_vendor_permissions` guard, before `save_isolated_lockfile`)

- [ ] **Step 1: Locate insertion point**

```bash
grep -n "repair_vendor\|save_isolated_lockfile" lib/update/isolated.sh
```

Expected:
```
103:        if declare -f repair_vendor_permissions &>/dev/null; then
104:            repair_vendor_permissions
105:        fi
106:
107:        # Update lockfile with new version
108:        print_info "Updating lockfile..."
109:        save_isolated_lockfile
```

- [ ] **Step 2: Insert GSD update call between repair_vendor and save_isolated_lockfile**

Add after the `repair_vendor_permissions` block (line ~105), before `print_info "Updating lockfile..."`:

```bash
        # Update GSD if installed
        if declare -f update_gsd_if_installed &>/dev/null; then
            update_gsd_if_installed || print_warning "GSD update failed (non-critical)"
        fi
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/update/isolated.sh && echo "syntax OK"
```

- [ ] **Step 4: Commit**

```bash
git add lib/update/isolated.sh
git commit -m "feat(gsd): update GSD during --update if installed"
```

---

### Task 7: Add `gsdVersion` to `lib/lockfile/save.sh`

**Files:**
- Modify: `lib/lockfile/save.sh`

The change is in two places:
1. After the `omp_installed_at` detection block — add GSD version detection
2. In the `jq -n` call — add `--arg gsdVer` and `gsdVersion: $gsdVer`

- [ ] **Step 1: Locate insertion points**

```bash
grep -n "omp_installed_at\|jq -n\|nvmVersion\|ompInstAt\|instAt" lib/lockfile/save.sh
```

Expected: `omp_installed_at` computed around line ~158, `jq -n` block starting around line ~167, `nvmVersion: "0.39.7"` as the last field.

- [ ] **Step 2: Add GSD version detection (after `omp_installed_at` block, before `jq -n`)**

After:
```bash
	# Detect NVM version dynamically
	local nvm_version
	nvm_version=$(nvm --version 2>/dev/null || echo "unknown")
```

Add:
```bash
	# Detect GSD version from marker file (offline/instant)
	local gsd_version="not installed"
	if declare -f detect_gsd &>/dev/null && detect_gsd &>/dev/null; then
		local gsd_marker="${CLAUDE_CONFIG_DIR}/.gsd-version"
		if [[ -f "$gsd_marker" ]]; then
			gsd_version=$(cat "$gsd_marker" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
		else
			gsd_version=$(npm view get-shit-done-cc version 2>/dev/null | tr -d '[:space:]' || echo "unknown")
		fi
	fi
```

- [ ] **Step 3: Add `--arg gsdVer` to jq call and `gsdVersion` to JSON**

In the `jq -n` call, after `--arg nvmVer "$nvm_version"` add:
```bash
		--arg gsdVer "$gsd_version" \
```

In the JSON body, after `nvmVersion: "0.39.7"` add:
```json
			gsdVersion: $gsdVer
```

The final JSON section should look like:
```bash
	jq -n \
		--arg nodeVer "$node_version" \
		--arg claudeVer "$claude_version" \
		--arg routerVer "$router_version" \
		--argjson lspServers "$lsp_servers_json" \
		--argjson lspPlugins "$lsp_plugins_json" \
		--arg statusEnabled "$statusline_enabled" \
		--arg statusScript "$statusline_script" \
		--arg ompVer "$omp_version" \
		--arg ompPlat "$omp_platform" \
		--arg ompInstAt "$omp_installed_at" \
		--arg instAt "$installed_at" \
		--arg nvmVer "$nvm_version" \
		--arg gsdVer "$gsd_version" \
		'{
			nodeVersion: $nodeVer,
			claudeCodeVersion: $claudeVer,
			routerVersion: $routerVer,
			lspServers: $lspServers,
			lspPlugins: $lspPlugins,
			statusLineEnabled: ($statusEnabled == "true"),
			statusLineScript: $statusScript,
			ohMyPoshVersion: $ompVer,
			ohMyPoshPlatform: $ompPlat,
			ohMyPoshInstalledAt: $ompInstAt,
			installedAt: $instAt,
			nvmVersion: "0.39.7",
			gsdVersion: $gsdVer
		}' > "$ISOLATED_LOCKFILE"
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n lib/lockfile/save.sh && echo "syntax OK"
```

- [ ] **Step 5: Smoke test JSON generation**

```bash
bash -c '
  CLAUDE_CONFIG_DIR=/tmp/test-lockfile-gsd
  ISOLATED_LOCKFILE=/tmp/test-lockfile-gsd.json
  ISOLATED_NVM_DIR=/tmp/fake-nvm
  mkdir -p "$CLAUDE_CONFIG_DIR/skills/gsd-core" "$ISOLATED_NVM_DIR"
  echo "1.40.0" > "$CLAUDE_CONFIG_DIR/.gsd-version"
  # Stub functions
  detect_gsd() { return 0; }
  setup_isolated_nvm() { :; }
  detect_statusline() { return 1; }
  detect_ohmyposh() { return 1; }
  get_router_path() { echo ""; }
  get_nvm_claude_path() { echo ""; }
  print_success() { :; }
  print_warning() { :; }
  print_info() { :; }
  update_lockfile_hash() { :; }
  nvm() { echo "0.39.7"; }
  node() { echo "v20.20.2"; }
  source lib/lockfile/save.sh
  save_isolated_lockfile
  jq .gsdVersion "$ISOLATED_LOCKFILE"
  rm -rf /tmp/test-lockfile-gsd /tmp/test-lockfile-gsd.json
'
```

Expected: `"1.40.0"`

- [ ] **Step 6: Commit**

```bash
git add lib/lockfile/save.sh
git commit -m "feat(gsd): add gsdVersion to lockfile via .gsd-version marker"
```

---

### Task 8: Add GSD install in `lib/lockfile/install.sh`

**Files:**
- Modify: `lib/lockfile/install.sh` (after router install block)

- [ ] **Step 1: Locate insertion point**

```bash
grep -n "router_version\|print_success.*Installation\|update_lockfile_hash" lib/lockfile/install.sh
```

Expected: router block ends around line ~89, `print_success "Installation from lockfile complete"` near line ~165.

- [ ] **Step 2: Insert GSD install after the router block**

After the router install block (the `fi` that closes `if [[ "$router_version" != "not installed" ]]`), add:

```bash
	# Install GSD if version specified in lockfile
	local gsd_version
	gsd_version=$(jq -r '.gsdVersion // "not installed"' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "not installed")

	if [[ "$gsd_version" != "not installed" ]] && [[ "$gsd_version" != "unknown" ]]; then
		echo ""
		print_info "Installing GSD version: $gsd_version"
		echo ""

		CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
			npx "get-shit-done-cc@$gsd_version" --global \
			&& echo "$gsd_version" > "${CLAUDE_CONFIG_DIR}/.gsd-version" \
			|| print_warning "GSD install failed (non-critical)"
	fi
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/lockfile/install.sh && echo "syntax OK"
```

- [ ] **Step 4: Smoke test (stub npx)**

```bash
bash -c '
  ISOLATED_LOCKFILE=/tmp/test-lockfile-gsd-install.json
  CLAUDE_CONFIG_DIR=/tmp/test-gsd-lf-install
  ISOLATED_NVM_DIR=/tmp/fake-nvm
  mkdir -p "$CLAUDE_CONFIG_DIR/skills" "$ISOLATED_NVM_DIR"
  echo '"'"'{"gsdVersion":"1.40.0","routerVersion":"not installed","nodeVersion":"20.20.2","claudeCodeVersion":"1.0.0","lspServers":{},"lspPlugins":{}}'"'"' > "$ISOLATED_LOCKFILE"
  npx() { echo "[stub] npx $*"; return 0; }
  print_info() { echo "  $*"; }
  print_warning() { echo "WARN: $*"; }
  print_success() { echo "✓ $*"; }
  print_error() { echo "ERROR: $*"; return 1; }
  setup_isolated_nvm() { :; }
  nvm() { echo "0.39.7"; }
  node() { echo ""; }
  install_isolated_nvm() { echo "[stub] install_isolated_nvm"; }
  get_nvm_claude_path() { echo ""; }
  get_router_path() { echo ""; }
  update_lockfile_hash() { :; }
  # Patch function to only test the gsd block:
  source lib/lockfile/install.sh
  # Verify gsd_version parsing only
  gsd_version=$(jq -r '"'"'.gsdVersion // "not installed"'"'"' "$ISOLATED_LOCKFILE")
  echo "gsdVersion from lockfile: $gsd_version"
  rm -rf /tmp/test-lockfile-gsd-install.json /tmp/test-gsd-lf-install /tmp/fake-nvm
'
```

Expected: `gsdVersion from lockfile: 1.40.0`

- [ ] **Step 5: Commit**

```bash
git add lib/lockfile/install.sh
git commit -m "feat(gsd): install GSD from lockfile when gsdVersion present"
```

---

### Task 9: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add GSD to commands section**

In the `### Daily` / `### Installation` section, after `./iclaude.sh --install-graphify`:

```bash
./iclaude.sh --install-gsd          # Install GSD framework (npx get-shit-done-cc)
./iclaude.sh --check-gsd            # Check GSD installation status
```

- [ ] **Step 2: Add GSD to features table**

In the `## Features` table, after the Graphify row:

```markdown
| GSD Framework (meta-prompting, spec-driven dev) | [docs/superpowers/specs/2026-05-14-gsd-integration-design.md](docs/superpowers/specs/2026-05-14-gsd-integration-design.md) |
```

- [ ] **Step 3: Update project overview line**

In the first paragraph, add `, and GSD framework` after `Graphify knowledge graph`:

```
**iclaude** is a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy (Presidio NLP), microVM sandbox (Firecracker), Graphify knowledge graph, and GSD framework.
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(gsd): add GSD to CLAUDE.md features table and commands"
```

---

### Task 10: Integration verification

**Files:** none (read-only verification)

- [ ] **Step 1: Full syntax check**

```bash
bash -n iclaude.sh && \
bash -n lib/gsd/detect.sh && \
bash -n lib/gsd/install.sh && \
bash -n lib/gsd/status.sh && \
bash -n lib/update/isolated.sh && \
bash -n lib/lockfile/save.sh && \
bash -n lib/lockfile/install.sh && \
echo "All syntax OK"
```

Expected: `All syntax OK`

- [ ] **Step 2: Check Phase 8.5 loads correctly**

```bash
grep -A 5 "Phase 8.5" iclaude.sh
```

Expected: shows the GSD source block with 3 source lines

- [ ] **Step 3: Check --check-gsd flag exists**

```bash
grep -n "check-gsd\|install-gsd" iclaude.sh
```

Expected: both flags present in command dispatch

- [ ] **Step 4: Check lockfile fields**

```bash
grep -n "gsdVersion\|gsd_version\|gsd-version" lib/lockfile/save.sh lib/lockfile/install.sh
```

Expected: `gsdVersion` appears in `save.sh` jq args + JSON body; `gsd_version` detection in `save.sh`; `gsd_version` + `npx` install in `install.sh`

- [ ] **Step 5: Check update hook**

```bash
grep -n "update_gsd_if_installed" lib/update/isolated.sh
```

Expected: 2 lines — the `declare -f` guard and the call

- [ ] **Step 6: Commit (if any final adjustments were made)**

```bash
git status
# Commit only if there are changes
```

---

## Self-Review Notes

**Spec coverage:**
- ✓ `lib/gsd/detect.sh` — Task 1
- ✓ `lib/gsd/install.sh` — Task 3
- ✓ `lib/gsd/status.sh` — Task 2
- ✓ Phase 8.5 source loading — Task 4
- ✓ `--install-gsd [--force]` flag with `--system` guard — Task 5
- ✓ `--check-gsd` flag — Task 5
- ✓ `save_isolated_lockfile` called on success (not inside `install_gsd`) — Task 5
- ✓ `update_gsd_if_installed` in `update_isolated_claude` — Task 6
- ✓ `gsdVersion` in lockfile via marker — Task 7
- ✓ GSD install from lockfile (non-critical failure) — Task 8
- ✓ CLAUDE.md updated — Task 9

**Type consistency:**
- `detect_gsd` used in `install.sh` (update_gsd_if_installed), `status.sh`, `save.sh` — all consistent
- `install_gsd` called by `update_gsd_if_installed` and CLI dispatch — consistent signature `install_gsd([--force])`
- `check_gsd_status` called by `--check-gsd` — consistent
- `.gsd-version` marker path: `${CLAUDE_CONFIG_DIR}/.gsd-version` — used identically in `install.sh`, `status.sh`, `save.sh`
- `skills/gsd-*` pattern used in `detect.sh`, `status.sh`, `install.sh` (force cleanup) — consistent
