import { type CanActivate, type ExecutionContext, HttpException, HttpStatus, Injectable } from "@nestjs/common";
import type { Request } from "express";

const WINDOW_MS = 60_000;
const LIMIT_PER_WINDOW = 120;

/**
 * Minimal in-memory sliding-window limiter for the public webhook endpoint. Per-task only,
 * which is fine at 1 Fargate task; if we scale out, each task still bounds abuse locally.
 */
@Injectable()
export class IpRateLimitGuard implements CanActivate {
  private readonly hits = new Map<string, number[]>();

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const ip = req.ip ?? "unknown";
    const now = Date.now();
    const windowStart = now - WINDOW_MS;

    const stamps = (this.hits.get(ip) ?? []).filter((t) => t > windowStart);
    if (stamps.length >= LIMIT_PER_WINDOW) {
      throw new HttpException("too many requests", HttpStatus.TOO_MANY_REQUESTS);
    }
    stamps.push(now);
    this.hits.set(ip, stamps);

    // opportunistic cleanup so the map can't grow unbounded
    if (this.hits.size > 10_000) {
      for (const [k, v] of this.hits) {
        if (v.every((t) => t <= windowStart)) this.hits.delete(k);
      }
    }
    return true;
  }
}
