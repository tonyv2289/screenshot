# Florida Condo Data Platform - 30 Day Ingestion Plan

## Objective
Ship a production pilot in 30 days that centralizes Florida condo compliance data, starting with public DBPR datasets and adding protected-document ingestion via partner uploads.

## Scope for day 30
- Stateful ingestion pipeline for DBPR condo/project and payment history extracts
- Source operations dashboard with freshness + job status
- Association-level compliance status computation for 25+ unit communities
- Pilot document intake workflow for association managers
- Audit trail and exportable compliance summary views

## Non-goals in first 30 days
- Full statewide backfill of every historical document
- Public crawling of owner-protected records
- Complete automation for all county-level registries

## Day-by-day execution

### Days 1-5: Foundation
- Provision Postgres, object storage, and secrets in target environment
- Create tables: `raw_source_snapshot`, `stg_dbpr_condo`, `stg_dbpr_payment`, `dim_association`
- Implement pullers for `Condo_*` and `paymenthist_8002*` files
- Add lineage fields (`source_url`, `checksum`, `fetched_at`, `job_run_id`)

Exit criteria:
- Nightly run lands parsed rows and preserves raw files

### Days 6-10: Identity and data quality
- Build deterministic keying on DBPR project number
- Add fallback match strategy using normalized name + county + address
- Add QA rules and review queue for unresolved matches
- Add unit tests for parser and resolver logic

Exit criteria:
- At least 95% association mapping coverage with confidence scores

### Days 11-15: Compliance engine + dashboard v1
- Implement Florida rule profile for 25+ unit scope
- Compute status buckets: `Compliant`, `At Risk`, `Overdue`
- Surface deadlines and filing completeness on dashboard
- Add pipeline run telemetry and source freshness indicators

Exit criteria:
- Dashboard reflects ingestion updates within 24 hours

### Days 16-20: SIRS + county pilot integration
- Integrate SIRS submission status feed (export/API/approved method)
- Ingest Miami-Dade pilot sample for cross-validation
- Add county and manager-level filters
- Create reconciliation report for unmatched entities

Exit criteria:
- County-level comparative views available in operations UI

### Days 21-25: Protected document intake
- Build upload workflow for association managers
- Extract metadata from documents (period, filing type, publication date)
- Add duplicate detection and source provenance tagging
- Add role-based access controls for manager and regulator personas

Exit criteria:
- Uploaded documents appear in association timeline with audit logs

### Days 26-30: Pilot hardening and launch
- Alerting: failed ingest, stale source, parser drift
- Runbook + incident response docs
- Pilot onboarding for 3 to 5 associations
- Usage analytics and feedback loop

Exit criteria:
- Pilot users can upload, review, and export compliance views without manual DB operations

## Risks and mitigations
- Protected records are inaccessible to general public
  - Mitigation: direct association/management partner feeds + explicit consent workflow
- Source schema drift in CSV exports
  - Mitigation: schema contracts + parser tests + quarantine lane
- Entity mismatch across agencies
  - Mitigation: multi-key resolver + review queue + confidence scoring

## Success metrics by day 30
- 2+ automated state sources live (DBPR condo + payment)
- 95%+ association resolution rate
- 99% successful daily ingestion runs
- Pilot users can complete upload-to-dashboard flow in under 10 minutes
