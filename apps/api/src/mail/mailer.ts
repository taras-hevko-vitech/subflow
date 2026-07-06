import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { Logger } from "@nestjs/common";
import type { Env } from "../config/env";

export interface MailMessage {
  to: string;
  subject: string;
  text: string;
}

/** Port for outgoing mail. SES in prod; a log transport for dev (no AWS account needed). */
export interface Mailer {
  send(msg: MailMessage): Promise<void>;
}

export const MAILER = Symbol("MAILER");

export class SesMailer implements Mailer {
  private readonly client: SESClient;

  constructor(
    region: string,
    private readonly from: string,
  ) {
    this.client = new SESClient({ region });
  }

  async send(msg: MailMessage): Promise<void> {
    await this.client.send(
      new SendEmailCommand({
        Source: this.from,
        Destination: { ToAddresses: [msg.to] },
        Message: {
          Subject: { Data: msg.subject, Charset: "UTF-8" },
          Body: { Text: { Data: msg.text, Charset: "UTF-8" } },
        },
      }),
    );
  }
}

/** Dev transport: prints the mail to the log. NEVER logs in production. */
export class LogMailer implements Mailer {
  private readonly logger = new Logger("LogMailer");

  async send(msg: MailMessage): Promise<void> {
    this.logger.log(`mail to=${msg.to} subject="${msg.subject}"\n${msg.text}`);
  }
}

export function createMailer(env: Env): Mailer {
  if (env.MAIL_TRANSPORT === "ses") return new SesMailer(env.AWS_REGION, env.MAIL_FROM);
  if (env.NODE_ENV === "production") {
    // A misconfigured prod must not silently dump magic links into logs.
    throw new Error("MAIL_TRANSPORT=log is not allowed in production");
  }
  return new LogMailer();
}
