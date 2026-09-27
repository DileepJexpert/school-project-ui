from test_admission_flow import HEADERS, student_payload, structure
from app.db import get_session
from app.reconcile import audit_session


def _policy():
    return {
        "academicYear": "2026-2027", "passPercentage": 40,
        "examOrder": ["TERM1", "TERM2"],
        "bands": [
            {"minPercentage": 90, "grade": "A+", "gradePoint": 10},
            {"minPercentage": 80, "grade": "A", "gradePoint": 9},
            {"minPercentage": 70, "grade": "B+", "gradePoint": 8},
            {"minPercentage": 60, "grade": "B", "gradePoint": 7},
            {"minPercentage": 50, "grade": "C", "gradePoint": 6},
            {"minPercentage": 40, "grade": "D", "gradePoint": 4},
            {"minPercentage": 0, "grade": "F", "gradePoint": 0},
        ],
    }


def _setup(client, *, configure_policy=True, configure_exams=True, subjects=("Mathematics",)):
    assert client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS
    ).status_code == 200
    if configure_policy:
        saved = client.put("/api/results/grading-policy", json=_policy(), headers=HEADERS)
        assert saved.status_code == 200, saved.text
    if configure_exams:
        for exam, weight in (("TERM1", 30), ("TERM2", 70)):
            config = client.post("/api/results/exam-config", json={
                "academicYear": "2026-2027", "examType": exam,
                "displayName": exam, "weightagePercent": weight,
                "maxMarksDefault": 100, "isActive": True,
            }, headers=HEADERS)
            assert config.status_code == 200, config.text
    assigned = client.put("/api/master-data/class-subjects", json={
        "className": "Class 5 - A", "academicYear": "2026-2027",
        "subjects": list(subjects),
    }, headers=HEADERS)
    assert assigned.status_code == 200, assigned.text
    students = []
    for name in ("Ada Rao", "Ben Rao"):
        response = client.post(
            "/api/students/add", json={**student_payload(), "fullName": name}, headers=HEADERS
        )
        assert response.status_code == 201, response.text
        students.append(response.json())
    return students


def test_publishing_requires_explicit_year_grading_policy(client):
    students = _setup(client, configure_policy=False)
    payload = {
        "className": "Class 5 - A", "examType": "TERM1", "academicYear": "2026-2027",
        "subject": "Mathematics", "maxMarks": 100, "enteredBy": "Teacher",
        "entries": [
            {"studentId": students[0]["id"], "marksObtained": 35},
            {"studentId": students[1]["id"], "marksObtained": 80},
        ],
    }
    draft = client.post("/api/results/bulk", json=payload, headers=HEADERS)
    assert draft.status_code == 200, draft.text
    assert draft.json()[0]["gradingPolicyConfigured"] is False
    publish_url = "/api/results/publish"
    params = {"className": "Class 5 - A", "examType": "TERM1", "year": "2026-2027"}
    assert client.put(publish_url, params=params, headers=HEADERS).status_code == 409
    assert client.get("/api/master-data?academicYear=2026-2027", headers=HEADERS).json()["gradingPolicyConfigured"] is False
    invalid = {**_policy(), "bands": list(reversed(_policy()["bands"]))}
    assert client.put("/api/results/grading-policy", json=invalid, headers=HEADERS).status_code == 422
    saved = client.put("/api/results/grading-policy", json=_policy(), headers=HEADERS)
    assert saved.status_code == 200, saved.text
    assert client.get("/api/master-data?academicYear=2026-2027", headers=HEADERS).json()["examWeightagesConfigured"] is True
    assert client.get("/api/results/grading-policy", params={"year": "2026-2027"}, headers=HEADERS).json() == saved.json()
    assert client.put(publish_url, params=params, headers=HEADERS).status_code == 200
    sheet = client.get("/api/results/class/Class 5 - A/exam/TERM1", params={"year": "2026-2027"}, headers=HEADERS).json()
    assert next(item for item in sheet if item["studentId"] == students[0]["id"])["isPassed"] is False
    assert client.put("/api/results/grading-policy", json={**_policy(), "passPercentage": 35}, headers=HEADERS).status_code == 409


def test_publication_requires_every_configured_class_subject(client):
    students = _setup(client, subjects=("Mathematics", "Science"))
    base = {
        "className": "Class 5 - A", "examType": "TERM1", "academicYear": "2026-2027",
        "maxMarks": 100, "enteredBy": "Teacher",
        "entries": [
            {"studentId": students[0]["id"], "marksObtained": 75},
            {"studentId": students[1]["id"], "marksObtained": 85},
        ],
    }
    assert client.post("/api/results/bulk", json={**base, "subject": "Mathematics"}, headers=HEADERS).status_code == 200
    params = {"className": "Class 5 - A", "examType": "TERM1", "year": "2026-2027"}
    assert client.put("/api/results/publish", params=params, headers=HEADERS).status_code == 409
    assert client.post("/api/results/bulk", json={**base, "subject": "Science"}, headers=HEADERS).status_code == 200
    assert client.put("/api/results/publish", params=params, headers=HEADERS).status_code == 200
    generator = client.app.dependency_overrides[get_session]()
    session = next(generator)
    try:
        assert audit_session(session, "school-a") == []
    finally:
        generator.close()
    changed = client.put("/api/master-data/class-subjects", json={
        "className": "Class 5 - A", "academicYear": "2026-2027", "subjects": ["Mathematics"],
    }, headers=HEADERS)
    assert changed.status_code == 409


def test_bulk_marks_validate_context_and_publish_only_complete_subjects(client):
    students = _setup(client)
    entries = [
        {"studentId": students[0]["id"], "marksObtained": 80},
        {"studentId": students[1]["id"], "marksObtained": 90},
    ]
    payload = {
        "className": "Class 5 - A",
        "examType": "TERM1",
        "academicYear": "2026-2027",
        "subject": "Mathematics",
        "maxMarks": 100,
        "enteredBy": "Teacher",
        "entries": entries[:1],
    }
    wrong = client.post("/api/results/bulk", json={**payload, "academicYear": "2027-2028"}, headers=HEADERS)
    assert wrong.status_code == 409
    assert client.post("/api/results/bulk", json={**payload, "className": "Class 6 - A"}, headers=HEADERS).status_code == 409
    assert client.post(
        "/api/results/bulk", json={**payload, "entries": [{**entries[0], "marksObtained": 101}]}, headers=HEADERS
    ).status_code == 422
    saved = client.post("/api/results/bulk", json=payload, headers=HEADERS)
    assert saved.status_code == 200, saved.text
    assert saved.json()[0]["grade"] == "A"
    publish = client.put(
        "/api/results/publish",
        params={"className": "Class 5 - A", "examType": "TERM1", "year": "2026-2027"},
        headers=HEADERS,
    )
    assert publish.status_code == 409
    second = client.post("/api/results/bulk", json={**payload, "entries": entries[1:]}, headers=HEADERS)
    assert second.status_code == 200, second.text
    sheet = client.get(
        "/api/results/class/Class 5 - A/exam/TERM1", params={"year": "2026-2027"}, headers=HEADERS
    ).json()
    assert len(sheet) == 2
    assert sorted(item["classRank"] for item in sheet) == [1, 2]
    assert client.get(
        f"/api/results/student/{students[0]['id']}", params={"year": "2026-2027"}, headers=HEADERS
    ).json()[0]["subject"] == "Mathematics"
    assert client.get(
        f"/api/results/student/{students[0]['id']}",
        params={"year": "2026-2027"}, headers={"X-Tenant-ID": "school-b"},
    ).status_code == 403

    published = client.put(
        "/api/results/publish",
        params={"className": "Class 5 - A", "examType": "TERM1", "year": "2026-2027"},
        headers=HEADERS,
    )
    assert published.status_code == 200, published.text
    assert published.json()["publishedCount"] == 2
    assert all(item["isPublished"] for item in client.get(
        "/api/results/class/Class 5 - A/exam/TERM1", params={"year": "2026-2027"}, headers=HEADERS
    ).json())
    assert client.post("/api/results/bulk", json=payload, headers=HEADERS).status_code == 409
    assert client.put(
        f"/api/results/{saved.json()[0]['id']}",
        json={"marksObtained": 81, "maxMarks": 100}, headers=HEADERS,
    ).status_code == 409
    assert client.delete(f"/api/results/{saved.json()[0]['id']}", headers=HEADERS).status_code == 409


def test_unpublished_marks_can_be_corrected_and_voided(client):
    student = _setup(client, subjects=("Science",))[0]
    payload = {
        "className": "Class 5 - A", "examType": "TERM1", "academicYear": "2026-2027",
        "subject": "Science", "maxMarks": 100, "enteredBy": "Teacher",
        "entries": [{"studentId": student["id"], "marksObtained": 20}],
    }
    result = client.post("/api/results/bulk", json=payload, headers=HEADERS).json()[0]
    assert result["isPassed"] is False
    updated = client.put(
        f"/api/results/{result['id']}", json={"marksObtained": 75, "maxMarks": 100}, headers=HEADERS
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["grade"] == "B+"
    assert updated.json()["isPassed"] is True
    assert client.delete(f"/api/results/{result['id']}", headers=HEADERS).status_code == 204
    assert client.get(
        f"/api/results/student/{student['id']}", params={"year": "2026-2027"}, headers=HEADERS
    ).json() == []


def test_exam_config_coscholastic_report_card_and_analytics(client):
    students = _setup(client, configure_exams=False)
    empty_card = client.get(
        f"/api/results/student/{students[0]['id']}/report",
        params={"year": "2026-2027"}, headers=HEADERS,
    ).json()
    assert empty_card["overallGrade"] == ""
    assert empty_card["classRank"] == 0
    config = {
        "academicYear": "2026-2027",
        "examType": "TERM1",
        "displayName": "Term One",
        "weightagePercent": 30,
        "maxMarksDefault": 100,
        "isActive": True,
    }
    saved_config = client.post("/api/results/exam-config", json=config, headers=HEADERS)
    assert saved_config.status_code == 200, saved_config.text
    assert client.get("/api/results/exam-config", params={"year": "2026-2027"}, headers=HEADERS).json() == [saved_config.json()]
    assert client.post(
        "/api/results/exam-config",
        json={**config, "examType": "TERM2", "displayName": "Term Two", "weightagePercent": 70},
        headers=HEADERS,
    ).status_code == 200
    assert client.post(
        "/api/results/coscholastic",
        json={
            "studentId": students[0]["id"],
            "className": "Class 6 - A",
            "academicYear": "2026-2027",
            "term": "TERM1",
            "areas": [{"name": "Art", "grade": "A"}],
        },
        headers=HEADERS,
    ).status_code == 409
    assessment = client.post(
        "/api/results/coscholastic",
        json={
            "studentId": students[0]["id"],
            "className": "Class 5 - A",
            "academicYear": "2026-2027",
            "term": "TERM1",
            "areas": [{"name": "Art", "grade": "A"}],
        },
        headers=HEADERS,
    )
    assert assessment.status_code == 200, assessment.text
    assert client.get(
        f"/api/results/coscholastic/student/{students[0]['id']}",
        params={"year": "2026-2027"}, headers=HEADERS,
    ).json() == [assessment.json()]

    marks = {
        "className": "Class 5 - A", "examType": "TERM1", "academicYear": "2026-2027",
        "subject": "Mathematics", "maxMarks": 100, "enteredBy": "Teacher",
        "entries": [
            {"studentId": students[0]["id"], "marksObtained": 80},
            {"studentId": students[1]["id"], "marksObtained": 90},
        ],
    }
    assert client.post("/api/results/bulk", json=marks, headers=HEADERS).status_code == 200
    assert client.put(
        "/api/results/publish",
        params={"className": "Class 5 - A", "examType": "TERM1", "year": "2026-2027"},
        headers=HEADERS,
    ).status_code == 200
    assert client.post("/api/results/exam-config", json={**config, "weightagePercent": 50}, headers=HEADERS).status_code == 409
    report = client.get(
        f"/api/results/student/{students[0]['id']}/report",
        params={"year": "2026-2027"}, headers=HEADERS,
    )
    assert report.status_code == 200, report.text
    card = report.json()
    assert card["cumulativePercentage"] == 80
    assert card["classRank"] == 2
    assert card["subjects"][0]["examResults"]["TERM1"]["marksObtained"] == 80
    assert card["coscholasticTerm1"]["areas"][0]["grade"] == "A"
    analytics = client.get(
        "/api/results/class/Class 5 - A/analytics",
        params={"year": "2026-2027", "examType": "TERM1"}, headers=HEADERS,
    )
    assert analytics.status_code == 200, analytics.text
    summary = analytics.json()
    assert summary["totalStudents"] == 2
    assert summary["gradedStudents"] == 2
    assert summary["classAverage"] == 85
    assert summary["highestPercentage"] == 90
    assert summary["subjectHeatmap"][0]["subject"] == "Mathematics"
    assert summary["recognition"][0]["studentName"] == "Ben Rao"

    second_term = {
        **marks,
        "examType": "TERM2",
        "entries": [
            {"studentId": students[0]["id"], "marksObtained": 60},
            {"studentId": students[1]["id"], "marksObtained": 90},
        ],
    }
    assert client.post("/api/results/bulk", json=second_term, headers=HEADERS).status_code == 200
    assert client.put(
        "/api/results/publish",
        params={"className": "Class 5 - A", "examType": "TERM2", "year": "2026-2027"},
        headers=HEADERS,
    ).status_code == 200
    final_card = client.get(
        f"/api/results/student/{students[0]['id']}/report",
        params={"year": "2026-2027"}, headers=HEADERS,
    ).json()
    assert final_card["cumulativePercentage"] == 66
    assert final_card["subjects"][0]["trend"] == "DECLINING"
    assert client.get(
        "/api/results/class/Class 5 - A/analytics", params={"year": "2026-2027"}, headers=HEADERS
    ).json()["classAverage"] == 78
