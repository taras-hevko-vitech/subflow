import { Inject, Logger, Module, type OnModuleInit } from "@nestjs/common";
import type PgBoss from "pg-boss";
import { ConnectionsModule } from "../connections/connections.module";
// Explicit import so boss.start() (JobsModule init) runs before queue registration below.
import { JobsModule, PG_BOSS } from "../jobs/jobs.module";
import { IpRateLimitGuard } from "./ip-rate-limit.guard";
import { WebhooksController } from "./webhooks.controller";
import {
  QUEUE_WEBHOOK_CHECK,
  QUEUE_WEBHOOK_EVENT,
  QUEUE_WEBHOOK_REGISTER,
  QUEUE_WEBHOOK_WATCHDOG,
  type RegisterJob,
  type WebhookEventJob,
  WebhooksService,
} from "./webhooks.service";

@Module({
  imports: [JobsModule, ConnectionsModule],
  controllers: [WebhooksController],
  providers: [WebhooksService, IpRateLimitGuard],
  exports: [WebhooksService],
})
export class WebhooksModule implements OnModuleInit {
  private readonly logger = new Logger(WebhooksModule.name);

  constructor(
    @Inject(PG_BOSS) private readonly boss: PgBoss | null,
    private readonly webhooks: WebhooksService,
  ) {}

  async onModuleInit(): Promise<void> {
    if (!this.boss) return;

    for (const q of [QUEUE_WEBHOOK_EVENT, QUEUE_WEBHOOK_REGISTER, QUEUE_WEBHOOK_CHECK, QUEUE_WEBHOOK_WATCHDOG]) {
      await this.boss.createQueue(q);
    }

    await this.boss.work<WebhookEventJob>(QUEUE_WEBHOOK_EVENT, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.webhooks.processEvent(job.data);
    });
    await this.boss.work<RegisterJob>(QUEUE_WEBHOOK_REGISTER, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.webhooks.register(job.data);
    });
    await this.boss.work<RegisterJob>(QUEUE_WEBHOOK_CHECK, { batchSize: 1 }, async (jobs) => {
      for (const job of jobs) await this.webhooks.checkConnection(job.data);
    });
    await this.boss.work(QUEUE_WEBHOOK_WATCHDOG, { batchSize: 1 }, async () => {
      await this.webhooks.watchdogSweep();
    });

    // Daily 06:00 UTC — one sweep is enough: mono disables webhooks silently, users notice never.
    await this.boss.schedule(QUEUE_WEBHOOK_WATCHDOG, "0 6 * * *");
    this.logger.log("webhook queues registered, watchdog scheduled daily");
  }
}
