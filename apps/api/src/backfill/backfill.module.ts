import { Inject, Logger, Module, type OnModuleInit } from "@nestjs/common";
import type PgBoss from "pg-boss";
import { ConnectionsModule } from "../connections/connections.module";
// Explicit import (even though JobsModule is @Global) so Nest inits JobsModule first:
// boss.start() must run before createQueue/work below.
import { JobsModule, PG_BOSS } from "../jobs/jobs.module";
import { BackfillController } from "./backfill.controller";
import { BackfillService, type PlanJobData, QUEUE_BACKFILL_PLAN, QUEUE_BACKFILL_WINDOW, type WindowJobData } from "./backfill.service";

@Module({
  imports: [JobsModule, ConnectionsModule],
  controllers: [BackfillController],
  providers: [BackfillService],
  exports: [BackfillService],
})
export class BackfillModule implements OnModuleInit {
  private readonly logger = new Logger(BackfillModule.name);

  constructor(
    @Inject(PG_BOSS) private readonly boss: PgBoss | null,
    private readonly backfill: BackfillService,
  ) {}

  async onModuleInit(): Promise<void> {
    if (!this.boss) return;

    await this.boss.createQueue(QUEUE_BACKFILL_PLAN);
    await this.boss.createQueue(QUEUE_BACKFILL_WINDOW);
    // detection.recompute queue + worker are owned by DetectionModule

    await this.boss.work<PlanJobData>(QUEUE_BACKFILL_PLAN, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.backfill.runPlan(job.data);
    });
    await this.boss.work<WindowJobData>(QUEUE_BACKFILL_WINDOW, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.backfill.runWindow(job.data);
    });
  }
}
