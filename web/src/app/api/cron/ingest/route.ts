import { writeAuditEvent } from "@/lib/audit";
import { isIngestionInProgress, startIngestion } from "@/lib/ingest-runner";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isCronAuthorized(request: Request): boolean {
  const expected = (process.env.CRON_SECRET || "").trim();
  if (!expected) return false;

  const bearer = request.headers.get("authorization");
  if (bearer && bearer.startsWith("Bearer ")) {
    const token = bearer.slice("Bearer ".length).trim();
    if (token === expected) return true;
  }

  const header = request.headers.get("x-cron-secret");
  if (header && header.trim() === expected) return true;
  return false;
}

function readLimit(
  payload: { full?: boolean; limit?: number } | null,
): { full: boolean; limit: number | null } {
  const full = Boolean(payload?.full ?? true);
  const requestedLimit = Number(payload?.limit);
  const limit = full
    ? null
    : Number.isFinite(requestedLimit) && requestedLimit > 0
      ? requestedLimit
      : Number(process.env.INGEST_LIMIT_ROWS || 1000);

  return { full, limit };
}

export async function POST(request: Request) {
  if (!(process.env.CRON_SECRET || "").trim()) {
    return Response.json({ ok: false, error: "CRON_SECRET is not configured." }, { status: 503 });
  }

  if (!isCronAuthorized(request)) {
    await writeAuditEvent(
      { eventType: "cron_ingest", actorType: "cron", status: "unauthorized" },
      request,
    );
    return Response.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (isIngestionInProgress()) {
    await writeAuditEvent(
      {
        eventType: "cron_ingest",
        actorType: "cron",
        status: "failure",
        metadata: { reason: "in_progress" },
      },
      request,
    );
    return Response.json({ ok: false, error: "An ingestion run is already in progress." }, { status: 409 });
  }

  let payload: { full?: boolean; limit?: number } | null = null;
  try {
    payload = (await request.json()) as { full?: boolean; limit?: number };
  } catch {
    payload = null;
  }

  const { full, limit } = readLimit(payload);
  const promise = startIngestion({
    limit,
    jobName: full ? "ingest_dbpr_cron_full" : "ingest_dbpr_cron",
  });

  if (!promise) {
    return Response.json({ ok: false, error: "Failed to start ingestion." }, { status: 409 });
  }

  promise
    .then(async (result) => {
      await writeAuditEvent(
        {
          eventType: "cron_ingest",
          actorType: "cron",
          status: "success",
          metadata: { full, limit, rowsProcessed: result.totalProcessed },
        },
        request,
      );
    })
    .catch(async (error) => {
      await writeAuditEvent(
        {
          eventType: "cron_ingest",
          actorType: "cron",
          status: "failure",
          metadata: {
            full,
            limit,
            error: error instanceof Error ? error.message : "Unknown error",
          },
        },
        request,
      );
    });

  await writeAuditEvent(
    {
      eventType: "cron_ingest",
      actorType: "cron",
      status: "started",
      metadata: { full, limit },
    },
    request,
  );

  return Response.json(
    {
      ok: true,
      mode: "background",
      message: "Cron ingestion started.",
      full,
      limit,
    },
    { status: 202 },
  );
}
