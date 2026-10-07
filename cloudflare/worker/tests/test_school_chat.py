import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user
from school_chat import router, root_router


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
        CREATE TABLE students (id TEXT PRIMARY KEY, tenant_id TEXT, full_name TEXT);
        CREATE TABLE chat_rooms (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            participant_1_id TEXT,
            participant_2_id TEXT,
            student_key TEXT,
            created_at TEXT
        );
        CREATE TABLE chat_messages (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            room_id TEXT,
            sender_id TEXT,
            message TEXT,
            message_type TEXT,
            timestamp TEXT,
            read_at TEXT
        );

        INSERT INTO tenants VALUES ('risingstar', 'Rising Star School', 1);
        INSERT INTO users VALUES ('user-1', 'risingstar', 'teacher1', 'Teacher Sharma', 'TEACHER');
        INSERT INTO users VALUES ('user-2', 'risingstar', 'parent1', 'Parent Verma', 'PARENT');
    """)

    app = FastAPI()
    app.include_router(router)
    app.include_router(root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "user-1",
        "username": "teacher1",
        "name": "Teacher Sharma",
        "role": "TEACHER",
    }
    return TestClient(app)


def test_chat_lifecycle():
    client = _client()

    # Create room
    create_payload = {
        "userId1": "user-1",
        "userId2": "user-2",
        "studentId": "",
        "names": {"user-1": "Teacher Sharma", "user-2": "Parent Verma"},
        "roles": {"user-1": "TEACHER", "user-2": "PARENT"}
    }
    res = client.post("/api/chat/rooms", json=create_payload, headers={"X-Tenant-ID": "risingstar"})
    assert res.status_code == 200
    room = res.json()
    room_id = room["id"]
    assert "user-1" in room["participantIds"]
    assert "user-2" in room["participantIds"]

    # Send message
    msg_payload = {
        "senderId": "user-1",
        "senderName": "Teacher Sharma",
        "senderRole": "TEACHER",
        "message": "Hello, how is student doing?",
        "messageType": "TEXT"
    }
    res_msg = client.post(f"/api/chat/rooms/{room_id}/messages", json=msg_payload, headers={"X-Tenant-ID": "risingstar"})
    assert res_msg.status_code == 200
    assert res_msg.json()["message"] == "Hello, how is student doing?"

    # Fetch messages
    res_list = client.get(f"/api/chat/rooms/{room_id}/messages", headers={"X-Tenant-ID": "risingstar"})
    assert res_list.status_code == 200
    msgs = res_list.json()
    assert len(msgs) == 1
    assert msgs[0]["message"] == "Hello, how is student doing?"

    # Get my rooms
    res_rooms = client.get("/api/chat/rooms?userId=user-1", headers={"X-Tenant-ID": "risingstar"})
    assert res_rooms.status_code == 200
    rooms = res_rooms.json()
    assert len(rooms) == 1
    assert rooms[0]["lastMessage"] == "Hello, how is student doing?"

    # Mark as read
    res_read = client.put(f"/api/chat/rooms/{room_id}/read", json={"userId": "user-2"}, headers={"X-Tenant-ID": "risingstar"})
    assert res_read.status_code == 200
    assert res_read.json()["read"] is True
