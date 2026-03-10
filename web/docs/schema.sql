-- Production-oriented schema for Florida Condo Ledger

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE associations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_project_number TEXT UNIQUE NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  file_number TEXT,
  legal_name TEXT NOT NULL,
  county TEXT,
  street_city_state_zip TEXT,
  street_address TEXT,
  city TEXT,
  state CHAR(2),
  zip TEXT,
  unit_count INTEGER NOT NULL CHECK (unit_count > 0),
  primary_status TEXT,
  secondary_status TEXT,
  managing_entity_number TEXT,
  managing_entity_name TEXT,
  managing_entity_route TEXT,
  managing_entity_street TEXT,
  managing_entity_city TEXT,
  managing_entity_state CHAR(2),
  managing_entity_zip TEXT,
  source_file TEXT NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE filings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
  filing_type TEXT NOT NULL,
  period_label TEXT NOT NULL,
  published_at DATE,
  source_label TEXT NOT NULL,
  source_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_history (
  id BIGSERIAL PRIMARY KEY,
  project_number TEXT NOT NULL,
  project_name TEXT,
  project_city TEXT,
  project_state CHAR(2),
  billing_year INTEGER NOT NULL,
  amount_billed NUMERIC,
  amount_paid NUMERIC,
  pending_amount_due NUMERIC,
  source_file TEXT NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (project_number, billing_year, source_file)
);

CREATE TABLE source_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  source_url TEXT NOT NULL,
  file_name TEXT NOT NULL,
  checksum_sha256 TEXT NOT NULL,
  row_count INTEGER,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE ingestion_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running',
  rows_processed INTEGER NOT NULL DEFAULT 0,
  rows_inserted INTEGER NOT NULL DEFAULT 0,
  rows_updated INTEGER NOT NULL DEFAULT 0,
  details JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL,
  actor_label TEXT,
  request_path TEXT,
  request_method TEXT,
  status TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_associations_slug ON associations(slug);
CREATE INDEX idx_associations_unit_count ON associations(unit_count);
CREATE INDEX idx_associations_county ON associations(county);
CREATE INDEX idx_filing_association_date ON filings(association_id, published_at DESC);
CREATE INDEX idx_payment_project_year ON payment_history(project_number, billing_year DESC);
CREATE INDEX idx_snapshots_source_time ON source_snapshots(source_name, fetched_at DESC);
CREATE INDEX idx_ingestion_runs_job_time ON ingestion_runs(job_name, started_at DESC);
CREATE INDEX idx_audit_logs_time ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_event_time ON audit_logs(event_type, created_at DESC);
