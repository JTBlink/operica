import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";

const state = vi.hoisted(() => ({
  workspace: null as { id: string; slug: string } | null,
}));

vi.mock("lucide-react", () => ({
  ChevronLeft: () => null,
  ChevronRight: () => null,
}));
vi.mock("motion/react", () => ({
  motion: {
    div: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
    header: ({ children }: { children: React.ReactNode }) => (
      <header>{children}</header>
    ),
  },
}));
vi.mock("@operica/ui/lib/utils", () => ({
  cn: (...classes: string[]) => classes.join(" "),
}));
vi.mock("@operica/ui/components/ui/sidebar", () => ({
  SidebarProvider: ({ children }: { children: React.ReactNode }) => (
    <div>{children}</div>
  ),
  SidebarTrigger: () => null,
  useSidebar: () => ({ state: "expanded", isCompact: false }),
}));
vi.mock("@operica/views/modals/registry", () => ({
  ModalRegistry: () => <div data-testid="modal-registry" />,
}));
vi.mock("@operica/views/layout", () => ({
  AppSidebar: () => <div data-testid="app-sidebar" />,
  GlobalShortcuts: () => <div data-testid="global-shortcuts" />,
}));
vi.mock("@operica/views/search", () => ({
  SearchCommand: () => <div data-testid="search-command" />,
  SearchTrigger: () => null,
}));
vi.mock("@operica/views/chat", () => ({
  FloatingChat: () => <div data-testid="floating-chat" />,
}));
vi.mock("@operica/views/platform", () => ({ useDesktopUnreadBadge: vi.fn() }));
vi.mock("@operica/views/navigation", () => ({
  useNavigation: () => ({ push: vi.fn() }),
}));
vi.mock("@operica/core/paths", () => ({
  WorkspaceSlugProvider: ({ children }: { children: React.ReactNode }) => (
    <>{children}</>
  ),
  useCurrentWorkspace: () => state.workspace,
  paths: { workspace: (slug: string) => ({ inbox: () => `/${slug}/inbox` }) },
}));
vi.mock("@operica/core/platform", () => ({
  getCurrentSlug: () => "solo",
  subscribeToCurrentSlug: () => () => {},
}));
vi.mock("@/hooks/use-tab-history", () => ({
  useNavigationInputBindings: vi.fn(),
  useTabHistory: () => ({
    canGoBack: false,
    canGoForward: false,
    goBack: vi.fn(),
    goForward: vi.fn(),
  }),
}));
vi.mock("@/platform/navigation", () => ({
  DesktopNavigationProvider: ({ children }: { children: React.ReactNode }) => (
    <>{children}</>
  ),
  routeContentLinkPath: vi.fn(),
  useNavigation: () => ({ push: vi.fn() }),
}));
vi.mock("./tab-bar", () => ({ TabBar: () => null }));
vi.mock("./tab-content", () => ({ TabContent: () => null }));
vi.mock("./window-overlay", () => ({ WindowOverlay: () => null }));

import { DesktopShell } from "./desktop-layout";

describe("DesktopShell", () => {
  it("does not mount workspace-scoped chrome when the current slug no longer resolves", () => {
    Object.assign(window, {
      desktopAPI: {
        onNavigationGesture: () => () => {},
        onInboxOpen: () => () => {},
      },
    });

    render(<DesktopShell />);

    expect(screen.queryByTestId("app-sidebar")).not.toBeInTheDocument();
    expect(screen.queryByTestId("global-shortcuts")).not.toBeInTheDocument();
    expect(screen.queryByTestId("search-command")).not.toBeInTheDocument();
    expect(screen.queryByTestId("floating-chat")).not.toBeInTheDocument();
    expect(screen.queryByTestId("modal-registry")).not.toBeInTheDocument();
  });
});
