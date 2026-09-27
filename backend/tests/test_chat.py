from test_admission_flow import HEADERS, student_payload, structure


def test_chat_uses_authenticated_sender_and_room_membership(client):
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    student = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    users = {}
    for name, role, email in (("Parent", "PARENT", "chat-parent@school.test"), ("Teacher", "TEACHER", "chat-teacher@school.test"), ("Other", "TEACHER", "chat-other@school.test")):
        created = client.post("/api/users", json={
            "email": email, "password": "chat-pass-123", "fullName": name,
            "role": role, **({"linkedEntityId": student["id"]} if role == "PARENT" else {}),
        }, headers=HEADERS)
        assert created.status_code == 201, created.text
        login = client.post("/api/auth/login", json={"email": email, "password": "chat-pass-123"}, headers=HEADERS)
        users[name] = (created.json()["id"], {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"})
    parent_id, parent_headers = users["Parent"]
    teacher_id, teacher_headers = users["Teacher"]
    other_id, other_headers = users["Other"]
    contacts = client.get("/api/users", headers=parent_headers)
    assert contacts.status_code == 200, contacts.text
    assert teacher_id in {item["id"] for item in contacts.json()}
    assert parent_id not in {item["id"] for item in contacts.json()}
    room = client.post("/api/chat/rooms", json={
        "userId1": parent_id, "userId2": teacher_id, "studentId": student["id"],
        "names": {}, "roles": {},
    }, headers=parent_headers)
    assert room.status_code == 200, room.text
    room_id = room.json()["id"]
    assert client.get(f"/api/chat/rooms?userId={teacher_id}", headers=parent_headers).status_code == 403
    assert client.get(f"/api/chat/rooms?userId={parent_id}", headers=parent_headers).json()[0]["id"] == room_id
    assert client.get(f"/api/chat/rooms/{room_id}/messages", headers=other_headers).status_code == 403
    assert client.post(f"/api/chat/rooms/{room_id}/messages", json={
        "senderId": other_id, "message": "Forged",
    }, headers=parent_headers).status_code == 403
    sent = client.post(f"/api/chat/rooms/{room_id}/messages", json={
        "senderId": parent_id, "message": "Hello",
    }, headers=parent_headers)
    assert sent.status_code == 200, sent.text
    assert sent.json()["senderId"] == parent_id
    assert client.get(f"/api/chat/rooms?userId={teacher_id}", headers=teacher_headers).json()[0]["unreadCounts"][teacher_id] == 1
    assert client.put(f"/api/chat/rooms/{room_id}/read", json={"userId": teacher_id}, headers=teacher_headers).status_code == 200
    assert client.get(f"/api/chat/rooms?userId={teacher_id}", headers=teacher_headers).json()[0]["unreadCounts"][teacher_id] == 0
