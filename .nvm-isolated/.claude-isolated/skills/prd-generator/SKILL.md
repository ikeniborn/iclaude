---
name: prd-generator
description: Автоматизированное создание Product Requirements Document (PRD) с интерактивными вопросами, AI-генерацией 14 разделов и 5 Mermaid диаграмм
version: 1.0.0
tags: [documentation, prd, product-management, mermaid, interactive, ai-generation]
dependencies: [thinking-framework, context-awareness, validation-framework]
author: iclaude Skills Team
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  rules: ./rules/*.md
user-invocable: true
---

# PRD Generator Skill

Автоматизированное создание Product Requirements Document (PRD) в структурированном формате Markdown с Mermaid диаграммами.

## Назначение

Создание comprehensive PRD документации в каталоге `docs/prd/` проекта. Скилл генерирует 14 разделов + 5 Mermaid диаграмм на основе интерактивного сбора требований.

## Когда использовать

**Используйте этот скилл когда:**
- Необходимо создать PRD для нового продукта/фичи с нуля
- Требуется обновить существующий PRD с новыми требованиями
- Нужна структурированная документация требований к продукту
- Требуются Mermaid диаграммы (product vision, user journey, system context, feature dependencies, roadmap)

**Ручной вызов:**
```
/prd-generator
```

**Auto-invocation triggers:**
- "Создай PRD для {product_name}"
- "Обнови PRD с новыми требованиями"
- "Сгенерируй Product Requirements Document"

## Как работает

Скилл выполняет 7 последовательных фаз для создания полной PRD документации.

### PHASE 0: Initialization & Context Detection

**Цель:** Определить режим работы (create/update) и загрузить контекст проекта

**Действия:**
1. Вызвать `@skill:context-awareness` для получения:
   - Название проекта, тип, tech stack
   - Существующая документация
   - Рабочая директория
2. Проверить существование `docs/prd/` directory:
   - Если существует → **UPDATE** режим (читаем README.md, определяем существующие секции)
   - Если НЕ существует → **CREATE** режим
3. Сохранить контекст для предзаполнения questionnaire:
   - Q1 (Product Name) ← `project_name`
   - Q8 (Tech Stack) ← `tech_stack`

**Thinking block:**
```xml
<thinking type="analysis">
ЗАДАЧА: Создать/обновить PRD для проекта {project_name}
КОНТЕКСТ: {project_type}, существующие секции: {existing_sections}
КОМПОНЕНТЫ: 14 markdown разделов + 5 Mermaid диаграмм + README.md
РЕЖИМ: {CREATE|UPDATE}
ACCEPTANCE CRITERIA:
  - Все 14 разделов заполнены AI-контентом
  - Все 5 диаграмм валидны (Mermaid syntax)
  - Навигация README.md корректна
  - UPDATE: пользовательские изменения сохранены
ВЫВОДЫ: {next_phase}
</thinking>
```

**Exit conditions:**
- ✓ Контекст определен (`project_name`, `project_type`, `tech_stack`)
- ✓ Режим установлен (`CREATE` или `UPDATE`)
- ✓ Целевая директория идентифицирована

---

### PHASE 1: Interactive Questionnaire

**Цель:** Собрать требования через 12 структурированных вопросов

**Questionnaire (via AskUserQuestion):**

**Q1: Product Name** (pre-filled from context)
- Validation: 3-100 chars
- Can be edited by user

**Q2: Product Type**
- Options: `SaaS | Mobile App | Desktop Application | API/Platform | Hardware + Software | Other`
- Determines default features and architecture templates

**Q3: Target Audience** (1-3 segments)
- Validation: 20-300 chars
- Example: "B2B SaaS для маркетологов, B2C мобильное приложение для студентов"
- Used for §4 Target Audience generation

**Q4: Business Goals** (2-5 SMART goals)
- Format: comma-separated
- Example: "Увеличить MRR на 30%, Снизить churn до 5%, Привлечь 1000 пользователей за 6 месяцев"
- Used for §2 Goals and Scope, §5 Business Requirements

**Q5: Success Metrics** (KPIs)
- Format: comma-separated
- Default: `["MAU", "Conversion rate", "Revenue"]`
- Example: "MAU, Conversion rate, NPS, ARR, Time to value"
- Used for §2 Goals and Scope

**Q6: Core Features** (3-15 features)
- Format: comma-separated
- Validation: min 3, max 15 features
- Example: "User authentication, Dashboard analytics, Real-time notifications, Export reports"
- Used for §6 Functional Requirements + feature breakdown

**Q7: User Scenarios** (2-5 scenarios)
- Format: comma-separated
- Validation: min 2 scenarios
- Example: "Регистрация нового пользователя, Создание отчета, Интеграция с внешним сервисом"
- Used for §6 User Scenarios

**Q8: Tech Stack** (pre-filled from context)
- Format: "Frontend: React, Backend: Node.js, Database: PostgreSQL"
- Can be edited
- Used for §9 Technical Requirements

**Q9: Integrations** (optional)
- Format: comma-separated
- Example: "Stripe (payments), SendGrid (email), Google Analytics"
- Used for §9 Integrations

**Q10: Timeline/Roadmap** (2-5 phases)
- Format: "MVP (Q1 2025), Beta (Q2 2025), Public Launch (Q3 2025)"
- Validation: min 2, max 5 phases
- Used for §10 Roadmap + roadmap-timeline.mmd diagram

**Q11: Known Risks** (optional)
- Format: comma-separated
- Example: "Зависимость от third-party API, Сложная миграция данных"
- Used for §11 Risks

**Q12: Target Directory** (default: `docs/prd/`)
- Validation: valid path
- Will be created if doesn't exist

**Validation:**
- **Required:** Q1-Q7, Q10, Q12
- **Optional:** Q9, Q11
- **Retry:** max 3 attempts при невалидном вводе
- **After 3 failures:** skip (if optional) или use default value

**Exit conditions:**
- ✓ Все 12 вопросов answered
- ✓ `user_input` JSON validated
- ✓ Required fields not empty

---

### PHASE 2: Requirements Analysis

**Цель:** Проанализировать собранные требования и спланировать структуру PRD

**Thinking block:**
```xml
<thinking type="analysis">
ЗАДАЧА: Проанализировать требования для PRD {product_name}
КОНТЕКСТ:
  - Продукт: {product_type} для {target_audience}
  - Бизнес-цели: {business_goals}
  - Фичи: {core_features}
  - Roadmap: {timeline}

АНАЛИЗ 14 СЕКЦИЙ:
§1 Executive Summary: Подсветить {top_business_goal}, {target_audience}, {launch_timeline}
§2 Goals and Scope: SMART-формулировки, Out of scope (inferred from product_type and MVP phase)
§3 Product Overview: Vision statement на основе {business_goals} + {core_features}
§4 Target Audience: 2-3 персоны на основе {target_audience}
§5 Business Requirements: KPIs = {success_metrics}, Revenue model (inferred from product_type)
§6 Functional Requirements: Core features breakdown + user scenarios
§7 Non-Functional Requirements: Performance, Security, Scalability (inferred from product_type/goals)
§8 User Interface: Design principles для {product_type}, wireframes (textual descriptions)
§9 Technical Requirements: {tech_stack}, {integrations}, infrastructure
§10 Roadmap: {timeline} → детализация фаз
§11 Risks: {known_risks} + inferred risks (technical debt, scalability, security)
§12 Testing: Test strategy для {product_type}
§13 Launch and Support: Launch checklist, support model
§14 Appendices: Glossary, references

MERMAID ДИАГРАММЫ (5 типов):
1. product-vision.mmd (graph TD): Goals → Features → Metrics (3 слоя, ~12 нод)
2. user-journey.mmd (journey): Awareness → Consideration → Purchase → Retention (4 секции)
3. system-context.mmd (graph TD - C4): Actors + {product_name} + External systems
4. feature-dependencies.mmd (graph TD): P0/P1/P2 features с зависимостями
5. roadmap-timeline.mmd (gantt): {timeline} фазы → milestones

INFERRED DATA:
- Персоны: 2-3 на основе {target_audience}
- Out of scope: на основе {product_type} и MVP фазы
- Revenue model: SaaS → subscription, Mobile → freemium+IAP
- Inferred risks: на основе {tech_stack}, {integrations}

ACCEPTANCE CRITERIA:
- Все 14 разделов заполнены AI-контентом (не placeholders)
- Все 5 Mermaid диаграмм валидны
- Навигация README.md корректна
- Content consistency: термины согласованы

ВЫВОДЫ: Готов к генерации структуры файлов
</thinking>
```

**Inferred data generation:**
- **Personas (2-3):** Based on `target_audience` + `product_type`
- **Out of scope:** Features not in MVP (based on `product_type` and first roadmap phase)
- **Revenue model:**
  - SaaS → Subscription (tiered pricing)
  - Mobile App → Freemium + IAP
  - Enterprise System → License + Support
- **Inferred risks:** Based on `tech_stack` complexity, `integrations` dependencies

**Exit conditions:**
- ✓ Analysis complete
- ✓ Inferred data extracted
- ✓ Content strategy defined

---

### PHASE 3: File Structure Generation

**Цель:** Создать структуру каталогов и файлов

**Directory structure:**
```
docs/prd/
├── README.md                              # Auto-generated navigation
├── 01-executive-summary.md
├── 02-goals-and-scope.md
├── 03-product-overview.md
├── 04-target-audience.md
├── 05-business-requirements.md
├── 06-functional-requirements/
│   ├── overview.md
│   ├── user-scenarios.md
│   └── features/
│       ├── feature-{slug}.md             # For each core feature from Q6
│       └── ...
├── 07-non-functional-requirements.md
├── 08-user-interface/
│   ├── design-guidelines.md
│   ├── wireframes.md
│   └── user-experience.md
├── 09-technical-requirements/
│   ├── architecture.md
│   ├── integrations.md
│   └── infrastructure.md
├── 10-roadmap.md
├── 11-risks.md
├── 12-testing.md
├── 13-launch-and-support.md
├── 14-appendices/
│   ├── glossary.md
│   └── references.md
└── diagrams/
    ├── product-vision.mmd
    ├── user-journey.mmd
    ├── system-context.mmd
    ├── feature-dependencies.mmd
    └── roadmap-timeline.mmd
```

**Feature breakdown:**
- For each `core_feature` from Q6:
  - Generate slug: "Task Management" → "task-management"
  - Create file: `06-functional-requirements/features/feature-{slug}.md`

**README.md navigation template:**
```markdown
# Product Requirements Document: {product_name}

**Version:** 1.0.0
**Last Updated:** {current_date}
**Status:** Draft

## Quick Navigation

### 1. Introduction
- [Executive Summary](./01-executive-summary.md)
- [Goals and Scope](./02-goals-and-scope.md)
- [Product Overview](./03-product-overview.md)

### 2. Audience & Requirements
- [Target Audience](./04-target-audience.md)
- [Business Requirements](./05-business-requirements.md)
- [Functional Requirements](./06-functional-requirements/overview.md)
  - [User Scenarios](./06-functional-requirements/user-scenarios.md)
  - [Features](./06-functional-requirements/features/)
- [Non-Functional Requirements](./07-non-functional-requirements.md)

### 3. Design & Technical
- [User Interface](./08-user-interface/design-guidelines.md)
- [Technical Requirements](./09-technical-requirements/architecture.md)

### 4. Planning
- [Roadmap](./10-roadmap.md)
- [Risks](./11-risks.md)
- [Testing](./12-testing.md)
- [Launch and Support](./13-launch-and-support.md)

### 5. Appendices
- [Glossary](./14-appendices/glossary.md)
- [References](./14-appendices/references.md)

## Diagrams
- [Product Vision](./diagrams/product-vision.mmd)
- [User Journey](./diagrams/user-journey.mmd)
- [System Context](./diagrams/system-context.mmd)
- [Feature Dependencies](./diagrams/feature-dependencies.mmd)
- [Roadmap Timeline](./diagrams/roadmap-timeline.mmd)
```

**Exit conditions:**
- ✓ All directories created
- ✓ README.md generated
- ✓ Placeholder files created (will be filled in Phase 4)

---

### PHASE 4: AI Content Generation

**Цель:** Сгенерировать AI-powered content для всех 14 секций

**Generation strategy:**
- **Parallel groups** for performance:
  - Group 1: §1, §2, §3 (Introduction) - parallel
  - Group 2: §4, §5 (Audience) - parallel
  - Group 3: §6, §7 (Requirements) - sequential (§6 first, then §7)
  - Group 4: §8, §9 (Design) - parallel
  - Group 5: §10, §11, §12, §13 (Planning) - parallel
  - Group 6: §14 (Appendices) - last (depends on all previous sections)

**Per-section generation:**

1. **Thinking block (analysis):**
```xml
<thinking type="analysis">
СЕКЦИЯ: {section_name}
ЦЕЛЬ: {purpose}
ВХОДНЫЕ ДАННЫЕ: {user_input fields}
СТРУКТУРА: {subsections}
TONE: {executive-friendly|technical|user-focused}
ВЫВОДЫ: Генерирую content
</thinking>
```

2. **AI-generation** based on:
   - `user_input` (Q1-Q12)
   - `inferred_data` (Phase 2)
   - `rules/prd-best-practices.md` (SMART goals, personas, user stories, NFR metrics)

**Feature files generation (separate for each feature):**

For each `core_feature` from Q6:

1. **Thinking block:**
```xml
<thinking type="analysis">
ФИЧА: {feature_name}
ЦЕЛЬ: Детальное описание фичи с user story и acceptance criteria
ВХОДНЫЕ ДАННЫЕ: {feature_name}, {user_scenarios}, {personas}
СТРУКТУРА:
  - Feature Description (1 paragraph)
  - User Story (As a...I want...so that...)
  - Acceptance Criteria (Given-When-Then format, 3-5 criteria)
  - Priority (P0/P1/P2)
  - Effort (S/M/L/XL)
  - Dependencies (other features)
ВЫВОДЫ: Генерирую detailed feature spec
</thinking>
```

2. **AI-generation** for `feature-{slug}.md`:
```markdown
# Feature: {Feature Name}

## Description
{AI-generated 1-2 paragraphs}

## User Story
**As a** {role from personas}
**I want** {action related to feature}
**So that** {benefit aligned with business goals}

## Acceptance Criteria
- [ ] Given {precondition}, when {action}, then {expected result}
- [ ] Given {precondition}, when {action}, then {expected result}
- [ ] Given {precondition}, when {action}, then {expected result}

## Priority
**P0** (Must Have for MVP) | **P1** (Should Have) | **P2** (Could Have)

## Effort Estimate
**S** (1-3 days) | **M** (1 week) | **L** (2 weeks) | **XL** (3+ weeks)

## Dependencies
- {Dependent feature 1}
- {Dependent feature 2}

## Technical Notes
{AI-generated implementation hints based on tech stack}
```

**Total words:** ~12,500 (main sections) + (N × 300) for feature files
где N = количество `core_features` из Q6

**Exit conditions:**
- ✓ Все 14 основных секций сгенерированы
- ✓ Все N feature files сгенерированы (each separately)
- ✓ Content not placeholder (real AI-generated prose)
- ✓ Cross-references correct (feature files link to each other via Dependencies)
- ✓ Terminology consistent (via glossary)

---

### PHASE 5: Mermaid Diagram Generation

**Цель:** Сгенерировать 5 Mermaid диаграмм с AI-powered visualization

**Diagram 1: product-vision.mmd (graph TD)**

3 layers: Business Goals → Product Features → Success Metrics

See `rules/mermaid-diagrams.md` for full template

**Diagram 2: user-journey.mmd (journey)**

4 sections: Awareness → Consideration → Purchase → Retention

See `rules/mermaid-diagrams.md` for full template

**Diagram 3: system-context.mmd (graph TD - C4 style)**

Actors + {Product Name} + External Systems

See `rules/mermaid-diagrams.md` for full template

**Diagram 4: feature-dependencies.mmd (graph TD)**

P0/P1/P2 features with dependencies, color-coded by priority

See `rules/mermaid-diagrams.md` for full template

**Diagram 5: roadmap-timeline.mmd (gantt)**

Based on `timeline` from Q10, phases → milestones → deliverables

See `rules/mermaid-diagrams.md` for full template

**Validation:**
- Syntax valid (regex patterns)
- Node definitions correct `NODE[Label]`
- Edge definitions correct `A --> B`
- Color scheme applied
- Complexity appropriate (5-15 nodes)

**Retry logic:**
- Max 2 retries на syntax error
- On failure: simplified fallback diagram (fewer nodes)

**Exit conditions:**
- ✓ All 5 diagrams generated
- ✓ Mermaid syntax valid
- ✓ Styling applied
- ✓ Complexity appropriate

---

### PHASE 6: Update/Merge Mode (conditional)

**Цель:** Smart merge при обновлении существующего PRD

**Activation:** Only if `initialization.mode = "UPDATE"`

**Merge strategy:**

**1. Full Overwrite (always):**
- `README.md` (auto-generated navigation)
- `diagrams/*.mmd` (auto-generated diagrams)

**2. Smart Merge (preserve user changes):**

For each section:
1. Read `existing_file`
2. Compare with `last_generated_content` (if metadata exists)
3. Compute diff

**Diff analysis:**
```
IF diff.is_empty():
  → Overwrite (user didn't change)
ELIF diff.is_append_only():
  → Merge: existing_file + "\n\n---\n\n## Updated\n\n" + new_content
ELSE:
  → Conflict: Ask user (keep_existing | use_new | merge_manual)
```

**3. Never Touch:**
- `14-appendices/` user-added files
- `06-functional-requirements/features/feature-custom-*.md` custom features

**Backup strategy:**
- Before merge: create `.prd-backup-{timestamp}/`
- Copy all existing files
- Backup kept for 7 days (cleanup policy)

**Conflict resolution:**
- Create `.new` file with new content
- Preserve existing file
- Prompt user: "Review {file} and {file}.new, merge manually, then delete .new"

**Exit conditions:**
- ✓ Backup created
- ✓ All conflicts resolved
- ✓ User additions preserved
- ✓ New content integrated

---

### PHASE 7: Validation & Output

**Цель:** Validate all files and generate structured output

**5 validators (parallel):**

**1. Markdown Syntax Validator:**
- Parse all `.md` files
- Check YAML frontmatter (if exists) using [@shared:frontmatter-parser](../_shared/frontmatter-parser.md)
- Validate heading hierarchy (# → ## → ### without skips)
- Check code blocks (fenced with ```)
- Validate lists (consistent indentation)

**2. Mermaid Diagrams Validator:**
- Parse all `.mmd` files
- Validate syntax via regex:
  - `graph TD|LR`, `journey`, `gantt`, `sequenceDiagram` valid
  - Node definitions `NODE[Label]`
  - Edge definitions `A --> B`, `A -.-> B`, `A ==> B`
- Check for syntax errors (unclosed brackets, typos)

**3. Navigation Links Validator:**
- Extract all `[text](path)` links
- Resolve relative paths
- Check if target file exists
- Check for broken links
- Validate anchor links (if used)

**4. Directory Structure Validator:**
- Check expected directories exist
- Verify file naming (kebab-case for features)
- Check for orphaned files (not referenced in README.md)
- Validate feature naming (`feature-*.md`)

**5. Content Quality Validator:**
- Check for placeholder text ("TODO", "TBD", "[FILL IN]")
- Validate minimum length (>100 words per major section)
- Check cross-reference consistency (glossary terms match usage)
- Basic contradiction detection

**Validation levels:**
- **Error:** Blocking issue (must fix)
- **Warning:** Non-blocking (can proceed)
- **Info:** Suggestion

**Final output (JSON):**
See `templates/prd-output.json` for full schema

**Markdown summary (user-friendly):**
```markdown
## PRD Generated Successfully ✅

**Product:** {product_name}
**Location:** `docs/prd/`
**Mode:** {create|update}

### Files Created ({N})

**Markdown Sections ({M}):**
- ✅ All 14 main sections + {N} feature files

**Mermaid Diagrams (5):**
- ✅ product-vision.mmd
- ✅ user-journey.mmd
- ✅ system-context.mmd
- ✅ feature-dependencies.mmd
- ✅ roadmap-timeline.mmd

### Validation Results
- ✅ Markdown syntax: passed
- ✅ Mermaid diagrams: passed
- ⚠️  Navigation links: 1 warning
- ✅ Directory structure: passed
- ⚠️  Content quality: 1 warning

### Statistics
- **Total Words:** {N}
- **Features:** {N}
- **Personas:** {N}
- **Roadmap Phases:** {N}

### Next Steps
1. Review: `cd docs/prd/ && cat README.md`
2. Render Mermaid: Use GitHub or VS Code extension
3. Customize: Add specific details, refine personas
4. Share: Send link to stakeholders
```

**Exit conditions:**
- ✓ All validators executed
- ✓ JSON output generated
- ✓ Markdown summary generated
- ✓ Files written to disk

---

## Error Handling

**Error codes and actions:**

| Code | Error | Action |
|------|-------|--------|
| E001 | User cancellation | STOP, return cancellation message |
| E002 | Invalid input (questionnaire) | Retry 3x with helpful message |
| E003 | Context detection failed | Continue without pre-fill |
| E004 | Directory permission error | STOP, suggest alternative |
| E005 | Mermaid syntax error | Retry 2x, fallback to simplified |
| E006 | Markdown syntax error | Auto-fix heading levels |
| E007 | Broken navigation link | Remove link or mark TODO |
| E008 | Merge conflict | Create .new file, ask user |
| E009 | Content generation timeout | Skip section, add placeholder |
| E010 | Validation failed (critical) | Mark status "partial" |

**Retry logic:**
- Questionnaire: max 3 retries per question
- Content generation: max 2 retries per section
- Mermaid diagrams: max 2 retries, fallback to simplified

**Graceful degradation:**
- If Phase 4 fails: create file structure with placeholders, status = "partial"
- If Phase 5 fails: skip diagrams, create TODO placeholders, status = "partial"
- If Phase 7 warnings: continue, status = "success" with warnings

---

## Format вывода

**Structured JSON output:**

See `templates/prd-output.json` for complete schema

**Key fields:**
- `status`: `success | partial | failed`
- `product_name`: from Q1
- `output_directory`: absolute path
- `mode`: `create | update`
- `generated_files`: counts and paths
- `validation_results`: per-validator status
- `statistics`: words, features, personas, phases

---

## Dependencies

**Required skills:**

1. **thinking-framework** (v2.0.0+)
   - Usage: All 7 phases use `@template:analysis`
   - Purpose: Structured reasoning for requirements analysis, content generation strategy, diagram design

2. **context-awareness** (v1.0.0+)
   - Usage: Phase 0 (Initialization)
   - Purpose: Detect project name, type, tech stack to pre-fill questionnaire (Q1, Q8)

3. **validation-framework** (v1.0.0+)
   - Usage: Phase 7 (Validation)
   - Purpose: Markdown syntax validator, link validator, content quality validator
   - Custom validators: Mermaid syntax, directory structure

---

## Workflow Integration

**User invocation:**
```
/prd-generator
```

**Auto-invocation keywords:**
- "Создай PRD для {product}"
- "Обнови PRD"
- "Сгенерируй Product Requirements Document"

**Output consumers:**
- `architecture-documentation` skill: consumes `sections.09-technical-requirements`, `diagrams.system-context`
- `task-decomposition` skill: consumes `sections.06-functional-requirements`, `diagrams.feature-dependencies`
- `git-workflow` skill: consumes `output_directory`, `product_name` for commit message

**Notes:**
- This skill generates files in user's project directory (`docs/prd/`), NOT in skill directory
- Skill files (`templates/`, `rules/`, `examples/`) are read-only references
- Generated PRD can be committed to git separately by user or via `git-workflow` skill
