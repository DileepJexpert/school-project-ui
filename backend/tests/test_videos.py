from test_admission_flow import HEADERS, student_payload, structure
from pathlib import Path


def test_video_upload_storage_and_linked_student_read(client, monkeypatch):
    storage = Path.cwd() / "data" / "video-test"
    monkeypatch.setenv("VIDEO_STORAGE_DIR", str(storage))
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    student = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    created = client.post("/api/videos", data={
        "title": "Lesson 1", "subject": "Math", "className": "Class 5 - A",
    }, files={"file": ("lesson.mp4", b"\x00\x00\x00\x18ftypisomdata", "video/mp4")}, headers=HEADERS)
    assert created.status_code == 201, created.text
    video_id = created.json()["id"]
    assert created.json()["fileSize"] == 16
    assert client.get("/api/videos", headers=HEADERS).json()[0]["id"] == video_id
    assert client.get("/api/videos", params={"className": "Class 5 - B"}, headers=HEADERS).json() == []
    assert client.get("/api/videos", params={"className": "Class 5 - A"}, headers=HEADERS).json()[0]["id"] == video_id
    assert client.post("/api/users", json={
        "email": "video-student@school.test", "password": "student-pass-123",
        "fullName": "Ada", "role": "STUDENT", "linkedEntityId": student["id"],
    }, headers=HEADERS).status_code == 201
    login = client.post("/api/auth/login", json={
        "email": "video-student@school.test", "password": "student-pass-123",
    }, headers=HEADERS)
    linked = {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"}
    assert client.get("/api/student-portal/videos", headers=linked).json()[0]["id"] == video_id
    streamed = client.get(f"/api/videos/{video_id}/stream", headers=linked)
    assert streamed.status_code == 200, streamed.text
    assert streamed.content == b"\x00\x00\x00\x18ftypisomdata"
    assert client.get(f"/api/videos/{video_id}/stream", headers=HEADERS).status_code == 200
    assert client.delete(f"/api/videos/{video_id}", headers=HEADERS).status_code == 204
    assert client.get(f"/api/videos/{video_id}", headers=HEADERS).status_code == 404
    assert list(storage.iterdir()) == []
