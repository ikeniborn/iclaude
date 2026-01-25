---
name: skill-generator
description: Автоматизированное создание новых скиллов с интерактивными вопросами, генерацией templates, schemas и валидацией
version: 1.2.0
tags: [meta, generator, scaffolding, templates, schemas, validation, interactive, toon]
dependencies: [thinking-framework, structured-planning, validation-framework, toon-skill]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  rules: ./rules/*.md
user-invocable: true
changelog:
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

**Question 1: Skill Name**
- Prompt: "Enter skill name (kebab-case, e.g., my-awesome-skill):"
- Validation: `/^[a-z][a-z0-9-]*$/` (3-50 chars)
- Check: Name must not conflict with existing skills
- Retry on failure with suggestions

**Question 2: Skill Type**
- Prompt: "Select skill type:\n1. system\n2. user-invocable\n3. bash-utility\n4. integration"
- Validation: enum [1,2,3,4]
- Mapping: {1: "system", 2: "user-invocable", ...}
- Sets `user-invocable` frontmatter field
- Determines default tags

**Question 3: Description**
- Prompt: "Brief description (1-2 sentences, 20-200 chars):"
- Validation: minLength 20, maxLength 200
- Must be informative (not placeholder text)

**Question 4: Dependencies**
- Prompt: "Dependencies (comma-separated, or Enter to skip):\nAvailable: ..."
- Validation: Each dependency must exist in skills/
- Check for circular dependencies (DFS graph traversal)
- Retry on error with cycle path visualization

**Question 5: Complexity Levels**
- Prompt: "Support complexity levels (minimal/standard/complex)? (Y/n)"
- Default: n
- If yes → Generate multiple templates (input-lite.json, input.json)
- If no → Generate single template

**Question 6: Output Format**
- Prompt: "Output format:\n1. JSON\n2. YAML\n3. Markdown\n4. Text\n5. Mixed (JSON + Markdown)"
- Default: JSON
- Determines template structure

**Question 7: Templates Needed**
- Prompt: "Templates (comma-separated):\nExamples: input, output, config\nOr Enter for default (input + output):"
- Validation: kebab-case names
- Default: ["input", "output"]
- Each generates `templates/{name}.json`

**Question 8: Additional Features**
- Prompt: "Features (comma-separated or Enter):\n- rules\n- examples\n- shared-data"
- Default: ["examples"]
- Controls which directories to create

**Question 9 (Conditional): Target Location**
- **Only asked if BOTH locations available**
- Prompt: "Where to create skill:\n1. Current project (.claude/skills/) - Project-specific [RECOMMENDED]\n2. iclaude global (.nvm-isolated/.claude-isolated/skills/) - Global for all projects"
- Default: 1 (project-specific)
- Recommendation: Always use project-specific unless creating shared utility

**Output:**
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

**4.1 Generate SKILL.md**

Structure with YAML frontmatter and standard sections:
- When to Use
- How It Works (with numbered steps)
- Output Format
- Templates
- Schemas
- Examples
- Workflow Integration

**4.2 Generate JSON Templates**

Example `templates/input.json`:
```json
{
  "$comment": "Input template for {skill_name} skill",
  "{skill_name}_input": {
    "$comment": "{description}",
    "field1": "{{field1: string, description}}",
    "field2": "{{field2: integer, min 1}}",
    "nested": {
      "subfield": "{{subfield: enum: val1|val2|val3}}"
    },
    "array": ["{{item: string}}"],
    "optional_field": "{{optional: string}}"
  }
}
```

**Placeholder syntax rules:**
- Basic: `{{name: type}}`
- With constraint: `{{name: type, constraint value}}`
- Enum: `{{name: enum: val1|val2|val3}}`
- Optional: `{{optional: type}}` (prefix `optional:`)
- Pattern: `{{name: pattern: /regex/}}`

**4.3 Auto-generate JSON Schemas**

Algorithm:
1. Parse template JSON
2. Extract all `{{...}}` placeholders via regex `/\{\{([^}]+)\}\}/g`
3. For each placeholder:
   - Parse format: `name: type[, constraint]*`
   - Map to JSON Schema type
   - Add constraints (minLength, maximum, enum, pattern)
   - Mark as required (if not `optional:`)
4. Build JSON Schema Draft-7

Example mapping:
```
{{name: string, min 3 chars}}
→
{
  "name": {
    "type": "string",
    "minLength": 3
  }
}
+ required: ["name"]
```

**4.4 Generate Examples**

Example `examples/basic-usage.md` with sections:
- Scenario
- Input
- Execution
- Output
- Explanation

**4.5 Generate Rules (if enabled)**

Example `rules/recommendations.md` with best practices and common pitfalls

### Step 5: Validation

**Purpose:** Validate all generated files before finalizing

**5 Validators (run in parallel):**

**Validator 1: YAML Frontmatter**
- Use [@shared:frontmatter-parser](../_shared/frontmatter-parser.md) for validation
- Validates: required fields, types, formats (semver), dependencies, circular dependencies
- See [@shared:frontmatter-parser](../_shared/frontmatter-parser.md) for complete validation rules and error messages

**Validator 2: JSON Templates**
- Parse JSON syntax (catch SyntaxError)
- Validate root key matches skill name pattern
- Extract placeholders
- Validate placeholder format (see rules/placeholder-mapping.md)

**Validator 3: JSON Schemas**
- Parse JSON Schema
- Check `$schema` field = Draft-7
- Validate against meta-schema
- Cross-check with template (required fields match, types match, enums match)

**Validator 4: Markdown Formatting**
- Check YAML frontmatter exists
- Extract headings
- Verify required sections: "When to Use", "How It Works", "Output Format"
- Validate code blocks (fenced with ```)
- Extract and validate references (@template:, @schema:, @example:)
- Check references resolve to files

**Validator 5: File Structure**
- Check SKILL.md exists
- Parse frontmatter.files
- For each declared file type: check directory exists, files exist
- Validate naming conventions (kebab-case for templates/schemas/examples)
- Detect orphaned files (not declared in frontmatter)

**Validation output:**
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

**Error types and recovery strategies:**

**E001: Invalid skill name**
- Show: "❌ Invalid name '{name}' (must be kebab-case)"
- Suggest: Auto-convert to kebab-case
- Retry: Q1 with suggestion

**E002: Skill exists**
- Show: "⚠️  Skill '{name}' already exists"
- Options: 1) Rename, 2) Overwrite [DANGEROUS], 3) Abort
- Action based on user choice

**E003: Unknown dependency**
- Show: "❌ Unknown dependency '{dep}'"
- List: Available skills
- Retry: Q4

**E004: Circular dependency**
- Show: "❌ Circular: skill-a → skill-b → skill-a"
- Explain: Which dependency to remove
- Retry: Q4

**E005: JSON syntax error**
- Detect: Trailing commas, unclosed braces
- Auto-fix: Remove trailing commas
- Re-validate

**E006: Missing section**
- Detect: Required section missing in SKILL.md
- Auto-fix: Add placeholder section
- Mark: Warning (not error)

**E007: Schema-template mismatch**
- Detect: Required field in template missing in schema
- Auto-fix: Regenerate schema from template
- Re-validate

### Step 7: Output Generation

**Purpose:** Produce final structured output + user-friendly summary

**JSON Output:**
```json
{
  "skill_generation": {
    "status": "success",
    "skill_directory": "/absolute/path/to/skills/my-skill",
    "files_created": [
      "SKILL.md",
      "templates/input.json",
      "templates/output.json",
      "schemas/input.schema.json",
      "schemas/output.schema.json",
      "examples/basic-usage.md"
    ],
    "validation_results": {
      "yaml_frontmatter": {"status": "passed", "errors": []},
      "json_templates": {"status": "passed", "errors": []},
      "json_schemas": {"status": "passed", "errors": []},
      "markdown_formatting": {"status": "warning", "warnings": ["No FAQ section"]},
      "file_structure": {"status": "passed", "errors": []}
    },
    "integration_notes": [
      "Skill created successfully",
      "Test with: /my-skill",
      "Commit to git: git add skills/my-skill/",
      "Update README.md with skill description"
    ],
    "dependencies": ["thinking-framework"],
    "skill_type": "user-invocable"
  }
}
```

**Markdown Summary:**
```markdown
## Skill Generated Successfully ✅

**Skill:** my-skill
**Type:** user-invocable
**Location:** `.claude/skills/my-skill/`

### Files Created (6)

- ✅ SKILL.md (YAML frontmatter + Markdown)
- ✅ templates/input.json
- ✅ templates/output.json
- ✅ schemas/input.schema.json
- ✅ schemas/output.schema.json
- ✅ examples/basic-usage.md

### Validation Results

- ✅ YAML frontmatter: passed
- ✅ JSON templates: passed
- ✅ JSON schemas: passed
- ⚠️  Markdown formatting: 1 warning (No FAQ section)
- ✅ File structure: passed

### Next Steps

1. **Review generated files:**
   ```bash
   cd .claude/skills/my-skill/
   cat SKILL.md
   ```

2. **Customize templates and examples**

3. **Test the skill:**
   ```bash
   /my-skill
   ```

4. **Commit to git:**
   ```bash
   git add skills/my-skill/
   git commit -m "feat(skills): add my-skill"
   ```
```

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

**NEW in v1.1.0:** Автоматическая генерация TOON format для token-efficient skill generation reporting

### Когда генерируется TOON

Skill автоматически генерирует TOON format когда:
- `files_created.length >= 5` ИЛИ
- `validation_results` объект конвертируется в массив validators (всегда 5 элементов)

### Token Savings

**Типичная экономия:**
- 20 files created: **45% token reduction**
- 5 validation results: **35% token reduction**
- Combined (files + validation): **40-50% total savings**

### Output Structure (Hybrid JSON + TOON)

```json
{
  "skill_generation": {
    "status": "success",
    "skill_directory": "/path/to/skills/my-awesome-skill",
    "files_created": [...],      // JSON (всегда присутствует)
    "validation_results": {...}, // JSON object (всегда присутствует)
    "integration_notes": [...],
    "dependencies": ["thinking-framework"],
    "skill_type": "user-invocable",
    "toon": {                    // TOON (опционально, если >= 5 элементов)
      "files_created_toon": "files_created[20]{relative_path,file_type,size_bytes}:\n  SKILL.md,markdown,4523\n  templates/input.json,template,1245\n  templates/output.json,template,1678\n  ...",
      "validation_results_toon": "validation_results[5]{validator_name,status,error_count,warning_count,messages}:\n  yaml_frontmatter,passed,0,0,\n  json_templates,passed,0,0,\n  json_schemas,passed,0,0,\n  markdown_formatting,warning,0,1,No FAQ section\n  file_structure,passed,0,0,",
      "token_savings": "42.5%",
      "size_comparison": "JSON: 3800 tokens, TOON: 2185 tokens"
    }
  }
}
```

### Benefits

- **Backward Compatible**: JSON output неизменён (primary format)
- **Token Efficient**: 40-50% savings для skills с множественными files
- **Validation Transparency**: TOON сохраняет validation results в компактном формате

### See Also

- **toon-skill** - Базовый навык для TOON API (@skill:toon-skill)
- **TOON Reference** - Full specification (@shared:TOON-REFERENCE.md)

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
