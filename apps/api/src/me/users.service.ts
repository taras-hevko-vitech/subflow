import { Inject, Injectable, NotFoundException, ServiceUnavailableException } from "@nestjs/common";
import { eq } from "drizzle-orm";
import { DB } from "../db/db.module";
import { deviceTokens, magicLinkTokens, users } from "../db/schema";
import type { Db } from "../db/types";

@Injectable()
export class UsersService {
  constructor(@Inject(DB) private readonly maybeDb: Db | null) {}

  private get db(): Db {
    if (!this.maybeDb) throw new ServiceUnavailableException("database not configured");
    return this.maybeDb;
  }

  async getProfile(userId: string): Promise<{ id: string; email: string; createdAt: Date }> {
    const [u] = await this.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new NotFoundException();
    return { id: u.id, email: u.email, createdAt: u.createdAt };
  }

  /**
   * Hard delete — the trust feature. The users FK cascade wipes device_tokens,
   * bank_connections → accounts → transactions, subscriptions → subscription_events,
   * detection_feedback and refresh_tokens. magic_link_tokens are keyed by email
   * (they may predate the user row), so they are deleted explicitly.
   */
  async hardDelete(userId: string): Promise<void> {
    const [u] = await this.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) return; // already gone — idempotent
    await this.db.delete(magicLinkTokens).where(eq(magicLinkTokens.email, u.email));
    await this.db.delete(users).where(eq(users.id, userId));
  }

  async registerDeviceToken(userId: string, token: string, platform: string): Promise<void> {
    await this.db.insert(deviceTokens).values({ userId, token, platform }).onConflictDoNothing();
  }
}
