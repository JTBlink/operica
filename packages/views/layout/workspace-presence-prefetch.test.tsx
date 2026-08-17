import { describe, expect, it, vi } from "vitest";
import { render } from "@testing-library/react";

const { prefetch, workspace } = vi.hoisted(() => ({
  prefetch: vi.fn(),
  workspace: { current: null as { id: string } | null },
}));

vi.mock("@operica/core/paths", () => ({
  useCurrentWorkspace: () => workspace.current,
}));
vi.mock("@operica/core/agents", () => ({
  useWorkspacePresencePrefetch: prefetch,
}));

import { WorkspacePresencePrefetch } from "./workspace-presence-prefetch";

describe("WorkspacePresencePrefetch", () => {
  it("disables presence queries while the current workspace is unresolved", () => {
    render(<WorkspacePresencePrefetch />);

    expect(prefetch).toHaveBeenCalledWith(undefined);
  });
});
