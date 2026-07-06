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
  // auth (subF-6)
  JWT_SECRET: z.string().min(16).default("dev-secret-change-me"),
  APP_BASE_URL: z.string().url().default("http://localhost:3000"),
  MAIL_TRANSPORT: z.enum(["log", "ses"]).default("log"),
  MAIL_FROM: z.string().default("Subflow <no-reply@subflow.app>"),
  AWS_REGION: z.string().default("eu-central-1"),
  // bank integration (subF-8); overridable for local mock runs
  MONO_BASE_URL: z.string().url().default("https://api.monobank.ua"),
  // mono hard limit is 1 req/60s per token; lowered only in local verification runs
  MONO_LEASE_SECONDS: z.coerce.number().int().positive().default(60),
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
  if (parsed.data.NODE_ENV === "production" && parsed.data.JWT_SECRET === "dev-secret-change-me") {
    throw new Error("JWT_SECRET must be set in production");
  }
  cached = parsed.data;
  return cached;
}
