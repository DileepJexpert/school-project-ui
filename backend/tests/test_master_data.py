from sqlalchemy import select, func

from app.db import get_session
from app.models import AcademicYearRecord, FeeStructure, SchoolClass, SchoolSiteContent, SchoolSubject, Student, User
from app.schemas import ClassSubjectsInput, FeeStructureInput, GradingPolicyInput
from app.seed import bootstrap_school


def test_first_run_catalogue_and_fee_seed_are_repeatable(client):
    fee = FeeStructureInput.model_validate({
        "className": "Nursery", "academicYear": "2026-2027",
        "feeComponents": [{"feeName": "Tuition", "amount": 100, "frequency": "MONTHLY"}],
    })
    generator = client.app.dependency_overrides[get_session]()
    session = next(generator)
    try:
        with session.begin():
            first = bootstrap_school(
                session, "school-a", "School A", "2026-2027", city="Delhi", board="CBSE",
                admin_email="seed@school.test", admin_password="initial-password-123",
                fee_structures=[fee],
            )
        with session.begin():
            second = bootstrap_school(
                session, "school-a", "School A", "2026-2027",
                admin_email="seed@school.test", fee_structures=[fee],
            )
        assert first == second
        assert session.scalar(select(func.count()).select_from(AcademicYearRecord)) == 1
        assert session.scalar(select(func.count()).select_from(SchoolClass)) == 27
        assert session.scalar(select(func.count()).select_from(SchoolSubject)) == 13
        assert session.scalar(select(func.count()).select_from(FeeStructure)) == 1
        assert session.scalar(select(func.count()).select_from(User).where(User.email == "seed@school.test")) == 1
        assert session.scalar(select(func.count()).select_from(Student)) == 0
        policy = GradingPolicyInput.model_validate({
            "academicYear": "2026-2027", "passPercentage": 40,
            "examOrder": ["TERM1", "TERM2"],
            "bands": [
                {"minPercentage": 40, "grade": "P", "gradePoint": 4},
                {"minPercentage": 0, "grade": "F", "gradePoint": 0},
            ],
        })
        session.rollback()
        with session.begin():
            configured = bootstrap_school(
                session, "school-a", "School A", "2026-2027", grading_policy=policy,
                additional_subjects=["Dance"],
                site_content={"mission": "Teach every child well"},
                class_subjects=[ClassSubjectsInput.model_validate({
                    "className": "Nursery", "academicYear": "2026-2027",
                    "subjects": ["English", "Dance"],
                })],
            )
        assert configured["gradingPolicyConfigured"] is True
        assert configured["additionalSubjects"] == 1
        assert configured["subjects"] == 14
        assert configured["classSubjectSets"] == 1
        assert session.get(SchoolSiteContent, "school-a").content["mission"] == "Teach every child well"
    finally:
        generator.close()
    result = client.get("/api/master-data?academicYear=2026-2027", headers={"X-Tenant-ID": "school-a"})
    assert result.status_code == 200, result.text
    assert len(result.json()["classes"]) == 27
    assert result.json()["gradingPolicyConfigured"] is True
    assert result.json()["examWeightagesConfigured"] is False
    assert result.json()["configuredSubjectClasses"] == ["Nursery"]
    assert "Dance" in result.json()["subjects"]
    assert result.json()["configuredFeeClasses"] == ["Nursery"]
    assert len(result.json()["missingFeeClasses"]) == 26

    next_year_fee = {
        "className": "Class 1 - A", "academicYear": "2027-2028",
        "feeComponents": [{"feeName": "Tuition", "amount": 120, "frequency": "MONTHLY"}],
    }
    assert client.post("/api/feestructures", json=[next_year_fee], headers={"X-Tenant-ID": "school-a"}).status_code == 200
    next_catalogue = client.get("/api/master-data?academicYear=2027-2028", headers={"X-Tenant-ID": "school-a"}).json()
    assert [item["year"] for item in next_catalogue["years"]] == ["2026-2027", "2027-2028"]
    assert next_catalogue["configuredFeeClasses"] == ["Class 1 - A"]


def test_admin_can_add_custom_subject_before_assigning_it(client):
    headers = {"X-Tenant-ID": "school-a"}
    assert client.post("/api/feestructures", json=[{
        "className": "Class 11 - A", "academicYear": "2026-2027",
        "feeComponents": [{"feeName": "Tuition", "amount": 100, "frequency": "MONTHLY"}],
    }], headers=headers).status_code == 200
    assignment = {
        "className": "Class 11 - A", "academicYear": "2026-2027", "subjects": ["Economics"],
    }
    assert client.put("/api/master-data/class-subjects", json=assignment, headers=headers).status_code == 422
    created = client.put("/api/master-data/subjects", json={"name": "Economics"}, headers=headers)
    assert created.status_code == 200, created.text
    assert client.put("/api/master-data/subjects", json={"name": "economics"}, headers=headers).json()["id"] == created.json()["id"]
    assert client.put("/api/master-data/class-subjects", json=assignment, headers=headers).status_code == 200
    assert client.get("/api/master-data/class-subjects", params={
        "className": "Class 11 - A", "academicYear": "2026-2027",
    }, headers=headers).json()["subjects"] == ["Economics"]
