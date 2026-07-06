# syntax=docker/dockerfile:1

# --- install + build (bun) ---
FROM oven/bun:1.3 AS build
WORKDIR /repo
# manifests first for layer caching
COPY package.json bun.lock tsconfig.base.json ./
COPY packages/shared/package.json packages/shared/
COPY packages/detection/package.json packages/detection/
COPY apps/api/package.json apps/api/
RUN bun install --frozen-lockfile
# sources
COPY packages ./packages
COPY apps/api ./apps/api
# compile workspace libs, then the api (tsc; paths resolve to package src)
RUN bun run --filter '@subflow/shared' build \
  && bun run --filter '@subflow/detection' build \
  && bun run --filter '@subflow/api' build
# drop dev dependencies so the runtime image ships prod deps only
RUN bun install --frozen-lockfile --production

# --- runtime (node) ---
FROM node:22-slim AS runtime
ENV NODE_ENV=production
WORKDIR /repo
# copy the whole pruned tree: bun spreads deps across root + per-package
# node_modules, so a wholesale copy is the reliable way to satisfy node's resolver.
COPY --from=build /repo ./
EXPOSE 3000
CMD ["node", "apps/api/dist/main.js"]
