import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, UseGuards } from "@nestjs/common";
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

  @Get("connections")
  list(@CurrentUser() user: AuthedUser) {
    return this.connections.listConnections(user.id);
  }

  @Post("connections/mono/personal")
  connectMono(@CurrentUser() user: AuthedUser, @Body() dto: ConnectMonoDto): Promise<ConnectResult> {
    return this.connections.connectMonoPersonal(user.id, dto.token);
  }

  @Delete("connections/:id")
  @HttpCode(204)
  async disconnect(@CurrentUser() user: AuthedUser, @Param("id", ParseUUIDPipe) id: string): Promise<void> {
    await this.connections.disconnect(user.id, id);
  }

  // mono account ids are opaque strings, not UUIDs — no ParseUUIDPipe here.
  @Patch("accounts/:id")
  setTracked(@CurrentUser() user: AuthedUser, @Param("id") accountId: string, @Body() dto: TrackAccountDto) {
    return this.connections.setAccountTracked(user.id, accountId, dto.isTracked);
  }
}
