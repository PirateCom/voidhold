import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { SESSION_COOKIE_MAX_AGE } from "@/lib/session";
import { supabaseAnonKey, supabaseUrl } from "./config";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const url = supabaseUrl();
  const anon = supabaseAnonKey();
  if (!url || !anon) {
    return { response: supabaseResponse, user: null };
  }

  const supabase = createServerClient(url, anon, {
    cookieOptions: {
      maxAge: SESSION_COOKIE_MAX_AGE,
      path: "/",
      sameSite: "lax",
    },
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, {
            ...options,
            maxAge: SESSION_COOKIE_MAX_AGE,
          }),
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { response: supabaseResponse, user };
}
