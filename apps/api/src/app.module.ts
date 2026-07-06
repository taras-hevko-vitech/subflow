import { Module } from "@nestjs/common";
import { ConfigModule } from "./config/config.module";
import { DbModule } from "./db/db.module";
import { HealthModule } from "./health/health.module";
import { JobsModule } from "./jobs/jobs.module";
import { AppLoggerModule } from "./observability/logging.module";

@Module({
  imports: [ConfigModule, AppLoggerModule, DbModule, JobsModule, HealthModule],
})
export class AppModule {}
