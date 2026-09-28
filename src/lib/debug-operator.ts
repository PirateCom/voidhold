export const DEBUG_OPERATOR_EMAIL = "zanugreuu@gmail.com";

export function isDebugOperator(email: string | null | undefined, debugFlag?: boolean) {
  if (debugFlag) return true;
  return (email ?? "").trim().toLowerCase() === DEBUG_OPERATOR_EMAIL;
}
