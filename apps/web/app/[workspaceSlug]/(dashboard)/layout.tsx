"use client";

import { DashboardLayout } from "@opercia/views/layout";
import { OperciaIcon } from "@opercia/ui/components/common/opercia-icon";
import { SearchCommand, SearchTrigger } from "@opercia/views/search";
import { FloatingChat } from "@opercia/views/chat";
import { WebNotificationBridge } from "@/components/web-notification-bridge";

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <DashboardLayout
      loadingIndicator={<OperciaIcon className="size-6" />}
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
