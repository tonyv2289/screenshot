"use client";

import { useEffect } from "react";

export function AdminLogoutClient() {
  useEffect(() => {
    let cancelled = false;

    async function signOut() {
      try {
        await fetch("/api/admin/session", { method: "DELETE" });
      } finally {
        if (!cancelled) {
          window.location.assign("/admin/login");
        }
      }
    }

    void signOut();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <section className="hero reveal">
      <p className="eyebrow">Admin Access</p>
      <h1>Signing out...</h1>
      <p>Your admin session is being cleared.</p>
    </section>
  );
}
