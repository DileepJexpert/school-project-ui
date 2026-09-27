from test_admission_flow import HEADERS, student_payload, structure


def _students(client):
    assert client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS
    ).status_code == 200
    results = []
    for name in ("Ada Rao", "Ben Rao"):
        response = client.post(
            "/api/students/add", json={**student_payload(), "fullName": name}, headers=HEADERS
        )
        assert response.status_code == 201, response.text
        results.append(response.json())
    return results


def test_attendance_requires_exact_roster_and_date_year(client):
    students = _students(client)
    entries = [
        {"studentId": students[0]["id"], "studentName": "Ada Rao", "status": "PRESENT"},
        {"studentId": students[1]["id"], "studentName": "Ben Rao", "status": "ABSENT"},
    ]
    payload = {
        "className": "Class 5 - A",
        "academicYear": "2026-2027",
        "date": "2026-09-24",
        "markedBy": "Admin",
        "entries": entries,
    }
    assert client.post("/api/attendance/mark", json={**payload, "entries": entries[:1]}, headers=HEADERS).status_code == 409
    assert client.post("/api/attendance/mark", json={**payload, "date": "2027-04-01"}, headers=HEADERS).status_code == 422
    assert client.post("/api/attendance/mark", json={**payload, "entries": entries + entries[:1]}, headers=HEADERS).status_code == 422
    assert client.get("/api/attendance/class/Class 5 - A", params={"date": "2026-09-24"}, headers=HEADERS).json() == []

    marked = client.post("/api/attendance/mark", json=payload, headers=HEADERS)
    assert marked.status_code == 200, marked.text
    assert len(marked.json()) == 2
    corrected = client.post(
        "/api/attendance/mark",
        json={**payload, "entries": [{**entries[0], "status": "LATE"}, entries[1]]},
        headers=HEADERS,
    )
    assert corrected.status_code == 200
    assert corrected.json()[0]["id"] == marked.json()[0]["id"]
    by_date = client.get("/api/attendance/class/Class 5 - A", params={"date": "2026-09-24"}, headers=HEADERS).json()
    assert {item["status"] for item in by_date} == {"LATE", "ABSENT"}
    assert client.get(
        "/api/attendance/class/Class 5 - A/range",
        params={"from": "2026-09-01", "to": "2026-09-30", "academicYear": "2026-2027"},
        headers=HEADERS,
    ).json() == by_date
    assert len(client.get(
        f"/api/attendance/student/{students[0]['id']}",
        params={"from": "2026-09-01", "to": "2026-09-30"},
        headers=HEADERS,
    ).json()) == 1
    summary = client.get(
        f"/api/attendance/student/{students[0]['id']}/summary",
        params={"academicYear": "2026-2027"}, headers=HEADERS,
    ).json()
    assert summary["totalDays"] == 1
    assert summary["lateDays"] == 1
    assert summary["attendancePercentage"] == 100
    assert client.get(
        f"/api/attendance/student/{students[0]['id']}/summary",
        params={"academicYear": "2026-2027"}, headers={"X-Tenant-ID": "school-b"},
    ).status_code == 403

    assert client.delete(f"/api/attendance/{marked.json()[0]['id']}", headers=HEADERS).status_code == 204
    assert len(client.get("/api/attendance/class/Class 5 - A", params={"date": "2026-09-24"}, headers=HEADERS).json()) == 1
    revived = client.post("/api/attendance/mark", json=payload, headers=HEADERS)
    assert revived.status_code == 200
    assert revived.json()[0]["id"] == marked.json()[0]["id"]
