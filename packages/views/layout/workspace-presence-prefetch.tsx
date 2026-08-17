"use client";

import { useCurrentWorkspace } from "@operica/core/paths";
import { useWorkspacePresencePrefetch } from "@operica/core/agents";

// Mount once inside the workspace shell to warm presence data. Route and
// workspace-list updates can briefly disagree while a workspace is removed,
// so this component accepts an unresolved workspace and disables its queries.
export function WorkspacePresencePrefetch() {
  const workspace = useCurrentWorkspace();
  useWorkspacePresencePrefetch(workspace?.id);
  return null;
}
