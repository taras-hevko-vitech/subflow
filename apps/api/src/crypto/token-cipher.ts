import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

// AES-256-GCM for bank tokens at rest. The key comes from Secrets Manager (env
// TOKEN_ENCRYPTION_KEY) — never the DB or repo. Ciphertext layout: base64(iv | tag | data).
const ALG = "aes-256-gcm";
const IV_LEN = 12;
const TAG_LEN = 16;

function keyFrom(secret: string): Buffer {
  const raw = Buffer.from(secret, "utf8");
  // Secrets Manager generates a 32-char key (= 32 bytes). Anything else is folded to 32.
  return raw.length === 32 ? raw : createHash("sha256").update(raw).digest();
}

export function encryptToken(plaintext: string, secret: string): string {
  const iv = randomBytes(IV_LEN);
  const cipher = createCipheriv(ALG, keyFrom(secret), iv);
  const data = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), data]).toString("base64");
}

export function decryptToken(payload: string, secret: string): string {
  const buf = Buffer.from(payload, "base64");
  const iv = buf.subarray(0, IV_LEN);
  const tag = buf.subarray(IV_LEN, IV_LEN + TAG_LEN);
  const data = buf.subarray(IV_LEN + TAG_LEN);
  const decipher = createDecipheriv(ALG, keyFrom(secret), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf8");
}
