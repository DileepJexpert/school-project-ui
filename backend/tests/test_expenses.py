HEADERS = {"X-Tenant-ID": "school-a"}


def test_expense_filters_tenant_isolation_and_void_history(client):
    payload = {
        "title": "Lab equipment",
        "category": "Supplies",
        "amount": 350.50,
        "date": "2026-09-01",
        "paidTo": "Vendor",
        "remarks": "Invoice 42",
    }
    created = client.post("/api/expenses", json=payload, headers=HEADERS)
    assert created.status_code == 201, created.text
    expense = created.json()
    assert expense["amount"] == 350.5
    assert client.get("/api/expenses", headers=HEADERS).json() == [expense]
    assert client.get("/api/expenses", params={"from": "2026-09-02"}, headers=HEADERS).json() == []
    assert client.get("/api/expenses", params={"to": "2026-09-01"}, headers=HEADERS).json() == [expense]
    assert client.get("/api/expenses", headers={"X-Tenant-ID": "school-b"}).status_code == 403
    assert client.delete(f"/api/expenses/{expense['id']}", headers={"X-Tenant-ID": "school-b"}).status_code == 403
    assert client.delete(f"/api/expenses/{expense['id']}", headers=HEADERS).status_code == 204
    assert client.get("/api/expenses", headers=HEADERS).json() == []
    assert client.delete(f"/api/expenses/{expense['id']}", headers=HEADERS).status_code == 404


def test_expense_rejects_invalid_amount_and_date_range(client):
    invalid = {
        "title": "No cost",
        "category": "Supplies",
        "amount": 0,
        "date": "2026-09-01",
        "paidTo": "Vendor",
    }
    assert client.post("/api/expenses", json=invalid, headers=HEADERS).status_code == 422
    assert client.get(
        "/api/expenses", params={"from": "2026-09-02", "to": "2026-09-01"}, headers=HEADERS
    ).status_code == 422
