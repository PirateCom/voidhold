"use client";

import { EmpireProvider } from "@/components/empire-provider";

export function Providers({
  configured,
  children,
}: {
  configured: boolean;
  children: React.ReactNode;
}) {
  return <EmpireProvider configured={configured}>{children}</EmpireProvider>;
}
