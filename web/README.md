# Condo Ledger (Florida Prototype)

Condo Ledger is a Florida-focused prototype for centralizing condo compliance and financial-disclosure operations.

## What is implemented

- Dashboard homepage at `/` with:
  - over-25-unit in-scope association counts
  - compliance status cards
  - source coverage summary
  - 30-day milestone snapshot
- Operations board at `/operations`:
  - Florida source registry (DBPR, SIRS, Sunbiz, DOR, county, partner feeds)
  - scheduled pipeline jobs and recent ingestion runs
  - admin ingestion controls (quick/full DBPR sync + manual CSV import)
- 30-day execution plan page at `/plan`
- Association detail route at `/condos/[id]`
- Admin auth routes: `/admin/login` and `/admin/logout`
- Filing intake route at `/filings/new` (writes to Postgres via API)
  - Write mode is enabled only when dashboard is in `Postgres` data mode
  - Supports optional direct document upload to `/public/uploads/filings`
- DBPR ingestion scripts and Postgres migration scripts

## Quick start with Postgres

```bash
cd web
cp .env.example .env.local
docker compose up -d
npm run db:migrate
npm run ingest:dbpr
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Production env template

- Copy `web/.env.production.example` into your host env configuration and set all required values.

## Admin auth env vars

- `ADMIN_APP_PASSWORD`: admin password for `/admin/login` (falls back to `ADMIN_API_KEY`)
- `ADMIN_SESSION_SECRET`: HMAC signing key for admin session cookies

## Ingestion commands

```bash
npm run db:migrate
npm run ingest:dbpr
```

For uncapped ingestion:

```bash
npm run ingest:dbpr -- --full
```

## Admin ingestion API

- Endpoint: `POST /api/admin/ingest`
- Optional auth: set `ADMIN_APP_PASSWORD` or `ADMIN_API_KEY`
- API auth supports either a cookie from `/admin/login` or header `x-admin-api-key`
- Payload example:

```json
{
  "full": false,
  "limit": 1000,
  "async": true
}
```

## Manual CSV import API

- Endpoint: `POST /api/admin/import`
- Optional auth: set `ADMIN_APP_PASSWORD` or `ADMIN_API_KEY`
- API auth supports either a cookie from `/admin/login` or header `x-admin-api-key`
- Request format: `multipart/form-data` with one or more files in field `files`
- Supported DBPR file names:
  - `Condo_*.csv`
  - `paymenthist_*.csv`
- Optional field: `async` (`true` by default)
- Optional env: `MANUAL_IMPORT_MAX_BYTES` (default `41943040`, 40 MB total upload payload)

## Filing write API

- Endpoint: `POST /api/filings`
- Optional auth: if admin auth is enabled, use `/admin/login` cookie or `x-admin-api-key`
- Payload example:

```json
{
  "associationId": "sunset-harbor",
  "type": "Annual Budget",
  "periodLabel": "FY 2026",
  "publishedAt": "2026-02-28",
  "sourceLabel": "Association Portal",
  "sourceUrl": "https://example.org/filing.pdf"
}
```

## Upload API

- Endpoint: `POST /api/uploads` (multipart form with field `file`)
- Stores files under `public/uploads/filings`
- Allowed extensions: `.pdf`, `.csv`, `.txt`, `.xls`, `.xlsx`
- Max file size: `10MB`

## Cron ingestion API

- Endpoint: `POST /api/cron/ingest`
- Auth: set `CRON_SECRET` and provide either:
  - `Authorization: Bearer <CRON_SECRET>`
  - `x-cron-secret: <CRON_SECRET>`
- Starts DBPR ingestion in background and returns `202` on success

## Health endpoint

- Endpoint: `GET /api/health`
- Returns service timestamp, auth mode, ingestion lock state, and DB reachability checks

## Docker deployment

Build image:

```bash
docker build -t condo-ledger-web .
```

Run container:

```bash
docker run --rm -p 3000:3000 \
  -e DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/condo_ledger \
  -e ADMIN_APP_PASSWORD=replace-me \
  -e ADMIN_SESSION_SECRET=replace-with-long-random \
  condo-ledger-web
```

## GitHub Actions automation

- Workflow: `.github/workflows/web-ci.yml`
  - Runs lint + build for `web/` on push/PR changes.
- Workflow: `.github/workflows/web-deploy-vercel.yml`
  - Deploys `web/` to Vercel production on `main` pushes or manual dispatch.
  - Required repo secrets:
    - `VERCEL_TOKEN`
    - `VERCEL_ORG_ID`
    - `VERCEL_PROJECT_ID`
  - Required Vercel project env vars:
    - `DATABASE_URL`
    - `ADMIN_APP_PASSWORD`
    - `ADMIN_SESSION_SECRET`
    - `CRON_SECRET`
- Workflow: `.github/workflows/cron-ingest.yml`
  - Triggers `/api/cron/ingest` daily and via manual dispatch.
  - Required repo secrets:
    - `CONDO_APP_BASE_URL` (example: `https://your-app.example.com`)
    - `CONDO_CRON_SECRET` (must match app `CRON_SECRET`)

## Current prototype status

- Dashboard auto-uses Postgres when `DATABASE_URL` is configured
- Falls back to mock data when DB is unavailable
- Authentication and permissions are not production-ready yet

## Important docs

- SQL migration: `db/migrations/001_initial.sql`
- SQL migration: `db/migrations/002_audit_logs.sql`
- 30-day delivery plan: `docs/30-day-ingestion-plan.md`
- DBPR runbook: `docs/dbpr-ingestion.md`

## Legal note

This project is a technical starting point, not legal advice. Florida compliance requirements should be validated with counsel before production use.
