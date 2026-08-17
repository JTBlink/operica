/**
 * @vitest-environment jsdom
 */
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, waitFor } from "@testing-library/react";
import type { ReactNode } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { setApiInstance } from "../api";
import { ApiError, type ApiClient } from "../api/client";
import { createAuthStore, registerAuthStore, useAuthStore } from "../auth";
import type { StorageAdapter, User, Workspace } from "../types";
import { workspaceKeys } from "../workspace/queries";
import { AuthInitializer } from "./auth-initializer";

const user: User = {
  id: "user-1",
  name: "Operica",
  email: "operica@operica.local",
  avatar_url: null,
  onboarded_at: "2026-08-14T00:00:00Z",
  onboarding_questionnaire: {},
  starter_content_state: "imported",
  language: null,
  profile_description: "",
  timezone: null,
  created_at: "2026-08-14T00:00:00Z",
  updated_at: "2026-08-14T00:00:00Z",
};

const workspace: Workspace = {
  id: "workspace-1",
  name: "Operica",
  slug: "operica",
  description: null,
  context: null,
  settings: {},
  repos: [],
  issue_prefix: "OPR",
  avatar_url: null,
  created_at: "2026-08-14T00:00:00Z",
  updated_at: "2026-08-14T00:00:00Z",
};

function emptyStorage(): StorageAdapter {
  const data: Record<string, string> = {};
  return {
    getItem: vi.fn((key) => data[key] ?? null),
    setItem: vi.fn((key, value) => {
      data[key] = value;
    }),
    removeItem: vi.fn((key) => {
      delete data[key];
    }),
  };
}

describe("AuthInitializer", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("accepts server-side auto-login when token storage is empty", async () => {
    const storage = emptyStorage();
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    const api = {
      getConfig: vi.fn().mockRejectedValue(new Error("config is optional")),
      getMe: vi.fn().mockResolvedValue(user),
      listWorkspaces: vi.fn().mockResolvedValue([workspace]),
    } as unknown as ApiClient;
    setApiInstance(api);
    registerAuthStore(createAuthStore({ api, storage }));

    function Wrapper({ children }: { children: ReactNode }) {
      return (
        <QueryClientProvider client={queryClient}>
          <AuthInitializer storage={storage}>{children}</AuthInitializer>
        </QueryClientProvider>
      );
    }

    render(<div>desktop</div>, { wrapper: Wrapper });

    await waitFor(() => expect(useAuthStore.getState().isLoading).toBe(false));
    expect(useAuthStore.getState().user).toEqual(user);
    expect(queryClient.getQueryData(workspaceKeys.list())).toEqual([workspace]);
  });

  it("bootstraps a Desktop bearer token for server auto-login", async () => {
    const storage = emptyStorage();
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    const api = {
      getConfig: vi.fn().mockRejectedValue(new Error("config is optional")),
      issueCliToken: vi.fn().mockResolvedValue({ token: "jwt-dev" }),
      setToken: vi.fn(),
      getMe: vi.fn().mockResolvedValue(user),
      listWorkspaces: vi.fn().mockResolvedValue([workspace]),
    } as unknown as ApiClient;
    setApiInstance(api);
    registerAuthStore(createAuthStore({ api, storage }));

    function Wrapper({ children }: { children: ReactNode }) {
      return (
        <QueryClientProvider client={queryClient}>
          <AuthInitializer
            storage={storage}
            identity={{ platform: "desktop" }}
          >
            {children}
          </AuthInitializer>
        </QueryClientProvider>
      );
    }

    render(<div>desktop</div>, { wrapper: Wrapper });

    await waitFor(() => expect(useAuthStore.getState().isLoading).toBe(false));
    expect(api.issueCliToken).toHaveBeenCalledOnce();
    expect(storage.getItem("operica_token")).toBe("jwt-dev");
    expect(api.setToken).toHaveBeenCalledWith("jwt-dev");
    expect(useAuthStore.getState().user).toEqual(user);
  });

  it("finishes initialization when a refreshed Desktop token still fails", async () => {
    const storage = emptyStorage();
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    const api = {
      getConfig: vi.fn().mockRejectedValue(new Error("config is optional")),
      issueCliToken: vi.fn().mockResolvedValue({ token: "jwt-dev" }),
      setToken: vi.fn(),
      getMe: vi
        .fn()
        .mockRejectedValueOnce(new ApiError("expired", 401, "Unauthorized"))
        .mockRejectedValue(new ApiError("still unauthorized", 401, "Unauthorized")),
      listWorkspaces: vi.fn().mockResolvedValue([workspace]),
    } as unknown as ApiClient;
    setApiInstance(api);
    registerAuthStore(createAuthStore({ api, storage }));

    function Wrapper({ children }: { children: ReactNode }) {
      return (
        <QueryClientProvider client={queryClient}>
          <AuthInitializer
            storage={storage}
            identity={{ platform: "desktop" }}
          >
            {children}
          </AuthInitializer>
        </QueryClientProvider>
      );
    }

    storage.setItem("operica_token", "expired-jwt");
    render(<div>desktop</div>, { wrapper: Wrapper });

    await waitFor(() => expect(useAuthStore.getState().isLoading).toBe(false));
    expect(api.issueCliToken).toHaveBeenCalledOnce();
    expect(storage.getItem("operica_token")).toBeNull();
    expect(useAuthStore.getState().user).toBeNull();
  });
});
