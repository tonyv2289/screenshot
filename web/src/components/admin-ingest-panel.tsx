"use client";

import { useState } from "react";

type IngestRun = {
  id: string;
  job_name: string;
  status: string;
  started_at: string;
  finished_at: string | null;
  rows_processed: number;
};

type StatusResponse = {
  ok: boolean;
  inProgress: boolean;
  usingDatabase: boolean;
  runs: IngestRun[];
  error?: string;
};

export function AdminIngestPanel({ adminKeyRequired }: { adminKeyRequired: boolean }) {
  const [limit, setLimit] = useState("1000");
  const [adminKey, setAdminKey] = useState("");
  const [importFiles, setImportFiles] = useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [status, setStatus] = useState<StatusResponse | null>(null);

  const authHeaders: HeadersInit = adminKey.trim() ? { "x-admin-api-key": adminKey.trim() } : {};

  async function triggerIngest(full: boolean) {
    setIsSubmitting(true);
    setMessage("");

    try {
      const parsedLimit = Number(limit);
      const response = await fetch("/api/admin/ingest", {
        method: "POST",
        headers: {
          ...authHeaders,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          full,
          async: full,
          limit: Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : 1000,
        }),
      });

      const body = (await response.json()) as {
        ok: boolean;
        error?: string;
        message?: string;
        mode?: "sync" | "background";
        result?: { runId: string; totalProcessed: number; filesProcessed: number };
      };

      if (!response.ok || !body.ok) {
        setMessage(body.error || "Unable to start ingestion.");
      } else if (body.mode === "sync" && body.result) {
        setMessage(
          `Ingestion complete. Run ${body.result.runId}, ${body.result.totalProcessed.toLocaleString()} rows processed.`,
        );
      } else {
        setMessage(body.message || "Ingestion started.");
      }
    } catch {
      setMessage("Request failed while starting ingestion.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function refreshStatus() {
    try {
      const response = await fetch("/api/admin/ingest", {
        method: "GET",
        headers: authHeaders,
        cache: "no-store",
      });

      const body = (await response.json()) as StatusResponse;
      setStatus(body);

      if (!response.ok || !body.ok) {
        setMessage(body.error || "Unable to fetch status.");
      }
    } catch {
      setMessage("Request failed while checking status.");
    }
  }

  async function importCsvFiles() {
    if (importFiles.length === 0) {
      setMessage("Select one or more DBPR CSV files first.");
      return;
    }

    setIsSubmitting(true);
    setMessage("");

    try {
      const formData = new FormData();
      for (const file of importFiles) {
        formData.append("files", file);
      }
      formData.set("async", "true");

      const response = await fetch("/api/admin/import", {
        method: "POST",
        headers: authHeaders,
        body: formData,
      });

      const body = (await response.json()) as {
        ok: boolean;
        error?: string;
        message?: string;
        result?: { runId: string; totalProcessed: number; filesProcessed: number };
      };

      if (!response.ok || !body.ok) {
        setMessage(body.error || "Unable to start manual import.");
      } else if (body.result) {
        setMessage(
          `Import complete. Run ${body.result.runId}, ${body.result.totalProcessed.toLocaleString()} rows processed.`,
        );
      } else {
        setMessage(body.message || "Manual import started.");
      }
    } catch {
      setMessage("Request failed while starting manual import.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="form-panel reveal delay-1">
      <div className="panel-head">
        <h2>Admin Ingestion</h2>
        <button type="button" onClick={refreshStatus} disabled={isSubmitting}>
          Refresh Status
        </button>
      </div>

      {adminKeyRequired ? (
        <>
          <label>
            Admin API key
            <input
              type="password"
              value={adminKey}
              onChange={(event) => setAdminKey(event.target.value)}
              placeholder="Enter x-admin-api-key"
            />
          </label>
          <p className="form-feedback">
            If you already signed in at `/admin/login`, this field can stay blank.
          </p>
        </>
      ) : null}

      <div className="field-grid">
        <label>
          Row cap per file (quick sync)
          <input
            type="number"
            min={1}
            value={limit}
            onChange={(event) => setLimit(event.target.value)}
          />
        </label>
      </div>

      <div className="chips-row">
        <button type="button" onClick={() => triggerIngest(false)} disabled={isSubmitting}>
          Start Quick Sync
        </button>
        <button type="button" onClick={() => triggerIngest(true)} disabled={isSubmitting}>
          Start Full Sync
        </button>
      </div>

      <div className="field-grid">
        <label>
          Manual CSV import (DBPR extracts)
          <input
            type="file"
            accept=".csv,text/csv"
            multiple
            onChange={(event) => setImportFiles(Array.from(event.target.files || []))}
          />
        </label>
      </div>
      <p className="form-feedback">
        Supported file names: <code>Condo_*.csv</code> and <code>paymenthist_*.csv</code>.
      </p>
      <div className="chips-row">
        <button type="button" onClick={importCsvFiles} disabled={isSubmitting || importFiles.length === 0}>
          Import Uploaded CSVs
        </button>
      </div>

      {message ? <p>{message}</p> : null}

      {status ? (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>In Progress</th>
                <th>Latest Job</th>
                <th>Latest Status</th>
                <th>Rows</th>
              </tr>
            </thead>
            <tbody>
              {status.runs.length > 0 ? (
                <tr>
                  <td>{status.inProgress ? "Yes" : "No"}</td>
                  <td>{status.runs[0].job_name}</td>
                  <td>{status.runs[0].status}</td>
                  <td>{status.runs[0].rows_processed.toLocaleString()}</td>
                </tr>
              ) : (
                <tr>
                  <td>{status.inProgress ? "Yes" : "No"}</td>
                  <td colSpan={3}>No ingestion runs recorded yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      ) : null}
    </section>
  );
}
