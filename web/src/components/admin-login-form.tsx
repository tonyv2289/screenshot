"use client";

import { useState } from "react";

export function AdminLoginForm({ nextPath }: { nextPath: string }) {
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);

    try {
      const response = await fetch("/api/admin/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });

      const body = (await response.json()) as { ok: boolean; error?: string };
      if (!response.ok || !body.ok) {
        setError(body.error || "Login failed.");
        return;
      }

      window.location.assign(nextPath);
    } catch {
      setError("Request failed while signing in.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="form-panel reveal delay-1">
      <form onSubmit={onSubmit}>
        <label>
          Admin password
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="Enter admin password"
            required
          />
        </label>

        <button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Signing in..." : "Sign In"}
        </button>

        {error ? <p className="form-feedback form-feedback-error">{error}</p> : null}
      </form>
    </section>
  );
}
