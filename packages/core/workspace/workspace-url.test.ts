import { describe, expect, it } from "vitest";
import { workspaceUrlHost } from "./workspace-url";

describe("workspaceUrlHost", () => {
  it("returns the host of a full app URL", () => {
    expect(workspaceUrlHost("https://opercia.example.com")).toBe(
      "opercia.example.com",
    );
  });

  it("ignores scheme, path, and trailing slash", () => {
    expect(workspaceUrlHost("https://opercia.example.com/")).toBe(
      "opercia.example.com",
    );
    expect(workspaceUrlHost("http://opercia.example.com/app/onboarding")).toBe(
      "opercia.example.com",
    );
  });

  it("preserves a non-default port", () => {
    expect(workspaceUrlHost("https://my.host:3000")).toBe("my.host:3000");
  });

  it("accepts a bare host without a scheme", () => {
    expect(workspaceUrlHost("opercia.example.com")).toBe("opercia.example.com");
    expect(workspaceUrlHost("opercia.example.com/path")).toBe(
      "opercia.example.com",
    );
  });

  it("falls back to the brand host when no app URL is configured", () => {
    expect(workspaceUrlHost("")).toBe("opercia.ai");
    expect(workspaceUrlHost("   ")).toBe("opercia.ai");
    expect(workspaceUrlHost(null)).toBe("opercia.ai");
    expect(workspaceUrlHost(undefined)).toBe("opercia.ai");
  });
});
