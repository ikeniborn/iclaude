# iclaude-validation

Применение многоперспективного анализа и validation loop для разработки iclaude.sh с обязательной проверкой архитектурных решений.

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | Auto-invoked in PHASE 0 (after context-awareness) |
| **Purpose** | Multi-perspective analysis + validation loop for iclaude development |
| **Duration** | 2-5 min (analysis + checks) |
| **Inputs** | task_description, project_context |
| **Outputs** | validation_plan, required_perspectives, validation_checkpoints |
| **Integration** | Links to lsp-integration, code-review, bash validation |

---

## When to Use

**Auto-invoked** when working on iclaude project (detected via `project_context.type == "bash-wrapper"`).

Use this skill to:
- Analyze bash script changes from multiple perspectives
- Plan validation checkpoints for development phases
- Ensure architectural decisions are verified
- Link LSP/code-review/tests to specific validation points

**Manual invocation:** Not recommended (auto-invoked by context-awareness)

---

## How It Works

### Step 1: Multi-Perspective Analysis

**Purpose:** Рассмотреть задачу с точки зрения 5 ключевых ролей

**Perspectives:**

| Role | Focus Areas | Questions to Ask |
|------|-------------|------------------|
| **System Architect** | Infrastructure, scalability, fault tolerance | • How does this change affect isolated environment isolation?<br>• What happens if NVM installation fails mid-process?<br>• Does lockfile handle version conflicts? |
| **Backend Developer** | Data processing, resource load, API efficiency | • Is proxy credential parsing robust?<br>• What's the memory footprint of parallel npm installs?<br>• Are temp files cleaned up properly? |
| **Security Specialist** | Vulnerabilities, data protection, best practices | • Is chmod 600 enforced on credentials file?<br>• Can proxy URL contain shell injection?<br>• Are passwords logged anywhere? |
| **DevOps Engineer** | Portability, CI/CD, reproducibility | • Will this work on macOS/Linux/WSL2?<br>• Can lockfile restore exact environment?<br>• How to test in clean environment? |
| **Technical Writer** | Documentation accuracy, code-doc sync | • Does CLAUDE.md reflect new --flag?<br>• Are function locations accurate?<br>• Is lockfile format documented? |

**Analysis Output:**
```json
{
  "multi_perspective_analysis": {
    "system_architect": {
      "concerns": ["Symlink management after npm update", "Lockfile version conflicts"],
      "recommendations": ["Add version conflict detection", "Test symlink repair"]
    },
    "backend_developer": {
      "concerns": ["ENOTEMPTY errors during cleanup"],
      "recommendations": ["Retry with exponential backoff", "Add cleanup_old_installations"]
    },
    "security_specialist": {
      "concerns": ["Proxy password in environment variables", "Domain to IP conversion"],
      "recommendations": ["Use HTTPS proxy only", "Add --proxy-ca for TLS"]
    },
    "devops_engineer": {
      "concerns": ["macOS vs Linux NVM paths", "CI/CD lockfile auto-update"],
      "recommendations": ["Test on both platforms", "Add GitHub Actions workflow"]
    },
    "technical_writer": {
      "concerns": ["Function locations in CLAUDE.md", "Missing --sandbox-check docs"],
      "recommendations": ["Update line numbers", "Add sandbox commands section"]
    }
  }
}
```

### Step 2: Validation Loop Planning

**Purpose:** Определить checkpoints для валидации на каждой фазе разработки

**Validation Checkpoints:**

| Phase | Tools | Validation Criteria | Example |
|-------|-------|---------------------|---------|
| **PHASE 0: LSP Diagnostics** | bash-language-server (shellcheck) | • No SC2086 (unquoted variables)<br>• No SC2155 (declare+assign)<br>• No SC2181 (check exit code directly) | `shellcheck iclaude.sh` |
| **PHASE 1: Syntax Check** | `bash -n` | • No syntax errors<br>• All functions defined before use | `bash -n iclaude.sh` |
| **PHASE 2: Unit Tests** | bats-core (optional) | • validate_proxy_url() tests<br>• resolve_domain_to_ip() tests | `bats tests/proxy.bats` |
| **PHASE 3: Code Review** | @skill:code-review | • Security: proxy credential handling<br>• Performance: symlink creation<br>• Maintainability: function complexity | Auto-invoked |
| **PHASE 4: Integration Tests** | Manual testing | • `--test` with real proxy<br>• `--isolated-install` from scratch<br>• `--install-from-lockfile` | See Test Cases section |
| **PHASE 5: Documentation Sync** | Manual check | • CLAUDE.md locations accurate<br>• New flags documented<br>• Lockfile format up-to-date | Compare code ↔ docs |

**Planning Output:**
```json
{
  "validation_plan": {
    "phase_0_lsp": {
      "tool": "shellcheck",
      "command": "shellcheck -x iclaude.sh",
      "required": true,
      "blocking": true
    },
    "phase_1_syntax": {
      "tool": "bash -n",
      "command": "bash -n iclaude.sh",
      "required": true,
      "blocking": true
    },
    "phase_3_code_review": {
      "tool": "@skill:code-review",
      "checks": ["security", "performance", "maintainability"],
      "required": true,
      "blocking": false
    },
    "phase_4_integration": {
      "tool": "manual",
      "test_cases": [
        "./iclaude.sh --test",
        "./iclaude.sh --isolated-install",
        "./iclaude.sh --install-from-lockfile"
      ],
      "required": true,
      "blocking": true
    }
  }
}
```

### Step 3: Execute Validation Loop

**Purpose:** Выполнить все checkpoints и собрать результаты

**Execution Flow:**
1. Run PHASE 0 (LSP) → If failed, stop and show errors
2. Run PHASE 1 (Syntax) → If failed, stop
3. Continue with PHASE 3 (Code Review) → Warnings OK
4. Suggest PHASE 4 (Integration) test commands
5. Remind about PHASE 5 (Documentation sync)

**Validation Results:**
```json
{
  "validation_results": {
    "phase_0_lsp": {
      "status": "passed",
      "errors": [],
      "warnings": ["SC2034: VAR unused (OK for export)"]
    },
    "phase_1_syntax": {
      "status": "passed",
      "errors": []
    },
    "phase_3_code_review": {
      "status": "passed_with_warnings",
      "warnings": ["Function repair_isolated_environment() > 50 lines"]
    },
    "phase_4_integration": {
      "status": "pending",
      "suggested_commands": [
        "./iclaude.sh --test",
        "./iclaude.sh --check-isolated"
      ]
    },
    "phase_5_documentation": {
      "status": "pending",
      "reminder": "Update CLAUDE.md with new function locations"
    }
  }
}
```

---

## Best Practices

### Multi-Perspective Analysis

**DO:**
- ✅ Ask specific questions for each role
- ✅ Consider edge cases (network failures, partial installations)
- ✅ Think about portability (macOS/Linux differences)
- ✅ Prioritize security (credential handling, shell injection)

**DON'T:**
- ❌ Skip perspectives (all 5 required)
- ❌ Give generic answers ("security is important")
- ❌ Ignore documentation sync

### Validation Loop

**DO:**
- ✅ Run LSP/syntax checks FIRST (blocking)
- ✅ Use shellcheck with `-x` flag (follow sourced files)
- ✅ Test with `--test` before committing
- ✅ Update CLAUDE.md line numbers after changes

**DON'T:**
- ❌ Skip syntax validation (prevents runtime errors)
- ❌ Ignore shellcheck warnings (SC2086, SC2155 are critical)
- ❌ Commit without documentation update

---

## Output Format

### JSON Output

See Step 2 and Step 3 above for full structure.

Key fields:
- `multi_perspective_analysis`: 5 roles × concerns + recommendations
- `validation_plan`: Phase → tool → command → blocking status
- `validation_results`: Phase → status → errors/warnings

---

## Integration with Other Skills

### Input Dependencies

Requires data from:
- `context-awareness` → project_type = "bash-wrapper"
- `lsp-integration` → shellcheck LSP status

### Output Consumers

Provides data to:
- `code-review` → Security/performance checks
- `git-workflow` → Pre-commit validation
- User → Test commands to run manually

---

## Test Cases

### Scenario 1: Adding new --flag to iclaude.sh

**Input:**
```json
{
  "task_description": "Add --sandbox-check flag to check sandbox availability",
  "project_context": {
    "type": "bash-wrapper",
    "files": ["iclaude.sh", "CLAUDE.md"]
  }
}
```

**Multi-Perspective Analysis:**
- System Architect: Where does sandbox detection fit in initialization flow?
- Backend: How to check Docker/bubblewrap availability efficiently?
- Security: Can sandbox escape via malicious command injection?
- DevOps: macOS always ready, Linux needs dependencies
- Technical Writer: Document in "Sandbox Commands" section

**Validation Plan:**
- PHASE 0: shellcheck after adding check_sandbox_availability()
- PHASE 1: bash -n iclaude.sh
- PHASE 3: code-review (security: command injection)
- PHASE 4: Test on macOS + Linux
- PHASE 5: Add to CLAUDE.md line 145-159

**Output:**
```json
{
  "validation_checkpoints": [
    {
      "phase": "LSP",
      "command": "shellcheck -x iclaude.sh",
      "blocking": true
    },
    {
      "phase": "Integration",
      "command": "./iclaude.sh --sandbox-check",
      "blocking": true
    },
    {
      "phase": "Documentation",
      "action": "Add to CLAUDE.md:145-159",
      "blocking": false
    }
  ]
}
```

---

## Examples

See `examples/add-flag.md` for complete workflow.

---

## Workflow Integration

This skill is auto-invoked in PHASE 0 when:
- `project_context.type == "bash-wrapper"`
- Task involves modifying `iclaude.sh` or related functions

**Typical Flow:**
```
context-awareness → iclaude-validation → structured-planning → execution → code-review → git-workflow
```

---

## Notes

- This skill is **iclaude-specific** (not applicable to other projects)
- Multi-perspective analysis is **mandatory** (not optional)
- Validation loop integrates with existing skills (lsp-integration, code-review)
- Documentation sync is **critical** (function locations change frequently)
