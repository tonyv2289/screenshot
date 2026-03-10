import Link from "next/link";
import { Nav } from "@/components/nav";
import { floridaSources, thirtyDayMilestones } from "@/lib/florida-program";
import { getDashboardData } from "@/lib/server-data";
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

export default async function Home() {
  const dashboardData = await getDashboardData();
  const associationsInScope = dashboardData.associations.filter((item) => item.unitCount > 25);
  const recentFilings = [...dashboardData.filings]
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))
    .slice(0, 5);
  const nextDeadlines = [...associationsInScope].sort((a, b) =>
    a.nextDeadline.localeCompare(b.nextDeadline),
  );

  const compliantCount = associationsInScope.filter(
    (item) => item.complianceStatus === "Compliant",
  ).length;
  const atRiskCount = associationsInScope.filter(
    (item) => item.complianceStatus === "At Risk",
  ).length;
  const overdueCount = associationsInScope.filter(
    (item) => item.complianceStatus === "Overdue",
  ).length;

  const liveSources = floridaSources.filter((source) => source.status === "Live Pull").length;

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">Florida Condo Transparency</p>
          <h1>Centralize condos over 25 units into one operations dashboard.</h1>
          <p>
            This prototype combines filing tracking, data-source operations, and a 30-day
            rollout plan focused on Florida-specific inputs.
          </p>
          <div className="chips-row">
            <span className="pill">
              Data mode: {dashboardData.usingDatabase ? "Postgres" : "Mock fallback"}
            </span>
          </div>
        </section>

        <section className="stats-grid reveal delay-1">
          <article className="metric-card">
            <span>Associations In Scope</span>
            <strong>{associationsInScope.length}</strong>
            <small>More than 25 units</small>
          </article>
          <article className="metric-card">
            <span>Compliant</span>
            <strong>{compliantCount}</strong>
            <small>Up to date on disclosures</small>
          </article>
          <article className="metric-card">
            <span>Connected Sources</span>
            <strong>{liveSources}</strong>
            <small>
              Automated DBPR pulls · {atRiskCount} at risk · {overdueCount} overdue
            </small>
          </article>
          <article className="metric-card">
            <span>30-Day Milestones</span>
            <strong>{thirtyDayMilestones.length}</strong>
            <small>Execution checkpoints</small>
          </article>
        </section>

        <section className="panel-grid reveal delay-2">
          <article className="panel">
            <div className="panel-head">
              <h2>Upcoming Deadlines</h2>
              <Link href="/filings/new">Add Filing</Link>
            </div>
            <ul className="stack-list">
              {nextDeadlines.map((condo) => (
                <li key={condo.id}>
                  <div>
                    <Link href={`/condos/${condo.id}`}>{condo.legalName}</Link>
                    <p>
                      {condo.city}, {condo.state} · {condo.unitCount} units
                    </p>
                  </div>
                  <span>{formatDate(condo.nextDeadline)}</span>
                </li>
              ))}
            </ul>
          </article>

          <article className="panel">
            <div className="panel-head">
              <h2>Recent Filings</h2>
            </div>
            <ul className="stack-list">
              {recentFilings.map((filing) => (
                <li key={filing.id}>
                  <div>
                    <p>{filing.type}</p>
                    <small>
                      {filing.periodLabel} · {filing.sourceLabel}
                    </small>
                  </div>
                  <span>{formatDate(filing.publishedAt)}</span>
                </li>
              ))}
            </ul>
          </article>
        </section>

        <section className="reveal delay-3">
          <div className="panel-head">
            <h2 className="section-title">Florida Source Coverage</h2>
            <Link href="/operations">View Ops Dashboard</Link>
          </div>
          <div className="source-grid">
            {floridaSources.map((source) => (
              <article key={source.id} className="source-card">
                <p className="source-meta">
                  {source.category} · {source.cadence}
                </p>
                <h3>{source.name}</h3>
                <p>{source.coverage}</p>
                <div className="chips-row">
                  <span className="pill">{source.status}</span>
                  <span className="pill">{source.ingestion}</span>
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="reveal delay-3">
          <div className="panel-head">
            <h2 className="section-title">30-Day Execution</h2>
            <Link href="/plan">Open Full Plan</Link>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Window</th>
                  <th>Goal</th>
                  <th>Acceptance</th>
                </tr>
              </thead>
              <tbody>
                {thirtyDayMilestones.map((milestone) => (
                  <tr key={milestone.id}>
                    <td>{milestone.dayRange}</td>
                    <td>{milestone.goal}</td>
                    <td>{milestone.acceptance}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="reveal delay-3">
          <div className="panel-head">
            <h2 className="section-title">Association Directory</h2>
            <Link href="/map">Open Map Dashboard</Link>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Association</th>
                  <th>Location</th>
                  <th>Units</th>
                  <th>Status</th>
                  <th>Next Deadline</th>
                </tr>
              </thead>
              <tbody>
                {associationsInScope.map((condo) => (
                  <tr key={condo.id}>
                    <td>
                      <Link href={`/condos/${condo.id}`}>{condo.legalName}</Link>
                    </td>
                    <td>
                      {condo.city}, {condo.state}
                    </td>
                    <td>{condo.unitCount}</td>
                    <td>
                      <span className={statusClass(condo.complianceStatus)}>
                        {condo.complianceStatus}
                      </span>
                    </td>
                    <td>{formatDate(condo.nextDeadline)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </main>
    </div>
  );
}
