import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from "@nestjs/common";
import { IsOptional, IsString, MaxLength } from "class-validator";
import { type AuthedUser, CurrentUser, JwtAuthGuard } from "../auth/jwt.guard";
import { DetectionService } from "./detection.service";

class VerdictDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}

@Controller("subscriptions")
@UseGuards(JwtAuthGuard)
export class SubscriptionsController {
  constructor(private readonly detection: DetectionService) {}

  // The aha screen: ₴/month + ₴/year totals and the detected list, sorted by cost.
  @Get()
  list(@CurrentUser() user: AuthedUser) {
    return this.detection.list(user.id);
  }

  @Post(":id/confirm")
  confirm(@CurrentUser() user: AuthedUser, @Param("id", ParseUUIDPipe) id: string, @Body() dto: VerdictDto) {
    return this.detection.setVerdict(user.id, id, "confirm", dto.comment);
  }

  // reject = "this is not a subscription": suppressed for this user + feeds detection_feedback
  @Post(":id/reject")
  reject(@CurrentUser() user: AuthedUser, @Param("id", ParseUUIDPipe) id: string, @Body() dto: VerdictDto) {
    return this.detection.setVerdict(user.id, id, "reject", dto.comment);
  }
}
