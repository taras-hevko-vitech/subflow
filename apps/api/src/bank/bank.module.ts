import { Global, Module } from "@nestjs/common";
import { loadEnv } from "../config/env";
import { BANK_PROVIDER } from "./bank-provider";
import { MonoPersonalProvider } from "./mono-personal.provider";

// Global: backfill (subF-9) and webhooks (subF-10) consume the same provider instance.
@Global()
@Module({
  providers: [
    {
      provide: BANK_PROVIDER,
      useFactory: () => new MonoPersonalProvider(loadEnv().MONO_BASE_URL),
    },
  ],
  exports: [BANK_PROVIDER],
})
export class BankModule {}
