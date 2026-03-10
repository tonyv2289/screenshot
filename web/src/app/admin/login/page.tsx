import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { AdminLoginForm } from "@/components/admin-login-form";
import { Nav } from "@/components/nav";
import {
  getAdminSessionCookieName,
  isAdminAuthEnabled,
  isSafeNextPath,
  isValidAdminSessionToken,
} from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function AdminLoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const params = await searchParams;
  const requestedNext = isSafeNextPath(params.next) ? params.next! : "/operations";
  const cookieStore = await cookies();
  const token = cookieStore.get(getAdminSessionCookieName())?.value;

  if (!isAdminAuthEnabled()) {
    redirect(requestedNext);
  }

  if (isValidAdminSessionToken(token)) {
    redirect(requestedNext);
  }

  return (
    <div className="page-wrap">
      <Nav />
      <main className="container">
        <section className="hero reveal">
          <p className="eyebrow">Admin Access</p>
          <h1>Sign in to manage ingestion and filing writes.</h1>
          <p>
            This creates a session cookie for protected registry workflows.
          </p>
        </section>
        <AdminLoginForm nextPath={requestedNext} />
      </main>
    </div>
  );
}
