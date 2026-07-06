CREATE TABLE IF NOT EXISTS "provider_rate_leases" (
	"connection_id" uuid PRIMARY KEY NOT NULL,
	"next_allowed_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "provider_rate_leases" ADD CONSTRAINT "provider_rate_leases_connection_id_bank_connections_id_fk" FOREIGN KEY ("connection_id") REFERENCES "public"."bank_connections"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
