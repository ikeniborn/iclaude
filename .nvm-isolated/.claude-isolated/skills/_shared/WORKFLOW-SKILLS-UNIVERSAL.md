# Universal Workflow & Skills Reference

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Purpose:** Централизованный universal workflow (PHASE 0-5) и skills compatibility matrix для всех project templates

---

## Overview

Этот документ описывает универсальный workflow, используемый всеми project templates (task-lite-clickhouse-v7.0, task-lite-familybudget-v7.0, etc.). Определяет 6 фаз выполнения задач и compatible skills для каждой фазы.

**Ключевые принципы:**
- ✅ Universal workflow применяется к ВСЕМ проектам
- ✅ Project templates добавляют только project-specific deviations
- ✅ Skills composition адаптируется к complexity (minimal/standard/complex)
- ✅ Data flow между фазами через structured output

**Кому это нужно:**
- Project templates (для reference universal workflow)
- adaptive-workflow skill (для complexity-based customization)
- structured-planning skill (для orchestration)
- Все skills участвующие в workflow

---

## Universal Workflow (PHASE 0-5)

### phase-0-complexity

### Diagram

```
┌──────────────────────────────────────────────────────────┐
│ PHASE 0: Context & Complexity                            │
│ Skills: context-awareness → lsp-integration (opt) →     │
│         context7-integration (opt) → adaptive-workflow   │
│ Output: {project_context, lsp_status, library_docs,     │
│          complexity}                                     │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 1: Analysis & Planning                             │
│ Skills: thinking-framework → structured-planning         │
│ Output: {task_plan, execution_mode_recommendation}      │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 1.5: Git Branch Setup [NEW]                        │
│ Skill: git-workflow [mode: create-branch]                │
│ Input: task_plan.git.branch_name                         │
│ Output: {git_branch_result}                              │
│ Actions: Checkout base → Pull → Create branch → Switch  │
│ Note: Branch created BEFORE approval and code changes    │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 2: Approval [Conditional]                          │
│ Skill: approval-gates                                    │
│ Condition: Skip if complexity == minimal                 │
│ Output: {approval_decision}                              │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 3: Execution                                       │
│ Mode A: Standard Execution (default)                     │
│   - Execute task_plan.execution_steps                    │
│   - Run syntax validation                                │
│   - code-review (if complexity != minimal)               │
│ External Tool: Bash Loop (optional)                         │
│   - ./iclaude.sh --loop task.md                  │
│   - Iterative execution until promise found              │
│ Output: {execution_results, code_review_results}        │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 3.5: Code Review Error Fixing [Conditional]       │
│ Condition: blocking_issues > 0 OR security warnings     │
│ Skills: code-review (re-run) + pr-automation (fixes)    │
│ Max iterations: 2                                        │
│ Output: {fixed_issues, final_code_review}               │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 4: Validation                                      │
│ Skill: validation-framework                              │
│ On FAILED: error-handling → rollback-recovery           │
│ Output: {validation_results} → PASSED/FAILED            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 5A: Git Commit & Push [MODIFIED]                   │
│ Skill: git-workflow [mode: commit-and-push]              │
│ Actions: Stage files → Commit → Push                     │
│ Note: Assumes branch already created in PHASE 1.5        │
│ Output: {git_result}                                      │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 5B: PR Automation [Optional]                       │
│ Skill: pr-automation                                     │
│ Trigger: Ask user via AskUserQuestion                   │
│ Workflow: Create PR → Monitor CI/CD → Fix → Ready       │
│ Output: {pr_result}                                      │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ PHASE 5C: Task Summary                                   │
│ Skill: git-workflow (task-summary template)             │
│ Output: {final_summary}                                  │
└──────────────────────────────────────────────────────────┘
```

---

## Skills Compatibility Matrix

### By Phase

| Phase | Skill | Required | Conditional | Complexity Filter |
|-------|-------|----------|-------------|-------------------|
| **0** | context-awareness | ✅ Always | - | All |
| **0** | lsp-integration | ⚠️ Optional | If TypeScript/Python/Go | All |
| **0** | context7-integration | ⚠️ Optional | If library docs needed | All |
| **0** | adaptive-workflow | ✅ Always | - | All |
| **1** | thinking-framework | ✅ Always | - | All |
| **1** | structured-planning | ✅ Always | - | All |
| **1.5** | git-workflow (create-branch) | ✅ Always | - | All |
| **2** | approval-gates | ⚠️ Conditional | Skip if minimal | standard, complex |
| **3** | loop mode | ⚠️ Conditional | If iterative task | complex |
| **3** | code-review | ⚠️ Conditional | Skip if minimal | standard, complex |
| **3.5** | code-review (re-run) | ⚠️ Conditional | If blocking_issues > 0 | standard, complex |
| **3.5** | pr-automation (fixes) | ⚠️ Conditional | If blocking_issues > 0 | standard, complex |
| **4** | validation-framework | ✅ Always | - | All |
| **4** | error-handling | ⚠️ Conditional | If validation failed | All |
| **4** | rollback-recovery | ⚠️ Conditional | If retries exhausted | All |
| **5A** | git-workflow | ✅ Always | - | All |
| **5B** | pr-automation | ⚠️ Optional | Ask user | All |
| **5C** | git-workflow (summary) | ✅ Always | - | All |

### Skill Dependencies

```
context-awareness
  └─ Output: project_context
     └─ Used by: structured-planning, validation-framework

lsp-integration
  └─ Output: lsp_status
     └─ Used by: code-review, validation-framework

context7-integration
  └─ Output: library_docs
     └─ Used by: structured-planning (execution_steps enrichment)

adaptive-workflow
  └─ Output: complexity
     └─ Used by: structured-planning (template selection), approval-gates (skip logic)

thinking-framework
  └─ Output: analysis_thinking
     └─ Used by: structured-planning (task understanding)

structured-planning
  └─ Output: task_plan
     └─ Used by: PHASE 3 (execution), PHASE 4 (validation), git-workflow (commit message)

code-review
  └─ Output: code_review_results
     └─ Used by: PHASE 3.5 (error fixing trigger)

validation-framework
  └─ Output: validation_results
     └─ Used by: error-handling (retry decision)

git-workflow
  └─ Output: git_result
     └─ Used by: pr-automation (PR creation), task summary

pr-automation
  └─ Output: pr_result
     └─ Used by: task summary (final status)
```

---

## Complexity-Based Customization

### Minimal Complexity

**Characteristics:**
- Simple tasks (1-2 files, 2-3 steps)
- Obvious solution
- Low risk

**Customizations:**
- ✅ PHASE 0: context-awareness + adaptive-workflow only (skip LSP/Context7)
- ✅ PHASE 1: Use task-plan-lite template
- ❌ PHASE 2: **SKIP approval-gates**
- ✅ PHASE 3: Standard execution, **SKIP code-review**
- ❌ PHASE 3.5: **SKIP error fixing loop**
- ✅ PHASE 4: Lightweight validation
- ✅ PHASE 5: Git workflow + summary

**Skills loaded:** ~8 skills (~300 lines)

**Example tasks:**
- Add method to existing service
- Fix typo in validation message
- Update configuration value

### Standard Complexity

**Characteristics:**
- Normal tasks (2-4 files, 3-6 steps)
- Well-defined solution
- Medium risk

**Customizations:**
- ✅ PHASE 0: Full context (LSP recommended, Context7 optional)
- ✅ PHASE 1: Use task-plan template
- ✅ PHASE 2: approval-gates (lite template)
- ✅ PHASE 3: Standard execution + code-review
- ✅ PHASE 3.5: Error fixing loop (if needed)
- ✅ PHASE 4: Full validation
- ✅ PHASE 5: Git workflow + optional PR automation

**Skills loaded:** ~10 skills (~400 lines)

**Example tasks:**
- Add new API endpoint
- Implement filtering feature
- Refactor service logic

### Complex Complexity

**Characteristics:**
- Complex tasks (5+ files, 7+ steps)
- Multiple approaches possible
- High risk or breaking changes

**Customizations:**
- ✅ PHASE 0: Full context (LSP + Context7 highly recommended)
- ✅ PHASE 1: Use task-plan template (extended with phases)
- ✅ PHASE 2: approval-gates (full template)
- ✅ PHASE 3: Ralph-loop recommended + code-review
- ✅ PHASE 3.5: Error fixing loop (if needed)
- ✅ PHASE 4: Comprehensive validation
- ✅ PHASE 5: Git workflow + PR automation recommended

**Skills loaded:** ~11 skills (~500 lines)

**Example tasks:**
- Database migration
- Authentication refactoring
- Multi-module feature implementation

---

## Data Flow

### PHASE 0 → PHASE 1

**Input:**
```json
{
  "project_context": {
    "language": "TypeScript",
    "framework": "FastAPI",
    "syntax_command": "tsc --noEmit",
    "test_command": "pytest",
    "prd_path": "docs/PRD.md"
  },
  "lsp_status": {
    "status": "READY",
    "plugins": ["typescript-lsp"],
    "servers": ["vtsls"]
  },
  "library_docs": {
    "loaded": true,
    "libraries": ["FastAPI", "Pydantic"]
  },
  "complexity": "standard"
}
```

**Output to PHASE 1:**
- structured-planning uses `syntax_command` для validation steps
- structured-planning uses `prd_path` для PRD alignment check
- structured-planning uses `library_docs` для enriching execution_steps с code examples
- structured-planning selects task-plan template based on `complexity`

### PHASE 1 → PHASE 1.5

**Input:**
```json
{
  "task_plan": {
    "task_name": "Add transaction filtering",
    "git": {
      "branch_name": "dev/transaction-filtering_20260126143022"
    }
  },
  "project_context": {
    "base_branch": "main"
  }
}
```

**Output to PHASE 1.5:**
- git-workflow uses `task_plan.git.branch_name` для создания ветки
- git-workflow uses `project_context.base_branch` (from CORE REQUIREMENTS #1) для checkout
- git-workflow creates branch BEFORE user approval and code changes

### PHASE 1.5 → PHASE 2

**Input:**
```json
{
  "git_branch_result": {
    "branch": "dev/transaction-filtering_20260126143022",
    "base_branch": "main",
    "switched": true
  },
  "task_plan": {
    "task_name": "Add transaction filtering",
    "execution_steps": [...],
    "acceptance_criteria": [...],
    "git": {...}
  },
  "complexity": "standard"
}
```

**Output to PHASE 2:**
- approval-gates uses `task_plan.task_name` для approval message
- approval-gates uses `execution_steps` count для approval template selection
- approval-gates **skips** if `complexity === "minimal"`

### PHASE 3 → PHASE 3.5

**Input:**
```json
{
  "code_review_results": {
    "passed": false,
    "blocking_issues": [
      {
        "category": "security",
        "severity": "BLOCKING",
        "file": "app.js",
        "line": 42,
        "message": "SQL injection vulnerability"
      }
    ],
    "warnings": [...]
  }
}
```

**Output to PHASE 3.5:**
- Error fixing loop **activates** if `blocking_issues.length > 0`
- pr-automation provides fix strategies from `rules/error-fixing-strategies.md`
- code-review re-runs after fixes
- **Exits** when `code_review.passed === true` OR max 2 iterations

### PHASE 4 → PHASE 5A

**Input:**
```json
{
  "validation_results": {
    "status": "PASSED",
    "validators": [...]
  },
  "task_plan": {
    "git": {
      "branch_name": "feature/transaction-filtering",
      "commit_type": "feat",
      "commit_summary": "add transaction filtering endpoint"
    }
  }
}
```

**Output to PHASE 5A:**
- git-workflow uses `task_plan.git` для commit message
- git-workflow stages files from `task_plan.files_to_change`
- git-workflow pushes to `task_plan.git.branch_name`

### PHASE 5A → PHASE 5B

**Input:**
```json
{
  "git_result": {
    "branch": "feature/transaction-filtering",
    "commit_hash": "abc123def",
    "pushed": true,
    "remote": "origin"
  }
}
```

**Output to PHASE 5B:**
- pr-automation uses `git_result.branch` для PR creation
- pr-automation creates PR from `git_result.branch` to `main`
- pr-automation monitors CI/CD checks
- pr-automation uses loop mode для auto-fixing CI failures

---

## Conditional Phases

### PHASE 2: Approval Gates

**Condition:** `complexity !== "minimal"`

**Logic:**
```javascript
if (complexity === "minimal") {
  // SKIP PHASE 2, proceed to PHASE 3
} else if (complexity === "standard") {
  // Use approval-gates → @template:approval-lite
} else if (complexity === "complex") {
  // Use approval-gates → @template:approval-full
}
```

**User responses:**
- `yes` → Proceed to PHASE 3
- `no` → Stop execution
- `modify` → Return to PHASE 1 for re-planning

### PHASE 3: Execution Mode

**Condition:** Task characteristics

**Ralph-Loop criteria (ALL must be true):**
1. ✅ Automatic validation available (tests/build/lint)
2. ✅ Multiple iterations expected (> 2 refinement cycles)
3. ✅ Clear completion promise detectable in validation output
4. ✅ Complexity = complex OR execution_steps > 5

**Otherwise:** Standard execution

### PHASE 3.5: Error Fixing Loop

**Condition:** `code_review_results.blocking_issues.length > 0` OR security warnings

**Logic:**
```javascript
if (code_review_results.blocking_issues.length > 0) {
  // Activate error fixing loop
  for (let iteration = 1; iteration <= 2; iteration++) {
    // Fix issues using strategies from pr-automation
    // Re-run code-review
    if (code_review.passed) {
      break; // Exit loop
    }
  }
}
```

**Max iterations:** 2 (prevent infinite loops)

### PHASE 5B: PR Automation

**Condition:** User approval via AskUserQuestion

**Question:**
```
Создать Pull Request для этих изменений?

Options:
1. Да, создать PR и мониторить CI/CD (Recommended)
2. Нет, только commit
```

**If "Да":**
- Execute full PR automation workflow
- Create draft PR
- Monitor CI/CD checks
- Auto-fix failures via loop mode
- Mark as ready when all checks pass

**If "Нет":**
- Skip to PHASE 5C (task summary)

---

## Safety Rules

### PHASE 3.5: Code Review Error Fixing

1. **NEVER introduce new bugs** while fixing
2. **ALWAYS re-run code-review** after fixes
3. **NEVER exceed max 2 iterations** (prevent infinite loops)
4. **ALWAYS preserve original logic** when fixing
5. **ONLY fix issues detected** by code-review (don't refactor)

### PHASE 5B: PR Automation

1. **NEVER auto-merge PR** (always human review)
2. **NEVER force push** to protected branches (main/master)
3. **NEVER commit secrets/credentials**
4. **ALWAYS use Conventional Commits** format
5. **ALWAYS wait for all checks** before marking ready
6. **NEVER use --no-verify** flag on commits

### General Workflow

1. **ALWAYS ask user** via AskUserQuestion before optional phases
2. **NEVER skip validation** after code changes
3. **ALWAYS log structured output** for each phase
4. **NEVER proceed** if approval-gates returns "no"
5. **ALWAYS rollback** if validation fails after max retries

---

## Project-Specific Customizations

### How Templates Override Universal Workflow

**Templates should:**
1. Reference this file: `@shared:WORKFLOW-SKILLS-UNIVERSAL.md`
2. Only document **deviations** from universal workflow
3. Add project-specific validation commands
4. Add project-specific git branch patterns (if different)

**Example template structure:**
```markdown
# Project Template Name

## Workflow
@shared:WORKFLOW-SKILLS-UNIVERSAL.md

### Project-Specific Additions

**PHASE 0:**
- Run custom pre-flight checks: `./scripts/preflight.sh`

**PHASE 4:**
- Additional validation: `npm run integration-tests`

**CORE REQUIREMENTS:**
1. Git branch pattern: `dev/<task_name>_<timestamp>` (override default)
2. Pre-flight checks: Check `/docs/architecture` exists
3. Finalization: Create PR to `test` branch (not `main`)
```

**What templates should NOT duplicate:**
- ❌ Full workflow diagram (use reference instead)
- ❌ Skills compatibility matrix (already in this file)
- ❌ Data flow between phases (already documented)
- ❌ Conditional phase logic (already documented)
- ❌ Safety rules (already documented)

---

## Skills Quick Reference Table

### skills-by-phase

**Compact table для templates:**

| Phase | Skill | Purpose |
|-------|-------|---------|
| 0 | context-awareness | Detect project context |
| 0 | lsp-integration | LSP plugin setup [optional] |
| 0 | context7-integration | Load library docs [optional] |
| 0 | adaptive-workflow | Determine complexity |
| 1 | thinking-framework | COT reasoning |
| 1 | structured-planning | Create task plan |
| 2 | approval-gates | User approval [conditional] |
| 3 | loop mode | Iterative execution [plugin] |
| 3 | code-review | Quality checks [conditional] |
| 3.5 | code-review (re-run) | Verify fixes [conditional] |
| 3.5 | pr-automation | Error fixing strategies [conditional] |
| 4 | validation-framework | Verify acceptance criteria |
| 4 | error-handling | Handle failures with retries |
| 4 | rollback-recovery | Rollback on exhausted retries |
| 5A | git-workflow | Commit with Conventional Commits |
| 5B | pr-automation | Create PR + CI/CD + auto-fix [optional] |
| 5C | git-workflow | Generate task summary |

**Note:** Все детальные templates, schemas и examples находятся в respective skills. Этот template только orchestration flow.

---

## Version History

### v1.0.0 (2026-01-25)

- ✅ Initial release
- ✅ Universal workflow (PHASE 0-5) diagram
- ✅ Skills compatibility matrix (17 skills)
- ✅ Complexity-based customization (minimal/standard/complex)
- ✅ Data flow documentation
- ✅ Conditional phases logic
- ✅ Safety rules
- ✅ Project template integration guide

---

**Автор:** Claude Code Team
**License:** MIT
**Support:** См. adaptive-workflow/SKILL.md для вопросов по complexity detection

---

## References

### Internal Resources

- **adaptive-workflow:** `@skill:adaptive-workflow` (complexity detection)
- **structured-planning:** `@skill:structured-planning` (orchestration)
- **approval-gates:** `@skill:approval-gates` (approval templates)
- **validation-framework:** `@skill:validation-framework` (validation logic)

### Project Templates

- **task-lite-clickhouse-v7.0.md**
- **task-lite-familybudget-v7.0.md**
- **task-lite-pihome-v7.0.md**
- **task-lite-vless-v7.0.md**

All templates reference this file для universal workflow.
