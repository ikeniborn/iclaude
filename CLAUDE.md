# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Rules

**1. Multi-Perspective Analysis**

При решении любой задачи рассматривай проблему с точки зрения:
- **Системный архитектор**: Инфраструктурные решения, масштабируемость, отказоустойчивость
- **Frontend разработчик**: UX/UI эффективность, производительность клиента, доступность
- **Backend разработчик**: Оптимальная обработка данных, нагрузка на ресурсы, эффективность API
- **Security специалист**: Потенциальные уязвимости, защита данных, соответствие best practices
- **Технический писатель**: Актуальность и корректность документации, синхронизация с кодом

**2. Validation Loop**

После разработки решения:
- Проводить повторную проверку архитектурных решений
- Верифицировать соответствие требованиям из всех перспектив
- Использовать инструменты валидации на соответствующих этапах:
  - PHASE 0: LSP diagnostics (TypeScript/Python)
  - PHASE 3: Code review (@skill:code-review)
  - PHASE 4: Tests (pytest, npm test)

**See also:** `@skill:iclaude-validation` for complete validation framework

---

## Project Overview

**iclaude** is a bash-based wrapper script for launching Claude Code with automatic HTTP/HTTPS proxy configuration. It provides both isolated (portable) and system-wide installation modes, with secure credential storage and automatic environment setup.

### Key Features
- Dual installation modes: isolated (`.nvm-isolated/`) and system-wide
- Automatic proxy configuration with credential persistence
- Version locking via lockfile for reproducible deployments
- Isolated configuration to prevent conflicts between installations
- Domain-to-IP resolution for proxy URLs
- TLS certificate support for HTTPS proxies
- **Automatic OAuth token refresh** using `claude setup-token` (long-lived ~1 year tokens)
- **Claude Code Router integration** for alternative LLM providers (OpenRouter, DeepSeek, Ollama, Gemini)

---

## Skills Reference

For detailed documentation, see project-specific skills in `.claude/skills/`:

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `@skill:iclaude-validation` | Multi-perspective analysis + validation loop | Auto-invoked when working on iclaude.sh |
| `@skill:iclaude-commands` | CLI commands reference (8 categories) | When user asks about --flags or commands |
| `@skill:iclaude-architecture` | Code architecture (9 components + critical functions) | When planning where to add functionality |
| `@skill:iclaude-best-practices` | Best practices, pitfalls, debugging | When reviewing code or troubleshooting |

**Quick examples:**

```bash
# Development Commands - see @skill:iclaude-commands
./iclaude.sh --test                    # Test proxy
./iclaude.sh --isolated-install        # Install isolated environment
./iclaude.sh --check-isolated          # Show versions/symlinks/lockfile

# Code Architecture - see @skill:iclaude-architecture
# Component 1: Proxy Management (lines 1343-1666)
# Component 7: OAuth Token Management (lines 2749-2874)

# Best Practices - see @skill:iclaude-best-practices
# ✅ Use HTTPS proxy (preserves domains for OAuth)
# ❌ Don't use SOCKS5 (crashes undici)
# ✅ Run --repair-isolated after git clone
```

---

## File Structure

```
.
├── iclaude.sh                          # Main wrapper script (3325 lines)
├── .claude_proxy_credentials           # Encrypted proxy credentials (chmod 600, not in git)
├── .nvm-isolated/                      # Isolated NVM environment (~278MB, in git)
│   ├── nvm.sh                         # NVM installation script
│   ├── versions/node/v18.20.8/        # Node.js installation
│   │   ├── bin/                       # Binaries (npm, npx, node, claude)
│   │   └── lib/node_modules/          # Global npm packages
│   ├── npm-global/                    # Global npm packages
│   └── .claude-isolated/              # Isolated Claude configuration
│       ├── history.jsonl              # Command history
│       ├── session-env/               # Active sessions
│       ├── .credentials.json          # Anthropic credentials
│       ├── settings.json              # User settings
│       ├── skills/                    # Claude Code skills (global)
│       └── projects/                  # Project-specific configs
├── .claude/                           # Project-specific configuration
│   └── skills/                        # iclaude-specific skills
│       ├── iclaude-validation/        # Validation framework
│       ├── iclaude-commands/          # CLI commands reference
│       ├── iclaude-architecture/      # Code architecture
│       └── iclaude-best-practices/    # Best practices
├── .nvm-isolated-lockfile.json        # Version lockfile (in git)
└── README.md                          # User documentation
```

### Files NOT in Git

- `.claude_proxy_credentials` - Contains sensitive proxy credentials
- `.nvm-isolated/.cache/` - NPM cache
- `.nvm-isolated/.npm/` - NPM temporary files
- `.nvm-isolated/.claude-isolated/*` - Session data (except skills/ and CLAUDE.md)

---

## Security Considerations

1. **Credential Storage**: `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion**: Credentials never committed to git (see .gitignore)
3. **Password Display**: Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy**: Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust**: Only use trusted proxy servers (MitM risk)

**See also:** `@skill:iclaude-best-practices` for detailed security guidelines

---

## Integration with Claude Code Skills

The repository includes a Skills system in `.nvm-isolated/.claude-isolated/skills/` (global) and `.claude/skills/` (project-specific).

**When developing iclaude.sh:**
- Use `structured-planning` skill for breaking down complex features
- Use `git-workflow` skill for commit message generation
- Use `validation-framework` skill for testing new features
- Use `@skill:iclaude-validation` for multi-perspective analysis

**See README.md for full Skills documentation.**

---

# Task Execution

**Назначение:** Адаптивный workflow с SGR + Structured Output и lazy-loading skills

**Проект:** IClaude

---

## Задачи

[User input]

**CORE REQUIREMENTS:**

1. **Pre-flight:** Изучить docs/architecture перед началом
2. **Clarification:** При планировании задавать уточняющие вопросы
3. **Documentation:** Актуализировать docs/architecture после изменений
4. **Progress Tracking:** Для non-trivial tasks использовать TaskCreate/TaskUpdate для visibility и recovery

---

## Execution Flow

### High-Level Orchestration

```
PHASE 0 → Context & Complexity Assessment
   @skill:context-awareness → {project_context}
   @skill:iclaude-validation → {multi_perspective_analysis, validation_plan} [if bash-wrapper]
   @skill:lsp-integration → {lsp_status} [optional]
   @skill:context7-integration → {library_docs} [optional]
   @skill:adaptive-workflow → {complexity, workflow_mode}
      ├─ v2.0.0: Auto-triggers @skill:task-decomposition for complex tasks

PHASE 1 → Analysis & Planning
   @skill:thinking-framework → COT reasoning
   @skill:structured-planning → {task_plan}

   📋 Task Creation [for non-trivial tasks]
      ├─ Use TaskCreate for each execution step from plan
      ├─ Set subject (imperative), description, activeForm (present continuous)
      └─ Track progress: TaskUpdate → in_progress/completed

PHASE 2 → Approval [conditional: skip if minimal]
   @skill:approval-gates → {user_approval}

PHASE 3 → Execution [mode selected by adaptive-workflow]
   Execute using domain skills
      ├─ TaskUpdate → in_progress (перед началом каждого task)
      ├─ @skill:code-review → {review}
      ├─ @skill:error-handling
      ├─ @skill:rollback-recovery [on critical errors]
      └─ TaskUpdate → completed (после завершения task)

PHASE 4 → Git & PR Automation
   @skill:git-workflow → {commit}
   @skill:pr-automation → {pr}

PHASE 5 → Summary
   @skill:git-workflow → @template:task-summary
```

---

### Task Management Tools

**Built-in Claude Code tools для progress tracking:**

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **TaskCreate** | Create task with subject, description, activeForm | PHASE 1 (после structured-planning для non-trivial tasks) |
| **TaskUpdate** | Update status (in_progress/completed) | PHASE 3 (перед началом и после завершения каждого task) |
| **TaskList** | View all tasks and progress | Проверка overall progress, поиск next task |
| **TaskGet** | Get full task details by ID | Получение context перед началом task |

**Criteria для использования:**
- ✅ Non-trivial tasks (>= 3 execution steps)
- ✅ Complex tasks requiring multiple phases
- ✅ Tasks где user хочет видеть progress
- ❌ Trivial one-step tasks

### Workflow Skills (Universal)

| Phase | Skill | Purpose | Details |
|-------|-------|---------|---------|
| 0 | context-awareness | Detect project context | См. skill |
| 0 | iclaude-validation | Multi-perspective + validation [if bash-wrapper] | См. skill |
| 0 | adaptive-workflow v2.0.0 | Determine complexity + task-decomposition | См. skill |
| 0 | lsp-integration | LSP integration [optional] | См. skill |
| 0 | context7-integration | Library docs [optional] | См. skill |
| 1 | thinking-framework | COT reasoning (3 templates) | См. skill |
| 1 | structured-planning v2.2.0 | Task plan + skill/prd-generator | См. skill |
| 2 | approval-gates | User approval [conditional] | См. skill |
| 3 | code-review | Quality + security checks | См. skill |
| 3 | error-handling | Failure handling | См. skill |
| 3 | rollback-recovery | Critical error rollback | См. skill |
| 4 | git-workflow | Branch, commit, summary | См. skill |
| 4 | pr-automation | PR + CI/CD + auto-fix | См. skill |

---

## Key Principles

**SGR (Structured Generation & Reasoning):**
- Thinking → Structured Output → Execute → Validate → Commit

**Progress Tracking:**
- Non-trivial tasks создают tasks via TaskCreate (PHASE 1)
- Each task marked as in_progress перед началом (PHASE 3)
- Each task marked as completed после завершения (PHASE 3)
- User видит progress via `/tasks` command

**Adaptive Workflow:**
- Complexity определяет workflow mode (см. @skill:adaptive-workflow)
- Auto-skip unnecessary phases
- Lazy loading skills

**Separation of Concerns:**
- **Template** = Orchestration flow только
- **Skills** = Вся реализационная логика, templates, schemas, safety rules
- **Project CLAUDE.md** = Project-specific commands, patterns, conventions

**Data Flow:**
- PHASE N output → PHASE N+1 input
- Structured artifacts между phases
- Dependencies: см. individual skills

---
