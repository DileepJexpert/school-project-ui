"""Private tenant chat; sender and membership come from the token."""

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import ChatMessage, ChatRoom, Student, User
from app.schemas import ChatMessageInput, ChatReadInput, ChatRoomInput

router = APIRouter(prefix="/chat", tags=["chat"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _room(session: Session, tenant: str, room_id: str, user_id: str) -> ChatRoom:
    room = session.get(ChatRoom, room_id)
    if room is None or room.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Chat room not found")
    if user_id not in (room.participant_1_id, room.participant_2_id):
        raise HTTPException(status_code=403, detail="Not a participant in this room")
    return room


def _room_wire(session: Session, item: ChatRoom) -> dict:
    first = session.get(User, item.participant_1_id)
    second = session.get(User, item.participant_2_id)
    student = session.get(Student, item.student_key) if item.student_key else None
    last = session.scalar(select(ChatMessage).where(ChatMessage.room_id == item.id).order_by(ChatMessage.timestamp.desc(), ChatMessage.id.desc()).limit(1))
    unread = {}
    for participant in (first, second):
        unread[participant.id] = sum(1 for msg in session.scalars(select(ChatMessage).where(
            ChatMessage.room_id == item.id, ChatMessage.sender_id != participant.id,
            ChatMessage.read_at.is_(None),
        )))
    return {
        "id": item.id,
        "participants": [first.id, second.id],
        "participantNames": {first.id: first.full_name, second.id: second.full_name},
        "participantRoles": {first.id: first.role, second.id: second.role},
        "studentId": item.student_key, "studentName": student.full_name if student else "",
        "lastMessage": last.message if last else None,
        "lastMessageAt": aware(last.timestamp).isoformat() if last else None,
        "unreadCounts": unread, "createdAt": aware(item.created_at).isoformat(),
    }


def _message_wire(session: Session, item: ChatMessage) -> dict:
    sender = session.get(User, item.sender_id)
    return {
        "id": item.id, "roomId": item.room_id, "senderId": sender.id,
        "senderName": sender.full_name, "senderRole": sender.role,
        "message": item.message, "messageType": item.message_type,
        "attachmentUrl": None, "read": item.read_at is not None,
        "timestamp": aware(item.timestamp).isoformat(),
    }


@router.get("/rooms")
def my_rooms(request: Request, session: Db, tenant: TenantId, user_id: str = Query(alias="userId")) -> list[dict]:
    if user_id != request.state.user_id:
        raise HTTPException(status_code=403, detail="Can list only own chat rooms")
    require_tenant(session, tenant)
    rooms = session.scalars(select(ChatRoom).where(
        ChatRoom.tenant_id == tenant,
        (ChatRoom.participant_1_id == user_id) | (ChatRoom.participant_2_id == user_id),
    ).order_by(ChatRoom.created_at.desc()))
    return [_room_wire(session, item) for item in rooms]


@router.post("/rooms")
def get_or_create_room(data: ChatRoomInput, request: Request, session: Db, tenant: TenantId) -> dict:
    if request.state.user_id not in (data.user_id1, data.user_id2) or data.user_id1 == data.user_id2:
        raise HTTPException(status_code=403, detail="Caller must be one of two different participants")
    with session.begin():
        lock_tenant(session, tenant)
        first_id, second_id = sorted((data.user_id1, data.user_id2))
        first = session.get(User, first_id)
        second = session.get(User, second_id)
        if first is None or second is None or any(user.tenant_id != tenant or not user.active for user in (first, second)):
            raise HTTPException(status_code=404, detail="Chat participant not found in school")
        if data.student_id:
            student = session.get(Student, data.student_id)
            if student is None or student.tenant_id != tenant:
                raise HTTPException(status_code=404, detail="Chat student not found in school")
            for user in (first, second):
                if user.role in ("STUDENT", "PARENT"):
                    linked = {part.strip() for part in (user.linked_entity_id or "").split(",")}
                    if student.id not in linked:
                        raise HTTPException(status_code=403, detail="Student not linked to chat participant")
        room = session.scalar(select(ChatRoom).where(
            ChatRoom.tenant_id == tenant, ChatRoom.participant_1_id == first_id,
            ChatRoom.participant_2_id == second_id, ChatRoom.student_key == data.student_id,
        ))
        if room is None:
            room = ChatRoom(
                tenant_id=tenant, participant_1_id=first_id, participant_2_id=second_id,
                student_key=data.student_id, created_at=datetime.now(timezone.utc),
            )
            session.add(room)
            session.flush()
        result = _room_wire(session, room)
    return result


@router.get("/rooms/{room_id}/messages")
def messages(room_id: str, request: Request, session: Db, tenant: TenantId, page: int = Query(0, ge=0), size: int = Query(50, ge=1, le=100)) -> list[dict]:
    _room(session, tenant, room_id, request.state.user_id)
    return [_message_wire(session, item) for item in session.scalars(select(ChatMessage).where(
        ChatMessage.tenant_id == tenant, ChatMessage.room_id == room_id,
    ).order_by(ChatMessage.timestamp.desc(), ChatMessage.id.desc()).offset(page * size).limit(size))]


@router.post("/rooms/{room_id}/messages")
def send_message(room_id: str, data: ChatMessageInput, request: Request, session: Db, tenant: TenantId) -> dict:
    if data.sender_id and data.sender_id != request.state.user_id:
        raise HTTPException(status_code=403, detail="senderId does not match token")
    with session.begin():
        lock_tenant(session, tenant)
        _room(session, tenant, room_id, request.state.user_id)
        item = ChatMessage(
            tenant_id=tenant, room_id=room_id, sender_id=request.state.user_id,
            message=data.message.strip(), message_type="TEXT", timestamp=datetime.now(timezone.utc),
        )
        if not item.message:
            raise HTTPException(status_code=422, detail="Message cannot be blank")
        session.add(item)
        session.flush()
        result = _message_wire(session, item)
    return result


@router.put("/rooms/{room_id}/read")
def mark_read(room_id: str, request: Request, session: Db, tenant: TenantId, data: ChatReadInput | None = None, user_id: str | None = Query(default=None, alias="userId")) -> Response:
    if (data and data.user_id and data.user_id != request.state.user_id) or (user_id and user_id != request.state.user_id):
        raise HTTPException(status_code=403, detail="Can mark only own messages read")
    with session.begin():
        lock_tenant(session, tenant)
        _room(session, tenant, room_id, request.state.user_id)
        for item in session.scalars(select(ChatMessage).where(
            ChatMessage.tenant_id == tenant, ChatMessage.room_id == room_id,
            ChatMessage.sender_id != request.state.user_id, ChatMessage.read_at.is_(None),
        )):
            item.read_at = datetime.now(timezone.utc)
    return Response(status_code=200)
