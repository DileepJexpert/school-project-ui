"""Bootstrap one platform administrator with an interactively entered password."""

import argparse
import getpass
from datetime import datetime, timezone

from sqlalchemy import select

from app.auth import password_hash
from app.db import SessionLocal
from app.models import User


def main() -> None:
    parser = argparse.ArgumentParser(description="Create an initial platform administrator")
    parser.add_argument("email")
    parser.add_argument("full_name")
    args = parser.parse_args()
    email = args.email.strip().lower()
    if "@" not in email:
        parser.error("Valid email required")
    password = getpass.getpass("Initial platform password: ")
    if len(password) < 8:
        parser.error("Password must contain at least 8 characters")
    with SessionLocal.begin() as session:
        if session.scalar(select(User.id).where(User.scope == "platform", User.email == email)):
            parser.error("Platform email already exists")
        session.add(User(
            scope="platform", tenant_id=None, email=email,
            password_hash=password_hash(password), full_name=args.full_name.strip(),
            phone="", role="SUPER_ADMIN", linked_entity_id=None,
            extra_permissions=[], active=True, created_at=datetime.now(timezone.utc),
        ))
    print("Platform administrator created")


if __name__ == "__main__":
    main()
