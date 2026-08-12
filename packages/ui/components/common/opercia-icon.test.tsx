import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { OperciaIcon } from "./opercia-icon";

describe("OperciaIcon", () => {
  it("fits the large bordered mark to the same visual ratio as the desktop icon", () => {
    const markup = renderToStaticMarkup(<OperciaIcon bordered size="lg" />);

    expect(markup).toContain("p-1.5");
    expect(markup).toContain("size-8");
    expect(markup).toContain('viewBox="40 40 176 176"');
    expect(markup).not.toContain("p-2.5");
    expect(markup).not.toContain("size-5");
  });
});
