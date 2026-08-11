import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { ArrowUpRight } from "lucide-react";

// Docs-local stateless Opercia mark — matches @opercia/ui's OperciaIcon,
// while staying safe to render from Server Components. Keep in sync with
// packages/ui/components/common/opercia-icon.tsx if the mark changes.
function OperciaMark() {
  return (
    <svg
      viewBox="0 0 256 256"
      fill="none"
      aria-hidden="true"
      className="size-[1em]"
    >
      <path
        fill="currentColor"
        d="M92 44h38c45.287 0 82 36.713 82 82v29c0 8.49-3.372 16.633-9.373 22.637L171 209v-79c0-23.196-18.804-42-42-42H62c-7.081 0-10.768-8.428-5.97-13.636l23.235-25.205C82.637 45.501 87.064 44 92 44Z"
      />
      <path
        fill="currentColor"
        d="M164 212h-38c-45.287 0-82-36.713-82-82v-29c0-8.49 3.372-16.633 9.373-22.637L85 47v79c0 23.196 18.804 42 42 42h67c7.081 0 10.768 8.428 5.97 13.636l-23.235 25.205C173.363 210.499 168.936 212 164 212Z"
      />
      <rect
        x="106"
        y="106"
        width="44"
        height="44"
        rx="12"
        fill="currentColor"
        transform="rotate(45 128 128)"
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
