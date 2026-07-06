import { LoggerModule } from "nestjs-pino";
import { loadEnv } from "../config/env";

const env = loadEnv();

// Structured JSON logs. Redaction is a hard security requirement: bank tokens and raw
// statements must NEVER appear in logs.
export const AppLoggerModule = LoggerModule.forRoot({
  pinoHttp: {
    level: env.LOG_LEVEL,
    autoLogging: true,
    redact: {
      paths: [
        "req.headers.authorization",
        "req.headers.cookie",
        'req.headers["x-token"]',
        'req.headers["x-key-id"]',
        'req.headers["x-sign"]',
        "*.token",
        "*.encryptedToken",
        "*.encrypted_token",
        "*.statement",
        "*.statementItem",
      ],
      censor: "[REDACTED]",
    },
  },
});
