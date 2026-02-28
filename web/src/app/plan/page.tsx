import { Nav } from "@/components/nav";
import { thirtyDayMilestones } from "@/lib/florida-program";

export default function PlanPage() {
  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">30-Day Plan</p>
          <h1>Florida condo data ingestion rollout.</h1>
          <p>
            Execution plan for launching a statewide Florida dashboard with DBPR-backed
            ingestion and protected-document partner uploads.
          </p>
        </section>

        <section className="reveal delay-1">
          <div className="milestone-list">
            {thirtyDayMilestones.map((milestone) => (
              <article key={milestone.id} className="milestone-card">
                <p className="milestone-window">{milestone.dayRange}</p>
                <h2>{milestone.goal}</h2>
                <ul>
                  {milestone.deliverables.map((deliverable) => (
                    <li key={deliverable}>{deliverable}</li>
                  ))}
                </ul>
                <p>
                  <strong>Acceptance:</strong> {milestone.acceptance}
                </p>
              </article>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
