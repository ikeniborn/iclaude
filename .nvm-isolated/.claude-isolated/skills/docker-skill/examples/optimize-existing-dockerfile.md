# Example: Optimize Existing Python Dockerfile (Reduce from 1.2GB to 250MB)

## Scenario

You have an existing Python FastAPI application with a **non-optimized Dockerfile**:

### Original Dockerfile (Bad Practices)

```dockerfile
FROM python:latest
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8000
CMD ["python", "main.py"]
```

**Problems**:
- ❌ Uses `:latest` tag (not reproducible)
- ❌ No multi-stage build (includes build dependencies in final image)
- ❌ Runs as root user (security risk)
- ❌ No HEALTHCHECK
- ❌ No .dockerignore (copies unnecessary files)
- ❌ Single-stage build (1.2GB image size)
- ❌ No layer optimization (COPY . before pip install)

**Goal**: Optimize Dockerfile to follow best practices and reduce size from **1.2GB to 250MB** (79% reduction).

---

## Step 1: Invoke docker-skill with optimize-layers Operation

```bash
/docker-skill
```

**Or specify operation directly** (if skill supports direct operation selection):
```json
{
  "docker_input": {
    "operation": "optimize-layers",
    "dockerfile_path": "./Dockerfile",
    "language": "python"
  }
}
```

---

## Step 2: Skill Analysis

The skill performs:

1. **Read existing Dockerfile**
2. **Detect violations**:
   - DL3006: Using `:latest` tag
   - DL3045: COPY all files before dependencies
   - DL3059: No USER directive (runs as root)
   - Missing HEALTHCHECK
   - No multi-stage build

3. **Calculate current metrics**:
   - Layers: 6
   - Estimated size: 1.2GB
   - Best practices followed: 2/10

4. **Generate optimization report**

---

## Step 3: Optimization Report (JSON Output)

```json
{
  "docker_operation": {
    "operation": "optimize-layers",
    "status": "success",

    "dockerfile_path": "./Dockerfile",
    "dockerfile_generated": true,

    "base_image": "python:3.11-slim",
    "multi_stage": true,

    "optimization_results": {
      "layers_before": 6,
      "layers_after": 14,
      "layers_reduced": -8,
      "size_before": "1.2GB",
      "size_after": "250MB",
      "size_reduction": "79%",
      "optimizations_applied": [
        "Changed base image: python:latest → python:3.11-slim (950MB → 150MB base)",
        "Added multi-stage build (builder + runtime)",
        "Reordered COPY: requirements.txt before application code",
        "Added non-root user (appuser:1000)",
        "Added HEALTHCHECK directive",
        "Created .dockerignore to exclude __pycache__, .git, tests",
        "Combined RUN commands to reduce layers",
        "Added cleanup: rm -rf /var/lib/apt/lists/*",
        "Pinned Python version (3.11 instead of :latest)",
        "Changed CMD to use uvicorn instead of python main.py"
      ]
    },

    "security_scan": {
      "hadolint_available": true,
      "hadolint_issues_before": 4,
      "hadolint_issues_after": 0,
      "hadolint_warnings": [],
      "non_root_user": true,
      "secrets_detected": false
    },

    "validation_results": {
      "healthcheck_configured": true,
      "best_practices_followed_before": 2,
      "best_practices_followed_after": 10,
      "best_practices_violations": []
    },

    "next_steps": [
      "Review optimized Dockerfile (Dockerfile.optimized)",
      "Compare with original: diff Dockerfile Dockerfile.optimized",
      "Test build: docker build -f Dockerfile.optimized -t myapp:optimized .",
      "Verify functionality: docker run -p 8000:8000 myapp:optimized",
      "Replace original: mv Dockerfile.optimized Dockerfile"
    ],

    "toon": {
      "optimizations_toon": "optimizations[10]{type,impact,savings}:\n  base_image,critical,950MB\n  multi_stage,high,200MB\n  ...",
      "token_savings": "48%"
    },

    "metadata": {
      "skill_version": "1.0.0",
      "execution_time": "1.8s",
      "timestamp": "2026-01-26T14:20:30Z",
      "hadolint_version": "2.12.0"
    }
  }
}
```

---

## Step 4: Optimized Dockerfile

The skill generates `Dockerfile.optimized`:

```dockerfile
# Multi-stage Python Dockerfile (optimized from 1.2GB to 250MB)
ARG PYTHON_VERSION=3.11

# =============================================================================
# Stage 1: Builder
# Purpose: Install build dependencies and compile packages
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libpq-dev \
        python3-dev \
        && rm -rf /var/lib/apt/lists/*

# Copy requirements (separate layer for caching)
COPY requirements.txt .

# Install dependencies to user directory
RUN pip install --user --no-cache-dir --upgrade pip && \
    pip install --user --no-cache-dir -r requirements.txt

# =============================================================================
# Stage 2: Runtime
# Purpose: Minimal production image
# =============================================================================
FROM python:${PYTHON_VERSION}-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser . .

# Set PATH
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user
USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Start with uvicorn (production ASGI server)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Step 5: Generated .dockerignore

```
__pycache__
*.pyc
*.pyo
*.pyd
.Python
.git
.env
.venv
venv/
env/
*.log
.pytest_cache
.coverage
htmlcov/
dist/
build/
*.egg-info
.vscode
.idea
*.md
README.md
tests/
.gitignore
.dockerignore
```

---

## Step 6: Before/After Comparison

| Metric | Before (Original) | After (Optimized) | Improvement |
|--------|------------------|-------------------|-------------|
| **Base Image** | python:latest (1GB) | python:3.11-slim (150MB) | -85% |
| **Final Size** | 1.2GB | 250MB | -79% |
| **Layers** | 6 | 14 | More granular (better caching) |
| **Root User** | ❌ Yes | ✅ No (appuser:1000) | Security +++ |
| **HEALTHCHECK** | ❌ No | ✅ Yes | Monitoring +++ |
| **Multi-stage** | ❌ No | ✅ Yes (2 stages) | Size reduction +++ |
| **Version Pinning** | ❌ :latest | ✅ 3.11 | Reproducibility +++ |
| **Layer Caching** | ❌ Poor | ✅ Optimized | Build speed +++ |
| **hadolint Issues** | 4 errors | 0 errors | Quality +++ |
| **Best Practices** | 2/10 | 10/10 | +800% |

---

## Step 7: Verification

### 7.1 Build Optimized Image

```bash
docker build -f Dockerfile.optimized -t myapp:optimized .
```

**Expected output**:
```
[+] Building 38.5s (16/16) FINISHED
 => [builder 1/4] FROM python:3.11-slim
 => [builder 2/4] RUN apt-get update && apt-get install -y gcc
 => [builder 3/4] COPY requirements.txt .
 => [builder 4/4] RUN pip install --user -r requirements.txt
 => [stage-1 1/5] RUN apt-get update && apt-get install -y libpq5
 => [stage-1 2/5] RUN useradd -m -u 1000 appuser
 => [stage-1 3/5] COPY --from=builder /root/.local /home/appuser/.local
 => [stage-1 4/5] COPY --chown=appuser:appuser . .
 => exporting to image
```

---

### 7.2 Compare Image Sizes

```bash
docker images | grep myapp
```

**Expected output**:
```
myapp   optimized   abc123  2 minutes ago   250MB
myapp   latest      def456  1 hour ago      1.2GB
```

**Size reduction**: 950MB saved (79%)

---

### 7.3 Test Functionality

```bash
# Run optimized container
docker run -d -p 8000:8000 --name myapp-opt myapp:optimized

# Wait for health check
sleep 10

# Verify health status
docker inspect --format='{{.State.Health.Status}}' myapp-opt
# Expected: healthy

# Test endpoint
curl http://localhost:8000/health
# Expected: {"status":"ok"}

# Cleanup
docker rm -f myapp-opt
```

---

### 7.4 Validate with hadolint

```bash
hadolint Dockerfile.optimized
```

**Expected**: No errors (exit code 0)

---

### 7.5 Security Scan (if trivy installed)

```bash
trivy image myapp:optimized
```

**Expected**: Significantly fewer vulnerabilities than `myapp:latest` (slim base has smaller attack surface)

---

## Step 8: Side-by-Side Diff

```diff
- FROM python:latest
+ ARG PYTHON_VERSION=3.11
+ FROM python:${PYTHON_VERSION}-slim AS builder

  WORKDIR /app

+ # Install build dependencies
+ RUN apt-get update && \
+     apt-get install -y --no-install-recommends gcc libpq-dev python3-dev && \
+     rm -rf /var/lib/apt/lists/*
+
+ # Copy requirements first (better caching)
+ COPY requirements.txt .
+
+ # Install to user directory
+ RUN pip install --user --no-cache-dir -r requirements.txt
+
+ # ===== Stage 2: Runtime =====
+ FROM python:${PYTHON_VERSION}-slim
+
+ RUN apt-get update && \
+     apt-get install -y --no-install-recommends libpq5 curl && \
+     rm -rf /var/lib/apt/lists/*
+
+ # Create non-root user
+ RUN useradd -m -u 1000 appuser && \
+     mkdir -p /app && \
+     chown -R appuser:appuser /app
+
+ WORKDIR /app
+
+ # Copy from builder
+ COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
+
+ # Copy application code
- COPY . .
- RUN pip install -r requirements.txt
+ COPY --chown=appuser:appuser . .
+
+ ENV PATH=/home/appuser/.local/bin:$PATH \
+     PYTHONUNBUFFERED=1 \
+     PYTHONDONTWRITEBYTECODE=1
+
+ USER appuser

  EXPOSE 8000

+ # Add health check
+ HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
+   CMD curl -f http://localhost:8000/health || exit 1
+
- CMD ["python", "main.py"]
+ CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Step 9: Performance Impact

### Build Time Comparison

| Dockerfile | First Build | Rebuild (no changes) | Rebuild (code change only) |
|------------|-------------|----------------------|----------------------------|
| **Original** | 120s | 115s | 110s (no caching) |
| **Optimized** | 85s | 5s (cached) | 8s (only app layer) |

**Key improvement**: Layer caching in optimized Dockerfile significantly reduces rebuild time.

---

### Runtime Performance

| Metric | Original | Optimized | Impact |
|--------|----------|-----------|--------|
| **Container start time** | 3.2s | 2.8s | -12% |
| **Memory usage (idle)** | 450MB | 180MB | -60% |
| **Attack surface (packages)** | 650+ | 150+ | -77% |

---

## Step 10: Apply Optimization

```bash
# Backup original
mv Dockerfile Dockerfile.old

# Use optimized version
mv Dockerfile.optimized Dockerfile

# Verify
git diff Dockerfile.old Dockerfile
```

---

## Summary

**Optimization Results**:
- ✅ Image size: 1.2GB → 250MB (-79%)
- ✅ Security: Root user → Non-root user
- ✅ Monitoring: No health check → HEALTHCHECK enabled
- ✅ Quality: 4 hadolint errors → 0 errors
- ✅ Best practices: 2/10 → 10/10
- ✅ Build time: 120s → 8s (cached rebuilds)

**Time saved**: ~4 hours of manual optimization and testing

**Files generated**:
- Dockerfile.optimized (2.3KB, 14 layers)
- .dockerignore (245 bytes, 18 exclusions)

---

## Lessons Learned

1. **Multi-stage builds are crucial** for compiled languages (Python, Node.js, Go)
2. **Base image choice matters** - slim/alpine can save 80-90% size
3. **Layer ordering is critical** - dependencies before code for caching
4. **Non-root user is mandatory** for security
5. **HEALTHCHECK enables self-healing** in orchestrators (Kubernetes, Docker Swarm)
6. **Version pinning prevents surprises** - never use :latest in production
7. **.dockerignore is essential** - reduces build context and image size

---

**Skill Used**: docker-skill v1.0.0
**Operation**: optimize-layers
**Date**: 2026-01-26
**Optimization Impact**: 79% size reduction, 10/10 best practices score
