import { Body, Controller, Param, Patch, Post, UseGuards } from "@nestjs/common";
import { IsBoolean, IsString, MinLength } from "class-validator";
import { type AuthedUser, CurrentUser, JwtAuthGuard } from "../auth/jwt.guard";
import { type ConnectResult, ConnectionsService } from "./connections.service";

class ConnectMonoDto {
  @IsString()
  @MinLength(10)
  token!: string;
}

class TrackAccountDto {
  @IsBoolean()
  isTracked!: boolean;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class ConnectionsController {
  constructor(private readonly connections: ConnectionsService) {}

  @Post("connections/mono/personal")
  connectMono(
    @CurrentUser() user: AuthedUser,
    @Body() dto: ConnectMonoDto,
  ): Promise<ConnectResult> {
    return this.connections.connectMonoPersonal(user.id, dto.token);
  }

  // mono account ids are opaque strings, not UUIDs — no ParseUUIDPipe here.
  @Patch("accounts/:id")
  setTracked(
    @CurrentUser() user: AuthedUser,
    @Param("id") accountId: string,
    @Body() dto: TrackAccountDto,
  ) {
    return this.connections.setAccountTracked(user.id, accountId, dto.isTracked);
  }
}
