# Global Skills Documentation Hub

**Location:** `.nvm-isolated/.claude-isolated/skills/`
**Total Skills:** 22 global skills
**Last Updated:** 2026-01-23

---

## Overview

This directory contains **global skills** for Claude Code that provide reusable functionality across all projects. Skills are organized into 6 categories based on their purpose and scope.

**What are skills?**
- Modular, reusable components for Claude Code workflows
- Each skill has SKILL.md (documentation), templates/, schemas/, examples/
- Skills can depend on other skills (dependency graph)
- Skills can be user-invocable (via `/skill-name`) or system-only

**Global vs Project-Specific Skills:**
- **Global skills** (this directory): Universal skills used across all projects
- **Project-specific skills** (`.claude/skills/` in project): Domain-specific skills for particular technology stacks

---

## Quick Navigation

### By Category
1. [Core Skills](#core-skills) (4) - Essential workflow components
2. [Integration Skills](#integration-skills) (2) - External tool integrations
3. [Workflow Skills](#workflow-skills) (3) - Git, PR, and code review
4. [Utility Skills](#utility-skills) (4) - Supporting functionality
5. [Specialized Skills](#specialized-skills) (4) - Specific use cases
6. [Generator Skills](#generator-skills) (4) - Content and structure generation

### By Usage
- [Most Used Skills](#most-used-skills) (13/21 = 61.9%)
- [Unused Skills](#unused-skills) (8/21 = 38.1%)
- [User-Invocable Skills](#user-invocable-skills) (2/21)

---

## Token Efficiency: TOON Format Integration

**NEW:** 18 навыков поддерживают TOON формат для **60-75% token savings** в inter-skill коммуникации.

### What is TOON?

**TOON (Token-Oriented Object Notation)** - компактный формат данных для LLM промптов:
- **60-75% token savings** для табличных данных (exceeds expected 30-60%)
- **Lossless** двусторонняя JSON ↔ TOON конвертация
- **Hybrid approach**: JSON primary + TOON optimization (100% backward compatible)
- **Automatic generation**: Threshold >= 5 элементов

**Example Savings:**
- 5 items: 71.3% savings
- 10 items: 74.5% savings
- 20 items: 68.3% savings
- 50 items: 67.8% savings

### Skills с TOON Support

#### ✅ Complete (3 skills)

| Skill | Version | Arrays Converted | Token Savings | Status |
|-------|---------|------------------|---------------|--------|
| **toon-skill** | 1.0.0 | - (base skill) | - | ✅ API, docs, tests |
| **architecture-documentation** | 1.2.0 | components, dependency_graph | 42% | ✅ Producer |
| **validation-framework** | 2.1.0 | (consumer only) | N/A | ✅ Consumer |

#### 🔄 Planned (5 high-priority skills)

| Skill | Priority | Target Arrays | Expected Savings | ETA |
|-------|----------|---------------|------------------|-----|
| **code-review** | HIGH | warnings, lsp_diagnostics | 40-50% | Phase 1 |
| **structured-planning** | HIGH | execution_steps, files_to_change | 35-45% | Phase 1 |
| **pr-automation** | HIGH | checks, autoFixedErrors, commits | 35-45% | Phase 1 |
| **skill-generator** | HIGH | validation_results, files_created | 40-50% | Phase 1 |
| **prd-generator** | HIGH | sections, diagrams, features | 45-55% | Phase 1 |

#### 📋 Medium Priority (5 skills)

| Skill | Target Arrays | Expected Savings | ETA |
|-------|---------------|------------------|-----|
| phase-execution | checkpoint_validation_steps | 25-35% | Phase 4 |
| adaptive-workflow | complexity_factors, phase_recommendations | 20-30% | Phase 4 |
| git-workflow | commit_history, validation_checks | 20-30% | Phase 4 |
| approval-gates | approval_steps | 25-35% | Phase 4 |
| error-handling | error_logs | 30-40% | Phase 4 |

#### ❌ Not Applicable (9 skills)

Skills without arrays or with arrays < 5 elements:
- context-awareness, isolated-environment, proxy-management, context7-integration, lsp-integration, thinking-framework, task-decomposition, rollback-recovery, commit-and-push

### How to Use TOON

**For Skill Developers:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Step 1: Generate JSON (always)
const output = { warnings: [...] };

// Step 2: Add TOON (if >= 5 elements)
if (output.warnings.length >= 5) {
  output.toon = {
    warnings_toon: arrayToToon('warnings', output.warnings,
      ['category', 'file', 'line', 'severity', 'message']),
    token_savings: calculateTokenSavings({ warnings: output.warnings }).savedPercent
  };
}

return output;
```

**For Skill Consumers:**

```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

// Strategy 1: Always use JSON (safest, backward compatible)
const warnings = upstreamOutput.warnings;

// Strategy 2: Prefer TOON if available (token efficient)
const warnings = upstreamOutput.toon?.warnings_toon
  ? toonToJson(upstreamOutput.toon.warnings_toon).warnings
  : upstreamOutput.warnings;
```

### Resources

- **Base Skill**: [toon-skill/SKILL.md](./toon-skill/SKILL.md) - API reference
- **Patterns**: [_shared/TOON-PATTERNS.md](./_shared/TOON-PATTERNS.md) - Integration patterns
- **API Docs**: [toon-skill/converters/README.md](./toon-skill/converters/README.md)
- **Examples**: [toon-skill/examples/](./toon-skill/examples/) - Integration guide

### Aggregate Savings

**Workflow Example (Complex Task):**
- structured-planning: 10 steps → 38% savings
- code-review: 15 warnings + 20 LSP diagnostics → 43% savings
- pr-automation: 8 checks + 15 commits → 40% savings

**Total Token Reduction: ~45%** in full workflow

**Context Window Benefits:**
- More space for code and reasoning
- Reduced API costs
- Faster LLM processing

---

## Core Skills

**Purpose:** Essential components for task execution workflow

These skills are **required** for Template-based workflows and provide foundational capabilities.

| Skill | Version | Description | Dependencies | User-Invocable |
|-------|---------|-------------|--------------|----------------|
| **adaptive-workflow** | 2.0.0 | Автоматический выбор сложности workflow (minimal/standard/complex) | context-awareness, task-decomposition, phase-execution | ❌ |
| **thinking-framework** | 1.0.0 | Структурированный reasoning через 3 универсальных шаблона (analysis/decision/risk) | - | ❌ |
| **structured-planning** | 2.2.0 | Создание планов задач с адаптивной JSON Schema (lite/full) | thinking-framework, adaptive-workflow, skill-generator, prd-generator | ❌ |
| **validation-framework** | 1.0.0 | Адаптивная валидация с partial validation | - | ❌ |

**Why Core:**
- adaptive-workflow: Determines task complexity → selects appropriate workflow mode
- thinking-framework: Provides structured reasoning for analysis, decisions, and risk assessment
- structured-planning: Generates task plans with JSON schemas based on complexity
- validation-framework: Validates execution results and detects errors

**Usage in Template:**
```
PHASE 0: adaptive-workflow determines complexity
PHASE 1: thinking-framework provides analysis → structured-planning creates task_plan
PHASE 5: validation-framework validates execution results
```

---

## Integration Skills

**Purpose:** Integrate Claude Code with external tools and services

These skills are **optional** and depend on external dependencies (LSP servers, MCP plugins).

| Skill | Version | Description | External Dependency | User-Invocable |
|-------|---------|-------------|---------------------|----------------|
| **lsp-integration** | 1.0.0 | Автоматическая установка LSP plugins для 11+ языков (TypeScript, Python, Go, etc.) | LSP servers (pyright, @vtsls/language-server, gopls, etc.) | ❌ |
| **context7-integration** | 1.0.0 | Автоматическая загрузка library docs через Context7 MCP plugin | Context7 MCP server | ❌ |

**Why Integration:**
- Enhance code intelligence with Language Server Protocol (go-to-definition, type checking)
- Load official library documentation for code examples and best practices

**External Dependencies:**
- **LSP servers:** `npm install -g pyright @vtsls/language-server`, `go install golang.org/x/tools/gopls@latest`
- **Context7 MCP:** See [External Dependencies Guide](./_shared/external-dependencies.md#context7-mcp-plugin)

**Usage in Template:**
```
PHASE 0: lsp-integration checks LSP plugin availability
         context7-integration loads library_docs (if available)
PHASE 3: code-review uses lsp_status for type checking
         structured-planning uses library_docs for code examples
```

**Graceful degradation:** Template works without these skills (fallback to basic mode)

---

## Workflow Skills

**Purpose:** Manage git, PR creation, and code review processes

These skills are **essential for git workflows** and PR automation.

| Skill | Version | Description | Dependencies | User-Invocable |
|-------|---------|-------------|--------------|----------------|
| **git-workflow** | 1.0.0 | Стандартизированный git workflow с Conventional Commits | - | ❌ |
| **pr-automation** | 1.3.0 | Автоматизация создания PR с мониторингом CI/CD (external loop tool для auto-fix) | git-workflow | ❌ |
| **code-review** | 1.0.0 | Автоматический review кода перед commit (security, quality, complexity) | - | ❌ |

**Why Workflow:**
- git-workflow: Standardized git commits with Conventional Commits format
- pr-automation: Create PR, monitor CI checks, auto-fix test failures
- code-review: Pre-commit code quality checks (security, complexity, duplicates)

**Usage in Template:**
```
PHASE 4: git-workflow creates commit with Conventional Commits message
PHASE 4: pr-automation creates PR → monitors CI/CD → manual or external loop tool for auto-fix
PHASE 3: code-review validates code quality during execution
```

**Key Features:**
- **git-workflow:** Conventional Commits (feat, fix, refactor), Co-Authored-By tag
- **pr-automation:** CI/CD monitoring, external loop tool support for auto-fix, draft → ready flow
- **code-review:** Security checks (SQL injection, XSS), complexity analysis, duplicate detection

---

## Utility Skills

**Purpose:** Supporting functionality for error handling, rollback, and approvals

These skills are **helpers** for other workflow skills.

| Skill | Version | Description | Dependencies | User-Invocable |
|-------|---------|-------------|--------------|----------------|
| **toon-skill** | 1.0.0 | Централизованный API для конвертации JSON ↔ TOON (60-75% token savings) | @toon-format/toon | ❌ |
| **context-awareness** | 1.0.0 | Автоматическое определение контекста проекта (language, framework, PRD) | - | ❌ |
| **error-handling** | 1.0.0 | Структурированная обработка ошибок workflow | - | ❌ |
| **rollback-recovery** | 1.0.0 | Механизм отката при критических ошибках | - | ❌ |
| **approval-gates** | 1.0.0 | Упрощённые approval gates для подтверждения плана | - | ❌ |

**Why Utility:**
- toon-skill: Centralized TOON converter API → eliminates code duplication across skills, provides token savings metrics
- context-awareness: Detects project language, framework, existing docs → pre-fills questionnaires
- error-handling: Structured error handling with retry logic and graceful degradation
- rollback-recovery: Checkpoint creation and rollback on critical failures
- approval-gates: User approval prompts for task plans (conditional on complexity)

**Usage in Template:**
```
PHASE 0: context-awareness detects project context
PHASE 2: approval-gates requests user approval (for standard/complex tasks)
PHASE 3: error-handling manages execution errors
PHASE 3: rollback-recovery restores checkpoint on critical failure
```

---

## Specialized Skills

**Purpose:** Skills for specific use cases (bash development, isolated environment, architecture docs, proxy)

These skills are **optional** and used for specialized tasks.

| Skill | Version | Description | Dependencies | User-Invocable |
|-------|---------|-------------|--------------|----------------|
| **bash-development** | 1.0.0 | Разработка и рефакторинг bash-функций для init_claude.sh | - | ❌ |
| **isolated-environment** | 1.0.0 | Управление изолированной установкой NVM и Claude Code в .nvm-isolated/ | - | ❌ |
| **architecture-documentation** | 1.0.0 | Генерация архитектурной документации в YAML формате | - | ❌ |
| **proxy-management** | 1.0.0 | Настройка, тестирование и отладка HTTP/HTTPS/SOCKS5 прокси для Claude Code | - | ❌ |

**Why Specialized:**
- bash-development: Used for iclaude.sh development (refactoring bash functions)
- isolated-environment: Manages .nvm-isolated/ (NVM, Node.js, Claude Code installation)
- architecture-documentation: Generates YAML docs for large projects (component dependencies)
- proxy-management: Configures proxy for Claude Code (HTTP/HTTPS/SOCKS5)

**When to use:**
- bash-development: When refactoring iclaude.sh or adding new bash functions
- isolated-environment: During iclaude setup or repair (--isolated-install, --repair-isolated)
- architecture-documentation: For large codebases requiring architectural overview
- proxy-management: When setting up proxy (--proxy flag in iclaude.sh)

**Note:** These skills are NOT used in Template workflows (project-specific use cases only)

---

## Generator Skills

**Purpose:** Generate content, structures, and decompose tasks

These skills are **content creators** that generate documentation, skills, and task plans.

| Skill | Version | Description | Dependencies | User-Invocable |
|-------|---------|-------------|--------------|----------------|
| **skill-generator** | 1.0.0 | Автоматизированное создание новых скиллов с интерактивными вопросами, генерацией templates, schemas и валидацией | thinking-framework, structured-planning, validation-framework | ✅ |
| **prd-generator** | 1.0.0 | Автоматизированное создание PRD (14 разделов + 5 Mermaid диаграмм) с интерактивными вопросами | thinking-framework, context-awareness, validation-framework | ✅ |
| **task-decomposition** | 1.0.0 | Разбиение задачи на 2-5 логических фаз с генерацией master plan и phase files | adaptive-workflow, structured-planning | ❌ |
| **phase-execution** | 1.0.0 | Автоматизация выполнения одной фазы из phase file с checkpoint validation и structured output | task-decomposition, rollback-recovery, validation-framework | ❌ |

**Why Generator:**
- skill-generator: Creates new skills interactively (SKILL.md, templates, schemas, examples)
- prd-generator: Creates Product Requirements Documents (14 sections + diagrams)
- task-decomposition: Breaks complex tasks into 2-5 manageable phases
- phase-execution: Executes individual phases with checkpoints and validation

**User-Invocable:**
- `/skill-generator` - Create new skill interactively
- `/prd-generator` - Create PRD interactively

**Integration with Core:**
- adaptive-workflow triggers task-decomposition for complex tasks (complexity = "complex")
- structured-planning recommends skill-generator for missing domain skills
- structured-planning recommends prd-generator for complex tasks without PRD

**Usage in Template:**
```
PHASE 0: adaptive-workflow determines complexity = "complex"
         → task-decomposition creates master_plan + phase files

FOR EACH phase:
  → phase-execution executes phase → checkpoint → validation

PHASE 1: structured-planning recommends /skill-generator (if domain skill missing)
PHASE 1: structured-planning recommends /prd-generator (if 5+ features, no PRD)
```

---

## Most Used Skills

**13 out of 21 skills (61.9%)** are actively used in Template workflows.

1. ✅ **adaptive-workflow** - Complexity detection (minimal/standard/complex)
2. ✅ **approval-gates** - User approval for task plans
3. ✅ **code-review** - Pre-commit code quality checks
4. ✅ **context7-integration** - Library documentation loading (optional)
5. ✅ **context-awareness** - Project context detection
6. ✅ **error-handling** - Structured error handling
7. ✅ **git-workflow** - Conventional Commits
8. ✅ **lsp-integration** - LSP plugins for code intelligence (optional)
9. ✅ **pr-automation** - PR creation + CI/CD monitoring
10. ✅ **rollback-recovery** - Checkpoint and rollback
11. ✅ **structured-planning** - Task plan generation
12. ✅ **thinking-framework** - Structured reasoning
13. ✅ **validation-framework** - Execution validation

**Coverage:** Template-based workflows use all Core, Integration, Workflow, and Utility skills.

---

## Unused Skills

**8 out of 21 skills (38.1%)** are NOT used in Template workflows.

These skills are available but serve specialized purposes:

1. ❌ **architecture-documentation** - Generate architectural docs (used for large projects only)
2. ❌ **bash-development** - Bash function development (used for iclaude.sh development)
3. ❌ **isolated-environment** - Manage .nvm-isolated/ (used during iclaude setup)
4. ❌ **phase-execution** - Execute individual phases (integrated with task-decomposition, not standalone)
5. ❌ **prd-generator** - Create PRD (user-invocable, recommended by structured-planning)
6. ❌ **proxy-management** - Proxy configuration (used for iclaude.sh proxy setup)
7. ❌ **skill-generator** - Create skills (user-invocable, recommended by structured-planning)
8. ❌ **task-decomposition** - Decompose complex tasks (integrated with adaptive-workflow for complex tasks)

**Recommendation:**
- **Integrate unused skills:** task-decomposition ✅ DONE (v2.0.0), skill-generator ✅ DONE (v2.1.0), prd-generator ✅ DONE (v2.2.0)
- **Keep specialized skills as-is:** bash-development, isolated-environment, architecture-documentation, proxy-management (project-specific use cases)

---

## User-Invocable Skills

**2 out of 21 skills (9.5%)** can be invoked directly by users via `/skill-name`.

| Skill | Command | Purpose | When to Use |
|-------|---------|---------|-------------|
| **skill-generator** | `/skill-generator` | Create new skill interactively (8-9 questions, auto-generate templates/schemas) | When creating domain-specific skills for project (e.g., fastapi-development) |
| **prd-generator** | `/prd-generator` | Create PRD interactively (12 questions, 14 sections + 5 diagrams) | For complex tasks with 5+ features, new product development |

**How to use:**
```bash
# Inside Claude Code session
/skill-generator
# Answer 8 questions → skill created in .claude/skills/

/prd-generator
# Answer 12 questions → PRD created in docs/prd/
```

**Auto-invocation triggers:**
- skill-generator: Recommended by structured-planning when domain skill missing
- prd-generator: Recommended by structured-planning for complex tasks without PRD

---

## Skill Dependencies Graph

Visual representation of skill dependencies (simplified):

```
Core Layer:
  thinking-framework (no deps)
  validation-framework (no deps)
  context-awareness (no deps)
    ↓
  adaptive-workflow → [context-awareness, task-decomposition, phase-execution]
    ↓
  structured-planning → [thinking-framework, adaptive-workflow, skill-generator, prd-generator]

Integration Layer:
  lsp-integration (no deps)
  context7-integration (no deps)

Workflow Layer:
  git-workflow (no deps)
  code-review (no deps)
  pr-automation → [git-workflow]

Utility Layer:
  error-handling (no deps)
  rollback-recovery (no deps)
  approval-gates (no deps)

Generator Layer:
  skill-generator → [thinking-framework, structured-planning, validation-framework]
  prd-generator → [thinking-framework, context-awareness, validation-framework]
  task-decomposition → [adaptive-workflow, structured-planning]
  phase-execution → [task-decomposition, rollback-recovery, validation-framework]

Specialized Layer:
  bash-development (no deps)
  isolated-environment (no deps)
  architecture-documentation (no deps)
  proxy-management (no deps)
```

**Circular dependency check:** ✅ No circular dependencies detected

---

## External Dependencies

Some skills require external tools to function:

### LSP Servers (for lsp-integration)
- **TypeScript/JavaScript:** `npm install -g @vtsls/language-server`
- **Python:** `npm install -g pyright`
- **Go:** `go install golang.org/x/tools/gopls@latest`
- **Rust:** `rustup component add rust-analyzer`

See [lsp-integration/SKILL.md](./lsp-integration/SKILL.md) for full list of 11+ languages.

### MCP Servers (for context7-integration)
- **Context7 MCP:** Load official library documentation (FastAPI, React, pandas, etc.)
- Installation: See [External Dependencies Guide](./_shared/external-dependencies.md#context7-mcp-plugin)

### External Loop Tools
- **Bash Loop Mode:** External tool for iterative task execution (NOT a skill)
- **Usage:** `./iclaude.sh --loop task.md` (sequential) or `./iclaude.sh --loop-parallel task.md` (parallel)
- **Documentation:** See [Loop Mode Documentation](../../CLAUDE.md#loop-mode-commands) and [Migration Guide](../../MIGRATION-GUIDE.md)

---

## Skill File Structure

Each skill follows this standard structure:

```
skills/{skill-name}/
├── SKILL.md                  # Main documentation (YAML frontmatter + Markdown)
├── templates/                # JSON templates (input, output, config, etc.)
│   ├── input.json
│   ├── output.json
│   └── ...
├── schemas/                  # JSON Schemas (auto-generated from templates)
│   ├── input.schema.json
│   ├── output.schema.json
│   └── ...
├── examples/                 # Usage examples
│   ├── basic-usage.md
│   └── ...
└── rules/                    # Best practices and conventions (optional)
    └── recommendations.md
```

**SKILL.md sections (standard):**
1. YAML frontmatter (name, version, dependencies, tags, etc.)
2. When to Use
3. How It Works
4. Output Format
5. Templates
6. Schemas
7. Examples
8. Workflow Integration

---

## Shared Resources

**Location:** `.nvm-isolated/.claude-isolated/skills/_shared/`

Shared resources used across multiple skills:

| Resource | Purpose | Used By |
|----------|---------|---------|
| **frontmatter-parser.md** | YAML frontmatter parsing and validation | skill-generator, structured-planning, validation-framework, context-awareness, adaptive-workflow |
| **base-schema.json** | Base JSON Schema definitions (git, file_change, code_review_issue, test_result, execution_step) | structured-planning, pr-automation, git-workflow, code-review, validation-framework |
| **markdown-templates.md** | Standard Markdown output templates | structured-planning, git-workflow, pr-automation, code-review |
| **external-dependencies.md** | External dependencies guide (Context7 MCP, LSP servers, gh CLI, git) | All skills referencing external tools |

**Why Shared:**
- Avoid duplication (DRY principle)
- Centralized validation logic
- Consistent JSON schemas
- Uniform Markdown formatting

---

## How to Create New Skills

**For global skills (universal across projects):**
1. Use `/skill-generator` inside Claude Code session
2. Select target location: "iclaude global" (`.nvm-isolated/.claude-isolated/skills/`)
3. Answer 8-9 interactive questions
4. Customize generated templates and examples
5. Commit to iclaude repository

**For project-specific skills (domain-specific):**
1. Use `/skill-generator` inside project directory
2. Select target location: "Current project" (`.claude/skills/`)
3. Answer questions (e.g., skill name: `fastapi-development`)
4. Customize for project's tech stack
5. Commit to project repository

**Example: Create fastapi-development skill**
```bash
# Inside Family Budget project
/skill-generator

Q1: Skill name? → fastapi-development
Q2: Skill type? → system
Q3: Description? → FastAPI REST API development patterns
Q4: Dependencies? → api-development, validation-framework
Q5: Complexity levels? → No
Q6: Output format? → JSON
Q7: Templates? → endpoint, pydantic-model, test
Q8: Features? → examples, rules

# Generated:
✅ .claude/skills/fastapi-development/SKILL.md
✅ .claude/skills/fastapi-development/templates/*.json
✅ .claude/skills/fastapi-development/schemas/*.schema.json
✅ .claude/skills/fastapi-development/examples/basic-crud.md
✅ .claude/skills/fastapi-development/rules/fastapi-best-practices.md
```

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-15 | 1.0.0 | Initial Skills Documentation Hub created |
|  |  | - Categorized 21 global skills into 6 categories |
|  |  | - Documented most used (13) and unused (8) skills |
|  |  | - Added dependency graph and external dependencies |
|  |  | - Created shared resources section |

---

## Maintenance

**Updating this README:**
- When adding new global skill: Add to appropriate category table
- When skill version changes: Update version in table
- When skill dependencies change: Update dependency graph
- When external dependencies change: Update External Dependencies section

**Validation:**
- Run `validate-template-skills.sh` to check skill references in Template files
- Check for circular dependencies before adding new skill dependencies

**Related Files:**
- [skills-coverage-matrix.md](../../skills-coverage-matrix.md) - Skills usage in Template
- [validate-template-skills.sh](../../validate-template-skills.sh) - Validation script
- [External Dependencies Guide](./_shared/external-dependencies.md) - External tools and plugins

---

**Maintainer:** iclaude Skills Team
**Contact:** See iclaude repository for contributions
