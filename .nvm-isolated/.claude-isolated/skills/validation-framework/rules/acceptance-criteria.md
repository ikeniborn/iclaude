# Acceptance Criteria Validation Rules

Алгоритмы для проверки acceptance criteria из task_plan.

## Parsing Acceptance Criteria

```
acceptance_criteria = task_plan.verification.acceptance_criteria

# Each criterion is a string describing expected outcome
# Examples:
#   "Login endpoint returns 200 OK with valid JWT"
#   "User model has email field"
#   "Performance < 100ms"
```

## Verification Logic

### Step 1: Classify Criterion Type

```
criterion_type = classify(criterion)

Types:
  - "response_code" → Check HTTP response
  - "file_contains" → Check file content
  - "performance" → Measure execution time
  - "test_passes" → Run specific test
  - "manual" → Requires manual verification
```

### Step 2: Verify Criterion

```
# Example: "Login endpoint returns 200 OK"
if criterion_type == "response_code":
    # Extract endpoint from criterion
    endpoint = extract_endpoint(criterion)  # "/api/login"
    expected_code = extract_code(criterion)  # 200

    # Make request
    response = http_request(endpoint)

    if response.status_code == expected_code:
        status = "met"
    else:
        status = "not_met"
        error = f"Expected {expected_code}, got {response.status_code}"

# Example: "User model has email field"
elif criterion_type == "file_contains":
    file_path = extract_file_path(criterion)  # "src/models/user.py"
    pattern = extract_pattern(criterion)      # "email.*=.*CharField"

    file_content = read_file(file_path)

    if re.search(pattern, file_content):
        status = "met"
    else:
        status = "not_met"
        error = f"Pattern '{pattern}' not found in {file_path}"
```

### Step 3: Aggregate Results

```
met_count = 0
not_met = []

for criterion in acceptance_criteria:
    result = verify_criterion(criterion)

    if result.status == "met":
        met_count += 1
    else:
        not_met.append({
            "criterion": criterion,
            "error": result.error
        })

if not_met.length == 0:
    validator_status = "passed"
    info = [f"{met_count}/{len(acceptance_criteria)} criteria met"]
else:
    validator_status = "failed"
    errors = [f"Criterion not met: {c['criterion']}" for c in not_met]
```

## Output

```json
{
  "validator_name": "Acceptance Criteria",
  "status": "passed",
  "errors": [],
  "info": ["3/3 criteria met"]
}
```
