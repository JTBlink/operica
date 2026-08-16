import type { Metadata } from "next";
import { OpericaLanding } from "@/features/landing/components/operica-landing";

export const metadata: Metadata = {
  title: "Homepage",
  description:
    "Operica — open-source platform that turns coding agents into real teammates. Assign tasks, track progress, compound skills.",
  openGraph: {
    title: "Operica — Project Management for Human + Agent Teams",
    description:
      "Manage your human + agent workforce in one place.",
    url: "/homepage",
  },
  alternates: {
    canonical: "/homepage",
  },
};

export default function HomepagePage() {
  return <OpericaLanding />;
}
