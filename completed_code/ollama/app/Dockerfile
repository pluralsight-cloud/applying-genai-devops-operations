# deps — production dependencies only (no dev tooling in final image)
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# builder — full install, compile TypeScript to dist/
FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
COPY tsconfig.json ./
COPY src ./src
RUN npm ci
RUN npm run build

# runner — dist + production node_modules; non-root; no sources or secrets
FROM node:24-alpine AS runner
WORKDIR /app

ARG PORT=3000
ENV NODE_ENV=production
ENV PORT=${PORT}

RUN addgroup -g 1001 -S appgroup \
  && adduser -u 1001 -S -G appgroup appuser

# GNU wget (BusyBox flags for HEALTHCHECK differ); Alpine default image has no curl.
RUN apk add --no-cache wget

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
