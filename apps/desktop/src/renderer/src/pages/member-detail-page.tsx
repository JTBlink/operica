import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { MemberDetailPage as SharedMemberDetailPage } from "@opercia/views/members";
import { useWorkspaceId } from "@opercia/core/hooks";
import { memberListOptions } from "@opercia/core/workspace/queries";
import { useDocumentTitle } from "@/hooks/use-document-title";

export function MemberDetailPage() {
  const { id } = useParams<{ id: string }>();
  const wsId = useWorkspaceId();
  const { data: members = [] } = useQuery(memberListOptions(wsId));
  const member = members.find((m) => m.user_id === id) ?? null;

  useDocumentTitle(member?.name ?? "Member");

  if (!id) return null;
  return <SharedMemberDetailPage userId={id} />;
}
