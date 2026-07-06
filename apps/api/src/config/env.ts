import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  PORT: z.coerce.number().int().positive().default(3000),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).default("info"),
  // Optional so the skeleton boots without a database.
  DATABASE_URL: z.string().url().optional(),
  SENTRY_DSN: z.string().url().optional(),
  // base64 AES-256-GCM key (subF-7); sourced from Secrets Manager in prod.
  TOKEN_ENCRYPTION_KEY: z.string().min(1).optional(),
});

export type Env = z.infer<typeof EnvSchema>;

/** DI token for the validated env object. */
export const ENV = Symbol("ENV");

let cached: Env | null = null;

export function loadEnv(): Env {
  if (cached) return cached;
  const parsed = EnvSchema.safeParse(process.env);
  if (!parsed.success) {
    // Never log values — only the offending keys.
    const keys = [...new Set(parsed.error.issues.map((i) => i.path.join(".")))].join(", ");
    throw new Error(`Invalid environment configuration: ${keys}`);
  }
  cached = parsed.data;
  return cached;
}
