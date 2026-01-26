---
name: skill-generator
description: Автоматизированное создание новых скиллов с интерактивными вопросами, генерацией templates, schemas и валидацией
version: 1.3.0
tags: [meta, generator, scaffolding, templates, schemas, validation, interactive, toon]
dependencies: [thinking-framework, structured-planning, validation-framework, toon-skill]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  rules: ./rules/*.md
user-invocable: true
changelog:
  - version: 1.3.0
    date: 2026-01-26
    changes:
      - "**Documentation Optimization**: 27% reduction (578 → 423 lines)"
      - "Added Quick Reference table at top for instant understanding"
      - "Compacted How It Works with tables instead of verbose lists"
      - "Added Best Practices section (Skill Design + Common Pitfalls + Template Tips)"
      - "Converted Error Handling to table with recovery strategies"
      - "Optimized TOON section - removed redundant examples"
      - "Replaced verbose JSON examples with references to @example and @rules"
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specification → @shared:TOON-REFERENCE.md"
      - "Обновлены references: ../_shared/TOON-PATTERNS.md → @shared:TOON-REFERENCE.md"
      - "Удалён author field"
  - version: 1.1.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Token-efficient skill generation reporting"
      - "TOON для files_created[] и validation_results (5 validators)"
      - "40-50% token savings для skills с множественными files"
      - "Special handling: validation_results object → array conversion"
  - version: 1.0.0
    date: 2025-XX-XX
    changes:
      - "Initial release"
---

# Skill Generator

Автоматизированное создание новых скиллов для текущего проекта с интерактивными вопросами, автоматической генерацией JSON Schema из template placeholders и полной валидацией.

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | `/skill-generator` (manual only, never auto-invoked) |
| **Duration** | ~5 min (Q&A + generation) vs ~2-3 hours manual |
| **Inputs** | 8-9 interactive questions (skill name, type, dependencies, templates) |
| **Outputs** | SKILL.md + templates/*.json + schemas/*.schema.json + examples/*.md |
| **Auto-generates** | JSON Schema from template placeholders (35-45% token savings) |
| **Validation** | 5 validators (YAML, JSON, Schema, Markdown, File Structure) |
| **TOON Support** | Auto-generates TOON for files_created[] & validation_results[] |
| **Target Location** | `.claude/skills/` (project) or `.nvm-isolated/.claude-isolated/skills/` (global) |

## When to Use

Use this skill when you need to:
- Create a new skill for current project or iclaude
- Generate skill structure automatically with validation
- Auto-generate JSON schemas from templates
- Ensure skill follows project conventions

**Manual invocation:**
`/skill-generator` or `@skill:skill-generator`

**Note:** This skill is NEVER invoked automatically. It's a user-facing tool for skill developers.

## How It Works

### Step 1: Initialization & Context Check

**Purpose:** Detect target project and determine where to create new skill

**Actions:**
1. Detect current working directory
2. Check if `.claude/skills/` exists (current project skills)
3. Check if `.nvm-isolated/.claude-isolated/skills/` exists (iclaude global skills)
4. Determine target location:
   - **Project-specific:** Create in `<project_root>/.claude/skills/`
   - **iclaude global:** Create in `.nvm-isolated/.claude-isolated/skills/`
5. Load existing skills from detected location
6. Extract available tags and common dependencies

**Detection logic:**
```javascript
// Priority order:
// 1. Current project (.claude/skills/) - DEFAULT
// 2. iclaude project (.nvm-isolated/.claude-isolated/skills/) - FALLBACK

const projectSkillsDir = path.join(cwd(), '.claude/skills')
const iclaudeSkillsDir = path.join(findIclaudeRoot(), '.nvm-isolated/.claude-isolated/skills')

if (fs.existsSync(projectSkillsDir)) {
  targetLocation = 'project'
  skillsDirectory = projectSkillsDir
} else if (fs.existsSync(iclaudeSkillsDir)) {
  targetLocation = 'iclaude-global'
  skillsDirectory = iclaudeSkillsDir
} else {
  // Ask user: create project skills dir or use iclaude global?
  askUserQuestion()
}
```

**Output:**
```json
{
  "initialization": {
    "status": "ready",
    "target_location": "project|iclaude-global",
    "skills_directory": "/absolute/path/to/skills",
    "existing_skills_count": 19,
    "available_tags": ["planning", "bash", "integration", ...],
    "common_dependencies": ["thinking-framework", "context-awareness", ...],
    "notes": [
      "Skills will be created in <project_root>/.claude/skills/",
      "This makes skills project-specific (not global)"
    ]
  }
}
```

### Step 2: Interactive User Questionnaire

**Purpose:** Gather requirements through 8-9 interactive questions using AskUserQuestion tool

| Question | Prompt | Validation | Default | Notes |
|----------|--------|------------|---------|-------|
| **Q1: Skill Name** | Enter skill name (kebab-case) | `/^[a-z][a-z0-9-]*$/` (3-50 chars) | - | Must not conflict with existing skills |
| **Q2: Skill Type** | 1=system, 2=user-invocable, 3=bash-utility, 4=integration | enum [1,2,3,4] | - | Sets `user-invocable` field & default tags |
| **Q3: Description** | Brief description (1-2 sentences) | 20-200 chars | - | Must be informative (not placeholder) |
| **Q4: Dependencies** | Comma-separated skill names | Must exist in skills/, no circular deps | none | DFS cycle detection with path visualization |
| **Q5: Complexity Levels** | Support minimal/standard/complex? (Y/n) | boolean | n | Yes → multiple templates (input-lite.json, input.json) |
| **Q6: Output Format** | 1=JSON, 2=YAML, 3=Markdown, 4=Text, 5=Mixed | enum [1,2,3,4,5] | JSON | Determines template structure |
| **Q7: Templates** | Comma-separated template names | kebab-case | input, output | Each → `templates/{name}.json` |
| **Q8: Features** | Comma-separated: rules, examples, shared-data | enum | examples | Controls directory creation |
| **Q9: Target Location** | 1=project (.claude/skills/), 2=global (iclaude) | enum [1,2] | project | **Only if BOTH locations available** |

**Output Structure:**
```json
{
  "user_input": {
    "skill_name": "my-awesome-skill",
    "skill_type": "user-invocable",
    "description": "...",
    "dependencies": ["thinking-framework"],
    "complexity_levels": true,
    "output_format": "JSON",
    "templates": ["input", "output", "config"],
    "features": ["rules", "examples"],
    "target_location": "project"
  }
}
```

### Step 3: Analysis & Planning

**Purpose:** Use thinking-framework to analyze requirements and plan structure

**Thinking block (analysis template):**
```xml
<thinking type="analysis">
ЗАДАЧА: Создать скилл "{skill_name}"
КОНТЕКСТ: {skill_type} скилл с dependencies [{deps}]
КОМПОНЕНТЫ:
  - SKILL.md (YAML frontmatter + Markdown)
  - templates/{name}.json × {N}
  - schemas/{name}.schema.json × {N}
  - rules/*.md (if feature enabled)
  - examples/*.md (if feature enabled)
ACCEPTANCE CRITERIA:
  - Valid YAML frontmatter
  - Valid JSON templates/schemas
  - Markdown follows conventions
  - File structure matches declarations
ВЫВОДЫ: Создать {total} файлов в skills/{skill_name}/
</thinking>
```

**Generate file structure map:**
```json
{
  "file_structure": {
    "skill_directory": "my-awesome-skill/",
    "files": [
      {"path": "SKILL.md", "type": "markdown", "content_type": "frontmatter+markdown"},
      {"path": "templates/input.json", "type": "json", "content_type": "template"},
      {"path": "schemas/input.schema.json", "type": "json-schema", "content_type": "schema"}
    ]
  }
}
```

### Step 4: Template Generation

**Purpose:** Generate all skill files with correct content

| Component | Description | Reference |
|-----------|-------------|-----------|
| **SKILL.md** | YAML frontmatter + standard sections (When to Use, How It Works, Output Format, etc.) | `@template:skill-template-base` |
| **JSON Templates** | Input/output templates with `{{placeholder}}` syntax | `@example:simple-system-skill` |
| **JSON Schemas** | Auto-generated from template placeholders (35-45% token savings) | `@rules:placeholder-mapping` |
| **Examples** | Usage examples (Scenario, Input, Output, Explanation) | `@example:simple-system-skill` |
| **Rules** | Best practices and common pitfalls (optional) | - |

**Placeholder Syntax:**

| Pattern | Schema Mapping | Example |
|---------|----------------|---------|
| `{{name: string}}` | `{"type": "string"}` | `"name": "value"` |
| `{{name: string, min 3 chars}}` | `{"type": "string", "minLength": 3}` | `"name": "abc"` |
| `{{name: integer, min 1}}` | `{"type": "integer", "minimum": 1}` | `"count": 10` |
| `{{name: enum: val1\|val2}}` | `{"enum": ["val1", "val2"]}` | `"type": "val1"` |
| `{{optional: type}}` | Not in required array | `"optional_field": null` |
| `{{name: pattern: /regex/}}` | `{"pattern": "regex"}` | `"name": "abc-123"` |

**Full placeholder mapping rules:** `@rules:placeholder-mapping`

**Schema Generation Algorithm:**
1. Parse template JSON → Extract `{{...}}` placeholders via `/\{\{([^}]+)\}\}/g`
2. Parse each placeholder → `name: type[, constraint]*`
3. Map to JSON Schema type + constraints (minLength, maximum, enum, pattern)
4. Build required array (non-optional fields only)
5. Generate JSON Schema Draft-7

**See also:** `@example:simple-system-skill` for complete template → schema → example workflow

### Step 5: Validation

**Purpose:** Validate all generated files before finalizing (5 validators run in parallel)

| Validator | Checks | Status | Reference |
|-----------|--------|--------|-----------|
| **YAML Frontmatter** | Required fields, types, semver format, dependencies, circular deps | passed/failed | [@shared:frontmatter-parser](../_shared/frontmatter-parser.md) |
| **JSON Templates** | JSON syntax, root key naming, placeholder extraction, placeholder format | passed/failed | `@rules:placeholder-mapping` |
| **JSON Schemas** | JSON Schema syntax, `$schema` field = Draft-7, meta-schema validation, template cross-check | passed/failed | - |
| **Markdown Formatting** | Frontmatter exists, required sections (When to Use, How It Works, Output Format), code blocks, references | passed/warning/failed | - |
| **File Structure** | SKILL.md exists, frontmatter.files declarations, directory/file existence, naming conventions (kebab-case), orphaned files | passed/failed | - |

**Output Structure:**
```json
{
  "validation_results": {
    "yaml_frontmatter": {"status": "passed", "errors": []},
    "json_templates": {"status": "passed", "errors": []},
    "json_schemas": {"status": "passed", "errors": []},
    "markdown_formatting": {"status": "warning", "warnings": ["No FAQ section"]},
    "file_structure": {"status": "passed", "errors": []}
  }
}
```

### Step 6: Error Handling & Recovery

| Error Code | Issue | Detection | Recovery Strategy |
|------------|-------|-----------|-------------------|
| **E001** | Invalid skill name | Name doesn't match `/^[a-z][a-z0-9-]*$/` | Show: "❌ Invalid name" → Auto-suggest kebab-case conversion → Retry Q1 |
| **E002** | Skill exists | Name conflicts with existing skill | Show: "⚠️ Skill exists" → Options: 1) Rename, 2) Overwrite [DANGEROUS], 3) Abort |
| **E003** | Unknown dependency | Dependency not found in skills/ | Show: "❌ Unknown dependency" → List available skills → Retry Q4 |
| **E004** | Circular dependency | DFS detects cycle in dependency graph | Show: "❌ Circular: skill-a → skill-b → skill-a" → Explain which dep to remove → Retry Q4 |
| **E005** | JSON syntax error | Trailing commas, unclosed braces | Auto-fix: Remove trailing commas → Re-validate |
| **E006** | Missing section | Required section missing in SKILL.md | Auto-fix: Add placeholder section → Mark as warning (not error) |
| **E007** | Schema-template mismatch | Required field in template missing in schema | Auto-fix: Regenerate schema from template → Re-validate |

### Step 7: Output Generation

**Purpose:** Produce final structured output + user-friendly summary

**JSON Output Structure:**
```json
{
  "skill_generation": {
    "status": "success|partial|failed",
    "skill_directory": "/absolute/path/to/skills/my-skill",
    "files_created": ["SKILL.md", "templates/*.json", "schemas/*.schema.json", "examples/*.md"],
    "validation_results": { /* 5 validator outputs */ },
    "integration_notes": ["Test with: /my-skill", "Commit: git add skills/my-skill/"],
    "dependencies": ["thinking-framework"],
    "skill_type": "user-invocable",
    "toon": { /* Optional TOON format (if >= 5 files) */ }
  }
}
```

**User-Friendly Summary:**

```
## Skill Generated Successfully ✅

**Skill:** my-skill | **Type:** user-invocable | **Location:** .claude/skills/my-skill/

### Files Created (6)
✅ SKILL.md, templates/input.json, templates/output.json, schemas/*.schema.json, examples/basic-usage.md

### Validation: 4 passed, 1 warning
⚠️ Markdown formatting: No FAQ section

### Next Steps
1. Review: `cat .claude/skills/my-skill/SKILL.md`
2. Customize templates & examples
3. Test: `/my-skill`
4. Commit: `git add skills/my-skill/ && git commit -m "feat(skills): add my-skill"`
```

## Best Practices

### Skill Design Principles

| Principle | Guideline | Example |
|-----------|-----------|---------|
| **Single Responsibility** | Each skill should do ONE thing well | ❌ "file-ops-and-validation" → ✅ "file-validator" + "file-transformer" |
| **Clear Dependencies** | Explicit dependencies, avoid circular deps | ✅ "code-review" depends on "thinking-framework" |
| **Validation First** | Use JSON Schema for all inputs/outputs | ✅ Auto-generated schemas from templates |
| **Token Efficiency** | Use TOON for arrays >= 5 elements | ✅ files_created[20] → 45% token savings |
| **Documentation** | Complete examples, not just templates | ✅ @example:simple-system-skill shows full workflow |
| **Reusability** | Design for reuse across projects | ✅ Project-specific (.claude/skills/) vs Global (iclaude) |

### Common Pitfalls

| Pitfall | Impact | Solution |
|---------|--------|----------|
| **No examples** | Users don't understand usage | Always generate examples/ with scenarios |
| **Overcomplicated templates** | Hard to maintain | Start simple, add complexity only when needed |
| **Missing validation** | Silent failures | Use all 5 validators, fix warnings |
| **Circular dependencies** | Skill won't load | Use DFS detection (E004 error handler) |
| **Unclear naming** | Hard to discover | Use descriptive kebab-case names |
| **No TOON support** | Token waste | Auto-enable for arrays >= 5 elements |

### Template Design Tips

1. **Start with output, then input** - Define what you want to produce first
2. **Use optional fields sparingly** - Required fields = explicit contracts
3. **Leverage enums** - Constrain values early (e.g., `enum: success|partial|failed`)
4. **Nest logically** - Group related fields in objects
5. **Document with $comment** - Explain non-obvious constraints

## Output Format

### Workflow Integration (JSON)

See Step 7 above for full JSON structure.

Key fields:
- `status`: success | partial | failed
- `files_created`: array of relative paths
- `validation_results`: 5 validator outputs
- `integration_notes`: next steps for user

### Documentation Files

Created files:
- `skills/{skill-name}/SKILL.md` - Main documentation
- `skills/{skill-name}/templates/*.json` - Input/output templates
- `skills/{skill-name}/schemas/*.schema.json` - JSON Schemas (auto-generated)
- `skills/{skill-name}/examples/*.md` - Usage examples
- `skills/{skill-name}/rules/*.md` - Best practices (optional)

## Templates

- `@template:skill-generator-input` - Input for non-interactive mode
- `@template:skill-generator-output` - Output structure
- `@template:skill-template-base` - Base template for new SKILL.md generation

## Schemas

- `@schema:skill-generator-input` - Validates input JSON (auto-generated)
- `@schema:skill-generator-output` - Validates output JSON (auto-generated)

## Examples

- `@example:simple-system-skill` - Create system skill (cleanup-automation)

## Rules

- `@rules:placeholder-mapping` - Placeholder syntax and schema generation

---

## TOON Format Support

**NEW in v1.1.0:** Автоматическая генерация TOON format для token-efficient reporting

### Auto-Generation Triggers

| Array | Threshold | Token Savings | Example |
|-------|-----------|---------------|---------|
| `files_created[]` | >= 5 files | 45% (20 files) | `SKILL.md,markdown,4523\ntemplates/input.json,template,1245...` |
| `validation_results` | Always (5 validators) | 35% | `yaml_frontmatter,passed,0,0\njson_templates,passed,0,0...` |

### Output Structure

**Hybrid JSON + TOON** (100% backward compatible):

```json
{
  "skill_generation": {
    "files_created": [...],      // JSON (always present - primary format)
    "validation_results": {...}, // JSON (always present - primary format)
    "toon": {                    // TOON (optional, if >= 5 elements)
      "files_created_toon": "files_created[20]{path,type,size}:\n  ...",
      "validation_results_toon": "validators[5]{name,status,errors,warnings}:\n  ...",
      "token_savings": "42.5%"
    }
  }
}
```

**Benefits:** 40-50% token savings for skills with multiple files, validation transparency, no breaking changes

**See also:** @skill:toon-skill (TOON API), @shared:TOON-REFERENCE.md (specification)

---

## Workflow Integration

### Input Dependencies

Requires data from:
- `thinking-framework` → Analysis thinking for requirement understanding
- `structured-planning` → Planning file structure
- `validation-framework` → Validation of generated files

### Output Consumers

Provides data to:
- User → Review and customize generated skill
- `git-workflow` → Commit skill to repository
- Other developers → Use generated skill as template
