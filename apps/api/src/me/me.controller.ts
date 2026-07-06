import { Body, Controller, Delete, Get, HttpCode, Post, UseGuards } from "@nestjs/common";
import { IsIn, IsString, MinLength } from "class-validator";
import { type AuthedUser, CurrentUser, JwtAuthGuard } from "../auth/jwt.guard";
import { UsersService } from "./users.service";

class DeviceTokenDto {
  @IsString()
  @MinLength(8)
  token!: string;

  @IsIn(["ios", "android"])
  platform!: "ios" | "android";
}

@Controller("me")
@UseGuards(JwtAuthGuard)
export class MeController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  profile(@CurrentUser() user: AuthedUser) {
    return this.usersService.getProfile(user.id);
  }

  // Hard-deletes EVERYTHING for this user. Double confirmation lives in the mobile UI.
  @Delete()
  @HttpCode(204)
  async remove(@CurrentUser() user: AuthedUser): Promise<void> {
    await this.usersService.hardDelete(user.id);
  }

  @Post("device-tokens")
  @HttpCode(204)
  async registerDevice(@CurrentUser() user: AuthedUser, @Body() dto: DeviceTokenDto): Promise<void> {
    await this.usersService.registerDeviceToken(user.id, dto.token, dto.platform);
  }
}
