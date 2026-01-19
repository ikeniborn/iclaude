# Architecture Validation Examples

## Example 1: Successful Review (No Issues)

### Input

```bash
# Modified files
git diff --name-only
iclaude.sh  # Lines 60-88 (validate-proxy-url function)

# Architecture state
docs/architecture/overview.yaml  # Valid, no cycles, proper layers
```

### Execution

```
[Architecture Validation]
✓ Checking architecture availability... OK
✓ Parsing overview.yaml... 48 components, 4 layers
✓ Determining scope...
  - Modified: validate-proxy-url
  - Dependents: proxy-management, cli-main
  - Total scope: 3 components
✓ Referential integrity... PASSED
✓ Circular dependencies... PASSED
✓ Layer boundaries... PASSED
✓ Component validation... PASSED
```

### Output

```json
{
  "code_review": {
    "score": 100,
    "passed": true,
    "blocking_issues": [],
    "metrics": {
      "architecture_compliance": {
        "score": 25,
        "max": 25,
        "issues": 0,
        "checks_run": [
          "referential_integrity",
          "circular_dependencies",
          "component_validation",
          "layer_boundaries"
        ],
        "scope": {
          "modified_components": ["validate-proxy-url"],
          "dependent_components": ["proxy-management", "cli-main"],
          "total_checked": 3
        }
      }
    },
    "architecture_available": true
  }
}
```

---

## Example 2: Blocked Review (Circular Dependency)

### Input

```yaml
# docs/architecture/overview.yaml
components:
  - id: cli-main
    dependencies:
      - component_id: proxy-management

  - id: proxy-management
    dependencies:
      - component_id: credential-storage

  - id: credential-storage
    dependencies:
      - component_id: cli-main  # ← Cycle!
```

### Execution

```
[Architecture Validation]
✓ Parsing overview.yaml...
✓ Referential integrity... PASSED
✗ Circular dependencies... FAILED (1 cycle found)
  Cycle: cli-main → proxy-management → credential-storage → cli-main
```

### Output

```json
{
  "code_review": {
    "score": 60,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "circular_dependency",
        "cycle_path": "cli-main → proxy-management → credential-storage → cli-main",
        "message": "Circular dependency detected",
        "suggestion": "Break cycle by introducing dependency injection or mediator pattern"
      }
    ],
    "metrics": {
      "architecture_compliance": {
        "score": 5,
        "max": 25,
        "issues": 1
      }
    }
  }
}
```

---

## Example 3: Layer Violation

### Input

```yaml
# docs/architecture/overview.yaml
layers:
  - id: cli
    level: 1
  - id: core
    level: 2
  - id: infrastructure
    level: 3

components:
  - id: credential-storage
    layer: infrastructure  # Level 3 (lowest)
    dependencies:
      - component_id: oauth-token-management  # oauth в core (level 2)
```

### Execution

```
[Architecture Validation]
✓ Parsing overview.yaml...
✓ Referential integrity... PASSED
✓ Circular dependencies... PASSED
✗ Layer boundaries... FAILED (1 violation)
  Violation: credential-storage (infrastructure) → oauth-token-management (core)
```

### Output

```json
{
  "code_review": {
    "score": 70,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "layer_violation",
        "component": "credential-storage",
        "layer": "infrastructure",
        "depends_on": "oauth-token-management",
        "depends_on_layer": "core",
        "message": "Layer violation: infrastructure depends on core (upward dependency)",
        "suggestion": "Move oauth-token-management to infrastructure layer OR remove dependency OR introduce adapter pattern"
      }
    ]
  }
}
```

---

## Example 4: Undocumented Component

### Input

```bash
# Modified file
git diff --name-only
iclaude.sh  # Added new function at line 3850

# docs/architecture/overview.yaml
# No component with file_path matching "iclaude.sh:3850-*"
```

### Execution

```
[Architecture Validation]
✓ Parsing overview.yaml...
✗ Component validation... FAILED (1 undocumented file)
  File: iclaude.sh (no matching component for changes at line 3850)
```

### Output

```json
{
  "code_review": {
    "score": 65,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "undocumented_component",
        "file": "iclaude.sh",
        "line_range": "3850-?",
        "message": "Modified code not documented in architecture",
        "suggestion": "Add component to docs/architecture/overview.yaml or update existing component's file_path"
      }
    ]
  }
}
```

---

## Example 5: Graceful Degradation (No Architecture)

### Input

```bash
# Architecture file missing
ls docs/architecture/
# (directory does not exist)
```

### Execution

```
[Architecture Validation]
! docs/architecture/overview.yaml not found
→ Triggering @skill:architecture-documentation to generate
→ Waiting for architecture generation...
→ Retrying architecture validation with generated docs...
```

### Output (After Generation)

```json
{
  "code_review": {
    "score": 100,
    "passed": true,
    "blocking_issues": [],
    "metrics": {
      "architecture_compliance": {
        "score": 25,
        "max": 25,
        "issues": 0,
        "$comment": "Architecture generated automatically by architecture-documentation skill"
      }
    },
    "architecture_available": true,
    "architecture_generated": true
  }
}
```

---

## Example 6: Unknown Schema Format

### Input

```yaml
# docs/architecture/custom-format.yaml
# Нестандартная структура без распознаваемых полей
myproject:
  modules:
    - name: ModuleA
      uses: [ModuleB]
```

### Execution

```
[Architecture Validation]
✓ Found architecture file: docs/architecture/custom-format.yaml
✗ Unknown schema format detected
→ Triggering @skill:architecture-documentation to standardize
```

### Output

```json
{
  "code_review": {
    "score": 0,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "unknown_schema",
        "message": "Architecture file found but structure not recognized",
        "files_found": ["docs/architecture/custom-format.yaml"],
        "suggestion": "Run @skill:architecture-documentation to standardize",
        "action": "trigger_skill"
      }
    ],
    "architecture_available": false
  }
}
```

---

## Example 7: Missing Dependencies (Parser Unavailable)

### Input

```bash
# yq and Python not installed
which yq
# (not found)

which python3
# (not found)
```

### Execution

```
[Architecture Validation]
✗ Missing required dependencies: yq or Python
→ Cannot parse YAML architecture
```

### Output

```json
{
  "code_review": {
    "score": 0,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "missing_dependencies",
        "message": "Required tools not installed: jq, yq or Python",
        "suggestion": "Install dependencies: npm install -g yq OR pip install PyYAML"
      }
    ],
    "architecture_available": false
  }
}
```

---

## Example 8: Hybrid Scope (Modified + Dependents)

### Input

```yaml
# docs/architecture/overview.yaml
components:
  - id: validate-proxy-url
    file_path: "iclaude.sh:60-88"
    dependencies: []

  - id: proxy-management
    file_path: "iclaude.sh:1343-1666"
    dependencies:
      - component_id: validate-proxy-url

  - id: cli-main
    file_path: "iclaude.sh:2996-3325"
    dependencies:
      - component_id: proxy-management

# Modified file
git diff --name-only
iclaude.sh  # Changes in validate-proxy-url function
```

### Execution

```
[Architecture Validation]
✓ Determining scope (hybrid mode)...
  1. Modified component: validate-proxy-url
  2. Direct dependent: proxy-management
  3. Indirect dependent: cli-main
  → Checking 3 components total

✓ All checks passed for scope
```

### Output

```json
{
  "code_review": {
    "metrics": {
      "architecture_compliance": {
        "scope": {
          "modified_components": ["validate-proxy-url"],
          "dependent_components": ["proxy-management", "cli-main"],
          "total_checked": 3
        }
      }
    }
  }
}
```

---

## Example 9: Referential Integrity Violation

### Input

```yaml
# docs/architecture/overview.yaml
components:
  - id: oauth-token-management
    dependencies:
      - component_id: jq-validator  # ← Компонент не существует!
      - component_id: credential-storage

  - id: credential-storage
    dependencies: []
```

### Execution

```
[Architecture Validation]
✗ Referential integrity... FAILED (1 broken dependency)
  Component: oauth-token-management
  Missing dependency: jq-validator
```

### Output

```json
{
  "code_review": {
    "score": 70,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "referential_integrity",
        "component": "oauth-token-management",
        "dependency": "jq-validator",
        "file": "docs/architecture/overview.yaml",
        "message": "Dependency 'jq-validator' not found in components list",
        "suggestion": "Add component 'jq-validator' to overview.yaml or remove from dependencies"
      }
    ]
  }
}
```

---

## Summary

| Scenario | Result | Action |
|----------|--------|--------|
| Valid architecture, no issues | ✅ Pass | Continue commit |
| Circular dependency | ❌ Block | Fix cycle before commit |
| Layer violation | ❌ Block | Refactor dependencies |
| Undocumented component | ❌ Block | Update architecture docs |
| Missing architecture | ❌ Block | Auto-generate via skill |
| Unknown schema | ❌ Block | Standardize via skill |
| Missing parser | ❌ Block | Install yq/Python |
| Hybrid scope check | ✅ Pass | Validates modified + dependents |
| Referential integrity fail | ❌ Block | Fix broken dependencies |

---

## Integration with architecture-documentation

**Automatic workflow** при отсутствии архитектуры:

```
STEP 1: code-review обнаруживает отсутствие docs/architecture/
  ↓
STEP 2: Создает BLOCKING issue с action: "trigger_skill"
  ↓
STEP 3: Автоматически вызывает @skill:architecture-documentation --generate
  ↓
STEP 4: architecture-documentation skill генерирует overview.yaml
  ↓
STEP 5: code-review повторно запускает валидацию
  ↓
STEP 6: Архитектурные проверки выполняются успешно
```
