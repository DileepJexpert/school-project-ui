from test_admission_flow import HEADERS, student_payload, structure


def test_transport_capacity_assignment_and_history(client):
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    first = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    second = client.post("/api/students/add", json={**student_payload(), "fullName": "Ben Rao"}, headers=HEADERS).json()

    route = client.post("/api/transport/routes", json={
        "zoneName": "Zone A", "displayName": "North", "areasCovered": "North",
        "stops": ["Gate", "Square"], "firstPickupTime": "7:10 AM", "monthlyFee": 800,
    }, headers=HEADERS)
    assert route.status_code == 201, route.text
    route_id = route.json()["id"]
    bus = client.post("/api/transport/buses", json={
        "busNumber": "BUS-1", "driverName": "Driver", "driverMobile": "9999999999",
        "routeId": route_id, "capacity": 1,
    }, headers=HEADERS)
    assert bus.status_code == 201, bus.text
    bus_id = bus.json()["id"]
    assigned = client.post("/api/transport/assignments", json={
        "studentId": first["id"], "busId": bus_id, "routeId": route_id, "pickupStop": "Gate",
    }, headers=HEADERS)
    assert assigned.status_code == 201, assigned.text
    assert client.post("/api/transport/assignments", json={
        "studentId": second["id"], "busId": bus_id, "routeId": route_id, "pickupStop": "Square",
    }, headers=HEADERS).status_code == 409
    assert client.post("/api/transport/assignments", json={
        "studentId": first["id"], "busId": bus_id, "routeId": route_id, "pickupStop": "Gate",
    }, headers=HEADERS).json()["id"] == assigned.json()["id"]
    assert client.get("/api/transport/stats", headers=HEADERS).json()["totalStudentsAssigned"] == 1
    assert client.get("/api/transport/buses", headers=HEADERS).json()[0]["assignedCount"] == 1
    assert client.delete(f"/api/transport/buses/{bus_id}", headers=HEADERS).status_code == 409
    assert client.delete(f"/api/transport/assignments/{assigned.json()['id']}", headers=HEADERS).status_code == 204
    assert client.get(f"/api/transport/assignments/student/{first['id']}", headers=HEADERS).status_code == 204
    assert client.delete(f"/api/transport/buses/{bus_id}", headers=HEADERS).status_code == 204


def test_student_transport_read_is_linked(client):
    client.post("/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS)
    first = client.post("/api/students/add", json=student_payload(), headers=HEADERS).json()
    other = client.post("/api/students/add", json={**student_payload(), "fullName": "Ben Rao"}, headers=HEADERS).json()
    created = client.post("/api/users", json={
        "email": "transport-student@school.test", "password": "student-pass-123",
        "fullName": "Ada", "role": "STUDENT", "linkedEntityId": first["id"],
    }, headers=HEADERS)
    assert created.status_code == 201, created.text
    login = client.post("/api/auth/login", json={
        "email": "transport-student@school.test", "password": "student-pass-123",
    }, headers=HEADERS)
    token_headers = {**HEADERS, "Authorization": f"Bearer {login.json()['token']}"}
    assert client.get("/api/transport/buses", headers=token_headers).status_code == 200
    assert client.get(f"/api/transport/assignments/student/{first['id']}", headers=token_headers).status_code == 204
    assert client.get(f"/api/transport/assignments/student/{other['id']}", headers=token_headers).status_code == 403
    assert client.get("/api/transport/assignments", headers=token_headers).status_code == 403
