import { getDbPool, isDatabaseConfigured } from "@/lib/db";
import { floridaSources, pipelineJobs } from "@/lib/florida-program";
import { condoAssociations, filings } from "@/lib/mock-data";
import zipcodes from "zipcodes";
import type { ComplianceStatus, CondoAssociation, Filing } from "@/lib/types";

type ZipLookupResult = { latitude: number; longitude: number } | null;
const zipLookup = zipcodes as unknown as { lookup: (zip: string) => ZipLookupResult };

export type DashboardAssociation = CondoAssociation;

export interface DashboardData {
  associations: DashboardAssociation[];
  filings: Filing[];
  usingDatabase: boolean;
}

export interface CondoDetailData {
  association: DashboardAssociation;
  filings: Filing[];
  usingDatabase: boolean;
}

export interface OperationsData {
  sources: Array<{
    id: string;
    name: string;
    category: "State" | "County" | "Partner";
    cadence: string;
    ingestion: string;
    status: string;
    owner: string;
    coverage: string;
    url: string;
    lastFetchedAt: string | null;
    lastSnapshotStatus: string | null;
  }>;
  jobs: Array<{
    id: string;
    schedule: string;
    source: string;
    jobName: string;
    output: string;
    status: "Ready" | "In Build" | "Blocked";
  }>;
  recentRuns: Array<{
    id: string;
    jobName: string;
    status: string;
    startedAt: string;
    finishedAt: string | null;
    rowsProcessed: number;
  }>;
  recentAudit: Array<{
    id: number;
    eventType: string;
    actorType: string;
    status: string;
    createdAt: string;
    actorLabel: string | null;
  }>;
  usingDatabase: boolean;
}

function asIsoDate(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function addDays(date: Date, days: number): Date {
  const value = new Date(date);
  value.setDate(value.getDate() + days);
  return value;
}

function deriveComplianceStatus(
  secondaryStatus: string | null,
  lastPublishedAt: Date | null,
): ComplianceStatus {
  const secondary = (secondaryStatus || "").toLowerCase();

  if (secondary.includes("delinquent") || secondary.includes("overdue")) {
    return "Overdue";
  }

  if (!lastPublishedAt) {
    return "At Risk";
  }

  const ageDays = Math.floor((Date.now() - lastPublishedAt.getTime()) / 86400000);
  if (ageDays > 365) {
    return "At Risk";
  }

  return "Compliant";
}

function normalizeZip(zip: string | null): string | null {
  if (!zip) return null;
  const match = zip.trim().match(/^(\d{5})/);
  return match ? match[1] : null;
}

function resolveCoordinates(zip: string | null): { latitude: number | null; longitude: number | null } {
  const normalizedZip = normalizeZip(zip);
  if (!normalizedZip) {
    return { latitude: null, longitude: null };
  }

  const lookup = zipLookup.lookup(normalizedZip);
  if (!lookup) {
    return { latitude: null, longitude: null };
  }

  return {
    latitude: lookup.latitude,
    longitude: lookup.longitude,
  };
}

function buildManagerEmail(entityName: string | null, fallback: string): string {
  const stem = (entityName || fallback)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
  return `${stem || "manager"}@association.local`;
}

function fallbackDashboardData(): DashboardData {
  const associations = condoAssociations.filter((item) => item.unitCount > 25);
  return {
    associations,
    filings,
    usingDatabase: false,
  };
}

export async function getDashboardData(): Promise<DashboardData> {
  if (!isDatabaseConfigured()) {
    return fallbackDashboardData();
  }

  const pool = getDbPool();
  if (!pool) {
    return fallbackDashboardData();
  }

  try {
    const associationRows = await pool.query<{
      id: string;
      slug: string;
      legal_name: string;
      county: string | null;
      city: string | null;
      state: string | null;
      zip: string | null;
      unit_count: number;
      managing_entity_name: string | null;
      secondary_status: string | null;
      last_published_at: string | null;
    }>(
      `
        SELECT
          a.id,
          a.slug,
          a.legal_name,
          a.county,
          a.city,
          a.state,
          a.zip,
          a.unit_count,
          a.managing_entity_name,
          a.secondary_status,
          MAX(f.published_at)::text AS last_published_at
        FROM associations a
        LEFT JOIN filings f ON f.association_id = a.id
        WHERE a.unit_count > 25
        GROUP BY
          a.id,
          a.slug,
          a.legal_name,
          a.county,
          a.city,
          a.state,
          a.zip,
          a.unit_count,
          a.managing_entity_name,
          a.secondary_status
        ORDER BY a.legal_name
        LIMIT 300
      `,
    );

    if (associationRows.rowCount === 0) {
      return fallbackDashboardData();
    }

    const filingRows = await pool.query<{
      id: string;
      condo_id: string;
      filing_type: string;
      period_label: string;
      published_at: string | null;
      source_label: string;
      source_url: string | null;
    }>(
      `
        SELECT
          f.id,
          a.slug AS condo_id,
          f.filing_type,
          f.period_label,
          f.published_at::text,
          f.source_label,
          f.source_url
        FROM filings f
        JOIN associations a ON a.id = f.association_id
        ORDER BY f.published_at DESC NULLS LAST, f.created_at DESC
        LIMIT 25
      `,
    );

    const associations: DashboardAssociation[] = associationRows.rows.map((row) => {
      const lastPublishedDate = row.last_published_at ? new Date(row.last_published_at) : null;
      const complianceStatus = deriveComplianceStatus(row.secondary_status, lastPublishedDate);
      const normalizedZip = normalizeZip(row.zip);
      const coordinates = resolveCoordinates(normalizedZip);

      const nextDeadline =
        complianceStatus === "Overdue"
          ? asIsoDate(addDays(new Date(), 14))
          : lastPublishedDate
            ? asIsoDate(addDays(lastPublishedDate, 365))
            : asIsoDate(new Date(new Date().getFullYear(), 11, 31));

      return {
        id: row.slug,
        legalName: row.legal_name,
        county: row.county || "Unknown",
        city: row.city || "Unknown",
        state: row.state || "FL",
        zip: normalizedZip,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        unitCount: row.unit_count,
        managerEmail: buildManagerEmail(row.managing_entity_name, row.slug),
        complianceStatus,
        nextDeadline,
        lastPublishedAt: lastPublishedDate ? asIsoDate(lastPublishedDate) : asIsoDate(new Date()),
      };
    });

    const mappedFilings: Filing[] = filingRows.rows.map((row) => ({
      id: row.id,
      condoId: row.condo_id,
      type: row.filing_type as Filing["type"],
      periodLabel: row.period_label,
      publishedAt: row.published_at || asIsoDate(new Date()),
      sourceLabel: row.source_label,
      sourceUrl: row.source_url || "#",
    }));

    return {
      associations,
      filings: mappedFilings,
      usingDatabase: true,
    };
  } catch (error) {
    console.error("Dashboard DB query failed, using fallback data.", error);
    return fallbackDashboardData();
  }
}

export async function getCondoBySlug(slug: string): Promise<CondoDetailData | null> {
  if (!isDatabaseConfigured()) {
    const association = condoAssociations.find((item) => item.id === slug);
    if (!association) return null;

    return {
      association,
      filings: filings.filter((item) => item.condoId === slug),
      usingDatabase: false,
    };
  }

  const pool = getDbPool();
  if (!pool) return null;

  try {
    const associationResult = await pool.query<{
      id: string;
      slug: string;
      legal_name: string;
      county: string | null;
      city: string | null;
      state: string | null;
      zip: string | null;
      unit_count: number;
      managing_entity_name: string | null;
      secondary_status: string | null;
      last_published_at: string | null;
    }>(
      `
        SELECT
          a.id,
          a.slug,
          a.legal_name,
          a.county,
          a.city,
          a.state,
          a.zip,
          a.unit_count,
          a.managing_entity_name,
          a.secondary_status,
          MAX(f.published_at)::text AS last_published_at
        FROM associations a
        LEFT JOIN filings f ON f.association_id = a.id
        WHERE a.slug = $1
        GROUP BY
          a.id,
          a.slug,
          a.legal_name,
          a.county,
          a.city,
          a.state,
          a.zip,
          a.unit_count,
          a.managing_entity_name,
          a.secondary_status
      `,
      [slug],
    );

    if (associationResult.rowCount === 0) {
      return null;
    }

    const row = associationResult.rows[0];
    const lastPublishedDate = row.last_published_at ? new Date(row.last_published_at) : null;
    const complianceStatus = deriveComplianceStatus(row.secondary_status, lastPublishedDate);
    const normalizedZip = normalizeZip(row.zip);
    const coordinates = resolveCoordinates(normalizedZip);

    const filingsResult = await pool.query<{
      id: string;
      filing_type: string;
      period_label: string;
      published_at: string | null;
      source_label: string;
      source_url: string | null;
    }>(
      `
        SELECT
          id,
          filing_type,
          period_label,
          published_at::text,
          source_label,
          source_url
        FROM filings
        WHERE association_id = $1
        ORDER BY published_at DESC NULLS LAST, created_at DESC
      `,
      [row.id],
    );

    return {
      association: {
        id: row.slug,
        legalName: row.legal_name,
        county: row.county || "Unknown",
        city: row.city || "Unknown",
        state: row.state || "FL",
        zip: normalizedZip,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        unitCount: row.unit_count,
        managerEmail: buildManagerEmail(row.managing_entity_name, row.slug),
        complianceStatus,
        nextDeadline: lastPublishedDate
          ? asIsoDate(addDays(lastPublishedDate, 365))
          : asIsoDate(new Date(new Date().getFullYear(), 11, 31)),
        lastPublishedAt: lastPublishedDate ? asIsoDate(lastPublishedDate) : asIsoDate(new Date()),
      },
      filings: filingsResult.rows.map((filing) => ({
        id: filing.id,
        condoId: row.slug,
        type: filing.filing_type as Filing["type"],
        periodLabel: filing.period_label,
        publishedAt: filing.published_at || asIsoDate(new Date()),
        sourceLabel: filing.source_label,
        sourceUrl: filing.source_url || "#",
      })),
      usingDatabase: true,
    };
  } catch (error) {
    console.error("Condo DB query failed, using fallback data.", error);
    const association = condoAssociations.find((item) => item.id === slug);
    if (!association) return null;

    return {
      association,
      filings: filings.filter((item) => item.condoId === slug),
      usingDatabase: false,
    };
  }
}

export async function getOperationsData(): Promise<OperationsData> {
  if (!isDatabaseConfigured()) {
    return {
      sources: floridaSources.map((source) => ({
        ...source,
        lastFetchedAt: null,
        lastSnapshotStatus: null,
      })),
      jobs: pipelineJobs,
      recentRuns: [],
      recentAudit: [],
      usingDatabase: false,
    };
  }

  const pool = getDbPool();
  if (!pool) {
    return {
      sources: floridaSources.map((source) => ({
        ...source,
        lastFetchedAt: null,
        lastSnapshotStatus: null,
      })),
      jobs: pipelineJobs,
      recentRuns: [],
      recentAudit: [],
      usingDatabase: false,
    };
  }

  try {
    const snapshots = await pool.query<{
      source_name: string;
      fetched_at: string;
      status: string;
    }>(
      `
        SELECT DISTINCT ON (source_name)
          source_name,
          fetched_at::text,
          status
        FROM source_snapshots
        ORDER BY source_name, fetched_at DESC
      `,
    );

    const recentRuns = await pool.query<{
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

    let recentAudit: OperationsData["recentAudit"] = [];
    try {
      const auditResult = await pool.query<{
        id: string;
        event_type: string;
        actor_type: string;
        status: string;
        created_at: string;
        actor_label: string | null;
      }>(
        `
          SELECT
            id,
            event_type,
            actor_type,
            status,
            created_at::text,
            actor_label
          FROM audit_logs
          ORDER BY created_at DESC
          LIMIT 20
        `,
      );

      recentAudit = auditResult.rows.map((row) => ({
        id: Number(row.id),
        eventType: row.event_type,
        actorType: row.actor_type,
        status: row.status,
        createdAt: row.created_at,
        actorLabel: row.actor_label,
      }));
    } catch (error) {
      const maybeCode =
        typeof error === "object" && error && "code" in error
          ? String((error as { code?: string }).code)
          : "";
      if (maybeCode !== "42P01") {
        console.error("Audit log query failed.", error);
      }
    }

    const sourceLookup = new Map(
      snapshots.rows.map((row) => [row.source_name.toLowerCase(), row]),
    );

    const sources = floridaSources.map((source) => {
      const lookupKeys = [source.name.toLowerCase()];
      if (source.name.toLowerCase().includes("dbpr condo extracts")) {
        lookupKeys.push("dbpr condo extracts");
      }
      if (source.name.toLowerCase().includes("dbpr payment history")) {
        lookupKeys.push("dbpr payment history");
      }

      const snapshot = lookupKeys
        .map((key) => sourceLookup.get(key))
        .find((value) => Boolean(value));

      return {
        ...source,
        lastFetchedAt: snapshot?.fetched_at || null,
        lastSnapshotStatus: snapshot?.status || null,
      };
    });

    return {
      sources,
      jobs: pipelineJobs,
      recentRuns: recentRuns.rows.map((run) => ({
        id: run.id,
        jobName: run.job_name,
        status: run.status,
        startedAt: run.started_at,
        finishedAt: run.finished_at,
        rowsProcessed: run.rows_processed,
      })),
      recentAudit,
      usingDatabase: true,
    };
  } catch (error) {
    console.error("Operations DB query failed, using fallback data.", error);
    return {
      sources: floridaSources.map((source) => ({
        ...source,
        lastFetchedAt: null,
        lastSnapshotStatus: null,
      })),
      jobs: pipelineJobs,
      recentRuns: [],
      recentAudit: [],
      usingDatabase: false,
    };
  }
}
