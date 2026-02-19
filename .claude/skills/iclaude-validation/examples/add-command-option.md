# Example: Adding a New Command-Line Option

This example demonstrates the complete workflow for adding a new command-line option to iclaude.sh.

## Scenario

Add a `--debug-mode` flag that enables verbose logging throughout iclaude.sh execution.

## Implementation Steps

### 1. Add Flag Variable

Add at the top of `main()` function (around line 2996):

```bash
main() {
    # Existing variables
    ISOLATED_INSTALL=false
    USE_PROXY=false
    # ... other flags ...

    # Add new flag
    DEBUG_MODE=false
```

### 2. Add Option Parsing

Add to the option parsing loop in `main()`:

```bash
case "$1" in
    # ... existing options ...

    --debug-mode)
        DEBUG_MODE=true
        echo "Debug mode enabled"
        shift
        ;;
```

### 3. Update Help Text

Add to `show_usage()` function (around line 2807):

```bash
echo "Debugging:"
echo "  --test                 Test proxy configuration without launching Claude Code"
echo "  --debug-mode           Enable verbose logging for debugging"
echo "  --show-password        Show proxy password in output (use with --test)"
```

### 4. Implement Functionality

Add a debug logging function:

```bash
# Add after other utility functions (around line 500)
debug_log() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}
```

Use throughout the script:

```bash
setup_isolated_nvm() {
    debug_log "Entering setup_isolated_nvm()"

    # ... existing code ...

    debug_log "NVM_DIR set to: $NVM_DIR"
    debug_log "PATH updated: $PATH"

    # ... rest of function ...
}
```

### 5. Test the Implementation

#### Test 1: Syntax Validation

```bash
bash -n iclaude.sh
```

**Expected**: No output (syntax is valid)

#### Test 2: Help Text

```bash
./iclaude.sh --help | grep debug-mode
```

**Expected**:
```
  --debug-mode           Enable verbose logging for debugging
```

#### Test 3: Debug Output

```bash
./iclaude.sh --debug-mode --test
```

**Expected**: Debug messages showing execution flow:
```
Debug mode enabled
[DEBUG] 2026-02-12 10:30:45 - Entering setup_isolated_nvm()
[DEBUG] 2026-02-12 10:30:45 - NVM_DIR set to: /path/to/.nvm-isolated
[DEBUG] 2026-02-12 10:30:45 - PATH updated: ...
```

#### Test 4: Without Debug Flag

```bash
./iclaude.sh --test
```

**Expected**: Normal output, no debug messages

#### Test 5: Combined with Other Flags

```bash
./iclaude.sh --debug-mode --no-proxy
```

**Expected**: Debug messages with proxy disabled

### 6. Validation Checklist

- [x] Syntax validation passes
- [x] Help text updated and displays correctly
- [x] Flag works in isolation
- [x] Flag works combined with other options
- [x] Debug output is informative
- [x] No debug output when flag not used
- [x] Backward compatibility preserved (no breaking changes)

## Test Plan (JSON Format)

```json
{
  "feature": "Debug Mode Flag",
  "description": "Add --debug-mode flag for verbose logging",
  "version": "1.0.0",
  "testCases": [
    {
      "id": "TC001",
      "name": "Syntax validation",
      "type": "unit",
      "priority": "critical",
      "steps": [
        {
          "action": "bash -n iclaude.sh",
          "expected": "No syntax errors"
        }
      ],
      "expectedResult": "Script syntax is valid"
    },
    {
      "id": "TC002",
      "name": "Help text display",
      "type": "unit",
      "priority": "high",
      "steps": [
        {
          "action": "./iclaude.sh --help | grep debug-mode",
          "expected": "Help text shows --debug-mode option"
        }
      ],
      "expectedResult": "Option documented in help"
    },
    {
      "id": "TC003",
      "name": "Debug output enabled",
      "type": "integration",
      "priority": "critical",
      "steps": [
        {
          "action": "./iclaude.sh --debug-mode --test",
          "expected": "Debug messages appear in stderr"
        }
      ],
      "expectedResult": "Verbose logging is active"
    },
    {
      "id": "TC004",
      "name": "Debug output disabled",
      "type": "integration",
      "priority": "high",
      "steps": [
        {
          "action": "./iclaude.sh --test",
          "expected": "No debug messages"
        }
      ],
      "expectedResult": "Normal quiet operation"
    },
    {
      "id": "TC005",
      "name": "Combined flags",
      "type": "integration",
      "priority": "medium",
      "steps": [
        {
          "action": "./iclaude.sh --debug-mode --no-proxy --test",
          "expected": "Debug mode works with other flags"
        }
      ],
      "expectedResult": "Flags don't conflict"
    }
  ]
}
```

## Common Issues

### Issue 1: Debug messages not appearing

**Symptom**: Running with `--debug-mode` shows no debug output

**Possible causes**:
1. `DEBUG_MODE` variable not exported to functions
2. `debug_log()` function not called in target functions
3. Output redirected to wrong stream

**Fix**:
```bash
# Make sure DEBUG_MODE is available globally
export DEBUG_MODE

# Or pass as parameter to functions
setup_isolated_nvm() {
    local debug_mode="$1"
    # ...
}
```

### Issue 2: Flag conflicts with existing options

**Symptom**: `--debug-mode` doesn't work when combined with other flags

**Possible causes**:
1. Option parsing doesn't handle combinations correctly
2. `shift` called incorrectly in loop

**Fix**:
```bash
# Ensure proper shift after processing each flag
case "$1" in
    --debug-mode)
        DEBUG_MODE=true
        shift  # Always shift after consuming flag
        ;;
esac
```

### Issue 3: Performance impact

**Symptom**: Script is noticeably slower with `--debug-mode`

**Solution**:
- Use conditional logging only at critical points
- Avoid logging in tight loops
- Consider adding `--verbose` for less critical debug info

## Documentation Updates

After implementing, update these files:

1. **CLAUDE.md** - Add to "Common Development Tasks" section
2. **README.md** - Add to "Development Commands" section
3. **CHANGELOG.md** - Add entry for new feature
4. **examples/** - Create this example file

## Git Workflow

```bash
# Create feature branch
git checkout -b feat/add-debug-mode

# Commit implementation
git add iclaude.sh
git commit -m "feat: add --debug-mode flag for verbose logging

- Add DEBUG_MODE flag variable
- Implement debug_log() function
- Add option parsing for --debug-mode
- Update help text with new option
- Add debug logging to key functions"

# Commit documentation
git add CLAUDE.md README.md examples/
git commit -m "docs: document --debug-mode flag

- Add usage examples to CLAUDE.md
- Update README.md with debug commands
- Create add-command-option.md example"

# Commit tests (if applicable)
git add tests/
git commit -m "test: add tests for --debug-mode flag"

# Push and create PR
git push -u origin feat/add-debug-mode
```

## Review Checklist

Before submitting PR:

- [ ] Code follows existing bash style conventions
- [ ] Function is properly documented with comments
- [ ] Help text is clear and concise
- [ ] All test cases pass
- [ ] No performance regression in normal mode
- [ ] Documentation is complete and accurate
- [ ] Git commits follow Conventional Commits format
- [ ] No breaking changes introduced

## Related Examples

- `modify-proxy-validation.md` - Changing validation logic
- `debugging.md` - Debugging techniques
