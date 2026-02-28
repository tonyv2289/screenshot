import { randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";
import { isAuthorizedApiRequest } from "@/lib/auth";
import { writeAuditEvent } from "@/lib/audit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const uploadDirectory = path.join(process.cwd(), "public", "uploads", "filings");
const allowedExtensions = new Set([".pdf", ".csv", ".txt", ".xlsx", ".xls"]);

function sanitizeExtension(fileName: string): string {
  const ext = path.extname(fileName || "").toLowerCase();
  if (allowedExtensions.has(ext)) return ext;
  return "";
}

export async function POST(request: Request) {
  if (!isAuthorizedApiRequest(request)) {
    await writeAuditEvent(
      { eventType: "upload_filing_document", actorType: "admin", status: "unauthorized" },
      request,
    );
    return Response.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "invalid_form_data" },
      },
      request,
    );
    return Response.json({ ok: false, error: "Invalid multipart form data." }, { status: 400 });
  }

  const candidate = formData.get("file");
  if (!(candidate instanceof File)) {
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "missing_file" },
      },
      request,
    );
    return Response.json({ ok: false, error: "No file provided." }, { status: 400 });
  }

  if (candidate.size <= 0) {
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "empty_file", size: candidate.size },
      },
      request,
    );
    return Response.json({ ok: false, error: "File is empty." }, { status: 400 });
  }

  if (candidate.size > MAX_UPLOAD_BYTES) {
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "file_too_large", size: candidate.size },
      },
      request,
    );
    return Response.json(
      { ok: false, error: "File exceeds 10MB max size." },
      { status: 413 },
    );
  }

  const ext = sanitizeExtension(candidate.name);
  if (!ext) {
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "invalid_extension", fileName: candidate.name },
      },
      request,
    );
    return Response.json(
      { ok: false, error: "Unsupported file type. Use PDF, CSV, TXT, XLS, or XLSX." },
      { status: 400 },
    );
  }

  try {
    await fs.mkdir(uploadDirectory, { recursive: true });
    const fileName = `${Date.now()}-${randomUUID()}${ext}`;
    const filePath = path.join(uploadDirectory, fileName);
    const bytes = Buffer.from(await candidate.arrayBuffer());
    await fs.writeFile(filePath, bytes);

    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "success",
        metadata: { fileName, size: candidate.size },
      },
      request,
    );

    return Response.json({
      ok: true,
      fileName,
      url: `/uploads/filings/${fileName}`,
      size: candidate.size,
    });
  } catch (error) {
    console.error("Upload failed:", error);
    await writeAuditEvent(
      {
        eventType: "upload_filing_document",
        actorType: "admin",
        status: "failure",
        metadata: { reason: "write_failed", error: error instanceof Error ? error.message : "unknown" },
      },
      request,
    );
    return Response.json({ ok: false, error: "Failed to persist uploaded file." }, { status: 500 });
  }
}
