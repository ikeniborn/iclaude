# Technical Validation Rules

Алгоритмы для Level 3 валидации (техническая корректность). Все проверки генерируют **WARNING** (не BLOCKING).

## Check 1: Files Exist

### Цель
Проверить, что файлы с `change_type: modify` существуют в репозитории.

### Алгоритм

```
for file in critical_files:
    if file.change_type == "modify":
        # Use Glob tool to check existence
        result = glob(file.file_path)

        if result.length == 0:
            warning = {
                "warning": "file_not_found",
                "message": f"File {file.file_path} marked for modify but not found",
                "suggestion": f "Change change_type to 'create' or verify path",
                "file_path": file.file_path
            }
```

### Handling False Positives

```
# Ignore warnings for files that may not exist yet:
ignore_if_mentioned_in_steps_as_create = [
    "Step X: Create new file {file_path}"
]

# Ignore warnings for generated files:
ignore_patterns = [
    "*.pyc",
    "__pycache__/",
    "node_modules/",
    "dist/",
    "build/"
]
```

### Example Results

**File exists (passed):**
```
File: src/auth/jwt.py (change_type: modify)
Glob result: ["src/auth/jwt.py"]
Status: ✅ passed
```

**File не существует (warning):**
```
File: src/auth/new_feature.py (change_type: modify)
Glob result: []
Status: ⚠️ WARNING
Message: "File src/auth/new_feature.py marked for modify but not found"
Suggestion: "Change change_type to 'create' or verify path"
```

---

## Check 2: Validation Commands Valid Syntax

### Цель
Проверить синтаксис команд из `verification.validation_commands`.

### Алгоритм

```
for command in verification.validation_commands:
    # Parse command (detect command name)
    cmd_name = command.split()[0]

    # Check if command exists
    result = which(cmd_name)
    if result is None:
        warning = {
            "warning": "command_not_found",
            "message": f"Validation command '{cmd_name}' not found in PATH",
            "suggestion": f"Install {cmd_name} or use alternative command"
        }

    # Language-specific syntax validation
    if cmd_name == "pytest":
        validate_pytest_syntax(command)
    elif cmd_name == "npm":
        validate_npm_syntax(command)
    # ... etc
```

### Language-Specific Validators

**pytest:**
```
validate_pytest_syntax(command):
    # Check for common mistakes
    if "--cov" in command and "pytest-cov" not in installed_plugins:
        warning = "pytest-cov plugin not installed"

    if re.match(r"pytest .+ -v -v", command):
        warning = "Duplicate -v flag (use -vv instead)"
```

**npm:**
```
validate_npm_syntax(command):
    if "npm run" in command:
        script_name = command.split("npm run ")[1].split()[0]
        # Check if script exists in package.json
        if script_name not in package_json.scripts:
            warning = f"Script '{script_name}' not found in package.json"
```

### Example Results

**Valid syntax (passed):**
```
Command: "pytest tests/ -v"
Status: ✅ passed
```

**Invalid syntax (warning):**
```
Command: "npm run type-check"
package.json scripts: {"test": "jest", "lint": "eslint"}
Status: ⚠️ WARNING
Message: "Script 'type-check' not found in package.json"
Suggestion: "Add 'type-check' script or use 'npm run test'"
```

---

## Check 3: Git Branch Pattern

### Цель
Проверить соответствие `branch_name` рекомендуемому паттерну.

### Regex Pattern

```regex
^(feature|fix|refactor|dev|chore|test|docs)/[a-z0-9_-]+$
```

**Prefixes:**
- `feature/` - новая функциональность
- `fix/` - исправление бага
- `refactor/` - рефакторинг кода
- `dev/` - development/experimental
- `chore/` - обслуживание (deps, config)
- `test/` - добавление тестов
- `docs/` - документация

**Naming:**
- Lowercase (a-z)
- Digits (0-9)
- Underscore (_) и hyphen (-) разрешены
- No uppercase, no special chars

### Алгоритм

```
branch_name = plan.git_info.branch_name

if re.match(r"^(feature|fix|refactor|dev|chore|test|docs)/[a-z0-9_-]+$", branch_name):
    status = "passed"
else:
    # Detect specific issues
    issues = []

    # Check prefix
    if not re.match(r"^(feature|fix|refactor|dev|chore|test|docs)/", branch_name):
        issues.append("Missing or invalid prefix (use feature/, fix/, etc.)")

    # Check case
    if re.search(r"[A-Z]", branch_name):
        issues.append("Contains uppercase letters (use lowercase)")
        suggestion = branch_name.lower()

    # Check special chars
    if re.search(r"[^a-z0-9_/-]", branch_name):
        issues.append("Contains invalid characters (use only a-z, 0-9, _, -)")

    warning = {
        "warning": "git_branch_pattern_invalid",
        "message": f"Branch name '{branch_name}' doesn't match pattern",
        "issues": issues,
        "suggestion": f"Use pattern: prefix/lowercase-name (e.g., {suggestion})"
    }
```

### Example Results

**Valid pattern (passed):**
```
Branch: "feature/jwt-auth"
Status: ✅ passed
```

**Invalid pattern (warning):**
```
Branch: "Feature/JWT-Auth"
Status: ⚠️ WARNING
Issues:
  - Contains uppercase letters (use lowercase)
Suggestion: "Use feature/jwt-auth"
```

**Missing prefix (warning):**
```
Branch: "jwt-auth"
Status: ⚠️ WARNING
Issues:
  - Missing or invalid prefix (use feature/, fix/, etc.)
Suggestion: "Use feature/jwt-auth or fix/jwt-auth"
```

---

## Check 4: Commit Type Valid

### Цель
Проверить, что `commit_type` соответствует Conventional Commits спецификации.

### Valid Types (Enum)

```
valid_types = [
    "feat",      # New feature
    "fix",       # Bug fix
    "refactor",  # Code refactor (no behavior change)
    "docs",      # Documentation only
    "test",      # Adding/updating tests
    "chore",     # Maintenance (deps, config, build)
    "perf",      # Performance improvement
    "style"      # Code style (formatting, no logic change)
]
```

### Алгоритм

```
commit_type = plan.git_info.commit_type

if commit_type in valid_types:
    status = "passed"
else:
    # Suggest closest match
    suggestions = fuzzy_match(commit_type, valid_types, threshold=0.6)

    warning = {
        "warning": "commit_type_invalid",
        "message": f"Commit type '{commit_type}' not in valid types",
        "valid_types": valid_types,
        "suggestions": suggestions
    }
```

### Fuzzy Matching

```
fuzzy_match(input, valid_types, threshold):
    matches = []
    for valid_type in valid_types:
        # Levenshtein distance or similar
        similarity = calculate_similarity(input, valid_type)
        if similarity >= threshold:
            matches.append((valid_type, similarity))

    return sorted(matches, key=lambda x: x[1], reverse=True)
```

### Example Results

**Valid type (passed):**
```
Commit Type: "feat"
Status: ✅ passed
```

**Invalid type (warning):**
```
Commit Type: "update"
Status: ⚠️ WARNING
Message: "Commit type 'update' not in valid types"
Suggestions: ["feat" (similarity: 0.3), "fix" (similarity: 0.2)]
Use "feat" for new features or "fix" for bug fixes
```

**Typo (warning):**
```
Commit Type: "fature"
Status: ⚠️ WARNING
Suggestions: ["feat" (similarity: 0.83)]
Message: "Did you mean 'feat'?"
```

---

## Check 5: JSON Schema Compliance

### Цель
Проверить, что task_plan.json соответствует JSON Schema из structured-planning.

### Алгоритм

```
# Load schema from structured-planning
schema_path = "@shared:structured-planning/schemas/{plan_type}-task-plan.schema.json"
schema = load_json_schema(schema_path)

# Validate plan against schema
result = validate_json_schema(task_plan, schema)

if result.valid:
    status = "passed"
else:
    for error in result.errors:
        warning = {
            "warning": "json_schema_violation",
            "message": f"Schema violation at {error.path}: {error.message}",
            "field": error.path,
            "error": error.message
        }
```

### Example Results

**Valid schema (passed):**
```
Plan Type: "standard"
Schema: standard-task-plan.schema.json
Validation: ✅ passed
```

**Schema violation (warning):**
```
Plan Type: "complex"
Schema: complex-task-plan.schema.json
Error: "Missing required field 'risks'"
Status: ⚠️ WARNING
Message: "Schema violation at .risks: Missing required field"
Suggestion: "Add 'risks' section for complex plans"
```

---

## Score Calculation

Technical validation awards points даже при warnings (warnings не снижают score):

```
technical_score = 0
max_technical_score = 25

checks = [
    files_exist,
    validation_commands_valid,
    git_branch_pattern,
    commit_type_valid,
    json_schema_compliance
]

points_per_check = max_technical_score / len(checks)  # 5 points each

for check in checks:
    if check.status == "passed":
        technical_score += points_per_check
    elif check.status == "warning":
        # Still award points (warnings don't reduce score)
        technical_score += points_per_check * 0.8  # 80% of points
```

**Example:**
```
Checks:
  files_exist: passed (5 points)
  validation_commands_valid: passed (5 points)
  git_branch_pattern: warning (4 points)
  commit_type_valid: passed (5 points)
  json_schema_compliance: passed (5 points)

Total: 24/25 points
```

---

## Summary

Все technical validation checks генерируют **WARNING** (никогда не BLOCKING).

**Цель:** Помочь улучшить качество плана, но не блокировать execution.

**Score:** 25 points max, распределенные по 5 checks (5 points each).
