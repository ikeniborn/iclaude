# Example: Simple System Skill - Automatic File Cleanup

## Scenario

Create a system skill that automatically cleans up temporary files older than N days with configurable file patterns.

**Requirements:**
- Skill type: system (автоматический, не вызывается пользователем)
- Complexity: minimal (нет complexity levels)
- Output: JSON only
- Templates: input + output (default)
- Features: examples only

## Interactive Q&A Session

```
/skill-generator

Q1: Enter skill name (kebab-case):
> cleanup-automation

✅ Valid name

Q2: Select skill type:
1. system
2. user-invocable
3. bash-utility
4. integration

> 1

✅ Type: system

Q3: Brief description (20-200 chars):
> Automatic cleanup of temporary files older than configured days with pattern matching

✅ Description accepted (85 chars)

Q4: Dependencies (comma-separated, or Enter to skip):
> (Enter pressed)

✅ No dependencies

Q5: Support complexity levels (minimal/standard/complex)? (Y/n):
> n

✅ Single template mode

Q6: Output format:
1. JSON
2. YAML
3. Markdown
4. Text
5. Mixed

> 1

✅ Format: JSON

Q7: Templates (comma-separated, or Enter for default):
> (Enter pressed)

✅ Templates: input, output

Q8: Features (comma-separated or Enter):
- rules
- examples
- shared-data

> examples

✅ Features: examples
```

## Generated Files

### 1. SKILL.md

```yaml
---
name: Cleanup Automation
description: Automatic cleanup of temporary files older than configured days with pattern matching
version: 1.0.0
tags: [system, automation, cleanup, filesystem]
dependencies: []
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
user-invocable: false
---

# Cleanup Automation

[Full content with When to Use, How It Works, Output Format, etc.]
```

### 2. templates/input.json

```json
{
  "$comment": "Input template for cleanup-automation skill",
  "cleanup_config": {
    "directories": ["{{directory: string}}"],
    "patterns": ["{{pattern: string}}"],
    "max_age_days": "{{age: integer, min 1}}",
    "dry_run": "{{dry_run: boolean, default: true}}"
  }
}
```

### 3. templates/output.json

```json
{
  "$comment": "Output template for cleanup-automation skill",
  "cleanup_result": {
    "status": "{{status: enum: success|partial|failed}}",
    "files_found": "{{count: integer}}",
    "files_deleted": "{{count: integer}}",
    "total_size_bytes": "{{size: integer}}"
  }
}
```

### 4. schemas/input.schema.json (auto-generated)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "cleanup_config": {
      "type": "object",
      "properties": {
        "directories": {
          "type": "array",
          "items": {"type": "string"}
        },
        "patterns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "max_age_days": {
          "type": "integer",
          "minimum": 1
        },
        "dry_run": {
          "type": "boolean",
          "default": true
        }
      },
      "required": ["directories", "patterns", "max_age_days"]
    }
  }
}
```

### 5. schemas/output.schema.json (auto-generated)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "cleanup_result": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["success", "partial", "failed"]
        },
        "files_found": {"type": "integer"},
        "files_deleted": {"type": "integer"},
        "total_size_bytes": {"type": "integer"}
      },
      "required": ["status", "files_found", "files_deleted", "total_size_bytes"]
    }
  }
}
```

### 6. examples/basic-usage.md

```markdown
# Basic Usage Example

## Scenario
Clean up .tmp files older than 7 days from /tmp directory

## Input
```json
{
  "cleanup_config": {
    "directories": ["/tmp"],
    "patterns": ["*.tmp"],
    "max_age_days": 7,
    "dry_run": true
  }
}
```

## Output
```json
{
  "cleanup_result": {
    "status": "success",
    "files_found": 15,
    "files_deleted": 0,
    "total_size_bytes": 52428800
  }
}
```
```

## Validation Results

```
✅ YAML Frontmatter: PASSED
✅ JSON Templates: PASSED
✅ JSON Schemas: PASSED
⚠️  Markdown Formatting: WARNING (No FAQ section)
✅ File Structure: PASSED

Overall Status: SUCCESS (1 warning)
```

## Next Steps

1. **Review generated files:**
   ```bash
   cd .claude/skills/cleanup-automation/
   cat SKILL.md
   ```

2. **Customize if needed:**
   - Edit templates for additional fields
   - Schemas will auto-regenerate

3. **Test the skill:**
   - Skill auto-invokes in workflow

4. **Commit to git:**
   ```bash
   git add skills/cleanup-automation/
   git commit -m "feat(skills): add cleanup-automation system skill"
   ```

## Time Saved

**Without skill-generator:** ~2-3 hours (manual SKILL.md + templates + schemas)
**With skill-generator:** ~5 minutes (Q&A + review)

**ROI:** 24-36x time savings
