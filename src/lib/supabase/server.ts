import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { SESSION_COOKIE_MAX_AGE } from "@/lib/session";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "./config";

export { isSupabaseConfigured };

export async function createClient() {
  const url = supabaseUrl();
  const anon = supabaseAnonKey();
  if (!url || !anon) return null;

  const cookieStore = await cookies();

  return createServerClient(url, anon, {
    cookieOptions: {
      maxAge: SESSION_COOKIE_MAX_AGE,
      path: "/",
      sameSite: "lax",
    },
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, {
              ...options,
              maxAge: SESSION_COOKIE_MAX_AGE,
            }),
          );
        } catch {
          /* called from a Server Component — middleware refreshes sessions */
        }
      },
    },
  });
}
