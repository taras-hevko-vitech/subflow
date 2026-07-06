import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from "@nestjs/common";
import type PgBoss from "pg-boss";
import { PG_BOSS } from "../jobs/jobs.module";
import { IpRateLimitGuard } from "./ip-rate-limit.guard";
import { type MonoStatementItemPayload, QUEUE_WEBHOOK_EVENT, type WebhookEventJob, WebhooksService } from "./webhooks.service";

// PUBLIC endpoint (no JWT): mono calls it. The connection uuid in the path is the shared
// secret; shape validation + ownership check + IP rate limit guard the rest. mono retries
// after 60s/600s and silently disables the webhook on the 3rd failure — so the POST must
// answer 200 immediately and do all real work async.
@Controller("webhooks/mono")
@UseGuards(IpRateLimitGuard)
export class WebhooksController {
  constructor(
    private readonly webhooks: WebhooksService,
    @Inject(PG_BOSS) private readonly boss: PgBoss | null,
  ) {}

  // Address validation probe from mono — must return plain 200.
  @Get(":connectionId")
  @HttpCode(200)
  validate(): { ok: true } {
    return { ok: true };
  }

  @Post(":connectionId")
  @HttpCode(200)
  async receive(@Param("connectionId", ParseUUIDPipe) connectionId: string, @Body() body: unknown): Promise<{ ok: true }> {
    const item = parseStatementItem(body);
    const accountId = (body as { data: { account: string } }).data.account;
    if (!(await this.webhooks.accountBelongsToConnection(connectionId, accountId))) {
      throw new NotFoundException();
    }
    await this.boss?.send(QUEUE_WEBHOOK_EVENT, { connectionId, accountId, item } satisfies WebhookEventJob, {
      retryLimit: 5,
      retryDelay: 30,
    });
    return { ok: true };
  }
}

function parseStatementItem(body: unknown): MonoStatementItemPayload {
  const b = body as { type?: unknown; data?: { account?: unknown; statementItem?: Record<string, unknown> } };
  const item = b?.data?.statementItem;
  if (
    b?.type !== "StatementItem" ||
    typeof b?.data?.account !== "string" ||
    !item ||
    typeof item.id !== "string" ||
    typeof item.time !== "number" ||
    typeof item.amount !== "number" ||
    typeof item.currencyCode !== "number"
  ) {
    throw new BadRequestException("unexpected payload shape");
  }
  return item as unknown as MonoStatementItemPayload;
}
