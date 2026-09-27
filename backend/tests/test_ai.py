from test_admission_flow import HEADERS, student_payload, structure


def test_optional_ai_config_usage_and_conversation_ownership(client, monkeypatch):
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    student = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    assert client.post("/api/users", json={
        "email": "ai-student@school.test", "password": "student-pass-123",
        "fullName": "Ada", "role": "STUDENT", "linkedEntityId": student["id"],
    }, headers=HEADERS).status_code == 201
    login = client.post("/api/auth/login", json={
        "email": "ai-student@school.test", "password": "student-pass-123",
    }, headers=HEADERS)
    student_headers = {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"}
    disabled = client.post("/api/ai/chat", json={"message": "How do fractions work?"}, headers=student_headers)
    assert disabled.status_code == 409
    config = client.put("/api/ai-config", json={
        "enabled": True, "enabledModes": ["TUTOR"],
        "primaryProvider": "OLLAMA", "fallbackProvider": None,
        "ollamaBaseUrl": "http://localhost:11434", "ollamaModel": "test-model",
        "dailyLimitPerStudent": 1, "maxConversationTurns": 2,
    }, headers=HEADERS)
    assert config.status_code == 200, config.text
    assert client.get("/api/ai-config", headers=student_headers).status_code == 403
    from app.routers import ai
    monkeypatch.setattr(ai, "call_ollama", lambda base, model, messages: ("A fraction is part of a whole.", 5, 8))
    reply = client.post("/api/ai/chat", json={"message": "How do fractions work?"}, headers=student_headers)
    assert reply.status_code == 200, reply.text
    assert reply.json()["dailyUsage"] == {"questionsToday": 1, "limitPerDay": 1}
    conv_id = reply.json()["conversationId"]
    assert client.get(f"/api/ai/conversations/{conv_id}", headers=student_headers).json()["messages"][-1]["role"] == "ASSISTANT"
    assert client.get("/api/ai/usage", headers=student_headers).json()[0]["success"] is True
    assert client.post("/api/ai/chat", json={"message": "Another question"}, headers=student_headers).status_code == 429
