import {
  runDbprIngestion,
  type RunDbprIngestionOptions,
  type RunDbprIngestionResult,
} from "@/lib/dbpr-ingestion";

declare global {
  var __dbprIngestPromise: Promise<unknown> | undefined;
}

export function isIngestionInProgress(): boolean {
  return Boolean(global.__dbprIngestPromise);
}

export function startIngestionJob<T>(job: () => Promise<T>): Promise<T> | null {
  if (global.__dbprIngestPromise) {
    return null;
  }

  const promise = job();
  global.__dbprIngestPromise = promise;

  promise.finally(() => {
    if (global.__dbprIngestPromise === promise) {
      global.__dbprIngestPromise = undefined;
    }
  });

  return promise;
}

export function startIngestion(
  options: RunDbprIngestionOptions,
): Promise<RunDbprIngestionResult> | null {
  return startIngestionJob(() => runDbprIngestion(options));
}
