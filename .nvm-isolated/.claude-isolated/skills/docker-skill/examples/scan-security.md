# Example: Security Scanning with hadolint

## Scenario

You have a **legacy Dockerfile** from an old project and want to verify it follows security best practices before deploying to production.

### Existing Dockerfile (Legacy)

```dockerfile
FROM ubuntu:latest
COPY . /app
WORKDIR /app
RUN apt-get install -y python3 python3-pip
RUN pip3 install flask
EXPOSE 5000
CMD python3 app.py
```

**Concerns**:
- Is this Dockerfile secure?
- Does it follow Docker best practices?
- Are there any CVE vulnerabilities?

---

## Step 1: Invoke docker-skill with scan-image Operation

```bash
/docker-skill
```

**Interactive Q&A:**
```
Q: Выберите операцию
→ scan-image (only security scan, no generation)
```

Or provide operation directly:
```json
{
  "docker_input": {
    "operation": "scan-image",
    "dockerfile_path": "./Dockerfile"
  }
}
```

---

## Step 2: Skill Analysis

The skill performs:

1. **hadolint scan** (if installed):
   ```bash
   hadolint Dockerfile --format json
   ```

2. **Regex secrets detection**:
   - Scan for API_KEY=, PASSWORD=, TOKEN=, etc.

3. **Best practices validation**:
   - Multi-stage build?
   - Non-root user?
   - HEALTHCHECK?
   - Version pinning?
   - etc.

---

## Step 3: Security Scan Results (JSON Output)

```json
{
  "docker_operation": {
    "operation": "scan-image",
    "status": "partial",

    "dockerfile_path": "./Dockerfile",

    "security_scan": {
      "hadolint_available": true,
      "hadolint_issues": 8,
      "hadolint_warnings": [
        {
          "rule": "DL3006",
          "severity": "error",
          "message": "Always tag the version of an image explicitly",
          "line": 1
        },
        {
          "rule": "DL3008",
          "severity": "warning",
          "message": "Pin versions in apt-get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`",
          "line": 5
        },
        {
          "rule": "DL3013",
          "severity": "warning",
          "message": "Pin versions in pip. Instead of `pip install <package>` use `pip install <package>==<version>`",
          "line": 6
        },
        {
          "rule": "DL3009",
          "severity": "info",
          "message": "Delete the apt-get lists after installing something",
          "line": 5
        },
        {
          "rule": "DL3015",
          "severity": "info",
          "message": "Avoid additional packages by specifying `--no-install-recommends`",
          "line": 5
        },
        {
          "rule": "DL3059",
          "severity": "info",
          "message": "Multiple consecutive `RUN` instructions. Consider consolidation.",
          "line": 5
        },
        {
          "rule": "DL4006",
          "severity": "warning",
          "message": "Set the `SHELL` option -o pipefail before `RUN` with a pipe in it",
          "line": 5
        },
        {
          "rule": "SC2086",
          "severity": "info",
          "message": "Double quote to prevent globbing and word splitting",
          "line": 8
        }
      ],
      "non_root_user": false,
      "secrets_detected": false,
      "secrets_patterns": []
    },

    "validation_results": {
      "healthcheck_configured": false,
      "best_practices_followed": 1,
      "best_practices_violations": [
        {
          "rule": "Multi-stage builds",
          "description": "No multi-stage build detected (only 1 FROM)",
          "severity": "warning",
          "fix": "Use multi-stage build to separate build and runtime dependencies"
        },
        {
          "rule": "Minimal base images",
          "description": "Using ubuntu:latest (250MB+) instead of alpine or slim variant",
          "severity": "critical",
          "fix": "Use python:3.11-slim (150MB) or python:3.11-alpine (50MB)"
        },
        {
          "rule": "Non-root user",
          "description": "No USER directive - container runs as root",
          "severity": "critical",
          "fix": "Add RUN useradd -m appuser && USER appuser"
        },
        {
          "rule": "Layer optimization",
          "description": "Multiple consecutive RUN commands (creates extra layers)",
          "severity": "warning",
          "fix": "Combine RUN commands with && operator"
        },
        {
          "rule": ".dockerignore",
          "description": ".dockerignore file not found",
          "severity": "warning",
          "fix": "Create .dockerignore to exclude .git, __pycache__, etc."
        },
        {
          "rule": "HEALTHCHECK",
          "description": "No HEALTHCHECK directive",
          "severity": "warning",
          "fix": "Add HEALTHCHECK to enable container health monitoring"
        },
        {
          "rule": "Version pinning",
          "description": "Using :latest tag (line 1) - not reproducible",
          "severity": "critical",
          "fix": "Pin specific version: ubuntu:22.04 or python:3.11-slim"
        },
        {
          "rule": "Cleanup in RUN",
          "description": "apt-get lists not removed (adds 30-50MB to image)",
          "severity": "warning",
          "fix": "Add && rm -rf /var/lib/apt/lists/* after apt-get install"
        },
        {
          "rule": "COPY ordering",
          "description": "COPY all files before installing dependencies (breaks caching)",
          "severity": "info",
          "fix": "COPY requirements.txt first, then RUN pip install, then COPY code"
        }
      ],
      "overall_score": 10
    },

    "next_steps": [
      "Review 8 hadolint issues (3 critical, 3 warnings, 2 info)",
      "Fix critical violations: version pinning, non-root user, minimal base image",
      "Consider running full optimization: operation=optimize-layers",
      "Add .dockerignore file",
      "Test Dockerfile after fixes: docker build -t myapp ."
    ],

    "toon": {
      "hadolint_warnings_toon": "hadolint_warnings[8]{rule,severity,message,line}:\n  DL3006,error,Always tag version explicitly,1\n  DL3008,warning,Pin versions in apt-get,5\n  DL3013,warning,Pin versions in pip,6\n  DL3009,info,Delete apt-get lists,5\n  DL3015,info,Use --no-install-recommends,5\n  DL3059,info,Consolidate RUN instructions,5\n  DL4006,warning,Set pipefail before pipe,5\n  SC2086,info,Double quote variables,8",
      "violations_toon": "best_practices_violations[9]{rule,severity,fix}:\n  Multi-stage builds,warning,Use multi-stage pattern\n  Minimal base images,critical,Use python:3.11-slim\n  Non-root user,critical,Add USER directive\n  Layer optimization,warning,Combine RUN with &&\n  .dockerignore,warning,Create .dockerignore\n  HEALTHCHECK,warning,Add HEALTHCHECK\n  Version pinning,critical,Pin :version not :latest\n  Cleanup in RUN,warning,Remove apt lists\n  COPY ordering,info,COPY deps before code",
      "token_savings": "52%"
    },

    "metadata": {
      "skill_version": "1.0.0",
      "execution_time": "0.8s",
      "timestamp": "2026-01-26T15:45:12Z",
      "hadolint_version": "2.12.0"
    }
  }
}
```

---

## Step 4: Violation Analysis

### Critical Issues (Must Fix)

| Rule | Line | Severity | Impact |
|------|------|----------|--------|
| **DL3006: Version pinning** | 1 | Critical | Build unpredictability |
| **Non-root user** | - | Critical | Security vulnerability |
| **Minimal base image** | 1 | Critical | +200MB image size |

### Warnings (Should Fix)

| Rule | Line | Severity | Impact |
|------|------|----------|--------|
| **DL3008: Pin apt versions** | 5 | Warning | Dependency unpredictability |
| **DL3013: Pin pip versions** | 6 | Warning | Python package unpredictability |
| **DL4006: Set pipefail** | 5 | Warning | Silent failures in pipes |
| **Cleanup apt lists** | 5 | Warning | +30-50MB image size |
| **HEALTHCHECK missing** | - | Warning | No self-healing |

### Info (Nice to Have)

| Rule | Line | Severity | Impact |
|------|------|----------|--------|
| **DL3015: --no-install-recommends** | 5 | Info | +20MB unnecessary packages |
| **DL3059: Consolidate RUN** | 5-6 | Info | +2 extra layers |
| **COPY ordering** | 2 | Info | Slower rebuilds |

---

## Step 5: hadolint Output (Raw)

```bash
hadolint Dockerfile
```

**Output**:
```
Dockerfile:1 DL3006 error: Always tag the version of an image explicitly
Dockerfile:5 DL3008 warning: Pin versions in apt-get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`
Dockerfile:6 DL3013 warning: Pin versions in pip. Instead of `pip install <package>` use `pip install <package>==<version>` or `pip install --requirement <requirements file>`
Dockerfile:5 DL3009 info: Delete the apt-get lists after installing something
Dockerfile:5 DL3015 info: Avoid additional packages by specifying `--no-install-recommends`
Dockerfile:5 DL3059 info: Multiple consecutive `RUN` instructions. Consider consolidation.
Dockerfile:5 DL4006 warning: Set the SHELL option -o pipefail before RUN with a pipe in it. If you are using /bin/sh in an alpine image or if your shell is symlinked to busybox then consider explicitly setting your SHELL to /bin/ash, or disable pipefail by ignoring DL4006
Dockerfile:8 SC2086 info: Double quote to prevent globbing and word splitting.
```

---

## Step 6: Fix Critical Issues

### Fix 1: Pin Base Image Version

**Before**:
```dockerfile
FROM ubuntu:latest
```

**After**:
```dockerfile
FROM python:3.11-slim  # Debian-based, 150MB
```

**Impact**:
- ✅ Reproducible builds
- ✅ Smaller base image (ubuntu:22.04 = 250MB, python:3.11-slim = 150MB)
- ✅ Pre-installed Python (no manual install)

---

### Fix 2: Add Non-Root User

**Before**:
```dockerfile
CMD python3 app.py  # Runs as root
```

**After**:
```dockerfile
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

CMD ["python3", "app.py"]
```

**Impact**:
- ✅ Security: Container escape exploits less dangerous
- ✅ Compliance: Meets security policies

---

### Fix 3: Optimize Layers and Cleanup

**Before**:
```dockerfile
RUN apt-get install -y python3 python3-pip
RUN pip3 install flask
```

**After**:
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

**Impact**:
- ✅ -30MB (removed apt cache)
- ✅ -2 layers (combined RUN)
- ✅ Better caching (requirements.txt separate)

---

## Step 7: Fully Fixed Dockerfile

```dockerfile
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

WORKDIR /app

# Copy requirements first (better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

EXPOSE 5000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Start application
CMD ["python3", "app.py"]
```

---

## Step 8: Re-scan Fixed Dockerfile

```bash
hadolint Dockerfile
```

**Expected**: No errors (exit code 0)

```bash
docker build -t myapp:fixed .
docker images myapp --format "{{.Size}}"
# Expected: ~200MB (vs 500MB+ with ubuntu:latest)
```

---

## Step 9: Security Score Improvement

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **hadolint issues** | 8 errors/warnings | 0 | 100% |
| **Best practices followed** | 1/10 | 9/10 | +800% |
| **Overall score** | 10/100 | 90/100 | +800% |
| **Non-root user** | ❌ No | ✅ Yes | Security +++ |
| **HEALTHCHECK** | ❌ No | ✅ Yes | Monitoring +++ |
| **Image size** | ~500MB | ~200MB | -60% |

---

## Summary

**Security Findings**:
- ✅ 8 hadolint issues identified (3 critical, 3 warnings, 2 info)
- ✅ 9 best practices violations detected
- ✅ No secrets found in Dockerfile

**Fixes Applied**:
- ✅ Pin base image version (ubuntu:latest → python:3.11-slim)
- ✅ Add non-root user (appuser:1000)
- ✅ Add HEALTHCHECK
- ✅ Optimize layers (combine RUN, cleanup apt cache)
- ✅ Improve COPY ordering (requirements.txt first)

**Impact**:
- Image size: 500MB → 200MB (-60%)
- Security score: 10/100 → 90/100 (+800%)
- Build time: Cached rebuilds 10x faster

**Time saved**: ~1 hour of manual hadolint analysis and fixing

---

## Next Steps

1. **Add .dockerignore**:
   ```bash
   /docker-skill
   # operation: create-dockerfile (will generate .dockerignore)
   ```

2. **Implement multi-stage build** (for even smaller image):
   ```bash
   /docker-skill
   # operation: optimize-layers
   ```

3. **CVE scanning** (future v1.1.0):
   ```bash
   trivy image myapp:fixed
   docker scout cves myapp:fixed
   ```

4. **Deploy with confidence**:
   ```bash
   docker-compose up -d
   ```

---

**Skill Used**: docker-skill v1.0.0
**Operation**: scan-image
**Date**: 2026-01-26
**hadolint Issues Found**: 8
**Security Score**: 10/100 → 90/100 (after fixes)
