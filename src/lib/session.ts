/** Keep the session cookie as long as browsers allow (~400 days). */
export const SESSION_COOKIE_MAX_AGE = 60 * 60 * 24 * 400;

export const sessionCookieOptions = {
  maxAge: SESSION_COOKIE_MAX_AGE,
  path: "/",
  sameSite: "lax" as const,
};
