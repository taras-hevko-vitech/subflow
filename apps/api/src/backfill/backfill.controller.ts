import { Controller, Get, NotFoundException, Param, ParseUUIDPipe, UseGuards } from "@nestjs/common";
import { type AuthedUser, CurrentUser, JwtAuthGuard } from "../auth/jwt.guard";
import { BackfillService } from "./backfill.service";

@Controller("connections")
@UseGuards(JwtAuthGuard)
export class BackfillController {
  constructor(private readonly backfill: BackfillService) {}

  // Progress for the onboarding screen: "month X of 12" + partial results note.
  @Get(":id/backfill")
  async progress(@CurrentUser() user: AuthedUser, @Param("id", ParseUUIDPipe) connectionId: string) {
    const progress = await this.backfill.getProgress(user.id, connectionId);
    if (!progress) throw new NotFoundException();
    return progress;
  }
}
