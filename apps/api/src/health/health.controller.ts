import { Controller, Get } from "@nestjs/common";

@Controller()
export class HealthController {
  // Liveness probe for the ALB target group (subF-5). Intentionally does not touch the DB.
  @Get("health")
  health(): { status: "ok"; service: string; ts: string } {
    return {
      status: "ok",
      service: "subflow-api",
      ts: new Date().toISOString(),
    };
  }
}
