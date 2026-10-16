import { createBrowserClient } from "@supabase/ssr";
import { readKeepLoggedInBrowser, sessionCookieOptionsFor } from "@/lib/session";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "./config";

export function createClient(keepLoggedIn = readKeepLoggedInBrowser()) {
  if (!isSupabaseConfigured()) return null;
  return createBrowserClient(supabaseUrl()!, supabaseAnonKey()!, {
    cookieOptions: sessionCookieOptionsFor(keepLoggedIn),
    isSingleton: false,
  });
}
