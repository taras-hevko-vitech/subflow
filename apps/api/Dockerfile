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

# --- runtime (node) ---
FROM node:22-slim AS runtime
ENV NODE_ENV=production
WORKDIR /repo
COPY --from=build /repo/node_modules ./node_modules
COPY --from=build /repo/package.json ./package.json
COPY --from=build /repo/packages/shared/package.json ./packages/shared/package.json
COPY --from=build /repo/packages/shared/dist ./packages/shared/dist
COPY --from=build /repo/packages/detection/package.json ./packages/detection/package.json
COPY --from=build /repo/packages/detection/dist ./packages/detection/dist
COPY --from=build /repo/apps/api/package.json ./apps/api/package.json
COPY --from=build /repo/apps/api/dist ./apps/api/dist
EXPOSE 3000
CMD ["node", "apps/api/dist/main.js"]
