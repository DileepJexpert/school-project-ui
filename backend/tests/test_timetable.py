from test_admission_flow import HEADERS, student_payload, structure


def _day(class_name="Class 5 - A", teacher="Ms Rao"):
    return {
        "className": class_name,
        "academicYear": "2026-2027",
        "dayOfWeek": "MONDAY",
        "periods": [
            {"periodNumber": 1, "subject": "Mathematics", "teacherName": teacher, "startTime": "09:00", "endTime": "09:45"},
            {"periodNumber": 2, "subject": "Science", "teacherName": teacher, "startTime": "09:45", "endTime": "10:30"},
        ],
    }


def test_timetable_upsert_teacher_conflicts_and_closed_year(client):
    saved = client.post("/api/timetable", json=_day(), headers=HEADERS)
    assert saved.status_code == 200, saved.text
    day = saved.json()
    assert day["periods"][0]["startTime"] == "09:00"
    assert client.get(
        "/api/timetable/Class 5 - A", params={"academicYear": "2026-2027"}, headers=HEADERS
    ).json() == [day]
    assert client.get(
        "/api/timetable/Class 5 - A", params={"academicYear": "2026-2027"},
        headers={"X-Tenant-ID": "school-b"},
    ).status_code == 403
    clash = client.post("/api/timetable", json=_day("Class 6 - A"), headers=HEADERS)
    assert clash.status_code == 409
    assert client.post("/api/timetable", json=_day("Class 6 - A", "Mr Singh"), headers=HEADERS).status_code == 200
    changed = client.post(
        "/api/timetable",
        json={**_day(), "id": day["id"], "periods": [_day()["periods"][0]]},
        headers=HEADERS,
    )
    assert changed.status_code == 200, changed.text
    assert changed.json()["id"] == day["id"]
    assert len(changed.json()["periods"]) == 1
    assert client.post(
        "/api/timetable",
        json={**_day(), "periods": [
            _day()["periods"][0],
            {"periodNumber": 2, "subject": "Science", "teacherName": "Mr Singh", "startTime": "09:30", "endTime": "10:30"},
        ]},
        headers=HEADERS,
    ).status_code == 422

    assert client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027"), structure("Class 6 - A", "2027-2028")],
        headers=HEADERS,
    ).status_code == 200
    assert client.post("/api/students/add", json=student_payload(), headers=HEADERS).status_code == 201
    assert client.post(
        "/api/academic-years/rollover",
        json={
            "sourceClass": "Class 5 - A", "sourceYear": "2026-2027", "action": "PROMOTE",
            "targetClass": "Class 6 - A", "targetYear": "2027-2028",
        },
        headers={**HEADERS, "Idempotency-Key": "timetable-rollover-01"},
    ).status_code == 201
    assert client.delete(f"/api/timetable/entry/{day['id']}", headers=HEADERS).status_code == 409
    assert client.get(
        "/api/timetable/Class 5 - A", params={"academicYear": "2026-2027"}, headers=HEADERS
    ).json()[0]["id"] == day["id"]


def test_timetable_deletes_class_and_validates_periods(client):
    invalid = _day()
    invalid["periods"][0]["endTime"] = "08:00"
    assert client.post("/api/timetable", json=invalid, headers=HEADERS).status_code == 422
    saved = client.post("/api/timetable", json=_day(), headers=HEADERS)
    assert saved.status_code == 200, saved.text
    assert client.delete(
        "/api/timetable/Class 5 - A", params={"academicYear": "2026-2027"}, headers=HEADERS
    ).status_code == 204
    assert client.get(
        "/api/timetable/Class 5 - A", params={"academicYear": "2026-2027"}, headers=HEADERS
    ).json() == []
