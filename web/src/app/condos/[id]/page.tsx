import Link from "next/link";
import { notFound } from "next/navigation";
import { Nav } from "@/components/nav";
import { getCondoBySlug } from "@/lib/server-data";
import type { ComplianceStatus } from "@/lib/types";

export const dynamic = "force-dynamic";

function formatDate(value: string): string {
  return new Date(`${value}T00:00:00`).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function statusClass(status: ComplianceStatus): string {
  if (status === "Compliant") return "pill pill-green";
  if (status === "At Risk") return "pill pill-yellow";
  return "pill pill-red";
}

export default async function CondoPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const condoData = await getCondoBySlug(id);

  if (!condoData) notFound();

  const condo = condoData.association;
  const condoFilings = condoData.filings.sort((a, b) =>
    b.publishedAt.localeCompare(a.publishedAt),
  );

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">Association Profile</p>
          <h1>{condo.legalName}</h1>
          <p>
            {condo.city}, {condo.state} · {condo.unitCount} units
          </p>
          <div className="chips-row">
            <span className={statusClass(condo.complianceStatus)}>{condo.complianceStatus}</span>
            <span className="pill">Next deadline: {formatDate(condo.nextDeadline)}</span>
            <span className="pill">
              Data mode: {condoData.usingDatabase ? "Postgres" : "Mock fallback"}
            </span>
          </div>
        </section>

        <section className="panel-grid reveal delay-1">
          <article className="panel">
            <h2>Contact</h2>
            <p>
              Property manager email: <a href={`mailto:${condo.managerEmail}`}>{condo.managerEmail}</a>
            </p>
            <p>Last published document: {formatDate(condo.lastPublishedAt)}</p>
          </article>
          <article className="panel">
            <h2>Registry Actions</h2>
            <p>Upload new financials, reserve studies, insurance summaries, and minutes.</p>
            <Link className="button-link" href="/filings/new">
              Submit a filing
            </Link>
          </article>
        </section>

        <section className="reveal delay-2">
          <div className="panel-head">
            <h2>Published Filings</h2>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Type</th>
                  <th>Reporting Period</th>
                  <th>Published</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                {condoFilings.length > 0 ? (
                  condoFilings.map((filing) => (
                    <tr key={filing.id}>
                      <td>{filing.type}</td>
                      <td>{filing.periodLabel}</td>
                      <td>{formatDate(filing.publishedAt)}</td>
                      <td>
                        <a href={filing.sourceUrl} target="_blank" rel="noreferrer">
                          {filing.sourceLabel}
                        </a>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={4}>No filings recorded yet.</td>
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
