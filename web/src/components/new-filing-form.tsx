"use client";

import { useState } from "react";
import type { FilingType } from "@/lib/types";

const filingTypes: FilingType[] = [
  "Annual Budget",
  "Reserve Study",
  "Year-End Financial Statement",
  "Insurance Summary",
  "Board Meeting Minutes",
];

type FilingFormAssociation = {
  id: string;
  legalName: string;
  city: string;
  state: string;
  unitCount: number;
};

type NewFilingFormProps = {
  associations: FilingFormAssociation[];
  adminKeyRequired: boolean;
  databaseReady: boolean;
};

type ApiResponse = {
  ok: boolean;
  error?: string;
  filing?: {
    id: string;
    condoId: string;
    legalName: string;
  };
};

function todayDateString(): string {
  return new Date().toISOString().slice(0, 10);
}

export function NewFilingForm({ associations, adminKeyRequired, databaseReady }: NewFilingFormProps) {
  const [associationId, setAssociationId] = useState<string>(associations[0]?.id || "");
  const [type, setType] = useState<FilingType>("Annual Budget");
  const [periodLabel, setPeriodLabel] = useState("");
  const [publishedAt, setPublishedAt] = useState(todayDateString());
  const [sourceLabel, setSourceLabel] = useState("");
  const [sourceUrl, setSourceUrl] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [adminKey, setAdminKey] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState<ApiResponse["filing"] | null>(null);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setSuccess(null);
    setIsSubmitting(true);

    const headers: HeadersInit = {
      "Content-Type": "application/json",
    };

    if (adminKey.trim()) {
      headers["x-admin-api-key"] = adminKey.trim();
    }

    try {
      let resolvedSourceUrl = sourceUrl.trim();

      if (file) {
        const uploadBody = new FormData();
        uploadBody.append("file", file);

        const uploadResponse = await fetch("/api/uploads", {
          method: "POST",
          headers: adminKey.trim() ? { "x-admin-api-key": adminKey.trim() } : undefined,
          body: uploadBody,
        });

        const uploadPayload = (await uploadResponse.json()) as {
          ok: boolean;
          error?: string;
          url?: string;
        };

        if (!uploadResponse.ok || !uploadPayload.ok || !uploadPayload.url) {
          setError(uploadPayload.error || "File upload failed.");
          return;
        }

        resolvedSourceUrl = uploadPayload.url;
      }

      const response = await fetch("/api/filings", {
        method: "POST",
        headers,
        body: JSON.stringify({
          associationId,
          type,
          periodLabel,
          publishedAt,
          sourceLabel,
          sourceUrl: resolvedSourceUrl,
        }),
      });

      const body = (await response.json()) as ApiResponse;
      if (!response.ok || !body.ok) {
        setError(body.error || "Unable to create filing.");
        return;
      }

      setSuccess(body.filing || null);
      setPeriodLabel("");
      setSourceLabel("");
      setSourceUrl("");
      setFile(null);
    } catch {
      setError("Request failed while creating filing.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="form-panel reveal delay-1">
      {!databaseReady ? (
        <p>
          Postgres is not active for this environment. Configure DATABASE_URL and run ingestion,
          then filing writes will be enabled.
        </p>
      ) : associations.length === 0 ? (
        <p>No database associations available yet. Run ingestion first, then add filings.</p>
      ) : (
        <form onSubmit={onSubmit}>
          {adminKeyRequired ? (
            <label>
              Admin API key
              <input
                type="password"
                value={adminKey}
                onChange={(event) => setAdminKey(event.target.value)}
                placeholder="Enter x-admin-api-key"
              />
            </label>
          ) : null}

          <div className="field-grid">
            <label>
              Association
              <select
                name="associationId"
                value={associationId}
                onChange={(event) => setAssociationId(event.target.value)}
                required
              >
                {associations.map((association) => (
                  <option key={association.id} value={association.id}>
                    {association.legalName} ({association.city}, {association.state} ·{" "}
                    {association.unitCount} units)
                  </option>
                ))}
              </select>
            </label>

            <label>
              Filing type
              <select
                name="filingType"
                value={type}
                onChange={(event) => setType(event.target.value as FilingType)}
                required
              >
                {filingTypes.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </label>

            <label>
              Reporting period
              <input
                name="periodLabel"
                value={periodLabel}
                onChange={(event) => setPeriodLabel(event.target.value)}
                placeholder="FY 2026"
                required
              />
            </label>

            <label>
              Publish date
              <input
                type="date"
                name="publishedAt"
                value={publishedAt}
                onChange={(event) => setPublishedAt(event.target.value)}
              />
            </label>

            <label>
              Source label
              <input
                name="sourceLabel"
                value={sourceLabel}
                onChange={(event) => setSourceLabel(event.target.value)}
                placeholder="Association Portal"
                required
              />
            </label>

            <label>
              Source URL
              <input
                name="sourceUrl"
                value={sourceUrl}
                onChange={(event) => setSourceUrl(event.target.value)}
                placeholder="https://..."
              />
            </label>

            <label>
              Upload filing document (optional)
              <input
                type="file"
                accept=".pdf,.csv,.txt,.xls,.xlsx"
                onChange={(event) => setFile(event.target.files?.[0] || null)}
              />
            </label>
          </div>

          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? "Saving..." : "Create Filing"}
          </button>

          {adminKeyRequired ? (
            <p className="form-feedback">
              You can sign in at `/admin/login` and leave API key blank, or provide
              `x-admin-api-key` here.
            </p>
          ) : null}

          {error ? <p className="form-feedback form-feedback-error">{error}</p> : null}

          {success ? (
            <p className="form-feedback form-feedback-success">
              Filing created for {success.legalName}. View association at /condos/{success.condoId}
            </p>
          ) : null}
        </form>
      )}
    </section>
  );
}
