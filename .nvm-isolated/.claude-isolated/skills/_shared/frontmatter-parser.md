# YAML Frontmatter Parser - Shared Component

**Version:** 1.0.0
**Author:** iclaude Skills Team
**Purpose:** Стандартизированный парсинг и валидация YAML frontmatter для всех skills

---

## Overview

Этот компонент предоставляет единообразный способ парсинга и валидации YAML frontmatter в SKILL.md файлах. Все skills должны использовать этот shared parser вместо реализации собственного.

**Используется в:**
- skill-generator
- structured-planning
- validation-framework
- context-awareness
- adaptive-workflow

---

## Frontmatter Format

### Required Fields

```yaml
---
name: string                    # Kebab-case, 3-50 chars, /^[a-z][a-z0-9-]*$/
description: string             # 20-200 chars, informative
version: string                 # Semver format: /^\d+\.\d+\.\d+$/
tags: array<string>             # At least 1 tag, lowercase-with-dashes
dependencies: array<string>     # Skills that this skill depends on (can be empty)
user-invocable: boolean         # true если skill вызывается пользователем (/skill-name)
---
```

### Optional Fields

```yaml
author: string                  # Author name or team
files:                          # File structure declaration
  templates: string             # Glob pattern, e.g., "./templates/*.json"
  schemas: string               # Glob pattern, e.g., "./schemas/*.schema.json"
  examples: string              # Glob pattern, e.g., "./examples/*.md"
  rules: string                 # Glob pattern, e.g., "./rules/*.md"
```

---

## Validation Rules

### Rule 1: Required Fields Check

**Валидация:**
- Все required fields должны присутствовать
- Нет пустых значений (empty string, null, undefined)

**Error messages:**
- `E_MISSING_FIELD`: "Missing required field: {field_name}"
- `E_EMPTY_VALUE`: "Empty value for required field: {field_name}"

---

### Rule 2: Field Type Validation

| Field | Expected Type | Validation |
|-------|---------------|------------|
| `name` | string | Must be string |
| `description` | string | Must be string |
| `version` | string | Must be string |
| `tags` | array | Must be array with length ≥ 1 |
| `dependencies` | array | Must be array (can be empty) |
| `user-invocable` | boolean | Must be true or false |

**Error messages:**
- `E_INVALID_TYPE`: "Invalid type for field {field_name}: expected {expected_type}, got {actual_type}"
- `E_EMPTY_ARRAY`: "Field {field_name} must contain at least 1 element"

---

### Rule 3: Name Format Validation

**Pattern:** `/^[a-z][a-z0-9-]*$/`

**Requirements:**
- Starts with lowercase letter
- Contains only lowercase letters, digits, and hyphens
- Length: 3-50 chars
- No consecutive hyphens (`--`)
- No trailing hyphens

**Valid examples:**
- `context-awareness`
- `git-workflow`
- `api-development`

**Invalid examples:**
- `ContextAwareness` (uppercase)
- `git_workflow` (underscore)
- `-git-workflow` (starts with hyphen)
- `a` (too short)

**Error messages:**
- `E_INVALID_NAME_FORMAT`: "Invalid skill name '{name}': must be kebab-case (lowercase-with-dashes)"
- `E_NAME_TOO_SHORT`: "Skill name too short: minimum 3 characters"
- `E_NAME_TOO_LONG`: "Skill name too long: maximum 50 characters"

---

### Rule 4: Version Semver Validation

**Pattern:** `/^\d+\.\d+\.\d+$/`

**Format:** MAJOR.MINOR.PATCH

**Valid examples:**
- `1.0.0`
- `2.15.3`
- `0.1.0`

**Invalid examples:**
- `1.0` (missing patch)
- `v1.0.0` (has prefix)
- `1.0.0-beta` (has suffix)

**Error messages:**
- `E_INVALID_VERSION`: "Invalid version '{version}': must be semver format (MAJOR.MINOR.PATCH)"

---

### Rule 5: Description Length Validation

**Requirements:**
- Minimum: 20 characters
- Maximum: 200 characters
- Must be informative (not placeholder text like "TODO", "description")

**Prohibited patterns:**
- `/^TODO/i`
- `/^description$/i`
- `/^\.\.\./`

**Error messages:**
- `E_DESCRIPTION_TOO_SHORT`: "Description too short: minimum 20 characters"
- `E_DESCRIPTION_TOO_LONG`: "Description too long: maximum 200 characters"
- `E_PLACEHOLDER_DESCRIPTION`: "Description appears to be placeholder text: '{description}'"

---

### Rule 6: Tags Format Validation

**Requirements:**
- At least 1 tag
- Each tag: kebab-case (lowercase-with-dashes)
- Pattern: `/^[a-z][a-z0-9-]*$/`

**Valid examples:**
```yaml
tags: [planning, bash, integration]
tags: [meta, generator, scaffolding]
```

**Invalid examples:**
```yaml
tags: []  # Empty array
tags: [Planning, BASH]  # Uppercase
tags: [api_development]  # Underscore
```

**Error messages:**
- `E_EMPTY_TAGS`: "Tags array is empty: at least 1 tag required"
- `E_INVALID_TAG_FORMAT`: "Invalid tag '{tag}': must be kebab-case"

---

### Rule 7: Dependencies Validation

**Requirements:**
- Must be array (can be empty)
- Each dependency: valid skill name (kebab-case)
- Each dependency must exist in `skills/` directory
- No circular dependencies

**Circular dependency check algorithm:**
```
FUNCTION check_circular(skill_name, visited_set, current_path):
  IF skill_name IN visited_set:
    THROW CircularDependencyError(current_path)

  visited_set.add(skill_name)
  current_path.append(skill_name)

  dependencies = load_dependencies(skill_name)
  FOR EACH dep IN dependencies:
    check_circular(dep, visited_set, current_path)

  visited_set.remove(skill_name)
  current_path.pop()
```

**Error messages:**
- `E_INVALID_DEPENDENCY_FORMAT`: "Invalid dependency '{dep}': must be valid skill name"
- `E_DEPENDENCY_NOT_FOUND`: "Dependency '{dep}' does not exist in skills/ directory"
- `E_CIRCULAR_DEPENDENCY`: "Circular dependency detected: {path}"

**Example circular dependency:**
```
skill-a → skill-b → skill-c → skill-a
Error: "Circular dependency detected: skill-a → skill-b → skill-c → skill-a"
```

---

## Parsing Algorithm

### Step 1: Extract Frontmatter Block

```
INPUT: SKILL.md file content

1. Split by "---" delimiter
2. Check format:
   - First "---" at line 1
   - Second "---" after YAML content
3. Extract content between delimiters

OUTPUT: Raw YAML string OR error
```

**Error handling:**
- `E_MISSING_FRONTMATTER`: "No YAML frontmatter found (missing --- delimiters)"
- `E_MALFORMED_FRONTMATTER`: "Malformed frontmatter: '---' delimiters not properly positioned"

---

### Step 2: Parse YAML

```
INPUT: Raw YAML string

1. Parse YAML using safe parser
2. Catch syntax errors

OUTPUT: JavaScript object OR error
```

**Error handling:**
- `E_YAML_SYNTAX`: "YAML syntax error at line {line}: {message}"
- `E_YAML_PARSE`: "Failed to parse YAML: {message}"

---

### Step 3: Validate Fields

```
INPUT: Parsed YAML object

1. Run Rule 1: Check required fields
2. Run Rule 2: Validate field types
3. Run Rule 3: Validate name format
4. Run Rule 4: Validate version semver
5. Run Rule 5: Validate description length
6. Run Rule 6: Validate tags format
7. Run Rule 7: Validate dependencies

OUTPUT: Validated frontmatter object OR array of errors
```

---

## Usage in Skills

### Import and Use

Skills должны ссылаться на этот parser следующим образом:

```markdown
## Frontmatter Parsing

Use `@shared:frontmatter-parser` for parsing and validating YAML frontmatter.

**Example:**
See [@shared:frontmatter-parser](../_shared/frontmatter-parser.md) for:
- Validation rules
- Error messages
- Parsing algorithm
```

### Migration from Legacy Code

**Before (дублированный код в skill):**
```
Parse frontmatter manually:
1. Split by "---"
2. Parse YAML
3. Validate fields (custom logic)
```

**After (использование shared parser):**
```
Use @shared:frontmatter-parser:
1. Refer to validation rules
2. Use standard error messages
3. Follow parsing algorithm
```

---

## Error Recovery Strategies

### E_MISSING_FIELD: Auto-fix not possible
- **Action:** Prompt user to add field
- **Suggestion:** Provide default value based on context

### E_INVALID_NAME_FORMAT: Auto-fix possible
- **Action:** Convert to kebab-case
- **Suggestion:** `ContextAwareness` → `context-awareness`

### E_INVALID_VERSION: Auto-fix possible
- **Action:** Add `.0.0` if missing
- **Suggestion:** `1` → `1.0.0`

### E_CIRCULAR_DEPENDENCY: Auto-fix not possible
- **Action:** Show dependency path
- **Suggestion:** User must remove one dependency from cycle

---

## Testing

### Valid Frontmatter Example

```yaml
---
name: example-skill
description: This is an example skill for testing frontmatter parser
version: 1.0.0
tags: [example, testing]
dependencies: [thinking-framework, context-awareness]
user-invocable: true
author: iclaude Skills Team
---
```

**Expected:** Pass all validations

---

### Invalid Frontmatter Examples

**Test Case 1: Missing required field**
```yaml
---
name: example-skill
description: This is an example
# version field missing
tags: [example]
dependencies: []
user-invocable: true
---
```
**Expected:** `E_MISSING_FIELD: Missing required field: version`

---

**Test Case 2: Invalid name format**
```yaml
---
name: ExampleSkill
description: This is an example skill for testing
version: 1.0.0
tags: [example]
dependencies: []
user-invocable: true
---
```
**Expected:** `E_INVALID_NAME_FORMAT: Invalid skill name 'ExampleSkill': must be kebab-case`

---

**Test Case 3: Circular dependency**

skill-a.md:
```yaml
dependencies: [skill-b]
```

skill-b.md:
```yaml
dependencies: [skill-a]
```

**Expected:** `E_CIRCULAR_DEPENDENCY: Circular dependency detected: skill-a → skill-b → skill-a`

---

## Version History

- **1.0.0** (2026-01-15): Initial version
  - Стандартизация format frontmatter
  - 7 validation rules
  - Error handling и recovery strategies

---

## References

- [skill-generator/SKILL.md](../skill-generator/SKILL.md) - Original validation logic
- [validation-framework/SKILL.md](../validation-framework/SKILL.md) - Frontmatter validation
- [YAML 1.2 Specification](https://yaml.org/spec/1.2/spec.html)
