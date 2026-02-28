export type SourceStatus =
  | "Live Pull"
  | "Manual Export"
  | "Needs Agreement"
  | "Partner Feed"
  | "Planned";

export interface FloridaSource {
  id: string;
  name: string;
  category: "State" | "County" | "Partner";
  cadence: string;
  ingestion: string;
  status: SourceStatus;
  owner: string;
  coverage: string;
  url: string;
}

export interface Milestone {
  id: string;
  dayRange: string;
  goal: string;
  deliverables: string[];
  acceptance: string;
}

export interface PipelineJob {
  id: string;
  schedule: string;
  source: string;
  jobName: string;
  output: string;
  status: "Ready" | "In Build" | "Blocked";
}

export const floridaSources: FloridaSource[] = [
  {
    id: "dbpr-condo-extracts",
    name: "DBPR Condo Extracts (Condo_* CSV)",
    category: "State",
    cadence: "Daily check, nightly import",
    ingestion: "Direct CSV pull + checksum",
    status: "Live Pull",
    owner: "Data Engineering",
    coverage: "Association master index, unit counts, manager fields",
    url: "https://www2.myfloridalicense.com/condos-timeshares-mobile-homes/public-records/",
  },
  {
    id: "dbpr-payment-history",
    name: "DBPR Payment History (8002*)",
    category: "State",
    cadence: "Daily check, nightly import",
    ingestion: "Direct CSV pull + join on project number/name",
    status: "Live Pull",
    owner: "Data Engineering",
    coverage: "Fee/payment trend and potential compliance risk signals",
    url: "https://www2.myfloridalicense.com/sto/file_download/extracts/paymenthist_8002D.csv",
  },
  {
    id: "dbpr-sirs",
    name: "DBPR SIRS Reporting Dashboards",
    category: "State",
    cadence: "Daily",
    ingestion: "Qlik export job or public-record feed",
    status: "Manual Export",
    owner: "Regulatory Ops",
    coverage: "Structural reserve reporting status",
    url: "https://www2.myfloridalicense.com/condos-timeshares-mobile-homes/condominiums-and-cooperatives-sirs-reporting/",
  },
  {
    id: "sunbiz-quarterly",
    name: "Sunbiz Corporate Data",
    category: "State",
    cadence: "Quarterly",
    ingestion: "Bulk file ingest with legal name/entity normalization",
    status: "Needs Agreement",
    owner: "Data Engineering",
    coverage: "Officer/entity lifecycle and legal identity matching",
    url: "https://dos.fl.gov/sunbiz/other-services/data-downloads/quarterly-data/",
  },
  {
    id: "fl-dor-rolls",
    name: "Florida DOR Assessment Rolls + GIS",
    category: "State",
    cadence: "July/October/final certification + annual GIS",
    ingestion: "Tax roll file ingest + parcel join",
    status: "Needs Agreement",
    owner: "Data Engineering",
    coverage: "Address normalization and parcel-level enrichment",
    url: "https://www.floridarevenue.com/property/Pages/DataPortal_RequestAssessmentRollGISData.aspx",
  },
  {
    id: "miami-dade-car",
    name: "Miami-Dade CAR",
    category: "County",
    cadence: "Weekly",
    ingestion: "Manual QA sample imports while API access is evaluated",
    status: "Manual Export",
    owner: "Regulatory Ops",
    coverage: "County-level uploaded condo documents",
    url: "https://www.miamidade.gov/global/economy/consumer-protection/condominium-apartment-registry.page",
  },
  {
    id: "association-uploads",
    name: "Association Direct Uploads",
    category: "Partner",
    cadence: "Continuous",
    ingestion: "Portal upload + metadata/OCR extraction",
    status: "Partner Feed",
    owner: "Product + Partnerships",
    coverage: "Owner-protected records not available in public datasets",
    url: "https://www.flsenate.gov/Laws/Statutes/2025/718.111",
  },
];

export const thirtyDayMilestones: Milestone[] = [
  {
    id: "m1",
    dayRange: "Days 1-5",
    goal: "Ship ingestion foundation",
    deliverables: [
      "Provision Postgres + object storage + secrets",
      "Land staging/raw schemas and source snapshot tables",
      "Nightly DBPR pulls for condo and payment extracts",
    ],
    acceptance: "Raw file snapshots and parsed tables available with lineage fields.",
  },
  {
    id: "m2",
    dayRange: "Days 6-10",
    goal: "Entity resolution and data quality",
    deliverables: [
      "Create association resolver (project number + fuzzy fallback)",
      "Add quality rules for invalid addresses and duplicate slugs",
      "Review queue for low-confidence joins",
    ],
    acceptance: "At least 95% of DBPR rows mapped to stable association IDs.",
  },
  {
    id: "m3",
    dayRange: "Days 11-15",
    goal: "Compliance computation and dashboard v1",
    deliverables: [
      "Add rules table for Florida 25+ unit thresholds",
      "Compute per-association status (Compliant/At Risk/Overdue)",
      "Release operations dashboard with source freshness indicators",
    ],
    acceptance: "Dashboard reflects status changes within 24h of ingest.",
  },
  {
    id: "m4",
    dayRange: "Days 16-20",
    goal: "SIRS + county enrichment",
    deliverables: [
      "Integrate SIRS reported status feed",
      "Load Miami-Dade CAR sample set for pilot",
      "Expose filters by county, manager, and source freshness",
    ],
    acceptance: "Users can compare SIRS status with filing completeness by county.",
  },
  {
    id: "m5",
    dayRange: "Days 21-25",
    goal: "Protected docs intake",
    deliverables: [
      "Ship manager/association upload workflow",
      "Parse uploaded PDFs and map to filing categories",
      "Add audit trail events for every upload and edit",
    ],
    acceptance: "Uploaded records appear in association timelines with provenance.",
  },
  {
    id: "m6",
    dayRange: "Days 26-30",
    goal: "Pilot launch",
    deliverables: [
      "Role-based access (public, manager, regulator)",
      "Pilot onboarding for 3 to 5 associations",
      "Runbook, SLA alerts, and incident playbook",
    ],
    acceptance: "Pilot users can log in, upload, and export dashboards without manual DB edits.",
  },
];

export const pipelineJobs: PipelineJob[] = [
  {
    id: "j1",
    schedule: "01:30 ET daily",
    source: "DBPR Condo Extracts",
    jobName: "ingest_dbpr_condos",
    output: "raw_dbpr_files, stg_dbpr_condos, dim_association_candidates",
    status: "Ready",
  },
  {
    id: "j2",
    schedule: "02:00 ET daily",
    source: "DBPR Payment History",
    jobName: "ingest_dbpr_payment_history",
    output: "stg_dbpr_payments, fact_payment_history",
    status: "Ready",
  },
  {
    id: "j3",
    schedule: "04:00 ET daily",
    source: "SIRS Dashboards",
    jobName: "ingest_sirs_reporting",
    output: "stg_sirs_submissions, fact_sirs_status",
    status: "In Build",
  },
  {
    id: "j4",
    schedule: "Saturdays 03:00 ET",
    source: "Miami-Dade CAR",
    jobName: "ingest_county_documents",
    output: "stg_county_docs, fact_county_documents",
    status: "In Build",
  },
  {
    id: "j5",
    schedule: "Quarterly",
    source: "Sunbiz",
    jobName: "ingest_sunbiz_entities",
    output: "dim_corporate_entity, bridge_association_entity",
    status: "Blocked",
  },
];
