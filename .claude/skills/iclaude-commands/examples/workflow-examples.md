# Workflow Examples

Common development and CI/CD workflows using iclaude.sh commands.

## Development Workflows

### Workflow 1: First Time Setup

**Scenario:** New developer cloning iclaude for first time

```bash
# 1. Clone repository
git clone https://github.com/user/iclaude.git
cd iclaude

# 2. Install isolated environment
./iclaude.sh --isolated-install

# 3. Configure proxy (if behind corporate proxy)
./iclaude.sh --proxy https://user:pass@proxy:8118

# 4. Test proxy
./iclaude.sh --test

# 5. Launch Claude Code
./iclaude.sh

# Result: Claude Code launches with proxy configured
```

**Duration:** ~10 minutes (first time)

### Workflow 2: Daily Development

**Scenario:** Developer working on iclaude.sh

```bash
# Morning: Launch with saved proxy
./iclaude.sh

# After making changes: Validate
bash -n iclaude.sh
./iclaude.sh --test

# Update Claude Code (weekly)
./iclaude.sh --update

# Check status before commit
./iclaude.sh --check-isolated
```

### Workflow 3: Adding New Feature

**Scenario:** Adding `--sandbox-check` flag

```bash
# 1. Create feature branch
git checkout -b feature/sandbox-check

# 2. Edit iclaude.sh
# Add check_sandbox_availability() function
# Add --sandbox-check flag parsing

# 3. Validate syntax
bash -n iclaude.sh

# 4. Test new flag
./iclaude.sh --sandbox-check

# 5. Check environment
./iclaude.sh --check-isolated

# 6. Commit changes
git add iclaude.sh CLAUDE.md
git commit -m "feat: add --sandbox-check flag"

# 7. Push and create PR
git push origin feature/sandbox-check
```

### Workflow 4: Router Development

**Scenario:** Testing alternative LLM providers

```bash
# 1. Install router
./iclaude.sh --install-router

# 2. Configure providers
vim router.json
# Add DeepSeek API key placeholder

# 3. Export API keys
export DEEPSEEK_API_KEY=sk-...

# 4. Check router status
./iclaude.sh --check-router

# 5. Launch with router
./iclaude.sh --router --no-chrome

# 6. Launch without router (native Claude)
./iclaude.sh

# Result: Switch between providers easily
```

## CI/CD Workflows

### Workflow 5: GitHub Actions Build

**Scenario:** CI pipeline installing and testing iclaude

```yaml
# .github/workflows/test.yml
name: Test iclaude
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install from lockfile
        run: ./iclaude.sh --install-from-lockfile

      - name: Validate syntax
        run: bash -n iclaude.sh

      - name: Check isolated environment
        run: ./iclaude.sh --check-isolated

      - name: Test proxy (mock)
        run: |
          # Start mock proxy
          docker run -d -p 8118:8118 mock-proxy
          ./iclaude.sh --proxy http://localhost:8118 --test
```

**Duration:** ~5-8 minutes per run

### Workflow 6: Team Onboarding

**Scenario:** New team member setting up development environment

```bash
# 1. Clone repository (with submodules)
git clone --recursive https://github.com/user/iclaude.git
cd iclaude

# 2. Restore from lockfile (exact team versions)
./iclaude.sh --install-from-lockfile

# 3. Repair symlinks (if needed after git clone)
./iclaude.sh --repair-isolated

# 4. Configure corporate proxy
./iclaude.sh --proxy https://proxy.company.com:8118

# 5. Test configuration
./iclaude.sh --test

# 6. Verify versions match team
./iclaude.sh --check-isolated
# Node: 18.20.8 ✅
# Claude: 2.1.15 ✅

# Result: Exact same environment as rest of team
```

### Workflow 7: Version Upgrade

**Scenario:** Upgrading Claude Code for entire team

```bash
# Developer machine:

# 1. Update Claude Code
./iclaude.sh --update

# 2. Test new version
./iclaude.sh --test
./iclaude.sh --check-isolated

# 3. Lockfile auto-updates
cat .nvm-isolated-lockfile.json
# "claudeCodeVersion": "2.1.16"

# 4. Commit updated lockfile
git add .nvm-isolated-lockfile.json
git commit -m "chore(deps): update Claude Code to 2.1.16"
git push

# Team members:

# 5. Pull changes
git pull

# 6. Install new version from lockfile
./iclaude.sh --install-from-lockfile

# Result: Entire team on Claude Code 2.1.16
```

## Troubleshooting Workflows

### Workflow 8: Proxy Not Working

```bash
# 1. Test proxy directly
curl -x http://proxy:8118 http://www.google.com

# 2. Check saved credentials
cat .claude_proxy_credentials
# (should show proxy URL)

# 3. Test with iclaude
./iclaude.sh --test --show-password

# 4. If fails, reconfigure
./iclaude.sh --proxy http://proxy:8118 --test

# 5. Launch without proxy (temporary)
./iclaude.sh --no-proxy
```

### Workflow 9: Broken Environment

```bash
# Symptoms:
# - command not found: claude
# - npm/npx not working
# - wrong versions

# Fix:

# 1. Check symlinks
ls -la .nvm-isolated/npm-global/bin/

# 2. Repair symlinks
./iclaude.sh --repair-isolated

# 3. If still broken, clean and reinstall
./iclaude.sh --cleanup-isolated
./iclaude.sh --install-from-lockfile

# 4. Verify fix
./iclaude.sh --check-isolated
```

### Workflow 10: OAuth Token Expired

```bash
# Symptoms:
# - "Token expired" error on launch
# - Auto-refresh failed

# Fix:

# 1. Manual refresh
./iclaude.sh --refresh-token

# 2. If fails, use /login in Claude Code
./iclaude.sh
# Then run: /login

# 3. Verify token
jq '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json
# Should be ~1 year in future
```

## Advanced Workflows

### Workflow 11: Multi-Environment Setup

**Scenario:** Developer working on multiple iclaude branches

```bash
# Project 1: main branch (stable)
cd ~/projects/iclaude-main
./iclaude.sh  # Uses .nvm-isolated/ in this directory

# Project 2: feature branch (testing)
cd ~/projects/iclaude-feature
./iclaude.sh  # Uses separate .nvm-isolated/ in this directory

# Result: Isolated environments per project directory
```

### Workflow 12: Offline Development

**Scenario:** Working without internet access

```bash
# Preparation (when online):
# 1. Install everything from lockfile
./iclaude.sh --install-from-lockfile

# 2. Commit .nvm-isolated/ to git (optional)
git add .nvm-isolated/
git commit -m "chore: commit isolated environment"

# Offline usage:
# 3. Clone repository (includes .nvm-isolated/)
git clone file:///usb/iclaude.git
cd iclaude

# 4. Repair symlinks
./iclaude.sh --repair-isolated

# 5. Launch (no internet needed)
./iclaude.sh --no-proxy

# Result: Fully functional offline
```

## Best Practices

**DO:**
- ✅ Use `--install-from-lockfile` for reproducible deployments
- ✅ Run `--repair-isolated` after `git clone`
- ✅ Test with `--test` before committing proxy changes
- ✅ Check status with `--check-isolated` before updates
- ✅ Commit lockfile to git (enables team synchronization)

**DON'T:**
- ❌ Manually edit `.nvm-isolated/` files
- ❌ Use `npm install` directly (use `--install-from-lockfile`)
- ❌ Delete lockfile (breaks reproducibility)
- ❌ Mix system and isolated installations
- ❌ Commit `.claude_proxy_credentials` to git
