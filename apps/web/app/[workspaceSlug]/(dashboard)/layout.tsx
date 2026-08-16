"use client";

import { DashboardLayout } from "@operica/views/layout";
import { OpericaIcon } from "@operica/ui/components/common/operica-icon";
import { SearchCommand, SearchTrigger } from "@operica/views/search";
import { FloatingChat } from "@operica/views/chat";
import { WebNotificationBridge } from "@/components/web-notification-bridge";

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <DashboardLayout
      loadingIndicator={<OpericaIcon className="size-6" />}
      searchSlot={<SearchTrigger />}
      extra={
        <>
          <SearchCommand />
          <WebNotificationBridge />
          <FloatingChat />
        </>
      }
    >
      {children}
    </DashboardLayout>
  );
}
