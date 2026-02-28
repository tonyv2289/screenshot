import Link from "next/link";
import { isAdminAuthEnabled } from "@/lib/auth";

const links = [
  { href: "/", label: "Dashboard" },
  { href: "/map", label: "Map View" },
  { href: "/operations", label: "Operations" },
  { href: "/plan", label: "30-Day Plan" },
  { href: "/filings/new", label: "Add Filing" },
];

if (isAdminAuthEnabled()) {
  links.splice(3, 0, { href: "/admin/login", label: "Admin" });
  links.splice(4, 0, { href: "/admin/logout", label: "Logout" });
}

export function Nav() {
  return (
    <header className="top-nav">
      <div className="top-nav-inner">
        <Link className="brand" href="/">
          Condo Ledger
        </Link>
        <nav>
          <ul className="top-nav-list">
            {links.map((link) => (
              <li key={link.href}>
                <Link href={link.href}>{link.label}</Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </header>
  );
}
