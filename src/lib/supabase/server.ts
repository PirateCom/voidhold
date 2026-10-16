import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import {
  KEEP_LOGGED_IN_COOKIE,
  applySessionCookieLifetime,
  sessionCookieOptionsFor,
} from "@/lib/session";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "./config";

export { isSupabaseConfigured };

export async function createClient() {
  const url = supabaseUrl();
  const anon = supabaseAnonKey();
  if (!url || !anon) return null;

  const cookieStore = await cookies();
  const keepLoggedIn = cookieStore.get(KEEP_LOGGED_IN_COOKIE)?.value !== "0";

  return createServerClient(url, anon, {
    cookieOptions: sessionCookieOptionsFor(keepLoggedIn),
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, applySessionCookieLifetime(value, options, keepLoggedIn)),
          );
        } catch {
          /* called from a Server Component — middleware refreshes sessions */
        }
      },
    },
  });
}
