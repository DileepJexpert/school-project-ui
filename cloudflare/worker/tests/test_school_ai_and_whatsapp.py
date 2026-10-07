import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user
from school_ai import (
    config_router as ai_cfg_router,
    config_root_router as ai_cfg_root_router,
    chat_router as ai_chat_router,
    chat_root_router as ai_chat_root_router,
)
from school_whatsapp import router as wa_router, root_router as wa_root_router


class Statement:
    def __init__(self, db: sqlite3.Connection, sql: str, bindings=None):
        self.db = db
        self.sql = sql
        self.bindings = bindings or []

    def bind(self, *bindings):
        return Statement(self.db, self.sql, list(bindings))

    async def first(self):
        cur = self.db.execute(self.sql, self.bindings)
        row = cur.fetchone()
        return dict(row) if row else None

    async def all(self):
        cur = self.db.execute(self.sql, self.bindings)
        rows = cur.fetchall()
        return [dict(r) for r in rows]

    async def run(self):
        cur = self.db.execute(self.sql, self.bindings)
        self.db.commit()
        return {"meta": {"changes": cur.rowcount}}


class D1:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def prepare(self, sql: str):
        return Statement(self.db, sql)


def _client():
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT PRIMARY KEY, name TEXT, active INTEGER);
        CREATE TABLE users (id TEXT PRIMARY KEY, tenant_id TEXT, username TEXT, full_name TEXT, role TEXT);
        CREATE TABLE students (id TEXT PRIMARY KEY, tenant_id TEXT, full_name TEXT, class_name TEXT);
        CREATE TABLE ai_configs (
            id TEXT PRIMARY KEY,
            tenant_id TEXT UNIQUE,
            enabled INTEGER,
            enabled_modes TEXT,
            primary_provider TEXT,
            ollama_base_url TEXT,
            ollama_model TEXT,
            daily_limit_per_student INTEGER,
            max_conversation_turns INTEGER,
            updated_by TEXT,
            updated_at TEXT
        );
        CREATE TABLE ai_conversations (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            user_id TEXT,
            homework_id TEXT,
            mode TEXT,
            subject TEXT,
            class_name TEXT,
            messages TEXT,
            session_active INTEGER,
            total_input_tokens INTEGER,
            total_output_tokens INTEGER,
            created_at TEXT,
            last_message_at TEXT
        );
        CREATE TABLE ai_usage (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            user_id TEXT,
            conversation_id TEXT,
            provider TEXT,
            input_tokens INTEGER,
            output_tokens INTEGER,
            status TEXT,
            request_timestamp TEXT
        );

        INSERT INTO tenants VALUES ('risingstar', 'Rising Star School', 1);
        INSERT INTO users VALUES ('user-1', 'risingstar', 'student1', 'Aashvi Sharma', 'STUDENT');
    """)

    app = FastAPI()
    app.include_router(ai_cfg_router)
    app.include_router(ai_cfg_root_router)
    app.include_router(ai_chat_router)
    app.include_router(ai_chat_root_router)
    app.include_router(wa_router)
    app.include_router(wa_root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "user-1",
        "username": "admin",
        "name": "Admin",
        "role": "SUPER_ADMIN",
        "permissions": ["*"],
    }
    return TestClient(app)


def test_ai_config_and_chat():
    client = _client()

    # Get default AI config
    res_get = client.get("/api/ai-config", headers={"X-Tenant-ID": "risingstar"})
    assert res_get.status_code == 200
    assert res_get.json()["enabled"] is False

    # Update AI config
    put_data = {
        "enabled": True,
        "enabledModes": ["TUTOR", "HOMEWORK_HELPER"],
        "primaryProvider": "OLLAMA",
        "ollamaBaseUrl": "http://localhost:11434",
        "ollamaModel": "llama3",
        "dailyLimitPerStudent": 25,
        "maxConversationTurns": 40
    }
    res_put = client.put("/api/ai-config", json=put_data, headers={"X-Tenant-ID": "risingstar"})
    assert res_put.status_code == 200
    assert res_put.json()["enabled"] is True
    assert res_put.json()["dailyLimitPerStudent"] == 25

    # AI Chat
    chat_payload = {
        "mode": "TUTOR",
        "subject": "Mathematics",
        "className": "Class 10",
        "message": "Explain Pythagorean theorem simply"
    }
    res_chat = client.post("/api/ai/chat", json=chat_payload, headers={"X-Tenant-ID": "risingstar"})
    assert res_chat.status_code == 200
    reply = res_chat.json()
    assert "conversationId" in reply
    assert len(reply["response"]) > 0

    # Get AI usage report
    res_rep = client.get("/api/ai-config/usage-report", headers={"X-Tenant-ID": "risingstar"})
    assert res_rep.status_code == 200
    assert len(res_rep.json()) >= 1


def test_whatsapp_config_and_conversations():
    client = _client()

    # Get default WhatsApp config
    res_wa_get = client.get("/api/whatsapp-config", headers={"X-Tenant-ID": "risingstar"})
    assert res_wa_get.status_code == 200
    assert res_wa_get.json()["enabled"] is False

    # Update WhatsApp config
    wa_update = {
        "enabled": True,
        "whatsappBusinessToken": "token123",
        "whatsappPhoneNumberId": "phone123",
        "webhookVerifyToken": "school-whatsapp-verify-2024",
        "welcomeMessage": "Welcome to Rising Star School AI assistant!",
        "enabledFeatures": ["ATTENDANCE", "FEES", "HOMEWORK", "RESULTS"],
        "aiProvider": "OLLAMA",
        "dailyLimitPerParent": 30,
        "defaultLanguage": "en"
    }
    res_wa_put = client.put("/api/whatsapp-config", json=wa_update, headers={"X-Tenant-ID": "risingstar"})
    assert res_wa_put.status_code == 200
    assert res_wa_put.json()["enabled"] is True

    # Send test message
    res_test = client.post("/api/whatsapp-config/test", json={"phone": "+919876543210", "message": "Test message"}, headers={"X-Tenant-ID": "risingstar"})
    assert res_test.status_code == 200
    assert res_test.json()["messageSent"] is True

    # Fetch conversations
    res_convs = client.get("/api/whatsapp-config/conversations", headers={"X-Tenant-ID": "risingstar"})
    assert res_convs.status_code == 200
    assert len(res_convs.json()) >= 1
