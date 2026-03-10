import { Nav } from "@/components/nav";
import { AdminLogoutClient } from "@/components/admin-logout-client";

export const dynamic = "force-dynamic";

export default function AdminLogoutPage() {
  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <AdminLogoutClient />
      </main>
    </div>
  );
}
