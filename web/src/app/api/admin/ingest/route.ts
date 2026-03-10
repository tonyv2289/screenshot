import { getDbPool } from "@/lib/db";
import { isAuthorizedApiRequest } from "@/lib/auth";
import { writeAuditEvent } from "@/lib/audit";
import { isIngestionInProgress, startIngestion } from "@/lib/ingest-runner";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return fallback;
}

export async function GET(request: Request) {
  if (!isAuthorizedApiRequest(request)) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_status",
        actorType: "admin",
        status: "unauthorized",
      },
      request,
    );
    return Response.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const pool = getDbPool();
  if (!pool) {
    return Response.json({
      ok: true,
      inProgress: isIngestionInProgress(),
      usingDatabase: false,
      runs: [],
    });
  }

  try {
    const result = await pool.query<{
      id: string;
      job_name: string;
      status: string;
      started_at: string;
      finished_at: string | null;
      rows_processed: number;
    }>(
      `
        SELECT
          id,
          job_name,
          status,
          started_at::text,
          finished_at::text,
          rows_processed
        FROM ingestion_runs
        ORDER BY started_at DESC
        LIMIT 10
      `,
    );

    return Response.json({
      ok: true,
      inProgress: isIngestionInProgress(),
      usingDatabase: true,
      runs: result.rows,
    });
  } catch (error) {
    return Response.json({
      ok: false,
      inProgress: isIngestionInProgress(),
      usingDatabase: false,
      runs: [],
      error: getErrorMessage(error, "Failed to fetch ingestion status"),
    });
  }
}

export async function POST(request: Request) {
  if (!isAuthorizedApiRequest(request)) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "unauthorized",
      },
      request,
    );
    return Response.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (isIngestionInProgress()) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "in_progress" },
      },
      request,
    );
    return Response.json(
      {
        ok: false,
        error: "An ingestion run is already in progress.",
      },
      { status: 409 },
    );
  }

  let payload: { full?: boolean; limit?: number; async?: boolean } = {};
  try {
    payload = (await request.json()) as { full?: boolean; limit?: number; async?: boolean };
  } catch {
    payload = {};
  }

  const full = Boolean(payload.full);
  const requestedLimit = Number(payload.limit);
  const limit = full
    ? null
    : Number.isFinite(requestedLimit) && requestedLimit > 0
      ? requestedLimit
      : Number(process.env.INGEST_LIMIT_ROWS || 1000);

  const runPromise = startIngestion({
    limit,
    jobName: full ? "ingest_dbpr_api_full" : "ingest_dbpr_api",
  });

  if (!runPromise) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "start_rejected" },
      },
      request,
    );
    return Response.json({ ok: false, error: "An ingestion run is already in progress." }, { status: 409 });
  }

  runPromise.catch((error) => {
    console.error("Background ingestion failed:", getErrorMessage(error, "Unknown error"));
  });

  const runAsync = payload.async !== false;

  if (runAsync) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "started",
        metadata: { full, limit, mode: "background" },
      },
      request,
    );
    return Response.json(
      {
        ok: true,
        mode: "background",
        message: "Ingestion started in background.",
        limit,
      },
      { status: 202 },
    );
  }

  try {
    const result = await runPromise;
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "success",
        metadata: { full, limit, mode: "sync", rowsProcessed: result.totalProcessed },
      },
      request,
    );
    return Response.json({ ok: true, mode: "sync", result });
  } catch (error) {
    await writeAuditEvent(
      {
        eventType: "admin_ingest_start",
        actorType: "admin",
        status: "failure",
        metadata: { full, limit, mode: "sync", error: getErrorMessage(error, "Ingestion failed") },
      },
      request,
    );
    return Response.json(
      {
        ok: false,
        error: getErrorMessage(error, "Ingestion failed"),
      },
      { status: 500 },
    );
  }
}
