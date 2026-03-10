import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Nav } from "@/components/nav";
import { NewFilingForm } from "@/components/new-filing-form";
import {
  getAdminSessionCookieName,
  isAdminAuthEnabled,
  isValidAdminSessionToken,
} from "@/lib/auth";
import { getDashboardData } from "@/lib/server-data";

export const dynamic = "force-dynamic";

export default async function NewFilingPage() {
  if (isAdminAuthEnabled()) {
    const cookieStore = await cookies();
    const token = cookieStore.get(getAdminSessionCookieName())?.value;
    if (!isValidAdminSessionToken(token)) {
      redirect("/admin/login?next=%2Ffilings%2Fnew");
    }
  }

  const dashboardData = await getDashboardData();
  const associations = dashboardData.usingDatabase
    ? [...dashboardData.associations]
        .sort((a, b) => a.legalName.localeCompare(b.legalName))
        .map((item) => ({
          id: item.id,
          legalName: item.legalName,
          city: item.city,
          state: item.state,
          unitCount: item.unitCount,
        }))
    : [];

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">New Disclosure</p>
          <h1>Add a required condo filing.</h1>
          <p>
            Create a filing record directly in the registry database for a specific association.
          </p>
          <div className="chips-row">
            <span className="pill">
              Data mode: {dashboardData.usingDatabase ? "Postgres" : "Mock fallback"}
            </span>
          </div>
        </section>

        <NewFilingForm
          associations={associations}
          adminKeyRequired={isAdminAuthEnabled()}
          databaseReady={dashboardData.usingDatabase}
        />
      </main>
    </div>
  );
}
