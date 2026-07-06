import { Module } from "@nestjs/common";
import { AuthModule } from "./auth/auth.module";
import { BackfillModule } from "./backfill/backfill.module";
import { BankModule } from "./bank/bank.module";
import { ConfigModule } from "./config/config.module";
import { ConnectionsModule } from "./connections/connections.module";
import { DbModule } from "./db/db.module";
import { DetectionModule } from "./detection/detection.module";
import { HealthModule } from "./health/health.module";
import { JobsModule } from "./jobs/jobs.module";
import { MeModule } from "./me/me.module";
import { AppLoggerModule } from "./observability/logging.module";
import { WebhooksModule } from "./webhooks/webhooks.module";

@Module({
  imports: [
    ConfigModule,
    AppLoggerModule,
    DbModule,
    JobsModule,
    HealthModule,
    AuthModule,
    MeModule,
    BankModule,
    ConnectionsModule,
    BackfillModule,
    WebhooksModule,
    DetectionModule,
  ],
})
export class AppModule {}
