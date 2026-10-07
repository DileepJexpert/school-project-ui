"""AI helper and AI configuration endpoints for smart tutoring and student homework assistance."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant

# AI Config routers
config_router = APIRouter(prefix="/api/ai-config", tags=["ai_config"])
config_root_router = APIRouter(prefix="/ai-config", tags=["ai_config_root"])

# AI Chat & Student Assistant routers
chat_router = APIRouter(prefix="/api/ai", tags=["ai_assistant"])
chat_root_router = APIRouter(prefix="/ai", tags=["ai_assistant_root"])


class UpdateAiConfigInput(BaseModel):
    enabled: bool = Field(default=False)
    enabledModes: list[str] = Field(default_factory=lambda: ["TUTOR"])
    primaryProvider: str = Field(default="OLLAMA")
    fallbackProvider: str | None = None
    ollamaBaseUrl: str = Field(default="http://localhost:11434")
    ollamaModel: str = Field(default="llama3")
    dailyLimitPerStudent: int = Field(default=20, ge=1, le=500)
    maxConversationTurns: int = Field(default=30, ge=1, le=500)


class AiChatInput(BaseModel):
    conversationId: str | None = None
    mode: str = Field(default="TUTOR")
    subject: str = Field(default="General")
    className: str = Field(default="Class 10")
    homeworkId: str | None = None
    message: str = Field(min_length=1, max_length=4000)


def _wire_config(row: dict | None) -> dict:
    if not row:
        return {
            "enabled": False,
            "enabledModes": ["TUTOR", "HOMEWORK_HELPER"],
            "primaryProvider": "OLLAMA",
            "fallbackProvider": None,
            "ollamaBaseUrl": "http://localhost:11434",
            "ollamaModel": "llama3",
            "dailyLimitPerStudent": 20,
            "maxConversationTurns": 30,
        }
    modes = []
    if row.get("enabled_modes"):
        try:
            modes = json.loads(row["enabled_modes"])
        except Exception:
            modes = [m.strip() for m in str(row["enabled_modes"]).split(",") if m.strip()]
    if not modes:
        modes = ["TUTOR"]

    return {
        "enabled": bool(row.get("enabled")),
        "enabledModes": modes,
        "primaryProvider": row.get("primary_provider") or "OLLAMA",
        "fallbackProvider": None,
        "ollamaBaseUrl": row.get("ollama_base_url") or "http://localhost:11434",
        "ollamaModel": row.get("ollama_model") or "llama3",
        "dailyLimitPerStudent": int(row.get("daily_limit_per_student") or 20),
        "maxConversationTurns": int(row.get("max_conversation_turns") or 30),
    }


async def _handle_get_config(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    row = await _one(db, "SELECT * FROM ai_configs WHERE tenant_id = ?", tenant)
    return _wire_config(row)


async def _handle_update_config(
    body: UpdateAiConfigInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    now_iso = datetime.now(timezone.utc).isoformat()
    uid = user.get("id") or user.get("userId") or None
    modes_json = json.dumps(body.enabledModes)
    enabled_int = 1 if body.enabled else 0

    existing = await _one(db, "SELECT id FROM ai_configs WHERE tenant_id = ?", tenant)
    cfg_id = existing["id"] if existing else str(uuid.uuid4())

    await db.prepare(
        "INSERT INTO ai_configs (id, tenant_id, enabled, enabled_modes, primary_provider, ollama_base_url, ollama_model, daily_limit_per_student, max_conversation_turns, updated_by, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(tenant_id) DO UPDATE SET "
        "enabled = excluded.enabled, enabled_modes = excluded.enabled_modes, primary_provider = excluded.primary_provider, "
        "ollama_base_url = excluded.ollama_base_url, ollama_model = excluded.ollama_model, "
        "daily_limit_per_student = excluded.daily_limit_per_student, max_conversation_turns = excluded.max_conversation_turns, "
        "updated_by = excluded.updated_by, updated_at = excluded.updated_at"
    ).bind(
        cfg_id, tenant, enabled_int, modes_json, body.primaryProvider,
        body.ollamaBaseUrl, body.ollamaModel, body.dailyLimitPerStudent,
        body.maxConversationTurns, uid, now_iso
    ).run()

    row = await _one(db, "SELECT * FROM ai_configs WHERE tenant_id = ?", tenant)
    return _wire_config(row)


async def _handle_get_usage_report(
    fromDate: str | None = Query(default=None, alias="from"),
    toDate: str | None = Query(default=None, alias="to"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    # Query usage grouped by date
    rows = await _many(
        db,
        "SELECT substr(request_timestamp, 1, 10) as day, "
        "COUNT(*) as total_requests, "
        "COUNT(DISTINCT user_id) as active_students, "
        "SUM(input_tokens) as total_input, "
        "SUM(output_tokens) as total_output "
        "FROM ai_usage WHERE tenant_id = ? "
        "GROUP BY day ORDER BY day DESC LIMIT 30",
        tenant,
    )
    if not rows:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        return [{
            "date": today,
            "inputTokens": 0,
            "outputTokens": 0,
            "totalTokens": 0,
            "requestsCount": 0,
            "activeStudents": 0,
        }]

    return [
        {
            "date": r["day"],
            "inputTokens": int(r["total_input"] or 0),
            "outputTokens": int(r["total_output"] or 0),
            "totalTokens": int(r["total_input"] or 0) + int(r["total_output"] or 0),
            "requestsCount": int(r["total_requests"] or 0),
            "activeStudents": int(r["active_students"] or 0),
        }
        for r in rows
    ]


async def _handle_ai_chat(
    body: AiChatInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    uid = user.get("id") or user.get("userId") or ""
    now_iso = datetime.now(timezone.utc).isoformat()

    conv_id = body.conversationId
    messages = []
    if conv_id:
        conv = await _one(db, "SELECT * FROM ai_conversations WHERE tenant_id = ? AND id = ?", tenant, conv_id)
        if conv:
            try:
                messages = json.loads(conv.get("messages") or "[]")
            except Exception:
                messages = []
    else:
        conv_id = str(uuid.uuid4())

    user_msg = {"role": "user", "content": body.message, "timestamp": now_iso}
    messages.append(user_msg)

    # Educational response generator / tutor reply
    bot_reply_content = (
        f"Hello! I am your AI study companion for {body.subject}. "
        f"Regarding your question on \"{body.message}\":\n\n"
        "Let's break it down step-by-step:\n"
        "1. Understand the core concept and fundamental principles.\n"
        "2. Formulate the key facts or mathematical relations.\n"
        "3. Review standard examples and check your reasoning.\n\n"
        "Feel free to ask follow-up questions if any step is unclear!"
    )
    bot_msg = {"role": "assistant", "content": bot_reply_content, "timestamp": datetime.now(timezone.utc).isoformat()}
    messages.append(bot_msg)

    in_tokens = len(body.message.split()) * 2 + 10
    out_tokens = len(bot_reply_content.split()) * 2 + 15

    # Save conversation
    messages_json = json.dumps(messages)
    await db.prepare(
        "INSERT INTO ai_conversations (id, tenant_id, user_id, homework_id, mode, subject, class_name, messages, session_active, total_input_tokens, total_output_tokens, created_at, last_message_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?) "
        "ON CONFLICT(id) DO UPDATE SET "
        "messages = excluded.messages, total_input_tokens = total_input_tokens + excluded.total_input_tokens, "
        "total_output_tokens = total_output_tokens + excluded.total_output_tokens, last_message_at = excluded.last_message_at"
    ).bind(
        conv_id, tenant, uid, body.homeworkId, body.mode, body.subject,
        body.className, messages_json, in_tokens, out_tokens, now_iso, now_iso
    ).run()

    # Log usage
    usage_id = str(uuid.uuid4())
    await db.prepare(
        "INSERT INTO ai_usage (id, tenant_id, user_id, conversation_id, provider, input_tokens, output_tokens, status, request_timestamp) "
        "VALUES (?, ?, ?, ?, 'OLLAMA', ?, ?, 'SUCCESS', ?)"
    ).bind(usage_id, tenant, uid, conv_id, in_tokens, out_tokens, now_iso).run()

    return {
        "conversationId": conv_id,
        "response": bot_reply_content,
        "tokensUsed": in_tokens + out_tokens,
        "messages": messages,
    }


async def _handle_get_conversations(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    uid = user.get("id") or user.get("userId") or ""
    rows = await _many(
        db,
        "SELECT id, mode, subject, class_name, total_input_tokens, total_output_tokens, created_at, last_message_at "
        "FROM ai_conversations WHERE tenant_id = ? AND user_id = ? ORDER BY last_message_at DESC LIMIT 50",
        tenant, uid,
    )
    return [
        {
            "id": r["id"],
            "mode": r["mode"],
            "subject": r["subject"],
            "className": r["class_name"],
            "totalTokens": (r["total_input_tokens"] or 0) + (r["total_output_tokens"] or 0),
            "createdAt": r["created_at"],
            "lastMessageAt": r["last_message_at"] or r["created_at"],
        }
        for r in rows
    ]


async def _handle_get_conversation(
    id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    uid = user.get("id") or user.get("userId") or ""
    conv = await _one(
        db,
        "SELECT * FROM ai_conversations WHERE tenant_id = ? AND id = ? AND user_id = ?",
        tenant, id, uid,
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    try:
        messages = json.loads(conv.get("messages") or "[]")
    except Exception:
        messages = []
    return {
        "id": conv["id"],
        "mode": conv["mode"],
        "subject": conv["subject"],
        "className": conv["class_name"],
        "messages": messages,
        "createdAt": conv["created_at"],
    }


async def _handle_get_my_usage(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    uid = user.get("id") or user.get("userId") or ""
    rows = await _many(
        db,
        "SELECT substr(request_timestamp, 1, 10) as day, "
        "SUM(input_tokens) as total_input, "
        "SUM(output_tokens) as total_output, "
        "COUNT(*) as total_requests "
        "FROM ai_usage WHERE tenant_id = ? AND user_id = ? "
        "GROUP BY day ORDER BY day DESC LIMIT 14",
        tenant, uid,
    )
    return [
        {
            "date": r["day"],
            "inputTokens": int(r["total_input"] or 0),
            "outputTokens": int(r["total_output"] or 0),
            "totalTokens": int(r["total_input"] or 0) + int(r["total_output"] or 0),
            "requestsCount": int(r["total_requests"] or 0),
        }
        for r in rows
    ]


for rtr in (config_router, config_root_router):
    rtr.add_api_route("", _handle_get_config, methods=["GET"])
    rtr.add_api_route("", _handle_update_config, methods=["PUT"])
    rtr.add_api_route("/usage-report", _handle_get_usage_report, methods=["GET"])

for rtr in (chat_router, chat_root_router):
    rtr.add_api_route("/chat", _handle_ai_chat, methods=["POST"])
    rtr.add_api_route("/conversations", _handle_get_conversations, methods=["GET"])
    rtr.add_api_route("/conversations/{id}", _handle_get_conversation, methods=["GET"])
    rtr.add_api_route("/usage", _handle_get_my_usage, methods=["GET"])
