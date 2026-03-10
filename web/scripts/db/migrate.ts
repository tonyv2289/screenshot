import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";
import dotenv from "dotenv";
import { Client } from "pg";

dotenv.config({ path: path.resolve(process.cwd(), ".env.local") });
dotenv.config();

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required to run migrations.");
  }

  const client = new Client({ connectionString: databaseUrl });
  await client.connect();

  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  const migrationsDir = path.resolve(process.cwd(), "db", "migrations");
  const files = (await fs.readdir(migrationsDir))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  for (const filename of files) {
    const alreadyApplied = await client.query(
      "SELECT 1 FROM schema_migrations WHERE filename = $1",
      [filename],
    );

    if (alreadyApplied.rowCount && alreadyApplied.rowCount > 0) {
      continue;
    }

    const sql = await fs.readFile(path.join(migrationsDir, filename), "utf8");

    await client.query("BEGIN");
    try {
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (filename) VALUES ($1)", [filename]);
      await client.query("COMMIT");
      console.log(`Applied migration: ${filename}`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
  }

  await client.end();
}

main().catch((error) => {
  console.error("Migration failed:", error);
  process.exit(1);
});
