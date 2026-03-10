import { getDbPool, isDatabaseConfigured } from "@/lib/db";
import { isAdminAuthEnabled } from "@/lib/auth";
import { isIngestionInProgress } from "@/lib/ingest-runner";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const databaseConfigured = isDatabaseConfigured();
  let databaseReachable = false;
  let databaseError: string | null = null;

  if (databaseConfigured) {
    const pool = getDbPool();
    if (pool) {
      try {
        await pool.query("SELECT 1");
        databaseReachable = true;
      } catch (error) {
        databaseReachable = false;
        databaseError = error instanceof Error ? error.message : "Unknown database error";
      }
    }
  }

  const healthy = !databaseConfigured || databaseReachable;

  return Response.json(
    {
      ok: healthy,
      service: "condo-ledger-web",
      timestamp: new Date().toISOString(),
      authEnabled: isAdminAuthEnabled(),
      ingestionInProgress: isIngestionInProgress(),
      databaseConfigured,
      databaseReachable,
      databaseError,
    },
    { status: healthy ? 200 : 503 },
  );
}
