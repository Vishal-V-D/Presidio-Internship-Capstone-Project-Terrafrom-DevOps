# ==================================================
# SUBMISSION SERVICE - DOCKER-IN-DOCKER DOCKERFILE
# ==================================================
# This Dockerfile enables running code execution in isolated Docker containers
# Requires privileged mode: docker run --privileged or privileged: true in compose
# ==================================================

FROM node:18-alpine

# Install Docker CLI and Docker daemon (Docker-in-Docker)
RUN apk add --no-cache \
    docker \
    docker-cli \
    docker-compose \
    openrc \
    curl \
    bash \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
# Run this command from your submission-service directory
COPY package*.json ./

# Install dependencies (include dev deps for TypeScript build)
RUN npm install

# Copy application code
COPY . ./

# Build TypeScript sources
RUN npm run build

# Create tmp directory for code execution
RUN mkdir -p /app/tmp && chmod 777 /app/tmp

# Expose submission service port
EXPOSE 5000

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start script that launches Docker daemon and application
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

echo "🚀 Starting Docker daemon..."
# Clean up stale docker pid files if present
rm -f /var/run/docker.pid
# Start Docker daemon in background with DinD-optimized flags
# --iptables=false: Don't manage iptables (avoids permission issues)
# --ip-forward=false: Don't enable IP forwarding (avoids WSL2 read-only fs error)
# --bridge=none: Don't create docker0 bridge (avoids netlink permission errors)
# --storage-driver=vfs: Simple storage driver that works in containers
dockerd --iptables=false --ip-forward=false --bridge=none --storage-driver=vfs &

# Wait for Docker to be ready
echo "⏳ Waiting for Docker daemon to be ready..."
timeout 30 sh -c 'until docker info >/dev/null 2>&1; do sleep 1; done' || {
    echo "❌ Docker daemon failed to start"
    exit 1
}

echo "✅ Docker daemon is ready"
echo "📦 Pulling required Docker images in background..."

# Pre-pull common images in background (non-blocking)
(docker pull python:3.11-slim || true) &
(docker pull node:18-alpine || true) &
(docker pull eclipse-temurin:17-jdk-alpine || true) &
(docker pull gcc:11 || true) &

echo "🎯 Starting submission service (images pulling in background)..."

# Start the Node.js application immediately
exec node dist/server.js
EOF

RUN chmod +x /app/start.sh

# Use start script as entrypoint
ENTRYPOINT ["/app/start.sh"]
