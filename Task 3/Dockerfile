# ---- Build stage ----
FROM node:18-alpine AS build

WORKDIR /app
COPY app/package.json ./
RUN npm install --omit=dev

# ---- Runtime stage ----
FROM node:18-alpine AS runtime

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY app/ ./

USER appuser

ENV PORT=3000
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
