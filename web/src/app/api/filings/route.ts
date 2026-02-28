import { getDbPool, isDatabaseConfigured } from "@/lib/db";
import { isAuthorizedApiRequest } from "@/lib/auth";
import { writeAuditEvent } from "@/lib/audit";
import type { FilingType } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const filingTypes: FilingType[] = [
  "Annual Budget",
  "Reserve Study",
  "Year-End Financial Statement",
  "Insurance Summary",
  "Board Meeting Minutes",
];

function readRequiredString(
  payload: Record<string, unknown>,
  field: string,
  maxLength = 160,
): string | null {
  const raw = payload[field];
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  if (!value || value.length > maxLength) return null;
  return value;
}

function normalizeDate(value: string | null): string | null {
  if (!value) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;

  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return null;
  return value;
}

function isFilingType(value: string): value is FilingType {
  return filingTypes.includes(value as FilingType);
}

function isHttpUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

function isAllowedSourceUrl(value: string): boolean {
  if (value.startsWith("/uploads/")) return true;
  return isHttpUrl(value);
}

function databaseErrorMessage(error: unknown): { status: number; message: string } {
  if (error instanceof Error) {
    const message = error.message.toLowerCase();
    if (
      message.includes("connect") ||
      message.includes("econnrefused") ||
      message.includes("timeout")
    ) {
      return {
        status: 503,
        message: "Database connection failed. Verify DATABASE_URL and that Postgres is running.",
      };
    }
  }

  return {
    status: 500,
    message: "Failed to create filing. Verify migrations and database availability.",
  };
}

export async function POST(request: Request) {
  if (!isAuthorizedApiRequest(request)) {
    await writeAuditEvent(
      { eventType: "create_filing", actorType: "admin", status: "unauthorized" },
      request,
    );
    return Response.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isDatabaseConfigured()) {
    await writeAuditEvent(
      {
        eventType: "create_filing",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "database_not_configured" },
      },
      request,
    );
    return Response.json(
      {
        ok: false,
        error: "Database is not configured. Set DATABASE_URL to enable filing writes.",
      },
      { status: 503 },
    );
  }

  const pool = getDbPool();
  if (!pool) {
    await writeAuditEvent(
      {
        eventType: "create_filing",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "database_unavailable" },
      },
      request,
    );
    return Response.json({ ok: false, error: "Database unavailable." }, { status: 503 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = (await request.json()) as Record<string, unknown>;
  } catch {
    await writeAuditEvent(
      {
        eventType: "create_filing",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "invalid_json_payload" },
      },
      request,
    );
    return Response.json({ ok: false, error: "Invalid JSON payload." }, { status: 400 });
  }

  const associationId = readRequiredString(payload, "associationId", 120);
  const filingTypeValue = readRequiredString(payload, "type", 80);
  const periodLabel = readRequiredString(payload, "periodLabel", 120);
  const sourceLabel = readRequiredString(payload, "sourceLabel", 120);
  const sourceUrlRaw =
    typeof payload.sourceUrl === "string" ? payload.sourceUrl.trim().slice(0, 500) : "";
  const publishedAtRaw =
    typeof payload.publishedAt === "string" ? payload.publishedAt.trim() : "";

  if (!associationId || !/^[a-z0-9-]+$/.test(associationId)) {
    return Response.json({ ok: false, error: "associationId must be a valid slug." }, { status: 400 });
  }

  if (!filingTypeValue || !isFilingType(filingTypeValue)) {
    return Response.json({ ok: false, error: "Invalid filing type." }, { status: 400 });
  }

  if (!periodLabel) {
    return Response.json({ ok: false, error: "periodLabel is required." }, { status: 400 });
  }

  if (!sourceLabel) {
    return Response.json({ ok: false, error: "sourceLabel is required." }, { status: 400 });
  }

  const publishedAt = normalizeDate(publishedAtRaw || null);
  if (publishedAtRaw && !publishedAt) {
    return Response.json({ ok: false, error: "publishedAt must use YYYY-MM-DD." }, { status: 400 });
  }

  const sourceUrl = sourceUrlRaw || null;
  if (sourceUrl && !isAllowedSourceUrl(sourceUrl)) {
    return Response.json(
      { ok: false, error: "sourceUrl must be an uploaded path or start with http:// or https://." },
      { status: 400 },
    );
  }

  try {
    const associationResult = await pool.query<{ id: string; slug: string; legal_name: string }>(
      `
        SELECT id, slug, legal_name
        FROM associations
        WHERE slug = $1
        LIMIT 1
      `,
      [associationId],
    );

    if (associationResult.rowCount === 0) {
      await writeAuditEvent(
        {
          eventType: "create_filing",
          actorType: "admin",
          status: "failure",
          metadata: { reason: "association_not_found", associationId },
        },
        request,
      );
      return Response.json({ ok: false, error: "Association not found." }, { status: 404 });
    }

    const association = associationResult.rows[0];
    const insertResult = await pool.query<{ id: string; published_at: string | null }>(
      `
        INSERT INTO filings (
          association_id,
          filing_type,
          period_label,
          published_at,
          source_label,
          source_url,
          created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
        RETURNING id, published_at::text
      `,
      [association.id, filingTypeValue, periodLabel, publishedAt, sourceLabel, sourceUrl],
    );

    await writeAuditEvent(
      {
        eventType: "create_filing",
        actorType: "admin",
        status: "success",
        metadata: {
          associationId,
          filingType: filingTypeValue,
          filingId: insertResult.rows[0].id,
        },
      },
      request,
    );

    return Response.json(
      {
        ok: true,
        filing: {
          id: insertResult.rows[0].id,
          condoId: association.slug,
          legalName: association.legal_name,
          type: filingTypeValue,
          periodLabel,
          publishedAt: insertResult.rows[0].published_at,
          sourceLabel,
          sourceUrl,
        },
      },
      { status: 201 },
    );
  } catch (error) {
    console.error("Failed to insert filing:", error);
    const mapped = databaseErrorMessage(error);
    await writeAuditEvent(
      {
        eventType: "create_filing",
        actorType: "admin",
        status: "failure",
        metadata: {
          reason: "insert_failed",
          associationId,
          filingType: filingTypeValue,
          error: mapped.message,
        },
      },
      request,
    );
    return Response.json({ ok: false, error: mapped.message }, { status: mapped.status });
  }
}
