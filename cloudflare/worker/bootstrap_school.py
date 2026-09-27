"""Private bootstrap utility for schools and administrators.

Creates initial tenant, academic year, and administrator records without
exposing any public HTTP credential-seeding endpoint.
Outputs SQL statements for direct D1 execution via Wrangler or SQLite.
"""

from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import secrets
import sys

# Ensure pure-python pydantic and vendor imports if needed
sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))
from school_auth import password_hash  # noqa: E402


def generate_bootstrap_sql(
    *,
    school_id: str,
    school_name: str,
    admin_email: str,
    admin_password: str,
    admin_name: str = "School Administrator",
    city: str = "Bengaluru",
    board: str = "CBSE",
    academic_year: str = "2026-2027",
    active: bool = True,
    legacy_bcrypt_hash: str | None = None,
) -> str:
    """Generate SQL statements to bootstrap a tenant, academic year, and initial admin."""
    now_iso = datetime.now(timezone.utc).isoformat()
    school_id = school_id.strip().lower()
    admin_email = admin_email.strip().lower()
    ay_id = f"ay_{school_id}_{academic_year.replace('-', '_')}"
    user_id = f"usr_admin_{school_id}_{secrets.token_hex(4)}"

    # Use scrypt hash by default, or optional legacy bcrypt hash for compatibility testing
    p_hash = legacy_bcrypt_hash if legacy_bcrypt_hash else password_hash(admin_password)

    lines = [
        "-- Private bootstrap script generated at " + now_iso,
        f"INSERT INTO tenants (id, name, active, city, board) "
        f"VALUES ('{school_id}', '{school_name}', {1 if active else 0}, '{city}', '{board}') "
        f"ON CONFLICT(id) DO UPDATE SET name = excluded.name, active = excluded.active;",
        "",
        f"INSERT INTO academic_years (id, tenant_id, year, start_date, end_date, status) "
        f"VALUES ('{ay_id}', '{school_id}', '{academic_year}', '2026-04-01', '2027-03-31', 'ACTIVE') "
        f"ON CONFLICT(id) DO NOTHING;",
        "",
        f"INSERT INTO users (id, scope, tenant_id, email, password_hash, full_name, phone, role, linked_entity_id, extra_permissions, active, created_at) "
        f"VALUES ('{user_id}', '{school_id}', '{school_id}', '{admin_email}', '{p_hash}', '{admin_name}', '+919876543210', 'SCHOOL_ADMIN', NULL, '[]', {1 if active else 0}, '{now_iso}') "
        f"ON CONFLICT(scope, email) DO UPDATE SET password_hash = excluded.password_hash, active = excluded.active;",
    ]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Bootstrap school tenant and administrator")
    parser.add_argument("--school-id", required=True, help="Unique school tenant code (e.g., school-a)")
    parser.add_argument("--name", required=True, help="School display name")
    parser.add_argument("--admin-email", required=True, help="Administrator email address")
    parser.add_argument("--admin-password", required=True, help="Administrator initial password")
    parser.add_argument("--admin-name", default="School Administrator", help="Administrator display name")
    parser.add_argument("--city", default="Bengaluru", help="School city")
    parser.add_argument("--board", default="CBSE", help="School educational board")
    parser.add_argument("--academic-year", default="2026-2027", help="Initial academic year")
    parser.add_argument("--inactive", action="store_true", help="Bootstrap as inactive")
    parser.add_argument("--output", "-o", help="Output .sql file path")

    args = parser.parse_args()
    sql = generate_bootstrap_sql(
        school_id=args.school_id,
        school_name=args.name,
        admin_email=args.admin_email,
        admin_password=args.admin_password,
        admin_name=args.admin_name,
        city=args.city,
        board=args.board,
        academic_year=args.academic_year,
        active=not args.inactive,
    )

    if args.output:
        out_path = Path(args.output).resolve()
        out_path.write_text(sql, encoding="utf-8")
        print(f"Bootstrap SQL written to {out_path}")
    else:
        print(sql)


if __name__ == "__main__":
    main()
