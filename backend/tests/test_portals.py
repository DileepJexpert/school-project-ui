from test_admission_flow import HEADERS, student_payload, structure


def _login(client, email, password):
    response = client.post("/api/auth/login", json={"email": email, "password": password}, headers=HEADERS)
    assert response.status_code == 200, response.text
    return {**HEADERS, "Authorization": f"Bearer {response.json()['token']}"}


def test_student_and_parent_portals_are_linked_to_their_records(client):
    assert client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS
    ).status_code == 200
    first = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    second = client.post(
        "/api/students/add", json={**student_payload(), "fullName": "Ben Rao"}, headers=HEADERS
    ).json()
    assert client.post(
        "/api/users",
        json={"email": "ada@school.test", "password": "student-pass-123", "fullName": "Ada", "role": "STUDENT", "linkedEntityId": first["id"]},
        headers=HEADERS,
    ).status_code == 201
    assert client.post(
        "/api/users",
        json={"email": "parent@school.test", "password": "parent-pass-123", "fullName": "Parent", "role": "PARENT", "linkedEntityId": first["id"]},
        headers=HEADERS,
    ).status_code == 201
    student_headers = _login(client, "ada@school.test", "student-pass-123")
    parent_headers = _login(client, "parent@school.test", "parent-pass-123")
    dashboard = client.get("/api/student-portal/dashboard", headers=student_headers)
    assert dashboard.status_code == 200, dashboard.text
    assert dashboard.json()["studentId"] == first["id"]
    assert dashboard.json()["pendingFees"] == 1700
    assert client.get("/api/student-portal/attendance", headers=student_headers).json() == []
    assert client.get("/api/student-portal/attendance/summary", headers=student_headers).json()["totalDays"] == 0
    assert client.get("/api/student-portal/results", headers=student_headers).json()["studentId"] == first["id"]
    assert client.get("/api/student-portal/timetable", headers=student_headers).json() == []
    assert client.get("/api/student-portal/fees", headers=student_headers).json()["dueFees"] == 1700
    assert client.get("/api/fees/dues", headers=student_headers).status_code == 403

    parent = client.get("/api/parent/dashboard", headers=parent_headers)
    assert parent.status_code == 200, parent.text
    assert [item["studentId"] for item in parent.json()["children"]] == [first["id"]]
    assert client.get(f"/api/parent/child/{first['id']}/fees", headers=parent_headers).status_code == 200
    assert client.get(f"/api/parent/child/{second['id']}/fees", headers=parent_headers).status_code == 403
    assert client.get("/api/students", headers=parent_headers).status_code == 403
