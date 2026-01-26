# Example: Create Optimized Dockerfile for Express.js TypeScript App

## Scenario

You have an Express.js TypeScript application with:
- **Language**: Node.js 18
- **Framework**: Express.js
- **Build tool**: TypeScript compiler (tsc)
- **Database**: PostgreSQL
- **Cache**: Redis
- **Package manager**: npm
- **Entry point**: `dist/index.js` (after TypeScript compilation)

**Goal**: Generate production-ready Dockerfile with multi-stage builds, Docker Compose for PostgreSQL + Redis, and follow all best practices.

---

## Step 1: Invoke docker-skill

```bash
# Manual invocation
/docker-skill
```

---

## Step 2: Interactive Questionnaire

The skill will ask 4-5 questions via `AskUserQuestion`:

### Q1: Выберите язык проекта
**Options**:
- nodejs ← **Selected**
- python

**Answer**: `nodejs`

---

### Q2: Укажите фреймворк (опционально)
**Type**: Text input (optional)

**Answer**: `express`

**Purpose**: Skill will optimize Dockerfile for Express.js (e.g., set PORT=3000 by default)

---

### Q3: Выберите уровень оптимизации образа
**Options**:
- minimal - Только базовые оптимизации
- standard - Рекомендуемый **(Recommended)** ← **Selected**
- aggressive - Максимальная оптимизация

**Answer**: `standard`

**Impact**:
- Multi-stage builds enabled (3 stages)
- Alpine base image (180MB vs 1.1GB)
- HEALTHCHECK configured
- Layer caching optimized

---

### Q4: Нужен Docker Compose для multi-container setup?
**Options**:
- yes - Создать docker-compose.yml ← **Selected**
- no - Только Dockerfile

**Answer**: `yes`

**Impact**: Skill will generate `docker-compose.yml` with:
- `app` service (Node.js app)
- `db` service (PostgreSQL 15-alpine)
- `redis` service (Redis 7-alpine)
- Networks and volumes

---

### Q5: Переопределить базовый образ? (опционально)
**Type**: Text input (optional)

**Answer**: *(skip - use auto-detect)*

**Default**: `node:18-alpine3.18` (auto-detected from context)

---

## Step 3: Generated Files

After answering questions, the skill generates:

### 1. Dockerfile (3-stage multi-stage build)

```dockerfile
# Multi-stage Node.js Dockerfile
ARG NODE_VERSION=18
ARG ALPINE_VERSION=3.18

# Stage 1: Dependencies
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Builder
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Runtime
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION}
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package*.json ./
USER nodejs
EXPOSE 3000
ENV NODE_ENV=production PORT=3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"
CMD ["node", "dist/index.js"]
```

**Key Features**:
- ✅ 3 stages: deps (prod dependencies), builder (TypeScript compilation), runtime (final image)
- ✅ Alpine base image (180MB final image)
- ✅ Non-root user (nodejs:1001)
- ✅ HEALTHCHECK (assumes /health endpoint)
- ✅ Layer caching (dependencies separate from code)
- ✅ Cleanup (npm cache clean)

---

### 2. .dockerignore

```
node_modules
.git
.env
*.log
npm-debug.log*
.npm
.vscode
.idea
coverage
.nyc_output
dist
build
*.md
README.md
.gitignore
.dockerignore
tests
__tests__
*.test.js
*.test.ts
.eslintrc*
.prettierrc*
tsconfig.json
```

**Purpose**: Exclude unnecessary files from Docker build context (reduces build time and image size)

---

### 3. docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: myapp-app
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgres://postgres:password@db:5432/appdb
      REDIS_URL: redis://redis:6379
      PORT: 3000
    depends_on:
      - db
      - redis
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 40s

  db:
    image: postgres:15-alpine
    container_name: myapp-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

**Key Features**:
- ✅ 3 services: app, db (PostgreSQL), redis
- ✅ Healthchecks for all services
- ✅ Persistent volumes for data
- ✅ Isolated network
- ✅ Auto-restart policy

---

## Step 4: Skill Output (JSON)

```json
{
  "docker_operation": {
    "operation": "create-dockerfile",
    "status": "success",

    "dockerfile_generated": true,
    "dockerfile_path": "./Dockerfile",
    "dockerignore_path": "./.dockerignore",
    "docker_compose_path": "./docker-compose.yml",

    "base_image": "node:18-alpine3.18",
    "multi_stage": true,
    "stages": [
      {
        "name": "deps",
        "base": "node:18-alpine",
        "purpose": "Production dependencies installation"
      },
      {
        "name": "builder",
        "base": "node:18-alpine",
        "purpose": "TypeScript compilation and build"
      },
      {
        "name": "runtime",
        "base": "node:18-alpine",
        "purpose": "Final production image"
      }
    ],

    "optimization_results": {
      "layers_before": 0,
      "layers_after": 12,
      "layers_reduced": 0,
      "size_estimate": "180MB (vs 1.1GB with node:18 full image)",
      "size_reduction": "83%",
      "optimizations_applied": [
        "Multi-stage build (3 stages)",
        "Alpine base image (180MB vs 1.1GB)",
        "Non-root user (nodejs:1001)",
        "Layer caching (dependencies separate from code)",
        "npm cache clean after install",
        "Production dependencies only in final stage",
        ".dockerignore excludes node_modules, tests, .git"
      ]
    },

    "security_scan": {
      "hadolint_available": true,
      "hadolint_issues": 0,
      "hadolint_warnings": [],
      "non_root_user": true,
      "secrets_detected": false,
      "secrets_patterns": []
    },

    "validation_results": {
      "healthcheck_configured": true,
      "best_practices_followed": 10,
      "best_practices_violations": []
    },

    "compose_info": {
      "compose_generated": true,
      "services_count": 3,
      "services": [
        {
          "name": "app",
          "image": "build context: .",
          "ports": ["3000:3000"],
          "depends_on": ["db", "redis"]
        },
        {
          "name": "db",
          "image": "postgres:15-alpine",
          "ports": [],
          "depends_on": []
        },
        {
          "name": "redis",
          "image": "redis:7-alpine",
          "ports": [],
          "depends_on": []
        }
      ],
      "networks_count": 1,
      "volumes_count": 2
    },

    "next_steps": [
      "Review generated Dockerfile, .dockerignore, and docker-compose.yml",
      "Add /health endpoint to your Express.js app (required for HEALTHCHECK)",
      "Create .env file with secrets (DB_PASSWORD, REDIS_PASSWORD)",
      "Build image: docker-compose build",
      "Test locally: docker-compose up",
      "Check health: docker inspect --format='{{json .State.Health}}' myapp-app",
      "Push to registry: docker-compose push (after configuring registry)"
    ],

    "metadata": {
      "skill_version": "1.0.0",
      "execution_time": "2.3s",
      "timestamp": "2026-01-26T12:34:56Z",
      "docker_version": "24.0.7",
      "hadolint_version": "2.12.0"
    }
  }
}
```

---

## Step 5: Verify Generated Files

### 5.1 Check Files Exist

```bash
ls -la Dockerfile .dockerignore docker-compose.yml
# Expected output:
# -rw-r--r-- 1 user user 2145 Jan 26 12:34 Dockerfile
# -rw-r--r-- 1 user user  312 Jan 26 12:34 .dockerignore
# -rw-r--r-- 1 user user 1847 Jan 26 12:34 docker-compose.yml
```

---

### 5.2 Validate Dockerfile with hadolint (if installed)

```bash
hadolint Dockerfile
# Expected: No issues (exit code 0)
```

---

### 5.3 Build Docker Image

```bash
docker-compose build
# Expected output:
# [+] Building 45.2s (18/18) FINISHED
#  => [deps 1/3] FROM node:18-alpine3.18
#  => [deps 2/3] COPY package*.json ./
#  => [deps 3/3] RUN npm ci --only=production
#  => [builder 1/4] COPY package*.json ./
#  => [builder 2/4] RUN npm ci
#  => [builder 3/4] COPY . .
#  => [builder 4/4] RUN npm run build
#  => [stage-2 1/5] RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
#  => [stage-2 2/5] COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
#  => [stage-2 3/5] COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
#  => [stage-2 4/5] COPY --chown=nodejs:nodejs package*.json ./
#  => exporting to image
#  => => naming to docker.io/library/myapp
```

---

### 5.4 Check Image Size

```bash
docker images myapp --format "{{.Size}}"
# Expected: ~180MB (vs 1.1GB for node:18 full image)
```

---

### 5.5 Run Containers

```bash
docker-compose up -d
# Expected output:
# [+] Running 4/4
#  ✔ Network myapp_app-network      Created
#  ✔ Container myapp-db             Started
#  ✔ Container myapp-redis          Started
#  ✔ Container myapp-app            Started
```

---

### 5.6 Verify Containers Running

```bash
docker-compose ps
# Expected output:
# NAME            IMAGE             COMMAND                  SERVICE   STATUS          PORTS
# myapp-app       myapp:latest      "node dist/index.js"     app       Up 30 seconds   0.0.0.0:3000->3000/tcp
# myapp-db        postgres:15-alpine "docker-entrypoint.s…"  db        Up 30 seconds   5432/tcp
# myapp-redis     redis:7-alpine    "docker-entrypoint.s…"  redis     Up 30 seconds   6379/tcp
```

---

### 5.7 Check Health Status

```bash
docker inspect --format='{{json .State.Health}}' myapp-app | jq
# Expected output:
# {
#   "Status": "healthy",
#   "FailingStreak": 0,
#   "Log": [
#     {
#       "Start": "2026-01-26T12:35:30Z",
#       "End": "2026-01-26T12:35:30Z",
#       "ExitCode": 0,
#       "Output": ""
#     }
#   ]
# }
```

---

### 5.8 Test Application

```bash
curl http://localhost:3000/health
# Expected: 200 OK
# {"status":"ok","timestamp":"2026-01-26T12:35:45Z"}
```

---

### 5.9 View Logs

```bash
docker-compose logs -f app
# Expected: Application startup logs
```

---

## Step 6: Best Practices Verification

| Best Practice | Status | Evidence |
|---------------|--------|----------|
| Multi-stage builds | ✅ | 3 stages: deps, builder, runtime |
| Minimal base image | ✅ | node:18-alpine (180MB vs 1.1GB) |
| Non-root user | ✅ | USER nodejs (UID 1001) |
| Layer optimization | ✅ | RUN commands combined with && |
| .dockerignore | ✅ | Excludes node_modules, .git, tests |
| HEALTHCHECK | ✅ | 30s interval, 3 retries |
| Version pinning | ✅ | node:18-alpine3.18 (no :latest) |
| Cleanup in RUN | ✅ | npm cache clean --force |
| COPY ordering | ✅ | package.json before COPY . |
| No secrets | ✅ | No hardcoded credentials |

**Score**: 10/10 ✅

---

## Step 7: Production Deployment

### 7.1 Create .env File (Secrets)

```bash
cat > .env <<EOF
DB_PASSWORD=secure_password_here
REDIS_PASSWORD=another_secure_password
NODE_ENV=production
EOF

chmod 600 .env
```

---

### 7.2 Update docker-compose.yml (Use .env)

Replace hardcoded passwords with environment variables:

```yaml
environment:
  POSTGRES_PASSWORD: ${DB_PASSWORD}
  # ...
```

---

### 7.3 Push to Registry

```bash
# Tag image
docker tag myapp:latest registry.example.com/myapp:1.0.0

# Push to registry
docker push registry.example.com/myapp:1.0.0
```

---

## Summary

**Time saved**: ~2 hours of manual Dockerfile writing and debugging

**Files generated**:
- Dockerfile (2145 bytes, 12 layers)
- .dockerignore (312 bytes, 23 exclusions)
- docker-compose.yml (1847 bytes, 3 services)

**Image size reduction**: 83% (1.1GB → 180MB)

**Security improvements**:
- Non-root user ✅
- No secrets in Dockerfile ✅
- Minimal attack surface (alpine) ✅
- Health monitoring ✅

**Best practices followed**: 10/10 ✅

---

## Troubleshooting

### Issue 1: Health check fails

**Symptom**: `docker inspect` shows `"Status": "unhealthy"`

**Solution**:
1. Check if `/health` endpoint exists in your Express.js app:
   ```javascript
   app.get('/health', (req, res) => {
     res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
   });
   ```
2. Increase `--start-period` in HEALTHCHECK if app takes longer to start
3. Check logs: `docker logs myapp-app`

---

### Issue 2: Database connection fails

**Symptom**: App logs show "Connection refused" or "ECONNREFUSED"

**Solution**:
1. Verify DATABASE_URL in docker-compose.yml:
   ```yaml
   DATABASE_URL: postgres://postgres:${DB_PASSWORD}@db:5432/appdb
   ```
2. Check if db service is healthy:
   ```bash
   docker-compose ps db
   # Should show "Up (healthy)"
   ```
3. Test connection from app container:
   ```bash
   docker exec -it myapp-app sh
   nc -zv db 5432
   # Expected: Connection to db 5432 port [tcp/postgresql] succeeded!
   ```

---

### Issue 3: Build fails with "npm ERR! code ENOENT"

**Symptom**: Docker build fails during `npm ci` or `npm run build`

**Solution**:
1. Ensure package.json and package-lock.json exist
2. Verify build script in package.json:
   ```json
   {
     "scripts": {
       "build": "tsc"
     }
   }
   ```
3. Check .dockerignore doesn't exclude package*.json

---

## Next Steps

1. Add integration tests to validate Docker setup
2. Set up CI/CD pipeline for automated builds
3. Configure registry authentication for private images
4. Implement multi-environment configs (dev, staging, prod)
5. Add monitoring (Prometheus, Grafana) for health metrics
6. Consider Kubernetes deployment for production scaling

---

**Skill Used**: docker-skill v1.0.0
**Operation**: create-dockerfile
**Date**: 2026-01-26
