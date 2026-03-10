import { Nav } from "@/components/nav";
import { FloridaMapDashboard } from "@/components/florida-map-dashboard";
import { getDashboardData } from "@/lib/server-data";

export const dynamic = "force-dynamic";

export default async function MapPage() {
  const dashboardData = await getDashboardData();
  const associationsInScope = dashboardData.associations.filter((item) => item.unitCount > 25);

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">Florida Map Dashboard</p>
          <h1>Filter compliance health and visualize association clusters across Florida.</h1>
          <p>
            Use status, county, unit count, and keyword filters to isolate where disclosure risk is
            concentrated.
          </p>
          <div className="chips-row">
            <span className="pill">
              Data mode: {dashboardData.usingDatabase ? "Postgres" : "Mock fallback"}
            </span>
          </div>
        </section>

        <FloridaMapDashboard associations={associationsInScope} />
      </main>
    </div>
  );
}
