import { NextResponse } from "next/server";
import { writeAuditEvent } from "@/lib/audit";
import {
  createAdminSessionToken,
  getAdminPassword,
  getAdminSessionCookieName,
  getAdminSessionTtlSeconds,
  isAdminAuthEnabled,
  isAuthorizedApiRequest,
} from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  return Response.json({
    ok: true,
    authEnabled: isAdminAuthEnabled(),
    authenticated: isAuthorizedApiRequest(request),
  });
}

export async function POST(request: Request) {
  if (!isAdminAuthEnabled()) {
    return Response.json({ ok: true, authEnabled: false });
  }

  let payload: { password?: string } = {};
  try {
    payload = (await request.json()) as { password?: string };
  } catch {
    payload = {};
  }

  const provided = (payload.password || "").trim();
  const expected = getAdminPassword();
  if (!provided || provided !== expected) {
    await writeAuditEvent(
      { eventType: "admin_session_login", actorType: "admin", status: "failure" },
      request,
    );
    return Response.json({ ok: false, error: "Invalid credentials." }, { status: 401 });
  }

  const token = createAdminSessionToken();
  const response = NextResponse.json({ ok: true, authEnabled: true });
  response.cookies.set({
    name: getAdminSessionCookieName(),
    value: token,
    path: "/",
    maxAge: getAdminSessionTtlSeconds(),
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  await writeAuditEvent(
    { eventType: "admin_session_login", actorType: "admin", status: "success" },
    request,
  );

  return response;
}

export async function DELETE(request: Request) {
  const response = NextResponse.json({ ok: true });
  response.cookies.set({
    name: getAdminSessionCookieName(),
    value: "",
    path: "/",
    maxAge: 0,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  await writeAuditEvent(
    { eventType: "admin_session_logout", actorType: "admin", status: "success" },
    request,
  );
  return response;
}
