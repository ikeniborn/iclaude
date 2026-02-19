# Example: Modifying Proxy Validation

This example demonstrates how to safely modify proxy validation logic in iclaude.sh while maintaining backward compatibility.

## Scenario

Enhance proxy validation to support IPv6 addresses in addition to IPv4.

## Background

**Current behavior** (iclaude.sh:56):
- `validate_proxy_url()` validates HTTP/HTTPS proxy URLs
- Supports IPv4 addresses and domain names
- Returns codes: 0 (valid IP), 1 (invalid), 2 (domain warning)

**Limitation**: IPv6 addresses like `[2001:db8::1]:8118` are rejected

## Implementation Steps

### 1. Understand Current Implementation

First, read the existing validation logic:

```bash
# View current function
sed -n '56,109p' iclaude.sh
```

Current function structure:
```bash
validate_proxy_url() {
    local url="$1"

    # Protocol validation (HTTP/HTTPS only)
    # URL format check
    # IPv4 detection
    # Domain name detection
}
```

### 2. Add IPv6 Detection Function

Add after `validate_proxy_url()` (around line 110):

```bash
is_ipv6_address() {
    local addr="$1"

    # Remove brackets if present
    addr="${addr#\[}"
    addr="${addr%\]}"

    # IPv6 regex pattern (simplified)
    # Full validation: supports compressed format (::), hex segments
    if [[ "$addr" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0  # Valid IPv6
    else
        return 1  # Not IPv6
    fi
}
```

### 3. Modify `validate_proxy_url()`

Update the function to handle IPv6:

```bash
validate_proxy_url() {
    local url="$1"

    # Extract protocol
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: Only HTTP and HTTPS protocols are supported" >&2
        return 1
    fi

    # Extract host:port (handle IPv6 brackets)
    local host_port
    host_port=$(echo "$url" | sed -E 's|^https?://(([^@]+)@)?||' | cut -d'/' -f1)

    # Extract host (IPv6 may have brackets)
    local host
    if [[ "$host_port" =~ ^\[([^\]]+)\] ]]; then
        # IPv6 address in brackets
        host="${BASH_REMATCH[1]}"

        if is_ipv6_address "$host"; then
            echo "Valid proxy URL with IPv6 address: [$host]"
            return 0
        else
            echo "Error: Invalid IPv6 address format" >&2
            return 1
        fi
    else
        # IPv4 or domain
        host=$(echo "$host_port" | cut -d':' -f1)

        if is_ip_address "$host"; then
            echo "Valid proxy URL with IPv4 address"
            return 0
        else
            echo "Warning: Proxy URL contains domain name: $host"
            return 2
        fi
    fi
}
```

### 4. Update `parse_proxy_url()`

Modify `parse_proxy_url()` to preserve IPv6 brackets:

```bash
parse_proxy_url() {
    local url="$1"

    # ... existing protocol extraction ...

    # Extract host (preserve IPv6 brackets)
    if [[ "$url" =~ \[([^\]]+)\]:([0-9]+) ]]; then
        # IPv6 with port
        PROXY_HOST="[${BASH_REMATCH[1]}]"
        PROXY_PORT="${BASH_REMATCH[2]}"
    elif [[ "$url" =~ \[([^\]]+)\] ]]; then
        # IPv6 without port
        PROXY_HOST="[${BASH_REMATCH[1]}]"
        PROXY_PORT="8080"  # default
    else
        # IPv4 or domain (existing logic)
        # ...
    fi
}
```

## Testing Strategy

### Test Suite

Create a comprehensive test suite covering all scenarios:

```bash
#!/bin/bash
# test-proxy-validation.sh

source iclaude.sh

test_ipv4() {
    echo "Test 1: IPv4 address"
    validate_proxy_url "http://192.168.1.100:8118"
    echo "Result: $?"
    echo ""
}

test_ipv6_full() {
    echo "Test 2: Full IPv6 address"
    validate_proxy_url "http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:8118"
    echo "Result: $?"
    echo ""
}

test_ipv6_compressed() {
    echo "Test 3: Compressed IPv6 (::)"
    validate_proxy_url "http://[2001:db8::1]:8118"
    echo "Result: $?"
    echo ""
}

test_ipv6_loopback() {
    echo "Test 4: IPv6 loopback"
    validate_proxy_url "http://[::1]:8118"
    echo "Result: $?"
    echo ""
}

test_ipv6_https() {
    echo "Test 5: IPv6 with HTTPS"
    validate_proxy_url "https://[2001:db8::1]:8118"
    echo "Result: $?"
    echo ""
}

test_ipv6_with_credentials() {
    echo "Test 6: IPv6 with credentials"
    validate_proxy_url "https://user:pass@[2001:db8::1]:8118"
    echo "Result: $?"
    echo ""
}

test_domain_name() {
    echo "Test 7: Domain name (backward compatibility)"
    validate_proxy_url "http://proxy.example.com:8118"
    echo "Result: $?"
    echo ""
}

test_invalid_ipv6() {
    echo "Test 8: Invalid IPv6"
    validate_proxy_url "http://[invalid::address::]:8118"
    echo "Result: $?"
    echo ""
}

test_socks5_rejection() {
    echo "Test 9: SOCKS5 rejection"
    validate_proxy_url "socks5://[2001:db8::1]:1080"
    echo "Result: $?"
    echo ""
}

# Run all tests
test_ipv4
test_ipv6_full
test_ipv6_compressed
test_ipv6_loopback
test_ipv6_https
test_ipv6_with_credentials
test_domain_name
test_invalid_ipv6
test_socks5_rejection
```

### Execute Tests

```bash
chmod +x test-proxy-validation.sh
./test-proxy-validation.sh
```

**Expected Output:**
```
Test 1: IPv4 address
Valid proxy URL with IPv4 address
Result: 0

Test 2: Full IPv6 address
Valid proxy URL with IPv6 address: [2001:0db8:85a3:0000:0000:8a2e:0370:7334]
Result: 0

Test 3: Compressed IPv6 (::)
Valid proxy URL with IPv6 address: [2001:db8::1]
Result: 0

Test 4: IPv6 loopback
Valid proxy URL with IPv6 address: [::1]
Result: 0

Test 5: IPv6 with HTTPS
Valid proxy URL with IPv6 address: [2001:db8::1]
Result: 0

Test 6: IPv6 with credentials
Valid proxy URL with IPv6 address: [2001:db8::1]
Result: 0

Test 7: Domain name (backward compatibility)
Warning: Proxy URL contains domain name: proxy.example.com
Result: 2

Test 8: Invalid IPv6
Error: Invalid IPv6 address format
Result: 1

Test 9: SOCKS5 rejection
Error: Only HTTP and HTTPS protocols are supported
Result: 1
```

## Backward Compatibility Testing

### Test Existing Credentials

```bash
# Create test credential file with IPv4
echo "http://192.168.1.100:8118" > .test_credentials

# Test loading (should work)
CREDENTIAL_FILE=".test_credentials" ./iclaude.sh --test

# Create test credential file with domain
echo "https://proxy.example.com:8118" > .test_credentials

# Test loading (should work)
CREDENTIAL_FILE=".test_credentials" ./iclaude.sh --test

# Cleanup
rm .test_credentials
```

### Test Edge Cases

```bash
# Missing port (should use default)
./iclaude.sh --proxy "http://[2001:db8::1]" --test

# HTTPS with domain (should preserve domain)
./iclaude.sh --proxy "https://proxy.example.com:8118" --test

# Special characters in password
./iclaude.sh --proxy "https://user:p@ss:w0rd!@[2001:db8::1]:8118" --test
```

## Performance Testing

Validate that the new regex doesn't slow down validation:

```bash
# Benchmark old validation
time for i in {1..1000}; do
    validate_proxy_url "http://192.168.1.100:8118" > /dev/null
done

# Benchmark new validation (with IPv6 support)
time for i in {1..1000}; do
    validate_proxy_url "http://[2001:db8::1]:8118" > /dev/null
done
```

**Acceptable**: <10% performance difference

## Integration Testing

Test with actual proxy server:

```bash
# Set up local IPv6 proxy (example with Privoxy)
# /etc/privoxy/config:
# listen-address [::1]:8118

# Test with iclaude.sh
./iclaude.sh --proxy "http://[::1]:8118" --test

# Launch Claude Code with IPv6 proxy
./iclaude.sh --proxy "http://[::1]:8118"
```

## Validation Checklist

- [ ] Syntax validation passes (`bash -n iclaude.sh`)
- [ ] All test cases pass (IPv4, IPv6, domain)
- [ ] Backward compatibility preserved
- [ ] Invalid addresses rejected correctly
- [ ] SOCKS5 still rejected
- [ ] Credentials parsed correctly with IPv6
- [ ] HTTPS preserves domain/IPv6 (no conversion)
- [ ] HTTP offers IP conversion (IPv4 only)
- [ ] Performance impact <10%
- [ ] Integration test with real proxy succeeds
- [ ] Documentation updated

## Common Issues

### Issue 1: IPv6 regex too strict

**Symptom**: Valid IPv6 addresses rejected

**Fix**: Use more permissive regex or validate using `getent`
```bash
is_ipv6_address() {
    local addr="$1"
    addr="${addr#\[}"
    addr="${addr%\]}"

    # Use getent for validation
    if getent hosts "$addr" >/dev/null 2>&1; then
        return 0
    fi

    # Fallback to regex
    # ...
}
```

### Issue 2: Brackets not preserved in environment variable

**Symptom**: `HTTPS_PROXY` shows `2001:db8::1:8118` instead of `[2001:db8::1]:8118`

**Fix**: Quote properly in `configure_proxy_from_url()`
```bash
export HTTPS_PROXY="http://[$PROXY_HOST]:$PROXY_PORT"
```

### Issue 3: Port parsing fails with IPv6

**Symptom**: Port extracted incorrectly from IPv6 URL

**Fix**: Match brackets first, then extract port
```bash
if [[ "$url" =~ \[([^\]]+)\]:([0-9]+) ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
fi
```

## Documentation Updates

Update these sections:

1. **CLAUDE.md** - "Proxy Management" section
   - Document IPv6 support
   - Add IPv6 examples
   - Update validation behavior

2. **README.md** - "Proxy Configuration" section
   - Add IPv6 usage examples
   - Update troubleshooting

3. **examples/** - Create this example file

## Test Plan (JSON Format)

```json
{
  "feature": "IPv6 Proxy Support",
  "description": "Add IPv6 address validation and parsing to proxy configuration",
  "version": "1.1.0",
  "testCases": [
    {
      "id": "TC001",
      "name": "IPv4 validation (regression)",
      "type": "regression",
      "priority": "critical",
      "steps": [
        {"action": "./iclaude.sh --proxy http://192.168.1.100:8118 --test"}
      ],
      "expectedResult": "IPv4 proxy works as before"
    },
    {
      "id": "TC002",
      "name": "IPv6 full address",
      "type": "unit",
      "priority": "critical",
      "steps": [
        {"action": "./iclaude.sh --proxy http://[2001:db8:85a3::8a2e:370:7334]:8118 --test"}
      ],
      "expectedResult": "IPv6 address validated and accepted"
    },
    {
      "id": "TC003",
      "name": "IPv6 compressed format",
      "type": "unit",
      "priority": "high",
      "steps": [
        {"action": "./iclaude.sh --proxy http://[2001:db8::1]:8118 --test"}
      ],
      "expectedResult": "Compressed IPv6 format accepted"
    },
    {
      "id": "TC004",
      "name": "IPv6 loopback",
      "type": "unit",
      "priority": "high",
      "steps": [
        {"action": "./iclaude.sh --proxy http://[::1]:8118 --test"}
      ],
      "expectedResult": "Loopback address [::1] works"
    },
    {
      "id": "TC005",
      "name": "IPv6 with credentials",
      "type": "integration",
      "priority": "high",
      "steps": [
        {"action": "./iclaude.sh --proxy https://user:pass@[2001:db8::1]:8118 --test"}
      ],
      "expectedResult": "Credentials parsed correctly with IPv6"
    },
    {
      "id": "TC006",
      "name": "Invalid IPv6 rejection",
      "type": "unit",
      "priority": "high",
      "steps": [
        {"action": "./iclaude.sh --proxy http://[invalid::address::]:8118 --test"}
      ],
      "expectedResult": "Invalid IPv6 format rejected with error"
    },
    {
      "id": "TC007",
      "name": "Domain name backward compatibility",
      "type": "regression",
      "priority": "critical",
      "steps": [
        {"action": "./iclaude.sh --proxy https://proxy.example.com:8118 --test"}
      ],
      "expectedResult": "Domain names still work with warning"
    },
    {
      "id": "TC008",
      "name": "Credential file backward compatibility",
      "type": "regression",
      "priority": "critical",
      "prerequisites": [".claude_proxy_credentials exists with IPv4"],
      "steps": [
        {"action": "./iclaude.sh --test"}
      ],
      "expectedResult": "Existing credentials file loads correctly"
    }
  ]
}
```

## Git Workflow

```bash
# Create feature branch
git checkout -b feat/ipv6-proxy-support

# Commit implementation
git add iclaude.sh
git commit -m "feat: add IPv6 address support for proxy configuration

- Add is_ipv6_address() validation function
- Update validate_proxy_url() to handle IPv6 brackets
- Modify parse_proxy_url() to preserve IPv6 format
- Maintain backward compatibility with IPv4 and domains

BREAKING CHANGE: None (fully backward compatible)"

# Commit tests
git add test-proxy-validation.sh
git commit -m "test: add comprehensive IPv6 proxy validation tests

- Test full and compressed IPv6 formats
- Test IPv6 with credentials
- Test backward compatibility with IPv4
- Test invalid address rejection"

# Commit documentation
git add CLAUDE.md README.md examples/
git commit -m "docs: document IPv6 proxy support

- Add IPv6 examples to CLAUDE.md
- Update README.md proxy section
- Create modify-proxy-validation.md example"

# Push and create PR
git push -u origin feat/ipv6-proxy-support
```

## Related Examples

- `add-command-option.md` - Adding new CLI flags
- `debugging.md` - Debugging validation issues
