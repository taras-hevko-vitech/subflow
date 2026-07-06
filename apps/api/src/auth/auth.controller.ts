import { Body, Controller, HttpCode, Post } from "@nestjs/common";
import { IsEmail, IsString, MinLength } from "class-validator";
import { AuthService, type TokenPair } from "./auth.service";

class RequestLinkDto {
  @IsEmail()
  email!: string;
}

class VerifyDto {
  @IsString()
  @MinLength(16)
  token!: string;
}

class RefreshDto {
  @IsString()
  @MinLength(16)
  refreshToken!: string;
}

@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // 204 regardless of whether the email is known — no user enumeration.
  @Post("request")
  @HttpCode(204)
  async request(@Body() dto: RequestLinkDto): Promise<void> {
    await this.auth.requestMagicLink(dto.email);
  }

  @Post("verify")
  @HttpCode(200)
  verify(@Body() dto: VerifyDto): Promise<TokenPair> {
    return this.auth.verifyMagicLink(dto.token);
  }

  @Post("refresh")
  @HttpCode(200)
  refresh(@Body() dto: RefreshDto): Promise<TokenPair> {
    return this.auth.refresh(dto.refreshToken);
  }
}
