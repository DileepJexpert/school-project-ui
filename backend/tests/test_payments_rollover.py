from test_admission_flow import HEADERS, student_payload, structure
from app.db import get_session
from app.reconcile import audit_session


def _setup(client, names=("Ada Rao",)):
    assert client.post(
        "/api/feestructures",
        json=[structure("Class 5 - A", "2026-2027")],
        headers=HEADERS,
    ).status_code == 200
    students = []
    for name in names:
        response = client.post(
            "/api/students/add",
            json={**student_payload(), "fullName": name},
            headers=HEADERS,
        )
        assert response.status_code == 201, response.text
        students.append(response.json())
    return students


def test_collect_fee_discount_receipt_retry_and_duplicate_rejection(client):
    student = _setup(client)[0]
    profile_url = f"/api/student-fee-profiles/{student['id']}"
    request = {
        "studentId": student["id"],
        "amount": 175,
        "discount": 25,
        "installmentNames": ["Tuition - Apr 2026", "Tuition - May 2026"],
        "paymentMode": "CASH",
    }
    headers = {**HEADERS, "Idempotency-Key": "cash-payment-001"}
    paid = client.post("/api/fees/collect", json=request, headers=headers)
    assert paid.status_code == 201, paid.text
    receipt = paid.json()
    assert receipt["amountPaid"] == 175
    assert receipt["discount"] == 25
    assert receipt["receiptNumber"]
    assert receipt["collectedByUserId"]
    assert receipt["paidForInstallments"] == request["installmentNames"]
    assert client.post("/api/fees/collect", json=request, headers=headers).json()["id"] == receipt["id"]
    assert client.get(f"/api/fees/payments/{receipt['id']}", headers=HEADERS).json()["id"] == receipt["id"]
    renamed = client.put(
        f"/api/students/{student['id']}", json={**student, "fullName": "Ada Corrected Rao"}, headers=HEADERS,
    )
    assert renamed.status_code == 200, renamed.text
    assert client.get(f"/api/fees/payments/{receipt['id']}", headers=HEADERS).json()["studentName"] == "Ada Rao"

    profile = client.get(profile_url, headers=HEADERS).json()
    assert profile["totalFees"] == 1700
    assert profile["paidFees"] == 175
    assert profile["totalDiscountGiven"] == 25
    assert profile["dueFees"] == 1500
    assert [item["amountDue"] for item in profile["feeInstallments"][:3]] == [0, 0, 100]
    assert profile["lastPayment"]["receiptNumber"] == receipt["receiptNumber"]
    assert client.post("/api/fees/collect", json=request, headers=HEADERS).status_code == 409
    changed = {**request, "amount": 176, "discount": 24}
    assert client.post("/api/fees/collect", json=changed, headers=headers).status_code == 409
    assert client.get(
        f"/api/fees/payments/{receipt['id']}", headers={"X-Tenant-ID": "school-b"}
    ).status_code == 403


def test_payment_must_match_selected_balance_and_year(client):
    student = _setup(client)[0]
    request = {
        "studentId": student["id"],
        "amount": 90,
        "discount": 0,
        "installmentNames": ["Tuition - Apr 2026"],
        "paymentMode": "DIGITAL_PAYMENT",
        "transactionId": "bank-001",
    }
    assert client.post("/api/fees/collect", json=request, headers=HEADERS).status_code == 422
    assert client.post(
        "/api/fees/collect", json={**request, "amount": 100, "academicYear": "2027-2028"}, headers=HEADERS
    ).status_code == 404
    assert client.post(
        "/api/fees/collect", json={**request, "amount": 100, "installmentNames": ["No fee"]}, headers=HEADERS
    ).status_code == 422
    paid = client.post("/api/fees/collect", json={**request, "amount": 100}, headers=HEADERS)
    assert paid.status_code == 201, paid.text
    another = {**request, "amount": 100, "installmentNames": ["Tuition - May 2026"]}
    assert client.post("/api/fees/collect", json=another, headers=HEADERS).status_code == 409
    assert client.get(f"/api/student-fee-profiles/{student['id']}", headers=HEADERS).json()["paidFees"] == 100


def test_void_payment_restores_dues_and_keeps_receipt_audit(client):
    student = _setup(client)[0]
    payment_data = {
        "studentId": student["id"], "amount": 175, "discount": 25,
        "installmentNames": ["Tuition - Apr 2026", "Tuition - May 2026"],
        "paymentMode": "DIGITAL_PAYMENT", "transactionId": "transfer-void-001",
    }
    paid = client.post("/api/fees/collect", json=payment_data, headers=HEADERS)
    assert paid.status_code == 201, paid.text
    payment_id = paid.json()["id"]
    url = f"/api/fees/payments/{payment_id}/void"
    assert client.post(url, json={"reason": "  "}, headers=HEADERS).status_code == 422
    assert client.post(url, json={"reason": "Cashier entered wrong amount"}, headers={"X-Tenant-ID": "school-b"}).status_code == 403

    voided = client.post(url, json={"reason": "Cashier entered wrong amount"}, headers=HEADERS)
    assert voided.status_code == 200, voided.text
    receipt = voided.json()
    assert receipt["status"] == "VOIDED"
    assert receipt["voidedAt"] and receipt["voidedByUserId"]
    assert receipt["voidReason"] == "Cashier entered wrong amount"
    assert client.post(url, json={"reason": "Cashier entered wrong amount"}, headers=HEADERS).json() == receipt
    assert client.post(url, json={"reason": "Another correction reason"}, headers=HEADERS).status_code == 409
    assert client.get(f"/api/fees/payments/{payment_id}", headers=HEADERS).json() == receipt
    ledger = client.get("/api/fees/payments", params={"status": "VOIDED", "studentId": student["id"]}, headers=HEADERS)
    assert ledger.status_code == 200, ledger.text
    assert ledger.json()["totalElements"] == 1
    assert ledger.json()["content"][0] == receipt
    assert client.get("/api/fees/payments", params={"status": "POSTED"}, headers=HEADERS).json()["totalElements"] == 0

    profile = client.get(f"/api/student-fee-profiles/{student['id']}", headers=HEADERS).json()
    assert profile["paidFees"] == 0
    assert profile["totalDiscountGiven"] == 0
    assert profile["dueFees"] == 1700
    assert profile["lastPayment"] is None
    assert [item["status"] for item in profile["feeInstallments"][:2]] == ["PENDING", "PENDING"]
    assert client.get("/api/reports/fees/report-summary", headers=HEADERS).json()["summary"]["totalCollected"] == 0
    assert client.get("/api/reports/school-summary", headers=HEADERS).json()["totalFeesDue"] == 1700
    assert client.post("/api/fees/collect", json=payment_data, headers=HEADERS).status_code == 409
    repaid = client.post(
        "/api/fees/collect", json={**payment_data, "transactionId": "transfer-corrected-002"}, headers=HEADERS,
    )
    assert repaid.status_code == 201, repaid.text
    generator = client.app.dependency_overrides[get_session]()
    session = next(generator)
    try:
        assert audit_session(session, "school-a") == []
    finally:
        generator.close()


def test_batch_rollover_keeps_old_year_dues_and_can_collect_them(client):
    students = _setup(client, ("Ada Rao", "Ben Rao"))
    student_id = students[0]["id"]
    payload = {
        "sourceClass": "Class 5 - A",
        "sourceYear": "2026-2027",
        "action": "PROMOTE",
        "targetClass": "Class 6 - A",
        "targetYear": "2027-2028",
    }
    headers = {**HEADERS, "Idempotency-Key": "rollover-class5-2027"}
    missing = client.post("/api/academic-years/rollover", json=payload, headers=headers)
    assert missing.status_code == 409
    assert all(
        client.get(f"/api/students/{student['id']}", headers=HEADERS).json()["academicYear"] == "2026-2027"
        for student in students
    )
    assert client.post(
        "/api/feestructures", json=[structure("Class 6 - A", "2027-2028")], headers=HEADERS
    ).status_code == 200
    moved = client.post("/api/academic-years/rollover", json=payload, headers=headers)
    assert moved.status_code == 201, moved.text
    run = moved.json()
    assert run["studentCount"] == 2
    assert set(run["studentIds"]) == {student["id"] for student in students}
    assert client.post("/api/academic-years/rollover", json=payload, headers=headers).json() == run
    assert client.get(f"/api/academic-years/rollover/{run['id']}", headers=HEADERS).json() == run
    assert client.get(f"/api/academic-years/rollover/{run['id']}", headers={"X-Tenant-ID": "school-b"}).status_code == 403
    assert client.post(
        "/api/academic-years/rollover", json={**payload, "targetClass": "Class 7 - A"}, headers=headers
    ).status_code == 409
    assert client.post(
        "/api/students/add",
        json={**student_payload(), "fullName": "Late student"},
        headers=HEADERS,
    ).status_code == 409
    assert client.post(
        "/api/students/enquiry",
        json={**student_payload(), "fullName": "Late enquiry"},
        headers=HEADERS,
    ).status_code == 409
    old_roster = client.get(
        "/api/students",
        params={"className": "Class 5 - A", "academicYear": "2026-2027"},
        headers=HEADERS,
    ).json()
    assert len(old_roster) == 2
    assert all(item["academicYear"] == "2026-2027" and item["status"] == "ACTIVE" for item in old_roster)

    current = client.get(f"/api/student-fee-profiles/{student_id}", headers=HEADERS).json()
    old = client.get(
        f"/api/student-fee-profiles/{student_id}",
        params={"academicYear": "2026-2027"},
        headers=HEADERS,
    ).json()
    assert current["academicYear"] == "2027-2028"
    assert current["dueFees"] == 1700
    assert old["dueFees"] == 1700
    payment = client.post(
        "/api/fees/collect",
        json={
            "studentId": student_id,
            "academicYear": "2026-2027",
            "amount": 100,
            "discount": 0,
            "installmentNames": ["Tuition - Apr 2026"],
            "paymentMode": "CASH",
        },
        headers=HEADERS,
    )
    assert payment.status_code == 201, payment.text
    assert payment.json()["academicYear"] == "2026-2027"
    old_after = client.get(
        f"/api/student-fee-profiles/{student_id}",
        params={"academicYear": "2026-2027"},
        headers=HEADERS,
    ).json()
    assert old_after["dueFees"] == 1600
    assert client.get(f"/api/student-fee-profiles/{student_id}", headers=HEADERS).json()["dueFees"] == 1700
    dues = client.get("/api/fees/dues", headers=HEADERS).json()
    assert len(dues) == 4
    assert len(client.get("/api/fees/dues", params={"academicYear": "2026-2027"}, headers=HEADERS).json()) == 2


def test_graduation_marks_students_inactive_without_new_fee_profile(client):
    student = _setup(client)[0]
    response = client.post(
        "/api/academic-years/rollover",
        json={"sourceClass": "Class 5 - A", "sourceYear": "2026-2027", "action": "GRADUATE"},
        headers={**HEADERS, "Idempotency-Key": "graduate-class5-2027"},
    )
    assert response.status_code == 201, response.text
    assert client.get(f"/api/students/{student['id']}", headers=HEADERS).json()["status"] == "INACTIVE"
    assert client.get(f"/api/student-fee-profiles/{student['id']}", headers=HEADERS).json()["dueFees"] == 1700


def test_rollover_rejects_closed_target_class_year(client):
    structures = [
        structure("Class 5 - A", "2026-2027"),
        structure("Class 5 - B", "2026-2027"),
        structure("Class 6 - A", "2027-2028"),
        structure("Class 7 - A", "2028-2029"),
    ]
    assert client.post("/api/feestructures", json=structures, headers=HEADERS).status_code == 200
    first = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    second = client.post(
        "/api/students/add",
        json={**student_payload(), "fullName": "Ben Rao", "classForAdmission": "Class 5 - B"},
        headers=HEADERS,
    ).json()
    first_move = {
        "sourceClass": "Class 5 - A", "sourceYear": "2026-2027", "action": "PROMOTE",
        "targetClass": "Class 6 - A", "targetYear": "2027-2028",
    }
    second_move = {
        "sourceClass": "Class 6 - A", "sourceYear": "2027-2028", "action": "PROMOTE",
        "targetClass": "Class 7 - A", "targetYear": "2028-2029",
    }
    assert client.post("/api/academic-years/rollover", json=first_move, headers={**HEADERS, "Idempotency-Key": "first-class-move"}).status_code == 201
    assert client.post("/api/academic-years/rollover", json=second_move, headers={**HEADERS, "Idempotency-Key": "second-class-move"}).status_code == 201
    late_move = {**first_move, "sourceClass": "Class 5 - B"}
    refused = client.post("/api/academic-years/rollover", json=late_move, headers={**HEADERS, "Idempotency-Key": "late-class-move"})
    assert refused.status_code == 409, refused.text
    assert client.get(f"/api/students/{second['id']}", headers=HEADERS).json()["classForAdmission"] == "Class 5 - B"
    assert client.get(f"/api/students/{first['id']}", headers=HEADERS).json()["classForAdmission"] == "Class 7 - A"


def test_fee_reports_reconcile_payments_discount_and_outstanding(client):
    student = _setup(client)[0]
    response = client.post(
        "/api/fees/collect",
        json={
            "studentId": student["id"],
            "amount": 80,
            "discount": 20,
            "installmentNames": ["Tuition - Apr 2026"],
            "paymentMode": "CASH",
        },
        headers=HEADERS,
    )
    assert response.status_code == 201, response.text
    report = client.get("/api/reports/fees/report-summary", headers=HEADERS).json()
    assert report["summary"] == {
        "totalCollected": 80,
        "totalDue": 1600,
        "totalDiscountGiven": 20,
        "totalTransactions": 1,
    }
    assert report["classSummaries"][0]["classForAdmission"] == "Class 5 - A"
    assert report["paymentModeSummary"] == [{"paymentMode": "CASH", "totalAmount": 80}]
    assert report["transactionsPage"]["content"][0]["receiptNumber"] == response.json()["receiptNumber"]
    assert report["transactionsPage"]["content"][0]["collectedBy"] == "Test Admin"
    empty_period = client.get(
        "/api/reports/fees/report-summary",
        params={"startDate": "2020-01-01", "endDate": "2020-12-31"},
        headers=HEADERS,
    ).json()
    assert empty_period["summary"]["totalCollected"] == 0
    assert empty_period["summary"]["totalDue"] == 1600
    assert client.get(
        "/api/reports/fees/report-summary",
        params={"startDate": "2021-01-01", "endDate": "2020-01-01"},
        headers=HEADERS,
    ).status_code == 422

    summary = client.get("/api/reports/school-summary", headers=HEADERS).json()
    assert summary["totalStudents"] == 1
    assert summary["enrollmentByClass"] == {"Class 5 - A": 1}
    assert summary["totalFeesCollected"] == 80
    assert summary["totalFeesDue"] == 1600
    assert summary["totalDiscountGiven"] == 20
