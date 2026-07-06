import { describe, expect, it } from "vitest";
import { normalizeMerchant } from "./normalize";

describe("normalizeMerchant", () => {
  it("strips the PayPal processor prefix", () => {
    expect(normalizeMerchant("PAYPAL *NETFLIX", 4899).normName).toBe("netflix");
  });

  it("collapses Apple billing tail to a canonical vendor", () => {
    expect(normalizeMerchant("APPLE.COM/BILL", 5735).normName).toBe("apple");
  });

  it("builds a canonicalKey from name + mcc", () => {
    expect(normalizeMerchant("Spotify", 5815).canonicalKey).toBe("spotify|5815");
  });

  it("keeps Cyrillic merchant names", () => {
    expect(normalizeMerchant("Київстар ТБ", 4899).normName).toBe("київстар тб");
  });

  it("is null-safe", () => {
    expect(normalizeMerchant(null).canonicalKey).toBe("|");
  });
});
