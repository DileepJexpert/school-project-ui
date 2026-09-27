from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.admissions import create_student, update_student
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Enrollment, Student
from app.schemas import StudentInput
from app.serializers import student_wire
from app.years import normalize_year

router = APIRouter(prefix="/students", tags=["students"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


@router.get("")
def list_students(
    session: Db,
    tenant: TenantId,
    class_name: str | None = Query(None, alias="className"),
    academic_year: str | None = Query(None, alias="academicYear"),
) -> list[dict]:
    require_tenant(session, tenant)
    if academic_year:
        try:
            year = normalize_year(academic_year)
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
        statement = (
            select(Student, Enrollment)
            .join(Enrollment, Enrollment.student_id == Student.id)
            .where(
                Student.tenant_id == tenant,
                Enrollment.tenant_id == tenant,
                Enrollment.academic_year == year,
            )
        )
        if class_name:
            statement = statement.where(Enrollment.class_name == class_name)
        result = []
        for student, enrollment in session.execute(statement.order_by(Student.full_name)):
            item = student_wire(student)
            item.update({
                "classForAdmission": enrollment.class_name,
                "academicYear": enrollment.academic_year,
                "rollNumber": enrollment.roll_number,
                "dateOfAdmission": enrollment.date_of_admission.isoformat(),
                "status": "ACTIVE" if enrollment.status in ("ACTIVE", "COMPLETED") else "INACTIVE",
            })
            result.append(item)
        return result
    statement = select(Student).where(Student.tenant_id == tenant)
    if class_name:
        statement = statement.where(Student.class_name == class_name)
    return [student_wire(student) for student in session.scalars(statement.order_by(Student.full_name))]


@router.get("/search")
def search_students(session: Db, tenant: TenantId, name: str = "") -> list[dict]:
    require_tenant(session, tenant)
    statement = select(Student).where(
        Student.tenant_id == tenant,
        Student.full_name.ilike(f"%{name}%"),
    )
    return [student_wire(student) for student in session.scalars(statement.order_by(Student.full_name))]


@router.post("/enquiry", status_code=201)
def create_enquiry(data: StudentInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            student = create_student(session, tenant, data, enquiry=True)
            result = student_wire(student)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Duplicate admission number") from error


@router.post("/add", status_code=201)
def admit_student(data: StudentInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            student = create_student(session, tenant, data, enquiry=False)
            result = student_wire(student)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Duplicate admission or enrollment") from error


@router.get("/{student_id}")
def get_student(student_id: str, session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    return student_wire(student)


@router.put("/{student_id}")
def save_student(student_id: str, data: StudentInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            student = session.get(Student, student_id)
            if student is None or student.tenant_id != tenant:
                raise HTTPException(status_code=404, detail="Student not found")
            result = student_wire(update_student(session, student, data))
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Duplicate admission or enrollment") from error


@router.delete("/{student_id}", status_code=204)
def delete_enquiry(student_id: str, session: Db, tenant: TenantId) -> None:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            student = session.get(Student, student_id)
            if student is None or student.tenant_id != tenant:
                raise HTTPException(status_code=404, detail="Student not found")
            if student.status != "ENQUIRY":
                raise HTTPException(
                    status_code=409,
                    detail="Only enquiries can be deleted; admitted student records must be retained",
                )
            if session.scalar(
                select(Enrollment.id).where(
                    Enrollment.tenant_id == tenant,
                    Enrollment.student_id == student_id,
                )
            ) is not None:
                raise HTTPException(status_code=409, detail="Enquiry has an enrollment")
            session.delete(student)
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Enquiry has related records") from error
