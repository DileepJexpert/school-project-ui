from copy import deepcopy


HEADERS = {"X-Tenant-ID": "school-a"}


def student_payload():
    return {
        "fullName": "Ada Rao",
        "dateOfBirth": "2015-04-10",
        "gender": "Female",
        "classForAdmission": "Class 5 - A",
        "academicYear": "2026-2027",
        "dateOfAdmission": "2026-04-01",
        "parentDetails": {"fatherName": "Rao"},
        "contactDetails": {"primaryContactNumber": "9999999999"},
        "previousSchoolDetails": {},
    }


def structure(class_name, year):
    return {
        "className": class_name,
        "academicYear": year,
        "feeComponents": [
            {"feeName": "Tuition", "amount": 100, "frequency": "MONTHLY"},
            {"feeName": "Annual", "amount": 500, "frequency": "YEARLY"},
        ],
    }


def test_enquiry_has_no_fee_profile_and_failed_conversion_is_atomic(client):
    created = client.post("/api/students/enquiry", json=student_payload(), headers=HEADERS)
    assert created.status_code == 201, created.text
    enquiry = created.json()
    assert enquiry["status"] == "ENQUIRY"
    assert enquiry["admissionNumber"].startswith("ENQ-")
    assert client.get(
        f"/api/student-fee-profiles/{enquiry['id']}", headers=HEADERS
    ).status_code == 404

    admission = {**enquiry, "status": "ACTIVE"}
    failed = client.put(
        f"/api/students/{enquiry['id']}", json=admission, headers=HEADERS
    )
    assert failed.status_code == 409
    unchanged = client.get(f"/api/students/{enquiry['id']}", headers=HEADERS).json()
    assert unchanged["status"] == "ENQUIRY"

    fees = client.post(
        "/api/feestructures",
        json=[structure("Class 5 - A", "2026-2027")],
        headers=HEADERS,
    )
    assert fees.status_code == 200
    converted = client.put(
        f"/api/students/{enquiry['id']}", json=admission, headers=HEADERS
    )
    assert converted.status_code == 200, converted.text
    assert converted.json()["admissionNumber"].startswith("ADM-")
    assert client.get(
        f"/api/student-fee-profiles/{enquiry['id']}", headers=HEADERS
    ).status_code == 200


def test_monthly_profile_and_next_year_keep_old_dues(client):
    first = structure("Class 5 - A", "2026-2027")
    second = structure("Class 6 - A", "2027-2028")
    saved = client.post("/api/feestructures", json=[first, second], headers=HEADERS)
    assert saved.status_code == 200, saved.text

    admission = client.post("/api/students/add", json=student_payload(), headers=HEADERS)
    assert admission.status_code == 201, admission.text
    student = admission.json()
    student_id = student["id"]
    old = client.get(f"/api/student-fee-profiles/{student_id}", headers=HEADERS)
    assert old.status_code == 200, old.text
    old_profile = old.json()
    assert len(old_profile["feeInstallments"]) == 13
    assert old_profile["feeInstallments"][0]["installmentName"] == "Tuition - Apr 2026"
    assert old_profile["feeInstallments"][11]["installmentName"] == "Tuition - Mar 2027"
    assert old_profile["dueFees"] == 1700.0

    promoted = {**student, "classForAdmission": "Class 6 - A", "academicYear": "2027-2028"}
    moved = client.put(f"/api/students/{student_id}", json=promoted, headers=HEADERS)
    assert moved.status_code == 200, moved.text
    assert moved.json()["academicYear"] == "2027-2028"

    new_profile = client.get(f"/api/student-fee-profiles/{student_id}", headers=HEADERS).json()
    assert new_profile["academicYear"] == "2027-2028"
    assert new_profile["feeInstallments"][0]["installmentName"] == "Tuition - Apr 2027"
    old_again = client.get(
        f"/api/student-fee-profiles/{student_id}",
        params={"academicYear": "2026-2027"},
        headers=HEADERS,
    ).json()
    assert old_again["academicYear"] == "2026-2027"
    assert old_again["dueFees"] == old_profile["dueFees"]

    repeat = client.put(f"/api/students/{student_id}", json=promoted, headers=HEADERS)
    assert repeat.status_code == 200
    assert len(client.get(f"/api/student-fee-profiles/{student_id}", headers=HEADERS).json()["feeInstallments"]) == 13


def test_tenant_isolation_and_used_structure_cannot_change(client):
    created = client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS
    )
    assert created.status_code == 200
    student = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    assert client.get(
        f"/api/students/{student['id']}", headers={"X-Tenant-ID": "school-b"}
    ).status_code == 403
    assert client.get(
        f"/api/student-fee-profiles/{student['id']}", headers={"X-Tenant-ID": "school-b"}
    ).status_code == 403
    changed = deepcopy(structure("Class 5 - A", "2026-2027"))
    changed["feeComponents"][0]["amount"] = 200
    assert client.post("/api/feestructures", json=[changed], headers=HEADERS).status_code == 409


def test_invalid_fee_amount_and_year_rejected(client):
    invalid = structure("Class 5 - A", "2026-2027")
    invalid["feeComponents"][0]["amount"] = -1
    assert client.post("/api/feestructures", json=[invalid], headers=HEADERS).status_code == 422
    bad_year = student_payload()
    bad_year["academicYear"] = "2026-2029"
    assert client.post("/api/students/enquiry", json=bad_year, headers=HEADERS).status_code == 422


def test_archived_enquiry_cannot_be_reactivated_without_enrollment(client):
    enquiry = client.post("/api/students/enquiry", json=student_payload(), headers=HEADERS).json()
    archived = client.put(
        f"/api/students/{enquiry['id']}", json={**enquiry, "status": "INACTIVE"}, headers=HEADERS
    )
    assert archived.status_code == 200, archived.text
    revived = client.put(
        f"/api/students/{enquiry['id']}", json={**enquiry, "status": "ACTIVE"}, headers=HEADERS
    )
    assert revived.status_code == 409
    assert client.get(f"/api/students/{enquiry['id']}", headers=HEADERS).json()["status"] == "INACTIVE"


def test_delete_enquiry_but_retain_admitted_student_history(client):
    enquiry = client.post("/api/students/enquiry", json=student_payload(), headers=HEADERS).json()
    deleted = client.delete(f"/api/students/{enquiry['id']}", headers=HEADERS)
    assert deleted.status_code == 204, deleted.text
    assert client.get(f"/api/students/{enquiry['id']}", headers=HEADERS).status_code == 404

    assert client.post(
        "/api/feestructures",
        json=[structure("Class 5 - A", "2026-2027")],
        headers=HEADERS,
    ).status_code == 200
    admitted = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    refused = client.delete(f"/api/students/{admitted['id']}", headers=HEADERS)
    assert refused.status_code == 409
    assert client.get(f"/api/student-fee-profiles/{admitted['id']}", headers=HEADERS).status_code == 200
