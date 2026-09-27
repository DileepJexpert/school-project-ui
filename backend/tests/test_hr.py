def _staff_payload(name: str = "Asha Rao") -> dict:
    return {
        "fullName": name, "email": "asha@example.test", "phone": "1234567890",
        "department": "TEACHING", "designation": "Teacher",
        "dateOfJoining": "2025-04-01", "basicSalary": 30000,
    }


def test_staff_payroll_leave_and_attendance(client):
    headers = {"X-Tenant-ID": "school-a"}
    created = client.post("/api/staff", json=_staff_payload(), headers=headers)
    assert created.status_code == 201, created.text
    staff = created.json()
    assert staff["employeeId"].startswith("EMP-")
    staff_id = staff["id"]
    assert client.get("/api/staff/dashboard", headers=headers).json()["totalStaff"] == 1
    assert client.get("/api/staff", headers=headers).json()[0]["id"] == staff_id

    generated = client.post("/api/salary/generate", json={"month": 9, "year": 2026}, headers=headers)
    assert generated.status_code == 200, generated.text
    salary = generated.json()[0]
    assert salary["hra"] == 6000
    assert salary["netSalary"] == 36900
    assert client.post("/api/salary/generate", json={"month": 9, "year": 2026}, headers=headers).json() == []
    paid = client.put(f"/api/salary/{salary['id']}/pay", headers=headers)
    assert paid.status_code == 200, paid.text
    assert paid.json()["status"] == "PAID"
    assert client.put(f"/api/salary/{salary['id']}/pay", headers=headers).json()["paidAt"] == paid.json()["paidAt"]
    conflict = client.put(f"/api/salary/{salary['id']}/pay", json={"paymentMode": "CASH"}, headers=headers)
    assert conflict.status_code == 409

    leave = client.post("/api/leave/apply", json={
        "staffId": staff_id, "leaveType": "CASUAL", "fromDate": "2026-09-25",
        "toDate": "2026-09-26", "reason": "Family event",
    }, headers=headers)
    assert leave.status_code == 201, leave.text
    assert leave.json()["totalDays"] == 2
    repeat_leave = client.post("/api/leave/apply", json={
        "staffId": staff_id, "leaveType": "CASUAL", "fromDate": "2026-09-26",
        "toDate": "2026-09-27", "reason": "Other event",
    }, headers=headers)
    assert repeat_leave.status_code == 409
    approved = client.put(f"/api/leave/{leave.json()['id']}/approve", json={"action": "approve"}, headers=headers)
    assert approved.json()["status"] == "APPROVED"
    assert client.get("/api/leave?status=APPROVED", headers=headers).json()[0]["id"] == leave.json()["id"]

    marks = client.post("/api/staff-attendance/mark", json=[{
        "staffId": staff_id, "date": "2026-09-24", "status": "PRESENT",
    }], headers=headers)
    assert marks.status_code == 201, marks.text
    assert client.get("/api/staff-attendance/date?date=2026-09-24", headers=headers).json()[0]["status"] == "PRESENT"
    duplicate = client.post("/api/staff-attendance/mark", json=[{
        "staffId": staff_id, "date": "2026-09-24", "status": "ABSENT",
    }, {
        "staffId": staff_id, "date": "2026-09-24", "status": "PRESENT",
    }], headers=headers)
    assert duplicate.status_code == 422

    assert client.delete(f"/api/staff/{staff_id}", headers=headers).status_code == 204
    assert client.get(f"/api/staff/{staff_id}", headers=headers).status_code == 404
    assert len(client.get(f"/api/salary/staff/{staff_id}", headers=headers).json()) == 1


def test_hr_rejects_unknown_staff_and_other_tenant(client):
    headers = {"X-Tenant-ID": "school-a"}
    assert client.post("/api/leave/apply", json={
        "staffId": "missing", "leaveType": "SICK", "fromDate": "2026-09-24",
        "toDate": "2026-09-24", "reason": "Ill",
    }, headers=headers).status_code == 404
    assert client.post("/api/staff-attendance/mark", json=[{
        "staffId": "missing", "date": "2026-09-24", "status": "PRESENT",
    }], headers=headers).status_code == 404
    assert client.get("/api/staff", headers={"X-Tenant-ID": "school-b"}).status_code == 403
