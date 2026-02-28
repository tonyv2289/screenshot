import { createHash } from "node:crypto";
import { parse } from "csv-parse/sync";
import { Client } from "pg";

type DbprCondoRow = {
  "Project Number": string;
  "File Number": string;
  "Condo Name": string;
  County: string;
  "Street City State Zip": string;
  Units: string;
  "Primary Status": string;
  "Secondary Status": string;
  "Managing Entity Number": string;
  "Managing Entity Name": string;
  "Managing Entity Route": string;
  "Managing Entity Street": string;
  "Managing Entity City": string;
  "Managing Entity State": string;
  "Managing Entity Zip": string;
};

type PaymentHistoryRow = {
  "Project Number": string;
  "Project Name": string;
  "Project City": string;
  "Project State": string;
  "Billing Year": string;
  "Amount Billed": string;
  "Amount Paid": string;
  "Pending Amount Due": string;
};

export type RunDbprIngestionOptions = {
  limit?: number | null;
  jobName?: string;
};

export type RunDbprIngestionResult = {
  runId: string;
  totalProcessed: number;
  filesProcessed: number;
  limit: number | null;
};

const condoFiles = [
  "Condo_NF.csv",
  "condo_CE.csv",
  "Condo_CW.csv",
  "Condo_MD.csv",
  "condo_PB.csv",
];

const paymentFiles = [
  "paymenthist_8002A.csv",
  "paymenthist_8002D.csv",
  "paymenthist_8002J.csv",
  "paymenthist_8002P.csv",
  "paymenthist_8002S.csv",
  "paymenthist_8002V.csv",
];

function asSlug(raw: string): string {
  return raw
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function parseMoney(value: string): number | null {
  const cleaned = value.replace(/[$,\s]/g, "").trim();
  if (!cleaned) return null;
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseIntSafe(value: string): number | null {
  const cleaned = value.replace(/[,\s]/g, "").trim();
  if (!cleaned) return null;
  const parsed = Number.parseInt(cleaned, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseAddressBlock(raw: string): { city: string | null; state: string | null; zip: string | null } {
  const parts = raw
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);

  if (parts.length < 2) {
    return { city: null, state: null, zip: null };
  }

  const city = parts[parts.length - 2] || null;
  const stateZip = (parts[parts.length - 1] || "").trim();
  const [state, ...zipParts] = stateZip.split(/\s+/);
  const zip = zipParts.join(" ") || null;

  return {
    city,
    state: state ? state.slice(0, 2).toUpperCase() : null,
    zip,
  };
}

async function insertSnapshot(
  client: Client,
  sourceName: string,
  sourceUrl: string,
  fileName: string,
  body: string,
  rowCount: number,
  status: string,
) {
  const checksum = createHash("sha256").update(body).digest("hex");

  await client.query(
    `
      INSERT INTO source_snapshots (
        source_name,
        source_url,
        file_name,
        checksum_sha256,
        row_count,
        status,
        fetched_at
      ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
    `,
    [sourceName, sourceUrl, fileName, checksum, rowCount, status],
  );
}

async function ingestCondoFile(client: Client, fileName: string, limit: number | null) {
  const sourceUrl = `https://www2.myfloridalicense.com/sto/file_download/extracts/${fileName}`;
  const response = await fetch(sourceUrl);

  if (!response.ok) {
    throw new Error(`Failed to fetch ${fileName}: HTTP ${response.status}`);
  }

  const text = await response.text();
  const parsed = parse(text, {
    columns: true,
    skip_empty_lines: true,
    relax_column_count: true,
    trim: true,
  }) as DbprCondoRow[];

  const rows = limit ? parsed.slice(0, limit) : parsed;

  let processed = 0;

  for (const row of rows) {
    const projectNumber = row["Project Number"]?.trim();
    const legalName = row["Condo Name"]?.trim();
    const units = parseIntSafe(row.Units || "");

    if (!projectNumber || !legalName || !units || units <= 0) {
      continue;
    }

    const slugBase = asSlug(legalName);
    const slug = `${slugBase || "association"}-${projectNumber.toLowerCase()}`;
    const address = parseAddressBlock(row["Street City State Zip"] || "");

    await client.query(
      `
        INSERT INTO associations (
          external_project_number,
          slug,
          file_number,
          legal_name,
          county,
          street_city_state_zip,
          city,
          state,
          zip,
          unit_count,
          primary_status,
          secondary_status,
          managing_entity_number,
          managing_entity_name,
          managing_entity_route,
          managing_entity_street,
          managing_entity_city,
          managing_entity_state,
          managing_entity_zip,
          source_file,
          last_seen_at,
          updated_at
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
          $11, $12, $13, $14, $15, $16, $17, $18, $19,
          $20, NOW(), NOW()
        )
        ON CONFLICT (external_project_number) DO UPDATE SET
          slug = EXCLUDED.slug,
          file_number = EXCLUDED.file_number,
          legal_name = EXCLUDED.legal_name,
          county = EXCLUDED.county,
          street_city_state_zip = EXCLUDED.street_city_state_zip,
          city = EXCLUDED.city,
          state = EXCLUDED.state,
          zip = EXCLUDED.zip,
          unit_count = EXCLUDED.unit_count,
          primary_status = EXCLUDED.primary_status,
          secondary_status = EXCLUDED.secondary_status,
          managing_entity_number = EXCLUDED.managing_entity_number,
          managing_entity_name = EXCLUDED.managing_entity_name,
          managing_entity_route = EXCLUDED.managing_entity_route,
          managing_entity_street = EXCLUDED.managing_entity_street,
          managing_entity_city = EXCLUDED.managing_entity_city,
          managing_entity_state = EXCLUDED.managing_entity_state,
          managing_entity_zip = EXCLUDED.managing_entity_zip,
          source_file = EXCLUDED.source_file,
          last_seen_at = NOW(),
          updated_at = NOW()
      `,
      [
        projectNumber,
        slug,
        row["File Number"] || null,
        legalName,
        row.County || null,
        row["Street City State Zip"] || null,
        address.city,
        address.state,
        address.zip,
        units,
        row["Primary Status"] || null,
        row["Secondary Status"] || null,
        row["Managing Entity Number"] || null,
        row["Managing Entity Name"] || null,
        row["Managing Entity Route"] || null,
        row["Managing Entity Street"] || null,
        row["Managing Entity City"] || null,
        row["Managing Entity State"] || null,
        row["Managing Entity Zip"] || null,
        fileName,
      ],
    );

    processed += 1;
  }

  await insertSnapshot(
    client,
    "DBPR Condo Extracts",
    sourceUrl,
    fileName,
    text,
    rows.length,
    "success",
  );

  return processed;
}

async function ingestPaymentFile(client: Client, fileName: string, limit: number | null) {
  const sourceUrl = `https://www2.myfloridalicense.com/sto/file_download/extracts/${fileName}`;
  const response = await fetch(sourceUrl);

  if (!response.ok) {
    throw new Error(`Failed to fetch ${fileName}: HTTP ${response.status}`);
  }

  const text = await response.text();
  const parsed = parse(text, {
    columns: true,
    skip_empty_lines: true,
    relax_column_count: true,
    trim: true,
  }) as PaymentHistoryRow[];

  const rows = limit ? parsed.slice(0, limit) : parsed;

  let processed = 0;

  for (const row of rows) {
    const projectNumber = row["Project Number"]?.trim();
    const billingYear = parseIntSafe(row["Billing Year"] || "");

    if (!projectNumber || !billingYear) {
      continue;
    }

    await client.query(
      `
        INSERT INTO payment_history (
          project_number,
          project_name,
          project_city,
          project_state,
          billing_year,
          amount_billed,
          amount_paid,
          pending_amount_due,
          source_file,
          ingested_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
        ON CONFLICT (project_number, billing_year, source_file) DO UPDATE SET
          project_name = EXCLUDED.project_name,
          project_city = EXCLUDED.project_city,
          project_state = EXCLUDED.project_state,
          amount_billed = EXCLUDED.amount_billed,
          amount_paid = EXCLUDED.amount_paid,
          pending_amount_due = EXCLUDED.pending_amount_due,
          ingested_at = NOW()
      `,
      [
        projectNumber,
        row["Project Name"] || null,
        row["Project City"] || null,
        row["Project State"] || null,
        billingYear,
        parseMoney(row["Amount Billed"] || ""),
        parseMoney(row["Amount Paid"] || ""),
        parseMoney(row["Pending Amount Due"] || ""),
        fileName,
      ],
    );

    processed += 1;
  }

  await insertSnapshot(
    client,
    "DBPR Payment History",
    sourceUrl,
    fileName,
    text,
    rows.length,
    "success",
  );

  return processed;
}

export async function runDbprIngestion(
  options: RunDbprIngestionOptions = {},
): Promise<RunDbprIngestionResult> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required for DBPR ingestion.");
  }

  const limitValue = options.limit ?? Number(process.env.INGEST_LIMIT_ROWS || 5000);
  const limit = limitValue === null ? null : Number.isFinite(limitValue) ? Math.max(1, limitValue) : 5000;
  const jobName = options.jobName || "ingest_dbpr_seed";

  const client = new Client({ connectionString: databaseUrl });
  await client.connect();

  const runInsert = await client.query(
    `INSERT INTO ingestion_runs (job_name, status, started_at) VALUES ($1, 'running', NOW()) RETURNING id`,
    [jobName],
  );
  const runId = runInsert.rows[0].id as string;

  let totalProcessed = 0;

  try {
    for (const fileName of condoFiles) {
      totalProcessed += await ingestCondoFile(client, fileName, limit);
    }

    for (const fileName of paymentFiles) {
      totalProcessed += await ingestPaymentFile(client, fileName, limit);
    }

    await client.query(
      `
        UPDATE ingestion_runs
        SET
          status = 'success',
          finished_at = NOW(),
          rows_processed = $2,
          rows_inserted = $2,
          details = jsonb_build_object('limit_per_file', $3::integer)
        WHERE id = $1
      `,
      [runId, totalProcessed, limit],
    );

    return {
      runId,
      totalProcessed,
      filesProcessed: condoFiles.length + paymentFiles.length,
      limit,
    };
  } catch (error) {
    await client.query(
      `
        UPDATE ingestion_runs
        SET
          status = 'failed',
          finished_at = NOW(),
          rows_processed = $2,
          details = jsonb_build_object('error', $3::text)
        WHERE id = $1
      `,
      [runId, totalProcessed, error instanceof Error ? error.message : "Unknown error"],
    );

    throw error;
  } finally {
    await client.end();
  }
}
