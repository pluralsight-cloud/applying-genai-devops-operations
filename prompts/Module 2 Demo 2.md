# Module 1 - Demo 2: Deploy an application using an AI-generated Dockerfile

Use the prompt below with your GenAI tool, then apply the structured requirements in this doc so the generated **Dockerfile** matches the course expectations for a **Node.js + TypeScript** API.

---

## AI prompt (copy into your assistant)

```text
You are an expert Docker and Node.js engineer. Generate a complete, production-ready
Dockerfile for a Node.js API written in TypeScript. Follow Docker best practices
for security, performance, and image size optimization.
```

---

## Application details

| Item | Value |
|------|--------|
| Runtime | **Node.js 24** (LTS codename *Krypton* — LTS as of May 2026, supported through April 2028) |
| Language | **TypeScript** (compile to JavaScript before run) |
| Package manager | **npm** (adjust if the repo uses Yarn or pnpm) |
| Source entry | `src/index.ts` |
| Built entry | `dist/index.js` |
| Build command | `npm run build` |
| Start command (local) | `npm start` (image should run Node on `dist/` directly — see Dockerfile requirements) |
| Default port | **3000** |

---

## Dockerfile requirements

### 1. Multi-stage build

Use **named stages** with this layout:

| Stage | Name | Base image | Purpose |
|-------|------|------------|---------|
| 1 | `deps` | `node:24-alpine` | Install **production** dependencies only (`npm ci --omit=dev`) so dev tooling is not in the final image |
| 2 | `builder` | `node:24-alpine` | Copy source; install **all** dependencies (including devDependencies for `tsc`); run **`npm run build`** → `src/` → `dist/` |
| 3 | `runner` (final) | `node:24-alpine` | Copy **`dist/`** from builder; copy **`node_modules/`** from deps; copy **`package.json`**; **do not** ship `src/`, `tsconfig.json`, `*.ts`, devDependencies, or test-only files — only this stage is published |

### 2. Security best practices

| Rule | Detail |
|------|--------|
| Non-root | Do **not** run as root |
| User / group | Dedicated **`appuser`** / **`appgroup`** |
| Ownership | App directory owned by `appuser` |
| `USER` | Switch to **`appuser`** before **`CMD`** |
| Secrets | Do **not** copy `.env` into the image; inject secrets at runtime (env vars, AWS Secrets Manager, etc.) |

### 3. Image optimization

- Base image for **all** stages: **`node:24-alpine`** (small, maintained base).
- Use **`npm ci`** instead of `npm install` for reproducible, faster installs.
- Set **`NODE_ENV=production`** in the final stage.

**`.dockerignore` should exclude (at minimum):**

```text
node_modules/
dist/
.env
.env.*
*.test.ts
*.spec.ts
coverage/
.git/
.github/
README.md
docker-compose*.yml
```

### 4. Runtime configuration

| Requirement | Detail |
|-------------|--------|
| `WORKDIR` | `/app` in **every** stage |
| Port | **Expose 3000**; support overrides via **`ARG` / `ENV`** at build time |
| Env defaults (final stage) | `NODE_ENV=production`, `PORT=3000` |
| `CMD` | **Exec form** only: `CMD ["node", "dist/index.js"]` — **do not** use shell form for the final `CMD` |

### 5. Health check (final stage)

Add a **`HEALTHCHECK`** on the final image:

| Option | Value |
|--------|--------|
| Interval | `30s` |
| Timeout | `5s` |
| Retries | `3` |
| Start period | `10s` |

Command (use **`wget`** — Alpine does not ship **`curl`** by default):

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
```

---

## Quick checklist for reviewers

- [ ] Three stages: `deps` → `builder` → `runner`
- [ ] Final image has no TypeScript sources or devDependencies
- [ ] Non-root user, exec-form `CMD`, production `NODE_ENV`
- [ ] `.dockerignore` present and aligned with the list above
- [ ] `HEALTHCHECK` hits `/health` on the configured port
