import { Global, Inject, Module, type OnModuleDestroy } from "@nestjs/common";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { loadEnv } from "../config/env";
import * as schema from "./schema";

export const PG_POOL = Symbol("PG_POOL");
export const DB = Symbol("DB");

// Connection is optional so the skeleton boots without a database. Once subF-7 lands the
// schema and DATABASE_URL is set, `DB` is a ready drizzle instance.
@Global()
@Module({
  providers: [
    {
      provide: PG_POOL,
      useFactory: (): Pool | null => {
        const env = loadEnv();
        if (!env.DATABASE_URL) return null;
        return new Pool({ connectionString: env.DATABASE_URL, max: 10 });
      },
    },
    {
      provide: DB,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) => (pool ? drizzle(pool, { schema }) : null),
    },
  ],
  exports: [PG_POOL, DB],
})
export class DbModule implements OnModuleDestroy {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async onModuleDestroy(): Promise<void> {
    await this.pool?.end();
  }
}
