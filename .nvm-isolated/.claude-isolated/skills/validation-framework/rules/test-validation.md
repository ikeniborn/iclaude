# Test Validation Rules

Алгоритмы для запуска validation commands и парсинга test results.

## Running Validation Commands

```
for command in validation_commands:
    # Run via Bash tool
    result = bash_tool.run(command)

    # Collect output
    test_results.append({
        "command": command,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "exit_code": result.exit_code
    })
```

## Parsing Test Output

### pytest

```
# Output: "===== 25 passed, 3 failed in 2.5s ====="
pattern = r"(\d+) passed.*?(\d+) failed"
match = re.search(pattern, stdout)

if match:
    passed = int(match.group(1))
    failed = int(match.group(2))

if failed > 0 or exit_code != 0:
    status = "failed"
    errors = [f"{failed} tests failed"]
else:
    status = "passed"
    info = [f"{passed} tests passed"]
```

### jest

```
# Output: "Tests: 3 failed, 25 passed, 28 total"
pattern = r"Tests:\s+(\d+) failed,\s+(\d+) passed"
match = re.search(pattern, stdout)

if match:
    failed = int(match.group(1))
    passed = int(match.group(2))

if failed > 0:
    status = "failed"
    errors = [f"{failed} tests failed"]
```

### npm test / cargo test

```
# Check exit code only
if exit_code == 0:
    status = "passed"
    info = ["All tests passed"]
else:
    status = "failed"
    errors = [f"Tests failed with exit code {exit_code}"]
```

## Output

```json
{
  "validator_name": "Test Suite",
  "status": "failed",
  "errors": ["3 tests failed"],
  "info": ["25 tests passed"]
}
```
