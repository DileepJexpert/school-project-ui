import hashlib
import json
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.admissions import add_enrollment_and_profile, matching_structure, require_open_class_year
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import ClassYearClosure, Enrollment, RolloverRun, Student
from app.schemas import RolloverInput

router = APIRouter(prefix="/academic-years", tags=["academic-years"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _wire(run: RolloverRun) -> dict:
    created_at = run.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    return {
        "id": run.id,
        "action": "PROMOTE" if run.target_year else "GRADUATE",
        "sourceClass": run.source_class,
        "sourceYear": run.source_year,
        "targetClass": run.target_class,
        "targetYear": run.target_year,
        "studentCount": run.student_count,
        "studentIds": run.student_ids,
        "createdAt": created_at.isoformat(),
    }


def _replay(session: Session, tenant: str, key: str, fingerprint: str) -> dict | None:
    run = session.scalar(
        select(RolloverRun).where(RolloverRun.tenant_id == tenant, RolloverRun.idempotency_key == key)
    )
    if run is None:
        return None
    if run.request_fingerprint != fingerprint:
        raise HTTPException(status_code=409, detail="Idempotency key was used for another rollover")
    return _wire(run)


@router.post("/rollover", status_code=201)
def roll_over_class(
    data: RolloverInput,
    session: Db,
    tenant: TenantId,
    idempotency_key: str = Header(alias="Idempotency-Key", min_length=8, max_length=128),
) -> dict:
    payload = json.dumps(data.model_dump(mode="json", by_alias=True), sort_keys=True)
    fingerprint = hashlib.sha256(payload.encode()).hexdigest()
    try:
        with session.begin():
            lock_tenant(session, tenant)
            replay = _replay(session, tenant, idempotency_key, fingerprint)
            if replay is not None:
                return replay

            rows = session.execute(
                select(Student, Enrollment)
                .join(Enrollment, Enrollment.student_id == Student.id)
                .where(
                    Student.tenant_id == tenant,
                    Student.status == "ACTIVE",
                    Student.class_name == data.source_class,
                    Student.academic_year == data.source_year,
                    Enrollment.tenant_id == tenant,
                    Enrollment.class_name == data.source_class,
                    Enrollment.academic_year == data.source_year,
                    Enrollment.status == "ACTIVE",
                )
                .order_by(Student.id)
                .with_for_update()
            ).all()
            if not rows:
                raise HTTPException(status_code=409, detail="No active students in source class and year")

            structure = None
            if data.action == "PROMOTE":
                require_open_class_year(session, tenant, data.target_class, data.target_year)
                structure = matching_structure(session, tenant, data.target_class, data.target_year)
            student_ids = []
            for student, enrollment in rows:
                student_ids.append(student.id)
                enrollment.status = "COMPLETED"
                if structure is None:
                    student.status = "INACTIVE"
                else:
                    student.class_name = data.target_class
                    student.academic_year = data.target_year
                    add_enrollment_and_profile(session, student, structure)

            run = RolloverRun(
                tenant_id=tenant,
                idempotency_key=idempotency_key,
                request_fingerprint=fingerprint,
                source_class=data.source_class,
                source_year=data.source_year,
                target_class=data.target_class,
                target_year=data.target_year,
                student_count=len(student_ids),
                student_ids=student_ids,
                created_at=datetime.now(timezone.utc),
            )
            session.add(run)
            session.flush()
            session.add(ClassYearClosure(
                tenant_id=tenant,
                class_name=data.source_class,
                academic_year=data.source_year,
                rollover_run_id=run.id,
                closed_at=run.created_at,
            ))
            session.flush()
            result = _wire(run)
        return result
    except IntegrityError as error:
        session.rollback()
        replay = _replay(session, tenant, idempotency_key, fingerprint)
        if replay is not None:
            return replay
        raise HTTPException(status_code=409, detail="Rollover conflicts with an existing enrollment") from error


@router.get("/rollover/{run_id}")
def get_rollover(run_id: str, session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    run = session.get(RolloverRun, run_id)
    if run is None or run.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Rollover not found")
    return _wire(run)
