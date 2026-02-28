import { Pool } from "pg";

declare global {
  var __condoLedgerDbPool: Pool | undefined;
}

export function getDbPool(): Pool | null {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) return null;

  if (!global.__condoLedgerDbPool) {
    global.__condoLedgerDbPool = new Pool({
      connectionString: databaseUrl,
      max: 8,
      connectionTimeoutMillis: 1000,
      idleTimeoutMillis: 5000,
    });
  }

  return global.__condoLedgerDbPool;
}

export function isDatabaseConfigured(): boolean {
  return Boolean(process.env.DATABASE_URL);
}
