import { isAuthorizedApiRequest } from "@/lib/auth";
import {
  isSupportedDbprImportFileName,
  runDbprManualImport,
  type DbprManualImportFile,
} from "@/lib/dbpr-manual-import";
import { writeAuditEvent } from "@/lib/audit";
import { isIngestionInProgress, startIngestionJob } from "@/lib/ingest-runner";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DEFAULT_MAX_BYTES = 40 * 1024 * 1024;

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return fallback;
}

function getMaxImportBytes(): number {
  const raw = Number(process.env.MANUAL_IMPORT_MAX_BYTES || DEFAULT_MAX_BYTES);
  if (!Number.isFinite(raw) || raw <= 0) return DEFAULT_MAX_BYTES;
  return Math.floor(raw);
}

function asFileArray(values: FormDataEntryValue[]): File[] {
  return values.filter((value): value is File => value instanceof File);
}

export async function POST(request: Request) {
  if (!isAuthorizedApiRequest(request)) {
    await writeAuditEvent(
      {
        eventType: "admin_import_start",
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
        eventType: "admin_import_start",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "in_progress" },
      },
      request,
    );
    return Response.json({ ok: false, error: "An ingestion run is already in progress." }, { status: 409 });
  }

  if (!process.env.DATABASE_URL) {
    return Response.json({ ok: false, error: "DATABASE_URL is not configured." }, { status: 503 });
  }

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return Response.json({ ok: false, error: "Invalid form payload." }, { status: 400 });
  }

  const files = asFileArray(formData.getAll("files"));
  if (files.length === 0) {
    return Response.json({ ok: false, error: "Add at least one CSV file under the 'files' field." }, { status: 400 });
  }

  const maxImportBytes = getMaxImportBytes();
  const totalBytes = files.reduce((sum, file) => sum + file.size, 0);
  if (totalBytes > maxImportBytes) {
    return Response.json(
      {
        ok: false,
        error: `Import payload exceeds ${Math.round(maxImportBytes / 1024 / 1024)} MB limit.`,
      },
      { status: 413 },
    );
  }

  const unsupported = files
    .map((file) => file.name)
    .filter((name) => !isSupportedDbprImportFileName(name));
  if (unsupported.length > 0) {
    return Response.json(
      {
        ok: false,
        error: `Unsupported file names: ${unsupported.join(", ")}. Use Condo_*.csv or paymenthist_*.csv.`,
      },
      { status: 400 },
    );
  }

  const importFiles: DbprManualImportFile[] = await Promise.all(
    files.map(async (file) => ({
      fileName: file.name,
      body: await file.text(),
    })),
  );

  const runPromise = startIngestionJob(() =>
    runDbprManualImport(importFiles, {
      jobName: "ingest_dbpr_manual_upload",
    }),
  );

  if (!runPromise) {
    return Response.json({ ok: false, error: "An ingestion run is already in progress." }, { status: 409 });
  }

  runPromise.catch((error) => {
    console.error("Background manual import failed:", getErrorMessage(error, "Unknown error"));
  });

  const runAsync = String(formData.get("async") || "true").toLowerCase() !== "false";

  if (runAsync) {
    await writeAuditEvent(
      {
        eventType: "admin_import_start",
        actorType: "admin",
        status: "started",
        metadata: {
          mode: "background",
          fileCount: files.length,
          totalBytes,
          fileNames: files.map((file) => file.name),
        },
      },
      request,
    );
    return Response.json(
      {
        ok: true,
        mode: "background",
        message: "Manual DBPR import started in background.",
        fileCount: files.length,
      },
      { status: 202 },
    );
  }

  try {
    const result = await runPromise;
    await writeAuditEvent(
      {
        eventType: "admin_import_start",
        actorType: "admin",
        status: "success",
        metadata: {
          mode: "sync",
          fileCount: files.length,
          rowsProcessed: result.totalProcessed,
          filesProcessed: result.filesProcessed,
          filesSkipped: result.filesSkipped,
        },
      },
      request,
    );
    return Response.json({ ok: true, mode: "sync", result });
  } catch (error) {
    await writeAuditEvent(
      {
        eventType: "admin_import_start",
        actorType: "admin",
        status: "failure",
        metadata: {
          mode: "sync",
          fileCount: files.length,
          error: getErrorMessage(error, "Manual import failed"),
        },
      },
      request,
    );
    return Response.json(
      {
        ok: false,
        error: getErrorMessage(error, "Manual import failed"),
      },
      { status: 500 },
    );
  }
}
