# Multi-stage Node.js Dockerfile (production-optimized)
# Based on Docker best practices + Habr recommendations
#
# Best practices applied:
# ✅ Multi-stage builds (3 stages: deps → builder → runtime)
# ✅ Minimal base image (alpine - 180MB vs 1.1GB for node:18)
# ✅ Non-root user (nodejs user with UID 1001)
# ✅ Layer optimization (combined RUN commands with &&)
# ✅ .dockerignore required (see .dockerignore template)
# ✅ HEALTHCHECK configured (30s interval, 3 retries)
# ✅ Version pinning (no :latest tags)
# ✅ Cleanup in RUN (npm cache clean --force)
# ✅ COPY ordering (dependencies first for cache efficiency)
# ✅ No secrets (use environment variables or Docker secrets)

# Build arguments (configurable via docker build --build-arg)
ARG NODE_VERSION=18
ARG ALPINE_VERSION=3.18

# =============================================================================
# Stage 1: Dependencies
# Purpose: Install production dependencies only (separate layer for caching)
# Size impact: ~100MB (node_modules)
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS deps

# Set working directory
WORKDIR /app

# Install dependencies for native modules (if needed)
# Alpine packages: python3, make, g++ for node-gyp builds
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Copy package files (separate layer for better caching)
# This layer only rebuilds if package.json or package-lock.json changes
COPY package.json package-lock.json ./

# Install production dependencies only
# --only=production: Excludes devDependencies
# npm ci: Clean install (faster and more reliable than npm install)
RUN npm ci --only=production && \
    npm cache clean --force

# =============================================================================
# Stage 2: Builder
# Purpose: Install dev dependencies and build TypeScript/assets
# Size impact: ~300MB (full node_modules + build output) - discarded in final stage
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Copy package files
COPY package.json package-lock.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci && \
    npm cache clean --force

# Copy source code
# .dockerignore ensures node_modules, .git, tests, etc. are excluded
COPY . .

# Build application (TypeScript compilation, asset bundling, etc.)
# Adjust build command based on your package.json scripts
RUN npm run build

# Optional: Run tests during build (uncomment if needed)
# RUN npm run test

# Optional: Prune devDependencies after build
# RUN npm prune --production

# =============================================================================
# Stage 3: Runtime (Final Image)
# Purpose: Minimal production image with only runtime files
# Size impact: ~180MB (alpine base + prod dependencies + build output)
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION}

# Install runtime dependencies (if needed)
# Example: dumb-init for proper signal handling
RUN apk add --no-cache \
    dumb-init \
    && rm -rf /var/cache/apk/*

# Security: Create non-root user
# nodejs group (GID 1001) and nodejs user (UID 1001)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

WORKDIR /app

# Copy production dependencies from deps stage
# --chown ensures correct ownership (nodejs:nodejs)
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application from builder stage
# Adjust paths based on your build output (dist/, build/, etc.)
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist

# Copy package files (needed for npm scripts and metadata)
COPY --chown=nodejs:nodejs package.json package-lock.json ./

# Copy additional runtime files (if needed)
# Examples: public/, views/, config/
# COPY --chown=nodejs:nodejs public ./public
# COPY --chown=nodejs:nodejs config ./config

# Security: Switch to non-root user
USER nodejs

# Expose application port (adjust based on your app)
# Default: 3000 for most Node.js frameworks (Express, Koa, Fastify)
EXPOSE 3000

# Environment variables (override at runtime)
ENV NODE_ENV=production \
    PORT=3000

# Health check (adjust endpoint based on your app)
# This assumes you have a /health or /healthcheck endpoint
# Interval: 30s, Timeout: 3s, Start period: 5s, Retries: 3
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Alternative health check using wget (if node health check not suitable)
# RUN apk add --no-cache wget
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#   CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start application with dumb-init (proper signal handling)
# dumb-init ensures SIGTERM is properly forwarded to Node.js process
# Adjust entry point based on your package.json "main" or build output
CMD ["dumb-init", "node", "dist/index.js"]

# Alternative CMD without dumb-init (if not needed)
# CMD ["node", "dist/index.js"]

# Alternative CMD using npm start (not recommended for production)
# CMD ["npm", "start"]

# =============================================================================
# Build and Run Instructions
# =============================================================================
#
# Build image:
#   docker build -t myapp:latest .
#   docker build -t myapp:latest --build-arg NODE_VERSION=20 .
#
# Run container:
#   docker run -d -p 3000:3000 --name myapp myapp:latest
#   docker run -d -p 3000:3000 -e NODE_ENV=production myapp:latest
#
# Build with docker-compose:
#   docker-compose build
#   docker-compose up -d
#
# Check health:
#   docker inspect --format='{{json .State.Health}}' <container_id>
#
# View logs:
#   docker logs -f myapp
#
# =============================================================================
# Customization Guide
# =============================================================================
#
# 1. Adjust NODE_VERSION for your project (14, 16, 18, 20, 21)
# 2. Change EXPOSE port if your app uses different port
# 3. Update HEALTHCHECK endpoint (/health, /api/health, /healthz)
# 4. Modify build command if not using "npm run build"
# 5. Adjust entry point (dist/index.js, dist/main.js, build/server.js)
# 6. Add runtime files (public/, views/) if needed
# 7. Install additional alpine packages if required
#
# =============================================================================
# Troubleshooting
# =============================================================================
#
# Build fails with "node-gyp" errors:
#   → Ensure python3, make, g++ are installed in deps and builder stages
#
# Health check fails:
#   → Verify /health endpoint exists and returns 200
#   → Increase --start-period if app takes longer to start
#   → Check logs: docker logs <container>
#
# Permission denied errors:
#   → Ensure --chown=nodejs:nodejs in COPY commands
#   → Check file permissions in source code
#
# Large image size:
#   → Verify .dockerignore excludes node_modules, .git, tests
#   → Remove unnecessary alpine packages
#   → Consider distroless base image for even smaller size
#
# =============================================================================
