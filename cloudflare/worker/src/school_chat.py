"""Real-time and asynchronous chat endpoints between teachers, parents, students, and staff."""

from __future__ import annotations

from datetime import datetime, timezone
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant

router = APIRouter(prefix="/api/chat", tags=["chat"])
root_router = APIRouter(prefix="/chat", tags=["chat_root"])


class CreateRoomInput(BaseModel):
    userId1: str = Field(min_length=1)
    userId2: str = Field(min_length=1)
    studentId: str | None = ""
    names: dict[str, str] = Field(default_factory=dict)
    roles: dict[str, str] = Field(default_factory=dict)


class SendMessageInput(BaseModel):
    senderId: str = Field(min_length=1)
    senderName: str | None = ""
    senderRole: str | None = ""
    message: str = Field(min_length=1, max_length=4000)
    messageType: str = Field(default="TEXT")


class ReadInput(BaseModel):
    userId: str = Field(min_length=1)


async def _enrich_room(db, tenant: str, r: dict, current_user_id: str) -> dict:
    p1 = r["participant_1_id"]
    p2 = r["participant_2_id"]

    # Fetch users for p1 and p2
    u1 = await _one(db, "SELECT id, full_name, role FROM users WHERE tenant_id = ? AND id = ?", tenant, p1)
    u2 = await _one(db, "SELECT id, full_name, role FROM users WHERE tenant_id = ? AND id = ?", tenant, p2)

    p_names = {
        p1: (u1["full_name"] if u1 else "User"),
        p2: (u2["full_name"] if u2 else "User"),
    }
    p_roles = {
        p1: (u1["role"] if u1 else "MEMBER"),
        p2: (u2["role"] if u2 else "MEMBER"),
    }

    # Fetch student name if student_key is present
    student_name = ""
    if r.get("student_key"):
        stu = await _one(db, "SELECT full_name FROM students WHERE tenant_id = ? AND id = ?", tenant, r["student_key"])
        if stu:
            student_name = stu["full_name"]

    # Fetch last message
    last_msg_row = await _one(
        db,
        "SELECT message, timestamp, sender_id FROM chat_messages WHERE tenant_id = ? AND room_id = ? ORDER BY timestamp DESC LIMIT 1",
        tenant, r["id"],
    )
    last_message = last_msg_row["message"] if last_msg_row else ""
    last_timestamp = last_msg_row["timestamp"] if last_msg_row else r["created_at"]

    # Unread counts
    unread_p1 = await _one(
        db,
        "SELECT COUNT(*) as cnt FROM chat_messages WHERE tenant_id = ? AND room_id = ? AND sender_id != ? AND read_at IS NULL",
        tenant, r["id"], p1,
    )
    unread_p2 = await _one(
        db,
        "SELECT COUNT(*) as cnt FROM chat_messages WHERE tenant_id = ? AND room_id = ? AND sender_id != ? AND read_at IS NULL",
        tenant, r["id"], p2,
    )
    unread_counts = {
        p1: int(unread_p1["cnt"]) if unread_p1 else 0,
        p2: int(unread_p2["cnt"]) if unread_p2 else 0,
    }

    return {
        "id": r["id"],
        "participantIds": [p1, p2],
        "participantNames": p_names,
        "participantRoles": p_roles,
        "studentId": r.get("student_key") or "",
        "studentName": student_name,
        "lastMessage": last_message,
        "lastMessageTimestamp": last_timestamp,
        "unreadCounts": unread_counts,
        "createdAt": r["created_at"],
    }


async def _handle_get_rooms(
    userId: str = Query(...),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    uid = userId.strip() or user.get("id") or user.get("userId") or ""
    rows = await _many(
        db,
        "SELECT * FROM chat_rooms WHERE tenant_id = ? AND (participant_1_id = ? OR participant_2_id = ?) ORDER BY created_at DESC",
        tenant, uid, uid,
    )
    results = []
    for r in rows:
        enriched = await _enrich_room(db, tenant, r, uid)
        results.append(enriched)

    # Sort rooms by latest activity
    results.sort(key=lambda x: x.get("lastMessageTimestamp") or x.get("createdAt") or "", reverse=True)
    return results


async def _handle_create_or_get_room(
    body: CreateRoomInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    u1 = body.userId1.strip()
    u2 = body.userId2.strip()
    s_key = (body.studentId or "").strip()

    # Search for existing room between u1 and u2
    existing = await _one(
        db,
        "SELECT * FROM chat_rooms WHERE tenant_id = ? AND "
        "((participant_1_id = ? AND participant_2_id = ?) OR (participant_1_id = ? AND participant_2_id = ?))",
        tenant, u1, u2, u2, u1,
    )
    if existing:
        return await _enrich_room(db, tenant, existing, u1)

    new_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "INSERT INTO chat_rooms (id, tenant_id, participant_1_id, participant_2_id, student_key, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?)"
    ).bind(new_id, tenant, u1, u2, s_key, now_iso).run()

    created = await _one(db, "SELECT * FROM chat_rooms WHERE tenant_id = ? AND id = ?", tenant, new_id)
    return await _enrich_room(db, tenant, created or {"id": new_id, "participant_1_id": u1, "participant_2_id": u2, "student_key": s_key, "created_at": now_iso}, u1)


async def _handle_get_messages(
    roomId: str,
    page: int = Query(default=0, ge=0),
    size: int = Query(default=50, ge=1, le=200),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    offset = page * size
    rows = await _many(
        db,
        "SELECT m.*, u.full_name as sender_name, u.role as sender_role "
        "FROM chat_messages m "
        "LEFT JOIN users u ON m.sender_id = u.id AND m.tenant_id = u.tenant_id "
        "WHERE m.tenant_id = ? AND m.room_id = ? "
        "ORDER BY m.timestamp DESC LIMIT ? OFFSET ?",
        tenant, roomId, size, offset,
    )
    return [
        {
            "id": r["id"],
            "roomId": r["room_id"],
            "senderId": r["sender_id"],
            "senderName": r.get("sender_name") or "User",
            "senderRole": r.get("sender_role") or "MEMBER",
            "message": r["message"],
            "messageType": r["message_type"],
            "timestamp": r["timestamp"],
            "readAt": r.get("read_at"),
        }
        for r in rows
    ]


async def _handle_send_message(
    roomId: str,
    body: SendMessageInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    room = await _one(db, "SELECT * FROM chat_rooms WHERE tenant_id = ? AND id = ?", tenant, roomId)
    if not room:
        raise HTTPException(status_code=404, detail="Chat room not found")

    msg_id = str(uuid.uuid4())
    sender_id = body.senderId or user.get("id") or user.get("userId") or ""
    now_iso = datetime.now(timezone.utc).isoformat()
    m_type = body.messageType.upper() if body.messageType else "TEXT"

    await db.prepare(
        "INSERT INTO chat_messages (id, tenant_id, room_id, sender_id, message, message_type, timestamp, read_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, NULL)"
    ).bind(msg_id, tenant, roomId, sender_id, body.message, m_type, now_iso).run()

    return {
        "id": msg_id,
        "roomId": roomId,
        "senderId": sender_id,
        "senderName": body.senderName or user.get("name") or "User",
        "senderRole": body.senderRole or user.get("role") or "MEMBER",
        "message": body.message,
        "messageType": m_type,
        "timestamp": now_iso,
        "readAt": None,
    }


async def _handle_mark_as_read(
    roomId: str,
    body: ReadInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE chat_messages SET read_at = ? "
        "WHERE tenant_id = ? AND room_id = ? AND sender_id != ? AND read_at IS NULL"
    ).bind(now_iso, tenant, roomId, body.userId).run()
    return {"success": True, "read": True}


for rtr in (router, root_router):
    rtr.add_api_route("/rooms", _handle_get_rooms, methods=["GET"])
    rtr.add_api_route("/rooms", _handle_create_or_get_room, methods=["POST"])
    rtr.add_api_route("/rooms/{roomId}/messages", _handle_get_messages, methods=["GET"])
    rtr.add_api_route("/rooms/{roomId}/messages", _handle_send_message, methods=["POST"])
    rtr.add_api_route("/rooms/{roomId}/read", _handle_mark_as_read, methods=["PUT"])
