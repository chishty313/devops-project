# syntax=docker/dockerfile:1

# ---- deps stage: install ONLY production dependencies ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# npm ci = clean, reproducible install from the lockfile.
# --omit=dev drops jest/supertest so they never ship in the image.
RUN npm ci --omit=dev

# ---- runtime stage: minimal image that just runs the app ----
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Run as a non-root user (security: a compromised process has fewer rights).
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./

USER app
EXPOSE 8080

# Container-level health check (Docker/Compose). Kubernetes uses its own probes.
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "src/server.js"]
