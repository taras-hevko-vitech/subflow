import "reflect-metadata";
import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { Logger } from "nestjs-pino";
import { AppModule } from "./app.module";
import { loadEnv } from "./config/env";
import { initSentry } from "./observability/sentry";

async function bootstrap(): Promise<void> {
  const env = loadEnv();
  initSentry(env);

  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableShutdownHooks();

  // OpenAPI: the contract source for mobile type generation (/docs UI, /openapi.json spec)
  const spec = new DocumentBuilder().setTitle("Subflow API").setVersion("0.1").addBearerAuth().build();
  SwaggerModule.setup("docs", app, () => SwaggerModule.createDocument(app, spec), {
    jsonDocumentUrl: "openapi.json",
  });

  await app.listen(env.PORT, "0.0.0.0");
}

void bootstrap();
