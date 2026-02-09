# Semantic Validation Rules

Алгоритмы для Level 2 валидации (семантическая согласованность плана).

## Check 1: Solution Addresses Problem

### Цель
Проверить, что предложенное решение (solution) действительно решает описанную проблему (problem).

### Алгоритм

#### Step 1: Extract Keywords from Problem
```
problem_keywords = extract_keywords(problem_section)
  - Tokenize text (split by whitespace, punctuation)
  - Remove stop words (the, a, an, is, are, etc.)
  - Stem/lemmatize remaining words
  - Extract technical terms (e.g., "authentication", "JWT", "database")
```

**Example:**
```
Problem: "User authentication fails when JWT token expires"
Keywords: ["user", "authentication", "fail", "JWT", "token", "expire"]
```

#### Step 2: Extract Keywords from Solution
```
solution_keywords = extract_keywords(solution_section)
```

**Example:**
```
Solution: "Implement JWT refresh token mechanism with 1-hour expiry"
Keywords: ["implement", "JWT", "refresh", "token", "mechanism", "hour", "expiry"]
```

#### Step 3: Calculate Correlation

**Method 1: Keyword Overlap (Simple)**
```
common_keywords = problem_keywords ∩ solution_keywords
correlation = |common_keywords| / |problem_keywords|
```

**Example:**
```
common_keywords = ["JWT", "token"]
correlation = 2 / 6 = 0.33
```

**Method 2: Weighted Overlap (Advanced)**
```
weight(keyword) = TF-IDF score or technical term boost
correlation = Σ(weight(k) for k in common_keywords) / Σ(weight(k) for k in problem_keywords)
```

#### Step 4: Evaluate Confidence

```
if correlation >= 0.6:
    status = "passed"
    confidence = correlation
else:
    status = "failed"
    confidence = correlation
    blocking_issue = "solution_confidence_low"
```

### Thresholds

- **Minimal plans**: confidence >= 0.5 (relaxed)
- **Standard plans**: confidence >= 0.6
- **Complex plans**: confidence >= 0.7 (strict)

### Example Results

**High confidence (passed):**
```
Problem: "Add user authentication to API"
Solution: "Implement JWT-based authentication middleware with bcrypt password hashing"
Confidence: 0.85 ✅
```

**Low confidence (failed):**
```
Problem: "Fix database connection timeout errors"
Solution: "Refactor frontend routing to use React Router v6"
Confidence: 0.1 ❌ BLOCKING
```

---

## Check 2: Steps Lead to Solution

### Цель
Проверить, что implementation steps покрывают все аспекты solution.

### Алгоритм

#### Step 1: Extract Actions from Solution
```
solution_actions = extract_actions(solution_section)
  - Identify verbs (implement, add, update, configure, etc.)
  - Identify objects (what is being modified)
  - Group into action units
```

**Example:**
```
Solution: "Implement JWT auth with refresh tokens and rate limiting"
Actions:
  1. "implement JWT auth"
  2. "add refresh tokens"
  3. "configure rate limiting"
```

#### Step 2: Extract Actions from Steps
```
step_actions = []
for step in implementation_steps:
    step_actions.extend(extract_actions(step.description))
```

**Example:**
```
Steps:
  1. "Create JWT service with sign/verify methods"
  2. "Add refresh token endpoint"
  3. "Implement rate limiter middleware"

Step Actions:
  1. "create JWT service", "add sign method", "add verify method"
  2. "add refresh token endpoint"
  3. "implement rate limiter"
```

#### Step 3: Calculate Coverage

```
covered_actions = []
for solution_action in solution_actions:
    for step_action in step_actions:
        if is_similar(solution_action, step_action):
            covered_actions.append(solution_action)
            break

coverage = |covered_actions| / |solution_actions|
```

**Similarity check:**
```
is_similar(action1, action2):
    # Check keyword overlap (>= 60%)
    # OR check semantic similarity (embedding vectors, cosine similarity >= 0.7)
```

#### Step 4: Evaluate Coverage

```
if coverage >= 0.7:
    status = "passed"
else:
    status = "failed"
    blocking_issue = "steps_coverage_low"
    missing_actions = solution_actions - covered_actions
```

### Thresholds

- **Minimal plans**: coverage >= 0.6
- **Standard plans**: coverage >= 0.7
- **Complex plans**: coverage >= 0.8

### Example Results

**High coverage (passed):**
```
Solution Actions: ["implement JWT", "add refresh tokens", "add rate limiting"]
Step Actions: ["create JWT service", "add refresh endpoint", "implement rate limiter", "add tests"]
Coverage: 3/3 = 1.0 ✅
```

**Low coverage (failed):**
```
Solution Actions: ["implement auth", "add rate limiting", "add logging"]
Step Actions: ["create auth middleware", "add tests"]
Coverage: 1/3 = 0.33 ❌ BLOCKING
Missing: ["add rate limiting", "add logging"]
```

---

## Check 3: File Alignment

### Цель
Проверить, что все файлы упомянутые в steps присутствуют в critical_files.

### Алгоритм

#### Step 1: Extract File Paths from Steps

```
step_files = []
for step in implementation_steps:
    # Regex patterns for file paths
    patterns = [
        r'\b[\w\-\.]+/[\w\-\./]+\.(js|ts|py|go|rs|java|etc)\b',  # path/to/file.ext
        r'\b[\w\-\.]+\.(js|ts|py|go|rs|java|etc)\b',              # file.ext
        r'`([^`]+\.(js|ts|py|go|rs|java|etc))`',                  # `file.ext` (markdown code)
    ]

    for pattern in patterns:
        matches = re.findall(pattern, step.description)
        step_files.extend(matches)

# Normalize paths (remove ./, resolve ../, etc.)
step_files = [normalize_path(f) for f in step_files]
step_files = list(set(step_files))  # Remove duplicates
```

**Example:**
```
Step 3: "Update src/auth/jwt_service.py with refresh token logic"
Step 5: "Add tests in tests/test_jwt_service.py"

Extracted: ["src/auth/jwt_service.py", "tests/test_jwt_service.py"]
```

#### Step 2: Get Critical Files List

```
critical_files = [f.file_path for f in plan.critical_files]
critical_files = [normalize_path(f) for f in critical_files]
```

**Example:**
```
Critical Files:
  - src/auth/jwt_service.py
  - src/middleware/auth.py
```

#### Step 3: Find Missing Files

```
missing_files = []
for step_file in step_files:
    if step_file not in critical_files:
        # Check if it's a new file (change_type == "create")
        # New files don't need to be in critical_files before creation
        if not is_new_file(step_file, plan):
            missing_files.append(step_file)
```

**is_new_file() logic:**
```
is_new_file(file_path, plan):
    # Check if step says "create" or "add new file"
    # OR check if file is in critical_files with change_type == "create"
```

#### Step 4: Evaluate Alignment

```
if missing_files.length == 0:
    status = "passed"
else:
    status = "failed"
    for missing_file in missing_files:
        blocking_issue = {
            "issue": "file_alignment_mismatch",
            "message": f"Step references {missing_file} not in Critical Files",
            "suggestion": f"Add {missing_file} to Critical Files section",
            "missing_file": missing_file
        }
```

### Whitelisting (Ignore Patterns)

Ignore файлы которые не нужно явно указывать в critical_files:

```
ignore_patterns = [
    "node_modules/",
    ".git/",
    "__pycache__/",
    "*.pyc",
    "package-lock.json",
    "yarn.lock"
]
```

### Example Results

**Aligned (passed):**
```
Step Files: ["src/auth/jwt.py", "src/middleware/auth.py"]
Critical Files: ["src/auth/jwt.py", "src/middleware/auth.py", "tests/test_auth.py"]
Status: ✅ passed (all step files in critical_files)
```

**Misaligned (failed):**
```
Step Files: ["src/auth/jwt.py", "tests/test_jwt.py"]
Critical Files: ["src/auth/jwt.py"]
Missing: ["tests/test_jwt.py"]
Status: ❌ BLOCKING
Suggestion: Add tests/test_jwt.py to Critical Files section
```

---

## Check 4: No Contradictions

### Цель
Проверить отсутствие противоречивых утверждений в плане.

### Алгоритм

#### Step 1: Extract Statements

```
statements = []
for section in [problem, solution, steps]:
    # Extract sentences
    sentences = split_sentences(section)
    for sentence in sentences:
        statements.append({
            "text": sentence,
            "section": section_name,
            "actions": extract_actions(sentence)
        })
```

#### Step 2: Detect Contradictions

**Pattern 1: Opposite Actions**
```
contradictions = []
for i, stmt1 in enumerate(statements):
    for stmt2 in statements[i+1:]:
        if is_contradiction(stmt1, stmt2):
            contradictions.append((stmt1, stmt2))

is_contradiction(stmt1, stmt2):
    # Check for opposite verbs (add vs remove, create vs delete, enable vs disable)
    # on the same object

    Examples:
    - "Add field user_id to table" vs "Remove field user_id from table"
    - "Enable rate limiting" vs "Disable rate limiting"
    - "Create database index" vs "Drop database index"
```

**Pattern 2: Incompatible Requirements**
```
Examples:
- "Use SQLite database" vs "Connect to PostgreSQL"
- "Store in local file" vs "Send to remote API"
- "Synchronous execution" vs "Async with promises"
```

#### Step 3: Evaluate

```
if contradictions.length == 0:
    status = "passed"
else:
    status = "failed"
    for (stmt1, stmt2) in contradictions:
        blocking_issue = {
            "issue": "contradiction_detected",
            "message": f"Contradiction: '{stmt1.text}' vs '{stmt2.text}'",
            "suggestion": "Resolve contradiction before execution"
        }
```

### Example Results

**No contradictions (passed):**
```
Step 1: "Add JWT authentication middleware"
Step 3: "Configure JWT expiry to 1 hour"
Status: ✅ passed (complementary statements)
```

**Contradiction (failed):**
```
Step 2: "Store tokens in Redis cache"
Step 4: "Remove Redis dependency, use in-memory storage"
Status: ❌ BLOCKING
Message: "Contradiction: 'Store tokens in Redis' vs 'Remove Redis dependency'"
```

---

## Summary

Все 4 семантических проверки являются **BLOCKING** для всех plan_type (minimal/standard/complex).

**Score distribution:**
- solution_addresses_problem: 25% (6.25 points)
- steps_lead_to_solution: 25% (6.25 points)
- file_alignment: 25% (6.25 points)
- no_contradictions: 25% (6.25 points)

**Total:** 25 points для semantic_validation level.
