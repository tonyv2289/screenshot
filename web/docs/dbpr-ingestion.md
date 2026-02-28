# DBPR Ingestion Runbook

## Sources ingested
- Condo extracts:
  - `Condo_NF.csv`
  - `condo_CE.csv`
  - `Condo_CW.csv`
  - `Condo_MD.csv`
  - `condo_PB.csv`
- Payment history extracts:
  - `paymenthist_8002A.csv`
  - `paymenthist_8002D.csv`
  - `paymenthist_8002J.csv`
  - `paymenthist_8002P.csv`
  - `paymenthist_8002S.csv`
  - `paymenthist_8002V.csv`

## Local startup

```bash
cd web
cp .env.example .env.local
docker compose up -d
npm run db:migrate
npm run ingest:dbpr
```

For full loads without row caps:

```bash
npm run ingest:dbpr -- --full
```

## What ingestion writes
- `associations`
- `payment_history`
- `source_snapshots`
- `ingestion_runs`

## Notes
- Default ingest runs with a row cap (`INGEST_LIMIT_ROWS`, default 5000 rows per source file).
- Use `--full` for uncapped ingestion.
- Dashboard and operations pages automatically switch to Postgres mode when `DATABASE_URL` is present.
