import { Global, Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { loadEnv } from "../config/env";
import { MAILER, createMailer } from "../mail/mailer";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { JwtAuthGuard } from "./jwt.guard";

// Global so JwtAuthGuard (and JwtService behind it) resolve anywhere without re-imports.
@Global()
@Module({
  imports: [
    JwtModule.register({
      global: true,
      secret: loadEnv().JWT_SECRET,
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtAuthGuard, { provide: MAILER, useFactory: () => createMailer(loadEnv()) }],
  exports: [AuthService, JwtAuthGuard, MAILER],
})
export class AuthModule {}
