from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.auth import active_session, authenticate, issue_tokens
from app.db import get_session
from app.dependencies import tenant_id
from app.schemas import LoginInput, RefreshInput

router = APIRouter(tags=["auth"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


@router.post("/api/auth/login")
def login_school(data: LoginInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        result = authenticate(session, data.email, data.password, tenant)
    return result


@router.post("/platform/auth/login")
def login_platform(data: LoginInput, session: Db) -> dict:
    with session.begin():
        result = authenticate(session, data.email, data.password, "platform")
    return result


@router.post("/api/auth/refresh")
def refresh(data: RefreshInput, session: Db) -> dict:
    with session.begin():
        old = active_session(session, data.refresh_token, refresh=True)
        if old is None:
            raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
        session.refresh(old, with_for_update=True)
        if old.revoked_at is not None:
            raise HTTPException(status_code=401, detail="Refresh token already used")
        old.revoked_at = datetime.now(timezone.utc)
        result = issue_tokens(session, old.user)
    return result


@router.post("/api/auth/logout")
def logout(
    session: Db,
    authorization: str = Header(alias="Authorization"),
) -> dict:
    with session.begin():
        token = authorization[7:] if authorization.startswith("Bearer ") else ""
        old = active_session(session, token)
        if old is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        old.revoked_at = datetime.now(timezone.utc)
    return {"message": "Logged out successfully"}
