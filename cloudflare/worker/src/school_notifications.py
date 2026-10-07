"""Notification system endpoints for school broadcasts, reminders, and alerts."""

from __future__ import annotations

from datetime import datetime, timezone
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant

router = APIRouter(prefix="/api/notifications", tags=["notifications"])
root_router = APIRouter(prefix="/notifications", tags=["notifications_root"])


def _wire_notification(row: dict, read_ids: set[str] | None = None) -> dict:
    is_read = bool(read_ids and row["id"] in read_ids)
    return {
        "id": row["id"],
        "title": row["title"],
        "message": row["message"],
        "type": (row.get("type") or "GENERAL").upper(),
        "targetAudience": (row.get("target_audience") or "ALL").upper(),
        "targetClass": row.get("target_class"),
        "targetStudentId": row.get("target_student_id"),
        "priority": (row.get("priority") or "MEDIUM").upper(),
        "createdBy": row.get("created_by") or "School Administration",
        "createdAt": row.get("created_at") or "",
        "expiresAt": row.get("expires_at"),
        "read": is_read,
    }


class NotificationInput(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = Field(min_length=1, max_length=4000)
    type: str = Field(default="GENERAL")
    targetAudience: str = Field(default="ALL")
    targetClass: str | None = None
    targetStudentId: str | None = None
    priority: str = Field(default="MEDIUM")
    expiresAt: str | None = None


async def _handle_list_notifications(
    type: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    user_id = user.get("id") or user.get("userId") or ""

    query = "SELECT * FROM notifications WHERE tenant_id = ? AND deleted_at IS NULL"
    params = [tenant]

    if type and type.strip().upper() != "ALL":
        query += " AND UPPER(type) = ?"
        params.append(type.strip().upper())

    query += " ORDER BY created_at DESC"
    rows = await _many(db, query, *params)

    # Get read notifications for this user
    read_rows = await _many(
        db,
        "SELECT notification_id FROM notification_reads WHERE tenant_id = ? AND user_id = ?",
        tenant, user_id,
    )
    read_ids = {r.get("notification_id") for r in read_rows if r.get("notification_id")}

    return [_wire_notification(r, read_ids) for r in rows]


async def _handle_create_notification(
    data: NotificationInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    now_iso = datetime.now(timezone.utc).isoformat()
    notif_id = f"notif_{uuid.uuid4().hex[:16]}"
    user_id = user.get("id") or user.get("userId") or "usr_admin"
    created_by = user.get("fullName") or user.get("email") or "Administration"

    await db.prepare(
        "INSERT INTO notifications ("
        "id, tenant_id, title, message, type, target_audience, target_class, "
        "target_student_id, priority, created_by, creator_id, created_at, expires_at"
        ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(
        notif_id,
        tenant,
        data.title.strip(),
        data.message.strip(),
        data.type.strip().upper(),
        data.targetAudience.strip().upper(),
        data.targetClass.strip() if data.targetClass else None,
        data.targetStudentId.strip() if data.targetStudentId else None,
        data.priority.strip().upper(),
        created_by,
        user_id,
        now_iso,
        data.expiresAt,
    ).run()

    created = await _one(db, "SELECT * FROM notifications WHERE id = ? AND tenant_id = ?", notif_id, tenant)
    return _wire_notification(created)


async def _handle_update_notification(
    id: str,
    data: NotificationInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    await db.prepare(
        "UPDATE notifications SET title = ?, message = ?, type = ?, target_audience = ?, "
        "target_class = ?, target_student_id = ?, priority = ?, expires_at = ? "
        "WHERE id = ? AND tenant_id = ? AND deleted_at IS NULL"
    ).bind(
        data.title.strip(),
        data.message.strip(),
        data.type.strip().upper(),
        data.targetAudience.strip().upper(),
        data.targetClass.strip() if data.targetClass else None,
        data.targetStudentId.strip() if data.targetStudentId else None,
        data.priority.strip().upper(),
        data.expiresAt,
        id.strip(),
        tenant,
    ).run()

    row = await _one(db, "SELECT * FROM notifications WHERE id = ? AND tenant_id = ?", id.strip(), tenant)
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    return _wire_notification(row)


async def _handle_mark_read(
    id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    user_id = user.get("id") or user.get("userId") or ""
    now_iso = datetime.now(timezone.utc).isoformat()
    read_id = f"nr_{uuid.uuid4().hex[:16]}"

    await db.prepare(
        "INSERT OR IGNORE INTO notification_reads (id, tenant_id, notification_id, user_id, read_at) "
        "VALUES (?, ?, ?, ?, ?)"
    ).bind(read_id, tenant, id.strip(), user_id, now_iso).run()

    row = await _one(db, "SELECT * FROM notifications WHERE id = ? AND tenant_id = ?", id.strip(), tenant)
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    return _wire_notification(row, {id.strip()})


async def _handle_delete_notification(
    id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE notifications SET deleted_at = ? WHERE id = ? AND tenant_id = ?"
    ).bind(now_iso, id.strip(), tenant).run()
    return {"message": "Notification deleted successfully"}


async def _handle_get_by_type(
    type: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    user_id = user.get("id") or user.get("userId") or ""
    rows = await _many(
        db,
        "SELECT * FROM notifications WHERE tenant_id = ? AND UPPER(type) = ? AND deleted_at IS NULL ORDER BY created_at DESC",
        tenant, type.strip().upper(),
    )
    read_rows = await _many(
        db,
        "SELECT notification_id FROM notification_reads WHERE tenant_id = ? AND user_id = ?",
        tenant, user_id,
    )
    read_ids = {r.get("notification_id") for r in read_rows if r.get("notification_id")}
    return [_wire_notification(r, read_ids) for r in rows]


# Routes
for r in (router, root_router):
    r.add_api_route("", _handle_list_notifications, methods=["GET"])
    r.add_api_route("", _handle_create_notification, methods=["POST"], status_code=201)
    r.add_api_route("/type/{type}", _handle_get_by_type, methods=["GET"])
    r.add_api_route("/{id}", _handle_update_notification, methods=["PUT"])
    r.add_api_route("/{id}/read", _handle_mark_read, methods=["PUT"])
    r.add_api_route("/{id}", _handle_delete_notification, methods=["DELETE"])
