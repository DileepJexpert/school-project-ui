from test_admission_flow import HEADERS, student_payload, structure


def test_contact_form_is_public_but_office_list_requires_login(client):
    payload = {
        "name": "Parent Name", "email": "parent@example.test",
        "phone": "9999999999", "gradeInterested": "Class 5",
        "message": "Please call me about admission.",
    }
    created = client.post("/api/contact/enquiry", json=payload, headers={
        "X-Tenant-ID": "school-a", "Authorization": "",
    })
    assert created.status_code == 201, created.text
    assert created.json()["status"] == "RECEIVED"
    assert client.get("/api/contact/enquiries", headers={"Authorization": "", **HEADERS}).status_code == 401
    listing = client.get("/api/contact/enquiries", headers=HEADERS)
    assert listing.status_code == 200, listing.text
    assert listing.json()[0]["message"] == payload["message"]


def test_staff_result_search_returns_only_published_marks(client):
    assert client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS).status_code == 200
    student = client.post("/api/students/add", json={
        **student_payload(), "rollNumber": "17",
    }, headers=HEADERS)
    assert student.status_code == 201, student.text
    student_id = student.json()["id"]
    params = {"rollNumber": "17", "className": "Class 5 - A", "academicYear": "2026-27"}
    assert client.get("/api/results", params=params, headers={"Authorization": "", **HEADERS}).status_code == 401
    assert client.get("/api/results", params=params, headers=HEADERS).json() == []
    mark = client.post("/api/results/bulk", json={
        "className": "Class 5 - A", "academicYear": "2026-2027", "examType": "TERM1",
        "subject": "Mathematics", "maxMarks": 100, "enteredBy": "Teacher",
        "entries": [{"studentId": student_id, "marksObtained": 80}],
    }, headers=HEADERS)
    assert mark.status_code == 200, mark.text
    assert client.get("/api/results", params=params, headers=HEADERS).json() == []
    # Published marks are what this search exposes, not drafts.
    from app.db import get_session
    from app.models import ResultRecord
    generator = client.app.dependency_overrides[get_session]()
    session = next(generator)
    try:
        with session.begin():
            session.get(ResultRecord, mark.json()[0]["id"]).is_published = True
    finally:
        generator.close()
    published = client.get("/api/results", params=params, headers=HEADERS)
    assert published.status_code == 200, published.text
    assert published.json()[0]["studentName"] == student.json()["fullName"]
    assert client.get("/api/results", params={**params, "className": "Class 5 - B"}, headers=HEADERS).json() == []


def test_browser_preflight_reaches_fastapi(client):
    response = client.options("/api/students", headers={
        "Origin": "http://localhost:54321",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "authorization,x-tenant-id",
        "Authorization": "",
    })
    assert response.status_code == 200, response.text
    assert response.headers["access-control-allow-origin"] == "http://localhost:54321"


def test_website_content_is_admin_managed_and_publicly_readable(client):
    empty = client.get("/api/site-content", headers={"Authorization": "", **HEADERS})
    assert empty.status_code == 200, empty.text
    assert empty.json()["schoolName"] == "School A"
    content = {"mission": "Teach every child well", "academicLevels": [
        {"id": "primary", "title": "Primary", "grades": "1-5",
         "focus": "Foundations", "highlights": ["Reading"]},
    ]}
    saved = client.put("/api/site-content", json={"content": content}, headers=HEADERS)
    assert saved.status_code == 200, saved.text
    assert client.get("/api/site-content", headers={"Authorization": "", **HEADERS}).json()["mission"] == content["mission"]
    assert client.put("/api/site-content", json={"content": {"madeUp": 1}}, headers=HEADERS).status_code == 422


def test_school_name_setting_updates_public_site_content(client):
    changed = client.put("/api/school/profile", json={"name": "A New School Name"}, headers=HEADERS)
    assert changed.status_code == 200, changed.text
    assert changed.json()["name"] == "A New School Name"
    assert client.get("/api/site-content", headers={"Authorization": "", **HEADERS}).json()["schoolName"] == "A New School Name"
    assert client.put("/api/school/profile", json={"name": "  "}, headers=HEADERS).status_code == 422
