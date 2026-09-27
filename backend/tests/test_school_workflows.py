from test_admission_flow import HEADERS, student_payload, structure


def _student(client):
    assert client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS).status_code == 200
    response = client.post("/api/students/add", json=student_payload(), headers=HEADERS)
    assert response.status_code == 201, response.text
    return response.json()


def test_homework_student_portal_is_year_scoped(client):
    student = _student(client)
    posted = client.post("/api/homework", json={
        "title": "Fractions", "description": "Page 10", "className": "Class 5 - A",
        "subject": "Math", "assignedDate": "2026-09-24", "dueDate": "2026-10-01",
        "academicYear": "2026-2027",
    }, headers=HEADERS)
    assert posted.status_code == 201, posted.text
    item = posted.json()
    assert item["academicYear"] == "2026-2027"
    assert client.post("/api/users", json={
        "email": "homework-student@school.test", "password": "student-pass-123",
        "fullName": "Ada", "role": "STUDENT", "linkedEntityId": student["id"],
    }, headers=HEADERS).status_code == 201
    login = client.post("/api/auth/login", json={
        "email": "homework-student@school.test", "password": "student-pass-123",
    }, headers=HEADERS)
    linked_headers = {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"}
    found = client.get("/api/student-portal/homework", headers=linked_headers)
    assert found.status_code == 200, found.text
    assert found.json()[0]["id"] == item["id"]
    assert client.get("/api/homework", headers=linked_headers).status_code == 403
    assert client.delete(f"/api/homework/{item['id']}", headers=HEADERS).status_code == 204
    assert client.get("/api/student-portal/homework", headers=linked_headers).json() == []


def test_incident_and_certificate_snapshots(client):
    student = _student(client)
    incident = client.post("/api/discipline", json={
        "studentId": student["id"], "severity": "WARNING", "category": "BEHAVIORAL",
        "description": "Classroom disruption", "incidentDate": "2026-09-20",
    }, headers=HEADERS)
    assert incident.status_code == 200, incident.text
    assert incident.json()["studentName"] == student["fullName"]
    assert client.get("/api/discipline/summary", headers=HEADERS).json()["unresolvedIncidents"] == 1
    resolved = client.put(f"/api/discipline/{incident.json()['id']}/resolve", json={"resolution": "Meeting held"}, headers=HEADERS)
    assert resolved.status_code == 200, resolved.text
    assert resolved.json()["resolved"] is True
    cert = client.post("/api/certificates/generate", json={
        "studentId": student["id"], "certificateType": "BONAFIDE", "reason": "Application",
    }, headers=HEADERS)
    assert cert.status_code == 200, cert.text
    assert cert.json()["serialNumber"] == "BF-1001"
    assert client.get(f"/api/certificates/student/{student['id']}", headers=HEADERS).json()[0]["id"] == cert.json()["id"]
    assert client.get("/api/certificates/type/BONAFIDE", headers=HEADERS).json()[0]["id"] == cert.json()["id"]
