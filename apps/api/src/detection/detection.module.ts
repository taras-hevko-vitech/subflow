import { Inject, Logger, Module, type OnModuleInit } from "@nestjs/common";
import type PgBoss from "pg-boss";
import { QUEUE_DETECTION_RECOMPUTE } from "../backfill/backfill.service";
// Explicit import so boss.start() (JobsModule init) runs before queue registration below.
import { JobsModule, PG_BOSS } from "../jobs/jobs.module";
import { DetectionService, type RecomputeJob } from "./detection.service";
import { SubscriptionsController } from "./subscriptions.controller";

@Module({
  imports: [JobsModule],
  controllers: [SubscriptionsController],
  providers: [DetectionService],
  exports: [DetectionService],
})
export class DetectionModule implements OnModuleInit {
  private readonly logger = new Logger(DetectionModule.name);

  constructor(
    @Inject(PG_BOSS) private readonly boss: PgBoss | null,
    private readonly detection: DetectionService,
  ) {}

  async onModuleInit(): Promise<void> {
    if (!this.boss) return;
    await this.detection.seedMerchants();
    await this.boss.createQueue(QUEUE_DETECTION_RECOMPUTE);
    await this.boss.work<RecomputeJob>(QUEUE_DETECTION_RECOMPUTE, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.detection.recompute(job.data);
    });
    this.logger.log("detection worker registered, seed catalog upserted");
  }
}
