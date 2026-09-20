"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";

const OTP_TYPES = new Set<EmailOtpType>([
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
  "email",
]);

export default function AuthCallbackPage() {
  const router = useRouter();
  const [message, setMessage] = useState("Signing you in…");

  useEffect(() => {
    let cancelled = false;

    async function finishSignIn() {
      const supabase = createClient();
      if (!supabase) {
        router.replace("/login?error=" + encodeURIComponent("Supabase is not configured."));
        return;
      }

      const url = new URL(window.location.href);
      const nextPath = url.searchParams.get("next");
      const next =
        nextPath && nextPath.startsWith("/") && !nextPath.startsWith("//") ? nextPath : "/";
      const authError =
        url.searchParams.get("error_description") ||
        url.searchParams.get("error_code") ||
        url.searchParams.get("error");
      const code = url.searchParams.get("code");
      const tokenHash = url.searchParams.get("token_hash");
      const typeParam = url.searchParams.get("type");
      const hash = url.hash.startsWith("#") ? url.hash.slice(1) : url.hash;
      const hashParams = new URLSearchParams(hash);

      if (authError) {
        router.replace("/login?error=" + encodeURIComponent(authError.replace(/\+/g, " ")));
        return;
      }

      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (cancelled) return;
        if (error) {
          router.replace("/login?error=" + encodeURIComponent(error.message));
          return;
        }
        router.replace(next);
        router.refresh();
        return;
      }

      if (tokenHash && typeParam && OTP_TYPES.has(typeParam as EmailOtpType)) {
        const { error } = await supabase.auth.verifyOtp({
          type: typeParam as EmailOtpType,
          token_hash: tokenHash,
        });
        if (cancelled) return;
        if (error) {
          router.replace("/login?error=" + encodeURIComponent(error.message));
          return;
        }
        router.replace(next);
        router.refresh();
        return;
      }

      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");
      if (accessToken && refreshToken) {
        const { error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
        if (cancelled) return;
        if (error) {
          router.replace("/login?error=" + encodeURIComponent(error.message));
          return;
        }
        router.replace(next);
        router.refresh();
        return;
      }

      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (cancelled) return;
      if (session) {
        router.replace(next);
        router.refresh();
        return;
      }

      if (!cancelled) {
        setMessage(
          "That email link did not finish signing you in. Request a new one and open it in this same browser.",
        );
        router.replace(
          "/login?error=" +
            encodeURIComponent(
              "That email link did not finish signing you in. Request a new one and open it in this same browser.",
            ),
        );
      }
    }

    void finishSignIn();
    return () => {
      cancelled = true;
    };
  }, [router]);

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[430px] flex-col justify-center bg-[var(--surface)] px-6">
      <p className="text-sm text-[var(--muted-fg)]">{message}</p>
    </div>
  );
}
