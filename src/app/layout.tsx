import type { Metadata, Viewport } from "next";
import { Exo_2, Source_Sans_3 } from "next/font/google";
import { Providers } from "@/components/providers";
import { isSupabaseConfigured } from "@/lib/supabase/config";
import "./globals.css";

const display = Exo_2({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["600", "700"],
});

const body = Source_Sans_3({
  variable: "--font-body",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Voidhold",
  description: "Hold a world in the dark. Mine, research, and raid derelicts.",
  appleWebApp: {
    capable: true,
    title: "Voidhold",
    statusBarStyle: "black-translucent",
  },
};

export const viewport: Viewport = {
  themeColor: "#070b14",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={`${display.variable} ${body.variable} bg-[var(--background)] antialiased`}>
        <Providers configured={isSupabaseConfigured()}>{children}</Providers>
      </body>
    </html>
  );
}
