import { describe, expect, it } from "vitest";
import { decryptToken, encryptToken } from "./token-cipher";

const KEY = "0123456789abcdef0123456789abcdef"; // 32 bytes

describe("token cipher (AES-256-GCM)", () => {
  it("round-trips a token", () => {
    const token = "uABCdef_monobank_personal_token";
    expect(decryptToken(encryptToken(token, KEY), KEY)).toBe(token);
  });

  it("produces different ciphertext each time (random IV)", () => {
    const a = encryptToken("same", KEY);
    const b = encryptToken("same", KEY);
    expect(a).not.toBe(b);
    expect(decryptToken(a, KEY)).toBe("same");
  });

  it("rejects a tampered ciphertext", () => {
    const buf = Buffer.from(encryptToken("secret", KEY), "base64");
    buf[buf.length - 1] ^= 0xff;
    expect(() => decryptToken(buf.toString("base64"), KEY)).toThrow();
  });

  it("fails with the wrong key", () => {
    const enc = encryptToken("secret", KEY);
    expect(() => decryptToken(enc, "ffffffffffffffffffffffffffffffff")).toThrow();
  });
});
