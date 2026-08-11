import type { Metadata } from "next";
import { OperciaLanding } from "@/features/landing/components/opercia-landing";

export const metadata: Metadata = {
  title: "Homepage",
  description:
    "Opercia — open-source platform that turns coding agents into real teammates. Assign tasks, track progress, compound skills.",
  openGraph: {
    title: "Opercia — Project Management for Human + Agent Teams",
    description:
      "Manage your human + agent workforce in one place.",
    url: "/homepage",
  },
  alternates: {
    canonical: "/homepage",
  },
};

export default function HomepagePage() {
  return <OperciaLanding />;
}
