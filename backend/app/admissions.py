from calendar import month_abbr
from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import school_year_start_month
from app.models import ClassYearClosure, Enrollment, FeeInstallment, FeeProfile, FeeStructure, Student
from app.schemas import StudentInput


def _normalize_class_code(class_name: str | None) -> str:
    c = (class_name or "").strip().upper()
    if not c:
        return "GEN"
    if "NUR" in c:
        return "NUR"
    if "LKG" in c or "JR" in c:
        return "LKG"
    if "UKG" in c or "SR" in c:
        return "UKG"
    if "PLAY" in c:
        return "PG"
    digits = "".join(ch for ch in c if ch.isdigit())
    if digits:
        try:
            return f"C{int(digits):02d}"
        except Exception:
            return f"C{digits}"
    clean = "".join(ch for ch in c if ch.isalnum())
    return (clean[:4] or "GEN").upper()


def _generate_admission_number(
    session: Session, tenant: str, class_name: str, doa=None, prefix: str = "ADM"
) -> str:
    if isinstance(doa, str) and len(doa) >= 7:
        date_code = doa[:7].replace("-", "")
    elif hasattr(doa, "strftime"):
        date_code = doa.strftime("%Y%m")
    else:
        date_code = datetime.now(timezone.utc).strftime("%Y%m")

    cls_code = _normalize_class_code(class_name)

    if prefix == "ENQ":
        count = session.scalar(
            select(func.count(Student.id)).where(Student.tenant_id == tenant, Student.status == "ENQUIRY")
        ) or 0
    else:
        count = session.scalar(
            select(func.count(Student.id)).where(Student.tenant_id == tenant, Student.status != "ENQUIRY")
        ) or 0

    start_seq = max(1, count + 1)
    seq = start_seq
    while True:
        candidate = f"{prefix}-{date_code}-{cls_code}-{seq:04d}"
        existing = session.scalar(
            select(Student.id).where(Student.tenant_id == tenant, Student.admission_number == candidate)
        )
        if not existing:
            return candidate
        seq += 1


def matching_structure(
    session: Session, tenant: str, class_name: str, academic_year: str
) -> FeeStructure:
    structure = session.scalar(
        select(FeeStructure).where(
            FeeStructure.tenant_id == tenant,
            FeeStructure.class_name == class_name,
            FeeStructure.academic_year == academic_year,
        )
    )
    if structure is None or not structure.components:
        raise HTTPException(
            status_code=409,
            detail=f"Set up fees for {class_name} ({academic_year}) before admission",
        )
    return structure


def require_open_class_year(session: Session, tenant: str, class_name: str, year: str) -> None:
    closure = session.scalar(
        select(ClassYearClosure.id).where(
            ClassYearClosure.tenant_id == tenant,
            ClassYearClosure.class_name == class_name,
            ClassYearClosure.academic_year == year,
        )
    )
    if closure is not None:
        raise HTTPException(status_code=409, detail=f"{class_name} ({year}) is closed after rollover")


def _installment_specs(structure: FeeStructure) -> list[tuple[str, Decimal]]:
    start_month = school_year_start_month()
    start_year = int(structure.academic_year[:4])
    specs: list[tuple[str, Decimal]] = []
    for component in structure.components:
        if component.frequency == "MONTHLY":
            for offset in range(12):
                month = (start_month - 1 + offset) % 12 + 1
                year = start_year + (start_month - 1 + offset) // 12
                specs.append(
                    (f"{component.name} - {month_abbr[month]} {year}", component.amount)
                )
        else:
            specs.append((component.name, component.amount))
    return specs


def add_enrollment_and_profile(
    session: Session, student: Student, structure: FeeStructure
) -> None:
    enrollment = Enrollment(
        tenant_id=student.tenant_id,
        student_id=student.id,
        academic_year=student.academic_year,
        class_name=student.class_name,
        roll_number=student.roll_number,
        date_of_admission=student.date_of_admission,
        status="ACTIVE",
    )
    session.add(enrollment)
    session.flush()
    profile = FeeProfile(
        tenant_id=student.tenant_id,
        enrollment_id=enrollment.id,
        fee_structure_id=structure.id,
    )
    profile.installments = [
        FeeInstallment(position=index, name=name, amount_due=amount)
        for index, (name, amount) in enumerate(_installment_specs(structure))
    ]
    session.add(profile)
    session.flush()


def apply_input(student: Student, data: StudentInput) -> None:
    student.full_name = data.full_name.strip()
    student.date_of_birth = data.date_of_birth
    student.gender = data.gender
    student.blood_group = data.blood_group
    student.nationality = data.nationality
    student.religion = data.religion
    student.mother_tongue = data.mother_tongue
    student.aadhar_number = data.aadhar_number
    student.class_name = data.class_for_admission
    student.academic_year = data.academic_year
    student.date_of_admission = data.date_of_admission
    student.roll_number = data.roll_number
    student.parent_details = data.parent_details.model_dump(by_alias=True)
    student.contact_details = data.contact_details.model_dump(by_alias=True)
    student.previous_school_details = data.previous_school_details.model_dump(by_alias=True)


def create_student(session: Session, tenant: str, data: StudentInput, *, enquiry: bool) -> Student:
    require_open_class_year(session, tenant, data.class_for_admission, data.academic_year)
    structure = None if enquiry else matching_structure(
        session, tenant, data.class_for_admission, data.academic_year
    )
    student = Student(tenant_id=tenant)
    apply_input(student, data)
    student.status = "ENQUIRY" if enquiry else "ACTIVE"
    sub_adm = data.admission_number.strip() if data.admission_number else ""
    if enquiry:
        student.admission_number = sub_adm or _generate_admission_number(
            session, tenant, data.class_for_admission, data.date_of_admission, prefix="ENQ"
        )
    else:
        student.admission_number = sub_adm or _generate_admission_number(
            session, tenant, data.class_for_admission, data.date_of_admission, prefix="ADM"
        )
    session.add(student)
    session.flush()
    if structure is not None:
        add_enrollment_and_profile(session, student, structure)
    return student


def update_student(session: Session, student: Student, data: StudentInput) -> Student:
    old_status = student.status
    old_class = student.class_name
    old_year = student.academic_year
    new_class = data.class_for_admission
    new_year = data.academic_year
    activating_enquiry = old_status == "ENQUIRY" and data.status == "ACTIVE"
    promoting = old_status == "ACTIVE" and data.status == "ACTIVE" and (
        old_class != new_class or old_year != new_year
    )

    if promoting:
        start = int(old_year[:4])
        if new_year != f"{start + 1}-{start + 2}" or new_class == old_class:
            raise HTTPException(status_code=409, detail="Use next-year class promotion")
    elif old_status == "ACTIVE" and data.status == "INACTIVE" and (
        old_class != new_class or old_year != new_year
    ):
        raise HTTPException(status_code=409, detail="Graduation must keep the old class and year")
    elif old_status != "ENQUIRY" and not promoting and (
        old_class != new_class or old_year != new_year
    ):
        raise HTTPException(status_code=409, detail="Class/year change requires promotion")

    structure = None
    if activating_enquiry or promoting:
        require_open_class_year(session, student.tenant_id, new_class, new_year)
        structure = matching_structure(session, student.tenant_id, new_class, new_year)
    if promoting:
        require_open_class_year(session, student.tenant_id, old_class, old_year)
    if old_status == "INACTIVE" and data.status == "ACTIVE":
        require_open_class_year(session, student.tenant_id, old_class, old_year)

    apply_input(student, data)
    student.status = data.status
    if activating_enquiry:
        submitted_number = data.admission_number.strip() if data.admission_number else ""
        if not submitted_number or submitted_number.startswith("ENQ-"):
            student.admission_number = _generate_admission_number(
                session, student.tenant_id, new_class, data.date_of_admission, prefix="ADM"
            )
        else:
            student.admission_number = submitted_number
        add_enrollment_and_profile(session, student, structure)
    elif promoting:
        old_enrollment = session.scalar(
            select(Enrollment).where(
                Enrollment.tenant_id == student.tenant_id,
                Enrollment.student_id == student.id,
                Enrollment.academic_year == old_year,
            )
        )
        if old_enrollment is None:
            raise HTTPException(status_code=409, detail="Previous enrollment is missing")
        old_enrollment.status = "COMPLETED"
        add_enrollment_and_profile(session, student, structure)
    elif old_status == "ACTIVE" and data.status == "INACTIVE":
        enrollment = session.scalar(
            select(Enrollment).where(
                Enrollment.tenant_id == student.tenant_id,
                Enrollment.student_id == student.id,
                Enrollment.academic_year == old_year,
            )
        )
        if enrollment is not None:
            enrollment.status = "INACTIVE"
    elif old_status == "INACTIVE" and data.status == "ACTIVE":
        enrollment = session.scalar(
            select(Enrollment).where(
                Enrollment.tenant_id == student.tenant_id,
                Enrollment.student_id == student.id,
                Enrollment.academic_year == old_year,
            )
        )
        if enrollment is None:
            raise HTTPException(status_code=409, detail="Inactive enquiry requires admission, not reactivation")
        enrollment.status = "ACTIVE"
    session.flush()
    return student
