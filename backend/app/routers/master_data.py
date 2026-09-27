"""Read first-run school catalogue and fee-setup readiness."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import AcademicYearRecord, ClassSubject, Enrollment, ExamConfig, FeeStructure, ResultRecord, SchoolClass, SchoolSubject
from app.schemas import ClassSubjectsInput, SchoolSubjectInput
from app.years import academic_year_for_date, normalize_year

router = APIRouter(prefix="/master-data", tags=["master data"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


@router.get("")
def master_data(session: Db, tenant: TenantId, academic_year: str | None = Query(default=None, alias="academicYear")) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(academic_year) if academic_year else academic_year_for_date(date.today())
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    years = list(session.scalars(select(AcademicYearRecord).where(
        AcademicYearRecord.tenant_id == tenant,
    ).order_by(AcademicYearRecord.year)))
    classes = list(session.scalars(select(SchoolClass).where(
        SchoolClass.tenant_id == tenant, SchoolClass.active.is_(True),
    ).order_by(SchoolClass.sort_order)))
    subjects = list(session.scalars(select(SchoolSubject).where(
        SchoolSubject.tenant_id == tenant, SchoolSubject.active.is_(True),
    ).order_by(SchoolSubject.sort_order)))
    configured = set(session.scalars(select(FeeStructure.class_name).where(
        FeeStructure.tenant_id == tenant, FeeStructure.academic_year == year,
    )))
    subject_classes = set(session.scalars(select(ClassSubject.class_name).where(
        ClassSubject.tenant_id == tenant, ClassSubject.academic_year == year,
    )))
    selected_year = next((item for item in years if item.year == year), None)
    exam_configs = list(session.scalars(select(ExamConfig).where(
        ExamConfig.tenant_id == tenant, ExamConfig.academic_year == year,
        ExamConfig.is_active.is_(True),
    )))
    exam_order = selected_year.exam_order if selected_year else None
    exam_weightages_configured = bool(
        exam_order and {item.exam_type for item in exam_configs} == set(exam_order)
        and all(item.weightage_percent > 0 for item in exam_configs)
        and sum(item.weightage_percent for item in exam_configs) == 100
    )
    return {
        "academicYear": year,
        "gradingPolicyConfigured": bool(selected_year and selected_year.grade_bands and selected_year.pass_percentage is not None),
        "examWeightagesConfigured": exam_weightages_configured,
        "years": [{"year": item.year, "startDate": item.start_date.isoformat(),
                   "endDate": item.end_date.isoformat(), "status": item.status} for item in years],
        "classes": [{"className": item.class_name, "baseClass": item.base_class,
                     "section": item.section} for item in classes],
        "subjects": [item.name for item in subjects],
        "configuredFeeClasses": [item.class_name for item in classes if item.class_name in configured],
        "missingFeeClasses": [item.class_name for item in classes if item.class_name not in configured],
        "configuredSubjectClasses": [item.class_name for item in classes if item.class_name in subject_classes],
        "missingSubjectClasses": [item.class_name for item in classes if item.class_name not in subject_classes],
    }


@router.get("/class-subjects")
def get_class_subjects(
    session: Db, tenant: TenantId,
    class_name: str = Query(alias="className"),
    academic_year: str = Query(alias="academicYear"),
) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    subjects = list(session.scalars(select(ClassSubject.subject_name).where(
        ClassSubject.tenant_id == tenant, ClassSubject.class_name == class_name,
        ClassSubject.academic_year == year,
    ).order_by(ClassSubject.subject_name)))
    return {"className": class_name, "academicYear": year, "subjects": subjects}


@router.get("/subjects")
def get_subjects(session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    return [
        {"id": item.id, "name": item.name, "active": item.active}
        for item in session.scalars(select(SchoolSubject).where(
            SchoolSubject.tenant_id == tenant,
        ).order_by(SchoolSubject.sort_order, SchoolSubject.name))
    ]


@router.put("/subjects")
def add_subject(data: SchoolSubjectInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        subject = session.scalar(select(SchoolSubject).where(
            SchoolSubject.tenant_id == tenant,
            func.lower(SchoolSubject.name) == data.name.lower(),
        ))
        if subject is None:
            order = session.scalar(select(func.max(SchoolSubject.sort_order)).where(
                SchoolSubject.tenant_id == tenant,
            ))
            subject = SchoolSubject(
                tenant_id=tenant, name=data.name,
                sort_order=(order or 0) + 1, active=True,
            )
            session.add(subject)
        else:
            subject.active = True
        session.flush()
        result = {"id": subject.id, "name": subject.name, "active": subject.active}
    return result


@router.put("/class-subjects")
def save_class_subjects(data: ClassSubjectsInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        school_class = session.scalar(select(SchoolClass.id).where(
            SchoolClass.tenant_id == tenant, SchoolClass.class_name == data.class_name,
            SchoolClass.active.is_(True),
        ))
        year = session.scalar(select(AcademicYearRecord.id).where(
            AcademicYearRecord.tenant_id == tenant, AcademicYearRecord.year == data.academic_year,
        ))
        if school_class is None or year is None:
            raise HTTPException(status_code=409, detail="Set up the class and academic year first")
        known = set(session.scalars(select(SchoolSubject.name).where(
            SchoolSubject.tenant_id == tenant, SchoolSubject.active.is_(True),
        )))
        if not set(data.subjects).issubset(known):
            raise HTTPException(status_code=422, detail="A subject is not in the school catalogue")
        existing = list(session.scalars(select(ClassSubject).where(
            ClassSubject.tenant_id == tenant, ClassSubject.class_name == data.class_name,
            ClassSubject.academic_year == data.academic_year,
        )))
        requested = set(data.subjects)
        if {item.subject_name for item in existing} != requested:
            results = list(session.scalars(select(ResultRecord).join(Enrollment).where(
                ResultRecord.tenant_id == tenant, ResultRecord.voided_at.is_(None),
                Enrollment.tenant_id == tenant, Enrollment.class_name == data.class_name,
                Enrollment.academic_year == data.academic_year,
            )))
            if any(item.is_published for item in results):
                raise HTTPException(status_code=409, detail="Published results lock class subjects")
            if any(item.subject not in requested for item in results):
                raise HTTPException(status_code=409, detail="Remove draft marks for subjects no longer selected")
            for item in existing:
                session.delete(item)
            session.flush()
            session.add_all(ClassSubject(
                tenant_id=tenant, class_name=data.class_name,
                academic_year=data.academic_year, subject_name=subject,
            ) for subject in data.subjects)
            session.flush()
    return {"className": data.class_name, "academicYear": data.academic_year,
            "subjects": sorted(data.subjects)}
