import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Nav } from "@/components/nav";
import { AdminIngestPanel } from "@/components/admin-ingest-panel";
import {
  getAdminSessionCookieName,
  isAdminAuthEnabled,
  isValidAdminSessionToken,
} from "@/lib/auth";
import { getOperationsData } from "@/lib/server-data";

export const dynamic = "force-dynamic";

export default async function OperationsPage() {
  if (isAdminAuthEnabled()) {
    const cookieStore = await cookies();
    const token = cookieStore.get(getAdminSessionCookieName())?.value;
    if (!isValidAdminSessionToken(token)) {
      redirect("/admin/login?next=%2Foperations");
    }
  }

  const data = await getOperationsData();

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">Data Operations</p>
          <h1>Ingestion status for Florida source systems.</h1>
          <p>
            This board tracks source readiness, owner assignments, and scheduled ETL jobs
            for the next 30 days.
          </p>
          <div className="chips-row">
            <span className="pill">
              Data mode: {data.usingDatabase ? "Postgres" : "Mock fallback"}
            </span>
          </div>
        </section>

        <AdminIngestPanel adminKeyRequired={isAdminAuthEnabled()} />

        <section className="reveal delay-1">
          <div className="panel-head">
            <h2 className="section-title">Source Registry</h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Source</th>
                  <th>Category</th>
                  <th>Cadence</th>
                  <th>Ingestion</th>
                  <th>Status</th>
                  <th>Owner</th>
                  <th>Last Pull</th>
                </tr>
              </thead>
              <tbody>
                {data.sources.map((source) => (
                  <tr key={source.id}>
                    <td>
                      <a href={source.url} target="_blank" rel="noreferrer">
                        {source.name}
                      </a>
                    </td>
                    <td>{source.category}</td>
                    <td>{source.cadence}</td>
                    <td>{source.ingestion}</td>
                    <td>
                      <span className="pill">{source.status}</span>
                    </td>
                    <td>{source.owner}</td>
                    <td>{source.lastFetchedAt ? new Date(source.lastFetchedAt).toLocaleString() : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="reveal delay-2">
          <div className="panel-head">
            <h2 className="section-title">Job Schedule</h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Schedule (ET)</th>
                  <th>Source</th>
                  <th>Job</th>
                  <th>Output</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {data.jobs.map((job) => (
                  <tr key={job.id}>
                    <td>{job.schedule}</td>
                    <td>{job.source}</td>
                    <td>
                      <code>{job.jobName}</code>
                    </td>
                    <td>{job.output}</td>
                    <td>
                      <span className="pill">{job.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="reveal delay-3">
          <div className="panel-head">
            <h2 className="section-title">Recent Ingestion Runs</h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Job</th>
                  <th>Status</th>
                  <th>Started</th>
                  <th>Finished</th>
                  <th>Rows</th>
                </tr>
              </thead>
              <tbody>
                {data.recentRuns.length > 0 ? (
                  data.recentRuns.map((run) => (
                    <tr key={run.id}>
                      <td>
                        <code>{run.jobName}</code>
                      </td>
                      <td>
                        <span className="pill">{run.status}</span>
                      </td>
                      <td>{new Date(run.startedAt).toLocaleString()}</td>
                      <td>{run.finishedAt ? new Date(run.finishedAt).toLocaleString() : "—"}</td>
                      <td>{run.rowsProcessed.toLocaleString()}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={5}>No ingestion runs recorded yet.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="reveal delay-3">
          <div className="panel-head">
            <h2 className="section-title">Recent Audit Events</h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>When</th>
                  <th>Event</th>
                  <th>Actor</th>
                  <th>Status</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                {data.recentAudit.length > 0 ? (
                  data.recentAudit.map((event) => (
                    <tr key={event.id}>
                      <td>{new Date(event.createdAt).toLocaleString()}</td>
                      <td>
                        <code>{event.eventType}</code>
                      </td>
                      <td>{event.actorType}</td>
                      <td>
                        <span className="pill">{event.status}</span>
                      </td>
                      <td>{event.actorLabel || "—"}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={5}>No audit events recorded yet.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </main>
    </div>
  );
}
