from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.master_data import ensure_catalog
from app.models import Enrollment, FeeComponent, FeeProfile, FeeStructure, Student
from app.schemas import FeeStructureInput
from app.serializers import profile_wire, structure_wire
from app.years import normalize_year

router = APIRouter(tags=["fees"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


@router.get("/feestructures")
def list_structures(year: str, session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    statement = select(FeeStructure).where(
        FeeStructure.tenant_id == tenant, FeeStructure.academic_year == year
    )
    return [structure_wire(item) for item in session.scalars(statement.order_by(FeeStructure.class_name))]


@router.post("/feestructures")
def save_structures(data: list[FeeStructureInput], session: Db, tenant: TenantId) -> list[dict]:
    if not data:
        raise HTTPException(status_code=422, detail="At least one structure is required")
    try:
        with session.begin():
            lock_tenant(session, tenant)
            for year in {item.academic_year for item in data}:
                ensure_catalog(session, tenant, year)
            seen: set[tuple[str, str]] = set()
            saved: list[FeeStructure] = []
            for item in data:
                key = (item.class_name, item.academic_year)
                if key in seen:
                    raise HTTPException(status_code=422, detail="Duplicate class/year in request")
                seen.add(key)
                names = [c.fee_name.strip().lower() for c in item.fee_components]
                if len(names) != len(set(names)):
                    raise HTTPException(status_code=422, detail="Duplicate fee component name")
                structure = session.scalar(
                    select(FeeStructure).where(
                        FeeStructure.tenant_id == tenant,
                        FeeStructure.class_name == item.class_name,
                        FeeStructure.academic_year == item.academic_year,
                    )
                )
                if structure is None:
                    structure = FeeStructure(
                        tenant_id=tenant,
                        class_name=item.class_name,
                        academic_year=item.academic_year,
                    )
                    session.add(structure)
                else:
                    in_use = session.scalar(
                        select(FeeProfile.id).where(FeeProfile.fee_structure_id == structure.id).limit(1)
                    )
                    if in_use:
                        raise HTTPException(status_code=409, detail="Fee structure is already in use")
                    structure.components.clear()
                    session.flush()
                structure.components = [
                    FeeComponent(
                        position=index,
                        name=component.fee_name.strip(),
                        amount=component.amount,
                        frequency=component.frequency,
                        description=component.description,
                    )
                    for index, component in enumerate(item.fee_components)
                ]
                session.flush()
                saved.append(structure)
            result = [structure_wire(item) for item in saved]
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Duplicate fee structure") from error


@router.delete("/feestructures/{structure_id}", status_code=204)
def delete_structure(structure_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        structure = session.get(FeeStructure, structure_id)
        if structure is None or structure.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Fee structure not found")
        in_use = session.scalar(
            select(FeeProfile.id).where(FeeProfile.fee_structure_id == structure.id).limit(1)
        )
        if in_use:
            raise HTTPException(status_code=409, detail="Fee structure is already in use")
        session.delete(structure)
    return Response(status_code=204)


@router.get("/student-fee-profiles/{student_id}")
def get_profile(
    student_id: str,
    session: Db,
    tenant: TenantId,
    academic_year: str | None = Query(None, alias="academicYear"),
) -> dict:
    require_tenant(session, tenant)
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    try:
        year = normalize_year(academic_year) if academic_year else student.academic_year
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    profile = session.scalar(
        select(FeeProfile)
        .join(Enrollment)
        .where(
            FeeProfile.tenant_id == tenant,
            Enrollment.student_id == student_id,
            Enrollment.academic_year == year,
        )
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="Fee profile not found for this year")
    return profile_wire(profile, student)
