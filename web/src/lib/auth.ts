import { createHmac, timingSafeEqual } from "node:crypto";

const ADMIN_SESSION_COOKIE = "condo_admin_session";
const ADMIN_SESSION_TTL_SECONDS = 60 * 60 * 12;

function getSigningSecret(): string {
  return process.env.ADMIN_SESSION_SECRET || getAdminPassword();
}

function signValue(value: string): string {
  const secret = getSigningSecret();
  return createHmac("sha256", secret).update(value).digest("hex");
}

function timingSafeHexEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, "hex");
  const right = Buffer.from(b, "hex");
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

function parseCookieHeader(cookieHeader: string | null): Record<string, string> {
  if (!cookieHeader) return {};
  const parts = cookieHeader.split(";").map((part) => part.trim());
  const cookies: Record<string, string> = {};

  for (const part of parts) {
    const separator = part.indexOf("=");
    if (separator <= 0) continue;
    const key = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (!key) continue;
    cookies[key] = decodeURIComponent(value);
  }

  return cookies;
}

export function getAdminPassword(): string {
  return (process.env.ADMIN_APP_PASSWORD || process.env.ADMIN_API_KEY || "").trim();
}

export function isAdminAuthEnabled(): boolean {
  return Boolean(getAdminPassword());
}

export function getAdminSessionCookieName(): string {
  return ADMIN_SESSION_COOKIE;
}

export function getAdminSessionTtlSeconds(): number {
  return ADMIN_SESSION_TTL_SECONDS;
}

export function createAdminSessionToken(): string {
  const expiresAt = Math.floor(Date.now() / 1000) + ADMIN_SESSION_TTL_SECONDS;
  const base = `${expiresAt}`;
  return `${base}.${signValue(base)}`;
}

export function isValidAdminSessionToken(token: string | null | undefined): boolean {
  if (!isAdminAuthEnabled()) return true;
  if (!token) return false;
  const [expiryRaw, signature] = token.split(".");
  if (!expiryRaw || !signature) return false;
  if (!/^\d+$/.test(expiryRaw)) return false;
  if (!/^[a-f0-9]{64}$/i.test(signature)) return false;

  const expiry = Number(expiryRaw);
  if (!Number.isFinite(expiry) || expiry <= Math.floor(Date.now() / 1000)) {
    return false;
  }

  const expected = signValue(expiryRaw);
  return timingSafeHexEqual(signature.toLowerCase(), expected.toLowerCase());
}

export function sessionTokenFromCookieHeader(cookieHeader: string | null): string | null {
  const cookies = parseCookieHeader(cookieHeader);
  return cookies[ADMIN_SESSION_COOKIE] || null;
}

export function isAuthorizedApiRequest(request: Request): boolean {
  if (!isAdminAuthEnabled()) return true;

  const expected = getAdminPassword();
  const provided = request.headers.get("x-admin-api-key");
  if (provided && provided === expected) {
    return true;
  }

  const sessionToken = sessionTokenFromCookieHeader(request.headers.get("cookie"));
  return isValidAdminSessionToken(sessionToken);
}

export function isSafeNextPath(pathname: string | null | undefined): boolean {
  if (!pathname) return false;
  return pathname.startsWith("/") && !pathname.startsWith("//");
}
