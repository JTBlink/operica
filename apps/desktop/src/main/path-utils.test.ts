import { describe, expect, it } from "vitest";
import { appendMissingPaths } from "./path-utils";

describe("appendMissingPaths", () => {
  it("preserves the shell-selected Node directory before fallbacks", () => {
    expect(
      appendMissingPaths("/home/dev/.nvm/current/bin:/usr/local/bin", [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/home/dev/.local/bin",
      ]),
    ).toBe(
      "/home/dev/.nvm/current/bin:/usr/local/bin:/opt/homebrew/bin:/home/dev/.local/bin",
    );
  });

  it("drops empty segments and duplicate fallbacks", () => {
    expect(appendMissingPaths(":/usr/bin::", ["/usr/bin", "/usr/local/bin"])).toBe(
      "/usr/bin:/usr/local/bin",
    );
  });
});
