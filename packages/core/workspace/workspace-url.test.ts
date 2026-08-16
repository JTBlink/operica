import { describe, expect, it } from "vitest";
import { workspaceUrlHost } from "./workspace-url";

describe("workspaceUrlHost", () => {
  it("returns the host of a full app URL", () => {
    expect(workspaceUrlHost("https://operica.example.com")).toBe(
      "operica.example.com",
    );
  });

  it("ignores scheme, path, and trailing slash", () => {
    expect(workspaceUrlHost("https://operica.example.com/")).toBe(
      "operica.example.com",
    );
    expect(workspaceUrlHost("http://operica.example.com/app/onboarding")).toBe(
      "operica.example.com",
    );
  });

  it("preserves a non-default port", () => {
    expect(workspaceUrlHost("https://my.host:3000")).toBe("my.host:3000");
  });

  it("accepts a bare host without a scheme", () => {
    expect(workspaceUrlHost("operica.example.com")).toBe("operica.example.com");
    expect(workspaceUrlHost("operica.example.com/path")).toBe(
      "operica.example.com",
    );
  });

  it("falls back to the brand host when no app URL is configured", () => {
    expect(workspaceUrlHost("")).toBe("operica.ai");
    expect(workspaceUrlHost("   ")).toBe("operica.ai");
    expect(workspaceUrlHost(null)).toBe("operica.ai");
    expect(workspaceUrlHost(undefined)).toBe("operica.ai");
  });
});
