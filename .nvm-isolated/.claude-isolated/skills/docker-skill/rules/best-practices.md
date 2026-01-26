# Docker Best Practices

Consolidated from:
- **Docker Official Documentation**: https://docs.docker.com/build/building/best-practices/
- **Habr статья**: https://habr.com/ru/companies/domclick/articles/546922/ (Как мы оптимизировали Docker-образы)
- **OWASP Docker Security**: https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html

**Last Updated**: 2026-01-26
**Applies to**: docker-skill v1.0.0

---

## Rule 1: Multi-Stage Builds

### Description
Use multi-stage builds to separate build-time dependencies from runtime dependencies, resulting in smaller and more secure final images.

### Rationale
- **Size reduction**: 60-80% smaller images by excluding build tools
- **Security**: Fewer packages = smaller attack surface
- **Clarity**: Logical separation between build and runtime

### Example (Node.js)

**Bad** (single-stage):
```dockerfile
FROM node:18
WORKDIR /app
COPY . .
RUN npm install  # Includes devDependencies
RUN npm run build
CMD ["node", "dist/index.js"]
# Result: 1.1GB image with dev dependencies
```

**Good** (multi-stage):
```dockerfile
# Stage 1: Dependencies
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Builder
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Runtime
FROM node:18-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
# Result: 180MB image (84% reduction)
```

### Enforcement
- **docker-skill**: Auto-generates multi-stage for Node.js and Python
- **hadolint**: Warns if multiple RUN apt-get install without cleanup

### Impact
- **Critical** for compiled languages (TypeScript, Go, Rust)
- **High** for Python (build dependencies for C extensions)
- **Medium** for static sites (build tools vs runtime server)

---

## Rule 2: Minimal Base Images

### Description
Use the smallest base image that meets your requirements (alpine, slim, distroless, or scratch).

### Rationale
- **Size**: Alpine is 5-10x smaller than full images
- **Security**: Fewer packages = fewer CVEs
- **Performance**: Faster pulls and deployments

### Base Image Comparison

| Language | Image | Size | Use Case | Security |
|----------|-------|------|----------|----------|
| **Node.js** | node:18 | 1.1GB | Development | Low |
| | node:18-slim | 250MB | Production (Debian-based) | Medium |
| | node:18-alpine | 180MB | **Production (recommended)** | High |
| | gcr.io/distroless/nodejs18 | 120MB | Maximum security | Very High |
| **Python** | python:3.11 | 1GB | Development | Low |
| | python:3.11-slim | 150MB | **Production (recommended)** | High |
| | python:3.11-alpine | 50MB | Advanced (requires build setup) | Very High |
| | gcr.io/distroless/python3 | 80MB | Maximum security | Very High |
| **Go** | golang:1.21 | 800MB | Build stage only | N/A |
| | alpine:3.18 | 7MB | Runtime (if CGO disabled) | Very High |
| | scratch | 0MB | **Runtime (static binary)** | Maximum |

### Example (Python)

**Bad**:
```dockerfile
FROM python:latest  # 1GB, unversioned
```

**Good**:
```dockerfile
FROM python:3.11-slim  # 150MB, versioned
```

**Best** (advanced):
```dockerfile
FROM python:3.11-alpine  # 50MB, requires more setup
```

### Enforcement
- **docker-skill**: Defaults to alpine for Node.js, slim for Python
- **hadolint**: DL3006 - "Always tag the version of an image explicitly"

### Trade-offs
- **Alpine**: Smaller size but uses `musl libc` instead of `glibc` (may cause compatibility issues)
- **Slim**: Larger but better compatibility with pre-built Python wheels
- **Distroless**: No shell (harder to debug), maximum security

---

## Rule 3: Non-Root User

### Description
Always run containers as non-root user to minimize security risks.

### Rationale
- **Security**: Container escape exploits are less dangerous with non-root user
- **Compliance**: Required by many security policies and Kubernetes Pod Security Standards
- **Least privilege**: Follows principle of least privilege

### Example (Node.js)

**Bad**:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .
CMD ["node", "index.js"]
# Runs as root (UID 0) - security risk!
```

**Good**:
```dockerfile
FROM node:18-alpine

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

WORKDIR /app
COPY --chown=nodejs:nodejs . .

USER nodejs  # ⬅ Switch to non-root
CMD ["node", "index.js"]
```

### Example (Python)

```dockerfile
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

WORKDIR /app
COPY --chown=appuser:appuser . .

USER appuser  # ⬅ Switch to non-root
CMD ["python", "main.py"]
```

### Enforcement
- **docker-skill**: Auto-adds USER directive
- **hadolint**: DL3002 - "Last USER should not be root"
- **Kubernetes**: Pod Security Policy can enforce runAsNonRoot

### Important Notes
- Use `--chown` in COPY to set correct ownership
- Ensure user has permissions to /app and any volume mounts
- Some base images already have non-root user (e.g., node:alpine has `node` user)

---

## Rule 4: Layer Optimization

### Description
Combine RUN commands with `&&` to reduce the number of layers and overall image size.

### Rationale
- **Size**: Each RUN creates a new layer with overhead
- **Caching**: Fewer layers = better cache efficiency
- **Cleanup**: Temporary files in same layer don't add to image size

### Example

**Bad** (creates 4 layers):
```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN rm -rf /var/lib/apt/lists/*
# Result: Cache still persists in layers 1-3
```

**Good** (creates 1 layer):
```dockerfile
RUN apt-get update && \
    apt-get install -y \
        curl \
        vim \
        && rm -rf /var/lib/apt/lists/*
# Result: Cache removed in same layer
```

### Best Practices
- Combine related commands with `&&`
- Use `\` for line continuation (readability)
- Sort packages alphabetically for easier maintenance
- Clean up in the same RUN command

### Enforcement
- **docker-skill**: Templates follow this pattern
- **hadolint**: DL3009 - "Delete the apt-get lists after installing something"

### Alpine-specific

```dockerfile
RUN apk add --no-cache \
        python3 \
        make \
        g++ \
        && rm -rf /var/cache/apk/*
```

---

## Rule 5: .dockerignore

### Description
Create `.dockerignore` file to exclude unnecessary files from Docker build context.

### Rationale
- **Build speed**: Smaller context = faster upload to Docker daemon
- **Size**: Prevents accidental inclusion of large files (node_modules, .git)
- **Security**: Excludes sensitive files (.env, credentials)

### Standard .dockerignore (Node.js)

```
# Dependencies
node_modules
npm-debug.log*
.npm

# Build output
dist
build
coverage

# IDE
.vscode
.idea
*.swp
*.swo

# Git
.git
.gitignore
.gitattributes

# Environment
.env
.env.local
.env.*.local

# Documentation
*.md
README.md
LICENSE

# Tests
tests
__tests__
*.test.js
*.test.ts
.nyc_output

# Misc
.DS_Store
Thumbs.db
```

### Standard .dockerignore (Python)

```
# Bytecode
__pycache__
*.pyc
*.pyo
*.pyd
.Python

# Virtual environments
.venv
venv/
env/
ENV/

# Build output
dist/
build/
*.egg-info

# Tests
.pytest_cache
.coverage
htmlcov/
.tox/

# IDE
.vscode
.idea
*.swp

# Git
.git
.gitignore

# Environment
.env
.env.local

# Documentation
*.md
README.md
docs/
```

### Enforcement
- **docker-skill**: Auto-generates .dockerignore
- **Manual check**: `docker build` output shows context size

### Verification

```bash
# Check build context size
docker build --no-cache -t test . 2>&1 | grep "Sending build context"
# Expected: < 10MB for typical app (without node_modules)
```

---

## Rule 6: HEALTHCHECK

### Description
Add HEALTHCHECK directive to enable Docker to test container health.

### Rationale
- **Orchestration**: Kubernetes/Swarm use health checks for rolling updates
- **Self-healing**: Unhealthy containers automatically restarted
- **Monitoring**: External tools can query health status

### Syntax

```dockerfile
HEALTHCHECK [OPTIONS] CMD <command>

OPTIONS:
  --interval=<duration>  # Default: 30s
  --timeout=<duration>   # Default: 30s
  --start-period=<duration>  # Default: 0s (grace period)
  --retries=<count>      # Default: 3
```

### Example (Node.js with HTTP endpoint)

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"
```

### Example (Python with curl)

```dockerfile
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
```

### Example (Database check)

```dockerfile
# PostgreSQL
HEALTHCHECK CMD pg_isready -U postgres || exit 1

# Redis
HEALTHCHECK CMD redis-cli ping || exit 1

# MongoDB
HEALTHCHECK CMD mongosh --eval "db.adminCommand('ping')" || exit 1
```

### Enforcement
- **docker-skill**: Auto-adds HEALTHCHECK (configurable)
- **Verification**: `docker inspect --format='{{.State.Health}}' <container>`

### Best Practices
- Set `--start-period` for slow-starting apps (>30s)
- Use lightweight check (HTTP GET, not full integration test)
- Return exit code 0 (success) or 1 (failure)
- Health endpoint should check critical dependencies (DB, Redis)

---

## Rule 7: Version Pinning

### Description
Always specify exact versions for base images and dependencies. Never use `:latest`.

### Rationale
- **Reproducibility**: Builds are consistent across environments
- **Stability**: Prevents unexpected breakages from upstream changes
- **Security**: Controlled updates with testing

### Example

**Bad**:
```dockerfile
FROM node:latest  # ⚠️ Unpredictable, can break at any time
FROM python:3     # ⚠️ Will use 3.12 when released, may break
```

**Good**:
```dockerfile
FROM node:18.20.0-alpine3.18  # ✅ Fully pinned
FROM python:3.11.7-slim       # ✅ Specific version
```

**Acceptable** (minor version pinning):
```dockerfile
FROM node:18-alpine  # ✅ Gets patch updates (18.20.x) but not major/minor
FROM python:3.11-slim  # ✅ Gets patch updates (3.11.x)
```

### Enforcement
- **docker-skill**: Uses specific versions in templates
- **hadolint**: DL3006 - "Always tag the version of an image explicitly"

### Update Strategy
1. Pin exact version in Dockerfile
2. Test thoroughly with that version
3. Update version explicitly when ready
4. Never rely on `:latest` in production

---

## Rule 8: Cleanup in RUN

### Description
Remove package manager cache in the same RUN command to prevent cache from persisting in image layers.

### Rationale
- **Size**: apt/apk/yum cache can add 100-500MB
- **Layer mechanics**: Files removed in later layers still exist in image

### Example (Debian/Ubuntu - apt)

**Bad**:
```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*  # ⚠️ Too late! Cache already in layer 2
```

**Good**:
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*  # ✅ Cleanup in same layer
```

### Example (Alpine - apk)

**Good**:
```dockerfile
RUN apk add --no-cache curl  # ✅ --no-cache prevents cache creation

# Or if you need cache temporarily:
RUN apk add --virtual .build-deps gcc make && \
    make install && \
    apk del .build-deps  # ✅ Remove build dependencies
```

### Example (Python - pip)

**Good**:
```dockerfile
RUN pip install --no-cache-dir -r requirements.txt  # ✅ Don't cache pip packages
```

### Enforcement
- **docker-skill**: Templates use --no-cache or cleanup
- **hadolint**: DL3009 - "Delete the apt-get lists after installing something"

### Cleanup Commands by Package Manager

| Package Manager | Cleanup Command |
|-----------------|-----------------|
| **apt** (Debian/Ubuntu) | `rm -rf /var/lib/apt/lists/*` |
| **apk** (Alpine) | `--no-cache` flag or `rm -rf /var/cache/apk/*` |
| **yum/dnf** (RHEL/CentOS) | `yum clean all` or `dnf clean all` |
| **pip** (Python) | `--no-cache-dir` flag |
| **npm** (Node.js) | `npm cache clean --force` |

---

## Rule 9: COPY Ordering

### Description
Copy dependency files (package.json, requirements.txt) before application code to leverage Docker layer caching.

### Rationale
- **Build speed**: Dependencies rarely change, so layer is cached
- **Efficiency**: Code changes don't invalidate dependency layer

### How Layer Caching Works

1. Docker caches each layer by instruction + file checksum
2. If instruction or files change, cache is invalidated
3. All subsequent layers are also invalidated

### Example (Node.js)

**Bad** (cache invalidated on every code change):
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .  # ⚠️ Invalidates cache when any file changes
RUN npm install  # ⚠️ Reinstalls all dependencies on every build
CMD ["node", "index.js"]
```

**Good** (cache preserved for dependencies):
```dockerfile
FROM node:18-alpine
WORKDIR /app

# 1. Copy dependency files first
COPY package.json package-lock.json ./

# 2. Install dependencies (cached unless package*.json change)
RUN npm ci

# 3. Copy application code (changes frequently)
COPY . .

CMD ["node", "index.js"]
```

### Example (Python)

**Good**:
```dockerfile
FROM python:3.11-slim
WORKDIR /app

# 1. Copy requirements first
COPY requirements.txt .

# 2. Install dependencies (cached)
RUN pip install -r requirements.txt

# 3. Copy code
COPY . .

CMD ["python", "main.py"]
```

### Cache Efficiency

| Scenario | Bad Dockerfile | Good Dockerfile |
|----------|---------------|-----------------|
| **No changes** | 2s (all cached) | 2s (all cached) |
| **Code change** | 120s (reinstall deps) | 5s (deps cached) |
| **Dependency change** | 120s | 120s (expected) |

### Enforcement
- **docker-skill**: Templates follow this pattern
- **Manual verification**: Check `docker build` output for "Using cache"

---

## Rule 10: No Secrets in Dockerfile

### Description
Never hardcode secrets (API keys, passwords, tokens) in Dockerfile or commit them to version control.

### Rationale
- **Security**: Secrets persist in image layers even if deleted later
- **Compliance**: Violates security policies and regulations
- **Exposure**: Images may be pushed to public registries

### Detection Patterns

The skill scans for these patterns:
- `API_KEY=`
- `PASSWORD=`
- `SECRET=`
- `TOKEN=`
- `aws_access_key`
- `PRIVATE_KEY`
- `ssh-rsa`
- `BEGIN RSA PRIVATE KEY`

### Example

**Bad** (hardcoded secrets):
```dockerfile
FROM node:18-alpine
ENV API_KEY=sk-1234567890abcdef  # ⚠️ Visible in image history!
ENV DB_PASSWORD=super_secret_123  # ⚠️ Committed to git!
CMD ["node", "index.js"]
```

**Good** (use environment variables):
```dockerfile
FROM node:18-alpine
# Secrets passed at runtime via docker run -e or docker-compose.yml
CMD ["node", "index.js"]
```

### Secure Alternatives

#### 1. Environment Variables (Runtime)

```bash
docker run -e API_KEY=secret -e DB_PASSWORD=secret myapp
```

#### 2. Docker Secrets (Swarm/Compose)

```yaml
# docker-compose.yml
services:
  app:
    secrets:
      - api_key
      - db_password

secrets:
  api_key:
    external: true
  db_password:
    external: true
```

#### 3. BuildKit Secrets (Build-time)

```dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) npm install
```

```bash
docker build --secret id=api_key,src=./api_key.txt .
```

#### 4. .env File (docker-compose)

```yaml
# docker-compose.yml
services:
  app:
    env_file: .env  # ⚠️ Ensure .env in .gitignore!
```

```bash
# .env (NOT in git!)
API_KEY=sk-1234567890abcdef
DB_PASSWORD=super_secret_123
```

### Enforcement
- **docker-skill**: Regex scan detects common secret patterns
- **git-secrets**: Pre-commit hook to prevent committing secrets
- **trufflehog**: Scans git history for secrets

### Verification

```bash
# Check image history for secrets
docker history myapp:latest --no-trunc | grep -i "api_key\|password\|secret"

# Inspect image layers
dive myapp:latest  # Interactive tool to explore layers
```

---

## Summary Table

| Rule | Impact | Enforcement | Violation Cost |
|------|--------|-------------|----------------|
| **1. Multi-stage builds** | Critical | Auto (docker-skill) | +60-80% image size |
| **2. Minimal base images** | High | Auto (alpine/slim default) | +500MB-1GB |
| **3. Non-root user** | Critical | Auto (USER directive) | Security vulnerability |
| **4. Layer optimization** | Medium | Template (&&) | +10-20% image size |
| **5. .dockerignore** | High | Auto-generated | +100-500MB, slow builds |
| **6. HEALTHCHECK** | High | Auto (configurable) | No self-healing |
| **7. Version pinning** | High | Template (:version) | Build unpredictability |
| **8. Cleanup in RUN** | Medium | Template (rm cache) | +100-500MB |
| **9. COPY ordering** | Medium | Template (deps first) | Slow builds |
| **10. No secrets** | Critical | Regex scan | Security breach |

---

## References

- **Docker Official Best Practices**: https://docs.docker.com/build/building/best-practices/
- **Habr: Как мы оптимизировали Docker-образы**: https://habr.com/ru/companies/domclick/articles/546922/
- **OWASP Docker Security**: https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
- **hadolint Rules**: https://github.com/hadolint/hadolint#rules
- **Multi-stage builds**: https://docs.docker.com/build/building/multi-stage/
- **Distroless base images**: https://github.com/GoogleContainerTools/distroless

---

**Maintained by**: docker-skill v1.0.0
**Last updated**: 2026-01-26
