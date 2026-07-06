import * as Sentry from "@sentry/node";
import type { Env } from "../config/env";

/** No-op unless SENTRY_DSN is set, so local/dev boots without Sentry. */
export function initSentry(env: Env): void {
  if (!env.SENTRY_DSN) return;
  Sentry.init({
    dsn: env.SENTRY_DSN,
    environment: env.NODE_ENV,
    tracesSampleRate: 0.1,
  });
}
