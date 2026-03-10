import type { Pool } from "pg";
import { getDbPool } from "@/lib/db";

type AuditStatus = "success" | "failure" | "unauthorized" | "started";

export type AuditEventInput = {
  eventType: string;
  actorType: string;
  actorLabel?: string | null;
  status: AuditStatus;
  requestPath?: string | null;
  requestMethod?: string | null;
  metadata?: Record<string, unknown>;
};

function getActorLabel(request: Request): string | null {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor) {
    return forwardedFor.split(",")[0].trim();
  }

  const realIp = request.headers.get("x-real-ip");
  if (realIp) return realIp.trim();
  return null;
}

async function insertAuditEvent(pool: Pool, event: AuditEventInput): Promise<void> {
  await pool.query(
    `
      INSERT INTO audit_logs (
        event_type,
        actor_type,
        actor_label,
        request_path,
        request_method,
        status,
        metadata,
        created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, NOW())
    `,
    [
      event.eventType,
      event.actorType,
      event.actorLabel || null,
      event.requestPath || null,
      event.requestMethod || null,
      event.status,
      JSON.stringify(event.metadata || {}),
    ],
  );
}

export async function writeAuditEvent(
  event: AuditEventInput,
  request?: Request,
): Promise<void> {
  const pool = getDbPool();
  if (!pool) return;

  const actorLabel = event.actorLabel || (request ? getActorLabel(request) : null);

  try {
    await insertAuditEvent(pool, {
      ...event,
      actorLabel,
      requestPath: event.requestPath || request?.url || null,
      requestMethod: event.requestMethod || request?.method || null,
    });
  } catch (error) {
    const maybeCode =
      typeof error === "object" && error && "code" in error
        ? String((error as { code?: string }).code)
        : "";

    if (maybeCode === "42P01") {
      return;
    }

    console.error("Failed to write audit event:", error);
  }
}
