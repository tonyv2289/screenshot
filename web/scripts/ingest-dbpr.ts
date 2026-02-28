import path from "node:path";
import process from "node:process";
import dotenv from "dotenv";
import { runDbprIngestion } from "@/lib/dbpr-ingestion";

dotenv.config({ path: path.resolve(process.cwd(), ".env.local") });
dotenv.config();

type CliOptions = {
  limit: number | null;
};

function parseArgs(argv: string[]): CliOptions {
  let limit: number | null = Number(process.env.INGEST_LIMIT_ROWS || 5000);

  for (const arg of argv) {
    if (arg === "--full") {
      limit = null;
    } else if (arg.startsWith("--limit=")) {
      const parsed = Number(arg.split("=")[1]);
      if (Number.isFinite(parsed) && parsed > 0) {
        limit = parsed;
      }
    }
  }

  return { limit };
}

async function main() {
  const { limit } = parseArgs(process.argv.slice(2));
  const result = await runDbprIngestion({
    limit,
    jobName: "ingest_dbpr_cli",
  });

  console.log(
    `DBPR ingestion completed. Run ${result.runId}. Rows processed: ${result.totalProcessed}.`,
  );
}

main().catch((error) => {
  console.error("DBPR ingestion failed:", error);
  process.exit(1);
});
