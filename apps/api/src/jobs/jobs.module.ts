import { Global, Inject, Logger, Module, type OnModuleDestroy, type OnModuleInit } from "@nestjs/common";
import PgBoss from "pg-boss";
import { loadEnv } from "../config/env";

export const PG_BOSS = Symbol("PG_BOSS");

// pg-boss runs in the same process as the API (no Redis). Backfill (subF-9), the webhook
// consumer (subF-10) and the watchdog register their queues here. Disabled without a DB.
@Global()
@Module({
  providers: [
    {
      provide: PG_BOSS,
      useFactory: (): PgBoss | null => {
        const env = loadEnv();
        if (!env.DATABASE_URL) return null;
        return new PgBoss({ connectionString: env.DATABASE_URL });
      },
    },
  ],
  exports: [PG_BOSS],
})
export class JobsModule implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(JobsModule.name);

  constructor(@Inject(PG_BOSS) private readonly boss: PgBoss | null) {}

  async onModuleInit(): Promise<void> {
    if (!this.boss) {
      this.logger.warn("pg-boss disabled (no DATABASE_URL)");
      return;
    }
    // Queues and workers register in the feature modules (backfill, webhooks, ...).
    await this.boss.start();
  }

  async onModuleDestroy(): Promise<void> {
    await this.boss?.stop();
  }
}
