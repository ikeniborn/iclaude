# Example: Adding --sandbox-check Flag

## Scenario

Add `--sandbox-check` flag to iclaude.sh that checks if sandbox environment is available (Docker or bubblewrap on Linux, always ready on macOS).

## Input

```json
{
  "task_description": "Add --sandbox-check flag to check sandbox availability",
  "project_context": {
    "type": "bash-wrapper",
    "primary_file": "iclaude.sh",
    "language": "bash"
  }
}
```

## Multi-Perspective Analysis

### System Architect
**Concerns:**
- Where to place `check_sandbox_availability()` in initialization flow?
- Should it run on every launch or only with --sandbox-check?

**Recommendations:**
- Add function after `detect_router()` (~line 380)
- Only run when `--sandbox-check` flag is passed (not automatic)
- Return status code: 0 (ready), 1 (missing dependencies), 2 (not applicable)

### Backend Developer
**Concerns:**
- How to detect Docker/bubblewrap efficiently?
- What if `docker` command exists but daemon is not running?

**Recommendations:**
- Use `command -v docker` for binary detection
- For Docker: run `docker ps` to check daemon status
- For bubblewrap: check `command -v bwrap`
- Cache result to avoid repeated checks

### Security Specialist
**Concerns:**
- Can sandbox check be exploited for command injection?
- Should we validate user input for sandbox commands?

**Recommendations:**
- No user input in sandbox detection (safe)
- Use absolute paths for commands (avoid PATH hijacking)
- Don't execute arbitrary sandbox commands without validation

### DevOps Engineer
**Concerns:**
- macOS doesn't need Docker/bubblewrap (native sandbox)
- Linux requires manual installation of dependencies
- CI/CD needs to handle missing sandbox gracefully

**Recommendations:**
- macOS: always return "ready"
- Linux: detect platform via `uname -s`
- Add `--sandbox-install` flag for automated dependency installation (future)

### Technical Writer
**Concerns:**
- New flag not documented in CLAUDE.md
- Sandbox Commands section missing
- No mention in "Development Commands"

**Recommendations:**
- Add "Sandbox Commands" section at line 145-159
- Document return codes and platform differences
- Add example: `./iclaude.sh --sandbox-check`

## Validation Plan

```json
{
  "validation_plan": {
    "phase_0_lsp": {
      "tool": "shellcheck",
      "command": "shellcheck -x iclaude.sh",
      "focus": ["SC2086: unquoted variables", "SC2181: exit code checks"],
      "blocking": true
    },
    "phase_1_syntax": {
      "tool": "bash -n",
      "command": "bash -n iclaude.sh",
      "blocking": true
    },
    "phase_3_code_review": {
      "tool": "@skill:code-review",
      "checks": [
        "Security: command injection in sandbox detection",
        "Performance: avoid repeated docker ps calls",
        "Maintainability: function length < 50 lines"
      ],
      "blocking": false
    },
    "phase_4_integration": {
      "tool": "manual",
      "test_cases": [
        "./iclaude.sh --sandbox-check  # macOS (expect: ready)",
        "./iclaude.sh --sandbox-check  # Linux without Docker (expect: missing)",
        "./iclaude.sh --sandbox-check  # Linux with Docker (expect: ready)"
      ],
      "blocking": true
    },
    "phase_5_documentation": {
      "updates": [
        "Add CLAUDE.md:145-159 'Sandbox Commands' section",
        "Update function list with check_sandbox_availability()",
        "Document return codes: 0=ready, 1=missing, 2=N/A"
      ],
      "blocking": false
    }
  }
}
```

## Implementation

### 1. Add Function (iclaude.sh:~385)

```bash
# Check sandbox availability (Docker or bubblewrap on Linux, native on macOS)
# Returns: 0=ready, 1=missing dependencies, 2=not applicable
check_sandbox_availability() {
    local platform=$(uname -s)

    case "$platform" in
        Darwin)
            echo "✅ Sandbox: macOS native sandbox (always available)"
            return 0
            ;;
        Linux)
            if command -v docker &>/dev/null; then
                if docker ps &>/dev/null 2>&1; then
                    echo "✅ Sandbox: Docker daemon running"
                    return 0
                else
                    echo "⚠️  Sandbox: Docker installed but daemon not running"
                    echo "Start with: sudo systemctl start docker"
                    return 1
                fi
            elif command -v bwrap &>/dev/null; then
                echo "✅ Sandbox: bubblewrap available"
                return 0
            else
                echo "❌ Sandbox: Missing dependencies"
                echo "Install: sudo apt-get install bubblewrap"
                return 1
            fi
            ;;
        *)
            echo "ℹ️  Sandbox: Platform $platform not tested"
            return 2
            ;;
    esac
}
```

### 2. Add Flag Parsing (iclaude.sh:~3020)

```bash
--sandbox-check)
    check_sandbox_availability
    exit $?
    ;;
```

### 3. Add Help Text (iclaude.sh:~2835)

```bash
echo "  --sandbox-check          Check sandbox availability (Docker/bubblewrap)"
```

## Validation Results

### PHASE 0: ShellCheck

```bash
$ shellcheck -x iclaude.sh

iclaude.sh:385:20: note: platform is assigned but never used [SC2034]
                    ^~~~~~
# PASS: SC2034 is acceptable for functions that may expand in future
```

### PHASE 1: Syntax Check

```bash
$ bash -n iclaude.sh
# PASS: No syntax errors
```

### PHASE 3: Code Review

```
✅ Security: No command injection (no user input)
✅ Performance: Docker check cached via return code
⚠️  Maintainability: Function 45 lines (OK, under 50 threshold)
```

### PHASE 4: Integration Tests

```bash
# macOS
$ ./iclaude.sh --sandbox-check
✅ Sandbox: macOS native sandbox (always available)

# Linux without Docker
$ ./iclaude.sh --sandbox-check
❌ Sandbox: Missing dependencies
Install: sudo apt-get install bubblewrap

# Linux with Docker
$ ./iclaude.sh --sandbox-check
✅ Sandbox: Docker daemon running
```

### PHASE 5: Documentation Sync

**CLAUDE.md changes:**

```diff
+### Sandbox Commands
+
+```bash
+# Check sandbox availability and requirements
+./iclaude.sh --sandbox-check
+
+# Install system dependencies (Linux/WSL2 only)
+./iclaude.sh --sandbox-install
+
+# macOS - check status (always ready)
+./iclaude.sh --sandbox-check
+
+# Restore from lockfile (auto-installs if sandboxAvailable: true)
+./iclaude.sh --install-from-lockfile
+```
```

## Output

```json
{
  "validation_results": {
    "phase_0_lsp": {
      "status": "passed",
      "warnings": ["SC2034: platform unused (acceptable)"]
    },
    "phase_1_syntax": {
      "status": "passed"
    },
    "phase_3_code_review": {
      "status": "passed_with_warnings",
      "warnings": ["Function length 45 lines (under 50 threshold)"]
    },
    "phase_4_integration": {
      "status": "passed",
      "tests_run": 3,
      "tests_passed": 3
    },
    "phase_5_documentation": {
      "status": "completed",
      "files_updated": ["CLAUDE.md:145-159"]
    }
  },
  "integration_notes": [
    "Commit changes: git add iclaude.sh CLAUDE.md",
    "Test on Linux before pushing",
    "Update lockfile schema if adding sandboxAvailable field"
  ]
}
```

## Explanation

This example demonstrates the complete iclaude-validation workflow:

1. **Multi-Perspective Analysis** identified 5 concerns (architecture, performance, security, portability, documentation)
2. **Validation Plan** specified 5 phases with specific tools and blocking criteria
3. **Implementation** followed recommendations (function placement, error handling, platform detection)
4. **Validation Results** confirmed all checks passed (LSP, syntax, code review, integration, docs)
5. **Documentation Sync** updated CLAUDE.md with new section and function reference

**Key Takeaways:**
- Multi-perspective analysis catches edge cases (Docker daemon not running)
- Validation loop prevents runtime errors (shellcheck + bash -n)
- Documentation sync keeps CLAUDE.md accurate (line numbers, return codes)
- Integration tests verify behavior on target platforms (macOS/Linux)
