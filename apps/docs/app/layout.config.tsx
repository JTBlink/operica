import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { ArrowUpRight } from "lucide-react";

// Docs-local stateless Opercia mark — matches @opercia/ui's OperciaIcon,
// while staying safe to render from Server Components. Keep in sync with
// packages/ui/components/common/opercia-icon.tsx if the mark changes.
function OperciaMark() {
  return (
    <svg
      viewBox="0 0 64 64"
      fill="none"
      aria-hidden="true"
      className="size-[1em]"
    >
      <path
        d="M14 25C16.7 14.4 26.3 7 38 7c13.8 0 25 11.2 25 25 0 10.4-6.4 19.4-15.5 23.1 5.2-5.1 7.5-11.5 6.1-18.2-2-9.6-10.5-16.7-20.4-16.7-7.7 0-14.7 4.2-18.3 10.6L14 25Z"
        fill="currentColor"
      />
      <path
        d="M50 39c-2.9 10.4-12.4 18-23.7 18C12.9 57 2 46.1 2 32.7c0-10 6.1-18.6 14.7-22.3-4.7 5-6.8 11.2-5.4 17.6 2 9.3 10.2 16.1 19.8 16.1 7.5 0 14.3-4.1 17.9-10.3L50 39Z"
        fill="currentColor"
      />
      <rect
        x="26"
        y="26"
        width="12"
        height="12"
        rx="3"
        fill="currentColor"
        transform="rotate(45 32 32)"
      />
    </svg>
  );
}

// GitHub mark — inlined SVG (lucide-react dropped the Github icon for brand
// trademark reasons). Path matches apps/web/features/landing/components/
// shared.tsx GitHubMark.
function GitHubMark() {
  return (
    <svg
      viewBox="0 0 16 16"
      aria-hidden="true"
      className="size-[1em]"
      fill="currentColor"
    >
      <path d="M8 0C3.58 0 0 3.58 0 8a8 8 0 0 0 5.47 7.59c.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2 .37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82A7.65 7.65 0 0 1 8 4.84c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
    </svg>
  );
}

// External links shown at the top of the sidebar (and in the top nav on
// desktop). Leading icon = brand identity (GitHub mark / Opercia mark);
// trailing ArrowUpRight = "opens externally" glyph, same pattern as
// `packages/views/layout/help-launcher.tsx` from PR #1560.
const externalLinkText = (label: string) => (
  <span className="inline-flex items-center gap-1">
    {label}
    <ArrowUpRight className="size-3 translate-y-px text-muted-foreground/60" />
  </span>
);

export const baseOptions: BaseLayoutProps = {
  nav: {
    title: (
      <span className="font-semibold text-base">Opercia Docs</span>
    ),
  },
  links: [
    {
      icon: <GitHubMark />,
      text: externalLinkText("GitHub"),
      url: "https://github.com/JTBlink/operica",
      external: true,
    },
    {
      icon: <OperciaMark />,
      text: externalLinkText("Opercia"),
      url: "https://opercia.ai",
      external: true,
    },
  ],
};
