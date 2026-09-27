from test_admission_flow import HEADERS, student_payload, structure


def test_targeted_notices_and_per_user_read_state(client):
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    student = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    other = client.post("/api/students/add", json={**student_payload(), "fullName": "Ben Rao"}, headers=HEADERS).json()
    for email, linked in (("parent1@school.test", student["id"]), ("parent2@school.test", other["id"])):
        assert client.post("/api/users", json={
            "email": email, "password": "parent-pass-123", "fullName": email,
            "role": "PARENT", "linkedEntityId": linked,
        }, headers=HEADERS).status_code == 201
    notice = client.post("/api/notifications", json={
        "title": "Meeting", "message": "Please attend", "type": "EVENT",
        "targetAudience": "INDIVIDUAL", "targetStudentId": student["id"],
    }, headers=HEADERS)
    assert notice.status_code == 201, notice.text
    notice_id = notice.json()["id"]

    def parent_headers(email):
        login = client.post("/api/auth/login", json={"email": email, "password": "parent-pass-123"}, headers=HEADERS)
        return {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"}

    first = parent_headers("parent1@school.test")
    second = parent_headers("parent2@school.test")
    assert client.get("/api/notifications", headers=first).json()[0]["read"] is False
    assert client.get("/api/notifications", headers=second).json() == []
    assert client.put(f"/api/notifications/{notice_id}/read", headers=first).json()["read"] is True
    assert client.get("/api/notifications", headers=first).json()[0]["read"] is True
    assert client.put(f"/api/notifications/{notice_id}/read", headers=second).status_code == 403
    assert client.get(f"/api/notifications/student/{other['id']}", headers=first).status_code == 403
    assert client.get("/api/notifications", headers=HEADERS).json()[0]["read"] is False
