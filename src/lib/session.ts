/** Keep the session cookie as long as browsers allow (~400 days). */
export const SESSION_COOKIE_MAX_AGE = 60 * 60 * 24 * 400;

export const KEEP_LOGGED_IN_COOKIE = "voidhold_keep_session";

export const sessionCookieOptions = {
  maxAge: SESSION_COOKIE_MAX_AGE,
  path: "/",
  sameSite: "lax" as const,
};

export function sessionCookieOptionsFor(keepLoggedIn: boolean) {
  return keepLoggedIn
    ? sessionCookieOptions
    : {
        path: "/",
        sameSite: "lax" as const,
      };
}

export function applySessionCookieLifetime<T extends { maxAge?: number; expires?: Date }>(
  value: string,
  options: T | undefined,
  keepLoggedIn: boolean,
): T {
  const base = { ...(options ?? {}) } as T;
  if (!value || base.maxAge === 0) {
    return { ...base, maxAge: 0 };
  }
  if (keepLoggedIn) {
    return { ...base, maxAge: SESSION_COOKIE_MAX_AGE };
  }
  delete base.maxAge;
  delete base.expires;
  return base;
}

export function readKeepLoggedInBrowser(): boolean {
  if (typeof document === "undefined") return true;
  const match = document.cookie
    .split("; ")
    .find((row) => row.startsWith(`${KEEP_LOGGED_IN_COOKIE}=`));
  if (!match) return true;
  return match.split("=")[1] !== "0";
}

export function writeKeepLoggedInBrowser(keepLoggedIn: boolean): void {
  if (typeof document === "undefined") return;
  if (keepLoggedIn) {
    document.cookie = `${KEEP_LOGGED_IN_COOKIE}=1; path=/; max-age=${SESSION_COOKIE_MAX_AGE}; samesite=lax`;
  } else {
    document.cookie = `${KEEP_LOGGED_IN_COOKIE}=0; path=/; samesite=lax`;
  }
}
