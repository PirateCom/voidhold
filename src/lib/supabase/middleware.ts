import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import {
  KEEP_LOGGED_IN_COOKIE,
  applySessionCookieLifetime,
  sessionCookieOptionsFor,
} from "@/lib/session";
import { supabaseAnonKey, supabaseUrl } from "./config";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const url = supabaseUrl();
  const anon = supabaseAnonKey();
  if (!url || !anon) {
    return { response: supabaseResponse, user: null };
  }

  const keepLoggedIn = request.cookies.get(KEEP_LOGGED_IN_COOKIE)?.value !== "0";

  const supabase = createServerClient(url, anon, {
    cookieOptions: sessionCookieOptionsFor(keepLoggedIn),
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(
            name,
            value,
            applySessionCookieLifetime(value, options, keepLoggedIn),
          ),
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { response: supabaseResponse, user };
}
