"""Optional Ollama homework helper with school controls and per-student limits."""

from datetime import date, datetime, time, timezone
from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import AiConfig, AiConversation, AiUsage, Homework, Student, User
from app.schemas import AiChatInput, AiConfigInput

config_router = APIRouter(prefix="/ai-config", tags=["ai config"])
chat_router = APIRouter(prefix="/ai", tags=["ai"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _config_wire(item: AiConfig | None) -> dict:
    return {
        "enabled": item.enabled if item else False,
        "enabledModes": item.enabled_modes if item else ["TUTOR"],
        "primaryProvider": item.primary_provider if item else "OLLAMA",
        "fallbackProvider": None,
        "ollamaBaseUrl": item.ollama_base_url if item else "http://localhost:11434",
        "ollamaModel": item.ollama_model if item else "llama3",
        "geminiApiKey": None, "claudeApiKey": None,
        "dailyLimitPerStudent": item.daily_limit_per_student if item else 20,
        "maxConversationTurns": item.max_conversation_turns if item else 30,
    }


def _conversation_wire(item: AiConversation) -> dict:
    return {
        "id": item.id, "studentId": item.user_id, "homeworkId": item.homework_id,
        "mode": item.mode, "subject": item.subject, "className": item.class_name,
        "messages": item.messages, "sessionActive": item.session_active,
        "totalInputTokens": item.total_input_tokens,
        "totalOutputTokens": item.total_output_tokens,
        "createdAt": aware(item.created_at).isoformat(),
        "lastMessageAt": aware(item.last_message_at).isoformat() if item.last_message_at else None,
    }


def _usage_wire(item: AiUsage) -> dict:
    return {
        "id": item.id, "studentId": item.user_id, "conversationId": item.conversation_id,
        "provider": item.provider, "inputTokens": item.input_tokens,
        "outputTokens": item.output_tokens, "success": item.status == "SUCCESS",
        "status": item.status, "requestTimestamp": aware(item.request_timestamp).isoformat(),
    }


@config_router.get("")
def get_config(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    return _config_wire(session.scalar(select(AiConfig).where(AiConfig.tenant_id == tenant)))


@config_router.put("")
def put_config(data: AiConfigInput, request: Request, session: Db, tenant: TenantId) -> dict:
    if not data.ollama_base_url.startswith(("http://", "https://")):
        raise HTTPException(status_code=422, detail="Ollama URL must use HTTP or HTTPS")
    with session.begin():
        lock_tenant(session, tenant)
        item = session.scalar(select(AiConfig).where(AiConfig.tenant_id == tenant))
        if item is None:
            item = AiConfig(tenant_id=tenant)
            session.add(item)
        item.enabled = data.enabled
        item.enabled_modes = list(dict.fromkeys(data.enabled_modes))
        item.primary_provider = "OLLAMA"
        item.ollama_base_url = data.ollama_base_url.rstrip("/")
        item.ollama_model = data.ollama_model
        item.daily_limit_per_student = data.daily_limit_per_student
        item.max_conversation_turns = data.max_conversation_turns
        item.updated_by = request.state.user_id
        item.updated_at = datetime.now(timezone.utc)
        result = _config_wire(item)
    return result


@config_router.get("/usage-report")
def usage_report(session: Db, tenant: TenantId, from_date: date = Query(alias="from"), to_date: date = Query(alias="to")) -> list[dict]:
    require_tenant(session, tenant)
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")
    start = datetime.combine(from_date, time.min, timezone.utc)
    end = datetime.combine(to_date, time.max, timezone.utc)
    return [_usage_wire(item) for item in session.scalars(select(AiUsage).where(
        AiUsage.tenant_id == tenant, AiUsage.request_timestamp >= start,
        AiUsage.request_timestamp <= end,
    ).order_by(AiUsage.request_timestamp.desc()))]


def call_ollama(base_url: str, model: str, messages: list[dict]) -> tuple[str, int, int]:
    try:
        response = httpx.post(
            f"{base_url}/api/chat",
            json={"model": model, "messages": [{"role": item["role"].lower(), "content": item["content"]} for item in messages], "stream": False},
            timeout=60.0,
        )
        response.raise_for_status()
        body = response.json()
        content = body["message"]["content"]
        if not isinstance(content, str) or not content.strip():
            raise ValueError("Ollama returned an empty message")
        return content, int(body.get("prompt_eval_count") or 0), int(body.get("eval_count") or 0)
    except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
        raise HTTPException(status_code=503, detail="AI provider unavailable") from error


def _own_conversation(session: Session, tenant: str, user_id: str, conversation_id: str) -> AiConversation:
    item = session.get(AiConversation, conversation_id)
    if item is None or item.tenant_id != tenant or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return item


@chat_router.get("/conversations")
def conversations(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    return [_conversation_wire(item) for item in session.scalars(select(AiConversation).where(
        AiConversation.tenant_id == tenant, AiConversation.user_id == request.state.user_id,
    ).order_by(AiConversation.created_at.desc()))]


@chat_router.get("/conversations/{conversation_id}")
def conversation(conversation_id: str, request: Request, session: Db, tenant: TenantId) -> dict:
    return _conversation_wire(_own_conversation(session, tenant, request.state.user_id, conversation_id))


@chat_router.get("/usage")
def usage(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    return [_usage_wire(item) for item in session.scalars(select(AiUsage).where(
        AiUsage.tenant_id == tenant, AiUsage.user_id == request.state.user_id,
    ).order_by(AiUsage.request_timestamp.desc()))]


@chat_router.post("/chat")
def chat(data: AiChatInput, request: Request, session: Db, tenant: TenantId) -> dict:
    now = datetime.now(timezone.utc)
    user_id = request.state.user_id
    with session.begin():
        lock_tenant(session, tenant)
        config = session.scalar(select(AiConfig).where(AiConfig.tenant_id == tenant))
        if config is None or not config.enabled:
            raise HTTPException(status_code=409, detail="AI Homework Helper is disabled for this school")
        if data.mode not in config.enabled_modes:
            raise HTTPException(status_code=409, detail="AI mode is not enabled")
        user = session.get(User, user_id)
        student = session.get(Student, user.linked_entity_id) if user.linked_entity_id else None
        if student is None or student.tenant_id != tenant:
            raise HTTPException(status_code=403, detail="Linked student required")
        start_today = datetime.combine(now.date(), time.min, timezone.utc)
        count = session.scalar(select(func.count()).select_from(AiUsage).where(
            AiUsage.tenant_id == tenant, AiUsage.user_id == user_id,
            AiUsage.request_timestamp >= start_today,
            AiUsage.status.in_(["PENDING", "SUCCESS"]),
        )) or 0
        if count >= config.daily_limit_per_student:
            raise HTTPException(status_code=429, detail="Daily AI limit reached")
        existing = _own_conversation(session, tenant, user_id, data.conversation_id) if data.conversation_id else None
        if existing:
            if existing.mode != data.mode or (data.homework_id and existing.homework_id != data.homework_id):
                raise HTTPException(status_code=409, detail="Conversation context differs")
            if not existing.session_active or sum(item["role"] == "USER" for item in existing.messages) >= config.max_conversation_turns:
                raise HTTPException(status_code=409, detail="Conversation turn limit reached")
            prior = list(existing.messages)
            subject, class_name, homework_id = existing.subject, existing.class_name, existing.homework_id
        else:
            homework = session.get(Homework, data.homework_id) if data.homework_id else None
            if data.homework_id and (homework is None or homework.tenant_id != tenant or homework.deleted_at or homework.class_name != student.class_name or homework.academic_year != student.academic_year):
                raise HTTPException(status_code=404, detail="Homework not assigned to student")
            subject = homework.subject if homework else ""
            class_name = student.class_name
            homework_id = homework.id if homework else None
            prior = [{"role": "SYSTEM", "content": f"You are a school tutor for {class_name}. Help the learner reason through the question, in {data.language}. Subject: {subject or 'general'}. Do not claim to know school-specific facts."}]
        reservation = AiUsage(
            tenant_id=tenant, user_id=user_id, provider="OLLAMA", status="PENDING",
            request_timestamp=now,
        )
        session.add(reservation)
        session.flush()
        reservation_id = reservation.id
        base_url, model, daily_limit = config.ollama_base_url, config.ollama_model, config.daily_limit_per_student
    prompt = prior + [{"role": "USER", "content": data.message.strip()}]
    try:
        answer, input_tokens, output_tokens = call_ollama(base_url, model, prompt)
    except HTTPException:
        with session.begin():
            usage_item = session.get(AiUsage, reservation_id)
            usage_item.status = "FAILED"
        raise
    with session.begin():
        lock_tenant(session, tenant)
        item = _own_conversation(session, tenant, user_id, data.conversation_id) if data.conversation_id else None
        if item is None:
            item = AiConversation(
                tenant_id=tenant, user_id=user_id, homework_id=homework_id,
                mode=data.mode, subject=subject, class_name=class_name,
                messages=[], session_active=True, total_input_tokens=0,
                total_output_tokens=0, created_at=now,
            )
            session.add(item)
            session.flush()
        timestamp = datetime.now(timezone.utc)
        appended = [
            {"role": "USER", "content": data.message.strip(), "timestamp": timestamp.isoformat()},
            {"role": "ASSISTANT", "content": answer, "timestamp": timestamp.isoformat()},
        ]
        item.messages = (list(item.messages) if data.conversation_id else prior) + appended
        item.total_input_tokens += input_tokens
        item.total_output_tokens += output_tokens
        item.last_message_at = timestamp
        usage_item = session.get(AiUsage, reservation_id)
        usage_item.status = "SUCCESS"
        usage_item.conversation_id = item.id
        usage_item.input_tokens = input_tokens
        usage_item.output_tokens = output_tokens
        session.flush()
        questions_today = session.scalar(select(func.count()).select_from(AiUsage).where(
            AiUsage.tenant_id == tenant, AiUsage.user_id == user_id,
            AiUsage.request_timestamp >= datetime.combine(now.date(), time.min, timezone.utc),
            AiUsage.status == "SUCCESS",
        )) or 0
        result = {
            "conversationId": item.id, "message": answer, "mode": data.mode,
            "provider": "OLLAMA", "tokensUsed": {"input": input_tokens, "output": output_tokens},
            "dailyUsage": {"questionsToday": questions_today, "limitPerDay": daily_limit},
        }
    return result
