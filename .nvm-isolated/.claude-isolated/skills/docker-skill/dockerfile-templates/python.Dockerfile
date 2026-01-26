# Multi-stage Python Dockerfile (production-optimized)
# Based on Docker best practices + Habr recommendations
#
# Best practices applied:
# ✅ Multi-stage builds (2 stages: builder → runtime)
# ✅ Minimal base image (slim - 250MB vs 1GB for python:3.11)
# ✅ Non-root user (appuser with UID 1000)
# ✅ Layer optimization (combined RUN commands with &&)
# ✅ .dockerignore required (see .dockerignore template)
# ✅ HEALTHCHECK configured (30s interval, 3 retries)
# ✅ Version pinning (specific Python version)
# ✅ Cleanup in RUN (rm -rf /var/lib/apt/lists/*)
# ✅ COPY ordering (requirements first for cache efficiency)
# ✅ No secrets (use environment variables or Docker secrets)

# Build arguments (configurable via docker build --build-arg)
ARG PYTHON_VERSION=3.11

# =============================================================================
# Stage 1: Builder
# Purpose: Install build dependencies and compile Python packages
# Size impact: ~500MB (build tools + all packages) - discarded in final stage
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS builder

# Set working directory
WORKDIR /app

# Install build dependencies (required for packages with C extensions)
# gcc: C compiler for native extensions (e.g., psycopg2, pillow)
# libpq-dev: PostgreSQL client library headers
# python3-dev: Python development headers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        libpq-dev \
        python3-dev \
        build-essential \
        && rm -rf /var/lib/apt/lists/*

# Copy requirements file (separate layer for better caching)
# This layer only rebuilds if requirements.txt changes
COPY requirements.txt .

# Install Python dependencies to user directory
# --user: Install to ~/.local (can be copied to runtime stage)
# --no-cache-dir: Don't cache pip packages (reduces image size)
# --upgrade: Ensure latest compatible versions
RUN pip install --user --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --user --no-cache-dir -r requirements.txt

# Optional: Install additional build-time dependencies
# COPY requirements-dev.txt .
# RUN pip install --user --no-cache-dir -r requirements-dev.txt

# =============================================================================
# Stage 2: Runtime (Final Image)
# Purpose: Minimal production image with only runtime files
# Size impact: ~250MB (slim base + compiled packages + application code)
# =============================================================================
FROM python:${PYTHON_VERSION}-slim

# Install runtime dependencies (libraries needed by compiled packages)
# libpq5: PostgreSQL client library (runtime)
# curl: For health checks (alternative: wget)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Security: Create non-root user
# appuser with UID 1000, home directory /home/appuser
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

# Set working directory
WORKDIR /app

# Copy installed packages from builder stage
# --from=builder: Copy from previous stage
# /root/.local: User-installed packages location
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy application code
# .dockerignore ensures __pycache__, .git, tests, etc. are excluded
COPY --chown=appuser:appuser . .

# Set PATH to include user-installed packages
ENV PATH=/home/appuser/.local/bin:$PATH

# Security: Switch to non-root user
USER appuser

# Expose application port (adjust based on your framework)
# Default: 8000 for FastAPI/Django, 5000 for Flask
EXPOSE 8000

# Environment variables (override at runtime)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Health check (adjust endpoint based on your framework)
# FastAPI: /health or /docs (Swagger)
# Django: /admin/ or /health/
# Flask: /health or /
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Alternative health check using Python requests (if curl not installed)
# HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
#   CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=2)" || exit 1

# Alternative health check using wget
# RUN apt-get update && apt-get install -y --no-install-recommends wget && rm -rf /var/lib/apt/lists/*
# HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
#   CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# Start application (adjust based on your framework)
# FastAPI with uvicorn:
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

# Alternative: FastAPI with Gunicorn (production-grade ASGI server)
# CMD ["gunicorn", "main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]

# Alternative: Django with Gunicorn
# CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]

# Alternative: Flask with Gunicorn
# CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000", "--workers", "4"]

# Alternative: Using Python directly (not recommended for production)
# CMD ["python", "main.py"]

# =============================================================================
# Build and Run Instructions
# =============================================================================
#
# Build image:
#   docker build -t myapp:latest .
#   docker build -t myapp:latest --build-arg PYTHON_VERSION=3.10 .
#
# Run container:
#   docker run -d -p 8000:8000 --name myapp myapp:latest
#   docker run -d -p 8000:8000 -e DATABASE_URL=postgres://... myapp:latest
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
# Interactive shell:
#   docker exec -it myapp bash
#
# =============================================================================
# Customization Guide
# =============================================================================
#
# 1. Adjust PYTHON_VERSION for your project (3.8, 3.9, 3.10, 3.11, 3.12)
# 2. Change EXPOSE port if your app uses different port
# 3. Update HEALTHCHECK endpoint (/health, /api/health, /healthz)
# 4. Modify CMD to match your ASGI/WSGI server and application
# 5. Adjust requirements.txt path if using pyproject.toml or setup.py
# 6. Add additional system packages in builder stage if needed
# 7. Configure worker count for Gunicorn (--workers flag)
#
# =============================================================================
# Common Frameworks Setup
# =============================================================================
#
# FastAPI:
#   requirements.txt: fastapi, uvicorn[standard]
#   CMD: uvicorn main:app --host 0.0.0.0 --port 8000
#   Health check: /health or /docs
#
# Django:
#   requirements.txt: django, gunicorn, psycopg2-binary
#   CMD: gunicorn myproject.wsgi:application --bind 0.0.0.0:8000
#   Health check: /admin/ or custom /health/ endpoint
#   Note: Run migrations before CMD: python manage.py migrate
#
# Flask:
#   requirements.txt: flask, gunicorn
#   CMD: gunicorn app:app --bind 0.0.0.0:8000
#   Health check: /health or /
#
# =============================================================================
# Troubleshooting
# =============================================================================
#
# Build fails with "gcc not found":
#   → Ensure build-essential, gcc, g++ in builder stage
#
# Package installation fails (psycopg2, pillow, etc.):
#   → Install development headers: libpq-dev, libjpeg-dev, etc.
#   → Check requirements.txt for correct package names
#
# Health check fails:
#   → Verify /health endpoint exists and returns 200
#   → Increase --start-period if app takes longer to start
#   → Check logs: docker logs <container>
#
# Permission denied errors:
#   → Ensure --chown=appuser:appuser in COPY commands
#   → Check that /app is owned by appuser
#
# Large image size:
#   → Verify .dockerignore excludes __pycache__, .git, tests
#   → Remove unnecessary apt packages
#   → Use python:3.11-alpine for even smaller size (requires additional setup)
#
# ImportError at runtime:
#   → Ensure all packages in requirements.txt
#   → Check PATH includes /home/appuser/.local/bin
#   → Verify packages were installed with --user flag in builder
#
# Database connection fails:
#   → Install runtime libraries: libpq5 (PostgreSQL), default-libmysqlclient-dev (MySQL)
#   → Check environment variables: DATABASE_URL, DB_HOST, DB_PORT
#
# =============================================================================
# Advanced Optimizations (v1.1.0)
# =============================================================================
#
# 1. Use Python alpine base (50% smaller but requires additional setup):
#    FROM python:3.11-alpine AS builder
#    RUN apk add --no-cache gcc musl-dev postgresql-dev
#
# 2. Use distroless base (Google's minimal runtime images):
#    FROM gcr.io/distroless/python3-debian11
#    (No shell, very secure, but harder to debug)
#
# 3. Multi-architecture builds:
#    docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
#
# 4. BuildKit cache mounts (faster builds):
#    RUN --mount=type=cache,target=/root/.cache/pip \
#        pip install -r requirements.txt
#
# 5. Poetry or Pipenv instead of requirements.txt:
#    COPY pyproject.toml poetry.lock ./
#    RUN poetry install --no-dev
#
# =============================================================================
