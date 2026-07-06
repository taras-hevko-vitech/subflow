import { Module } from "@nestjs/common";
import { AuthModule } from "./auth/auth.module";
import { ConfigModule } from "./config/config.module";
import { DbModule } from "./db/db.module";
import { HealthModule } from "./health/health.module";
import { JobsModule } from "./jobs/jobs.module";
import { MeModule } from "./me/me.module";
import { AppLoggerModule } from "./observability/logging.module";

@Module({
  imports: [
    ConfigModule,
    AppLoggerModule,
    DbModule,
    JobsModule,
    HealthModule,
    AuthModule,
    MeModule,
  ],
})
export class AppModule {}
