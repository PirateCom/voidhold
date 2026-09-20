import { createBrowserClient } from "@supabase/ssr";
import { sessionCookieOptions } from "@/lib/session";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "./config";

export function createClient() {
  if (!isSupabaseConfigured()) return null;
  return createBrowserClient(supabaseUrl()!, supabaseAnonKey()!, {
    cookieOptions: sessionCookieOptions,
  });
}
