from datetime import datetime, timezone
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import AcademicYearRecord, ClassSubject, CoscholasticAssessment, Enrollment, ExamConfig, ResultRecord, Student
from app.result_reporting import class_analytics, grade as _grade, grading_policy, report_card
from app.schemas import CoscholasticInput, ExamConfigInput, GradingPolicyInput, ResultBulkInput, ResultUpdateInput
from app.serializers import money
from app.years import normalize_year

router = APIRouter(prefix="/results", tags=["results"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _rank(session: Session, record: ResultRecord) -> int:
    peers = list(session.scalars(
        select(ResultRecord).join(Enrollment).where(
            ResultRecord.tenant_id == record.tenant_id,
            ResultRecord.exam_type == record.exam_type,
            ResultRecord.subject == record.subject,
            ResultRecord.voided_at.is_(None),
            Enrollment.tenant_id == record.tenant_id,
            Enrollment.class_name == record.enrollment.class_name,
            Enrollment.academic_year == record.enrollment.academic_year,
        )
    ))
    percentage = record.marks_obtained / record.max_marks
    return 1 + sum(1 for item in peers if item.marks_obtained / item.max_marks > percentage)


def _wire(session: Session, record: ResultRecord) -> dict:
    enrollment = record.enrollment
    percentage = record.marks_obtained * 100 / record.max_marks
    policy = grading_policy(session, record.tenant_id, enrollment.academic_year)
    grade, grade_point = _grade(percentage, policy)
    return {
        "id": record.id,
        "studentId": enrollment.student_id,
        "studentName": enrollment.student.full_name,
        "rollNumber": enrollment.roll_number or "",
        "className": enrollment.class_name,
        "academicYear": enrollment.academic_year,
        "examType": record.exam_type,
        "subject": record.subject,
        "marksObtained": money(record.marks_obtained),
        "maxMarks": money(record.max_marks),
        "percentage": round(float(percentage), 2),
        "grade": grade,
        "gradePoint": grade_point,
        "isPassed": policy is not None and percentage >= policy.pass_percentage,
        "gradingPolicyConfigured": policy is not None,
        "classRank": _rank(session, record),
        "teacherRemarks": record.teacher_remarks,
        "isPublished": record.is_published,
        "enteredBy": record.entered_by,
    }


@router.get("")
def search_published_results(
    session: Db, tenant: TenantId,
    roll_number: str = Query(alias="rollNumber", min_length=1),
    class_name: str = Query(alias="className", min_length=1),
    academic_year: str = Query(alias="academicYear"),
) -> list[dict]:
    """School staff can look up published marks by year, class and roll number."""
    require_tenant(session, tenant)
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    records = session.scalars(select(ResultRecord).join(Enrollment).where(
        ResultRecord.tenant_id == tenant,
        ResultRecord.is_published.is_(True),
        ResultRecord.voided_at.is_(None),
        Enrollment.tenant_id == tenant,
        Enrollment.class_name == class_name.strip(),
        Enrollment.academic_year == year,
        Enrollment.roll_number == roll_number.strip(),
    ).order_by(ResultRecord.exam_type, ResultRecord.subject))
    return [_wire(session, item) for item in records]


@router.post("/bulk")
def bulk_marks(data: ResultBulkInput, session: Db, tenant: TenantId) -> list[dict]:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            enrollments = list(session.scalars(select(Enrollment).where(
                Enrollment.tenant_id == tenant,
                Enrollment.class_name == data.class_name,
                Enrollment.academic_year == data.academic_year,
            )))
            by_student = {item.student_id: item for item in enrollments}
            if any(item.student_id not in by_student for item in data.entries):
                raise HTTPException(status_code=409, detail="A student is outside the selected class and year")
            enrollment_ids = [by_student[item.student_id].id for item in data.entries]
            existing = {
                item.enrollment_id: item
                for item in session.scalars(select(ResultRecord).where(
                    ResultRecord.tenant_id == tenant,
                    ResultRecord.enrollment_id.in_(enrollment_ids),
                    ResultRecord.exam_type == data.exam_type,
                    ResultRecord.subject == data.subject,
                ).with_for_update())
            }
            saved = []
            for entry in data.entries:
                enrollment = by_student[entry.student_id]
                record = existing.get(enrollment.id)
                if record is None:
                    record = ResultRecord(
                        tenant_id=tenant,
                        enrollment=enrollment,
                        exam_type=data.exam_type.strip(),
                        subject=data.subject.strip(),
                    )
                    session.add(record)
                elif record.is_published:
                    raise HTTPException(status_code=409, detail="Published marks cannot be changed")
                record.marks_obtained = entry.marks_obtained
                record.max_marks = data.max_marks
                record.teacher_remarks = entry.teacher_remarks
                record.entered_by = data.entered_by.strip()
                record.updated_at = datetime.now(timezone.utc)
                record.voided_at = None
                saved.append(record)
            session.flush()
            result = [_wire(session, item) for item in saved]
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Marks conflict with an existing record") from error


@router.get("/class/{class_name}/exam/{exam_type}")
def class_sheet(class_name: str, exam_type: str, session: Db, tenant: TenantId, year: str) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    records = list(session.scalars(select(ResultRecord).join(Enrollment).where(
        ResultRecord.tenant_id == tenant,
        ResultRecord.exam_type == exam_type,
        ResultRecord.voided_at.is_(None),
        Enrollment.tenant_id == tenant,
        Enrollment.class_name == class_name,
        Enrollment.academic_year == year,
    ).order_by(ResultRecord.subject, Enrollment.roll_number, Enrollment.student_id)))
    return [_wire(session, item) for item in records]


@router.get("/student/{student_id}")
def student_results(student_id: str, session: Db, tenant: TenantId, year: str) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    records = list(session.scalars(select(ResultRecord).join(Enrollment).where(
        ResultRecord.tenant_id == tenant,
        ResultRecord.voided_at.is_(None),
        Enrollment.tenant_id == tenant,
        Enrollment.student_id == student_id,
        Enrollment.academic_year == year,
    ).order_by(ResultRecord.exam_type, ResultRecord.subject)))
    return [_wire(session, item) for item in records]


@router.put("/publish")
def publish_results(
    session: Db, tenant: TenantId,
    class_name: str = Query(alias="className"),
    exam_type: str = Query(alias="examType"),
    year: str = Query(),
) -> dict:
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    with session.begin():
        lock_tenant(session, tenant)
        policy = grading_policy(session, tenant, year)
        if policy is None or exam_type not in (policy.exam_order or []):
            raise HTTPException(status_code=409, detail="Configure grading bands, pass mark and exam order before publishing")
        configs = list(session.scalars(select(ExamConfig).where(
            ExamConfig.tenant_id == tenant, ExamConfig.academic_year == year,
            ExamConfig.is_active.is_(True),
        )))
        configured = {item.exam_type: item.weightage_percent for item in configs}
        if (set(configured) != set(policy.exam_order)
                or any(weight <= 0 for weight in configured.values())
                or sum(configured.values()) != 100):
            raise HTTPException(status_code=409, detail="Active exam weightages must match exam order and total 100%")
        enrollments = list(session.scalars(select(Enrollment).where(
            Enrollment.tenant_id == tenant,
            Enrollment.class_name == class_name,
            Enrollment.academic_year == year,
        )))
        expected = {item.id for item in enrollments}
        records = list(session.scalars(select(ResultRecord).join(Enrollment).where(
            ResultRecord.tenant_id == tenant,
            ResultRecord.exam_type == exam_type,
            ResultRecord.voided_at.is_(None),
            Enrollment.tenant_id == tenant,
            Enrollment.class_name == class_name,
            Enrollment.academic_year == year,
        ).with_for_update()))
        if not expected or not records:
            raise HTTPException(status_code=409, detail="No marks to publish")
        subjects = {item.subject for item in records}
        expected_subjects = set(session.scalars(select(ClassSubject.subject_name).where(
            ClassSubject.tenant_id == tenant,
            ClassSubject.class_name == class_name,
            ClassSubject.academic_year == year,
        )))
        if not expected_subjects or subjects != expected_subjects:
            raise HTTPException(status_code=409, detail="Marks must cover every configured class subject")
        for subject in subjects:
            if {item.enrollment_id for item in records if item.subject == subject} != expected:
                raise HTTPException(status_code=409, detail=f"Complete {subject} marks before publishing")
        for record in records:
            record.is_published = True
        count = len(records)
        return {"className": class_name, "examType": exam_type, "academicYear": year, "publishedCount": count}


def _policy_wire(policy: AcademicYearRecord) -> dict:
    return {
        "academicYear": policy.year,
        "passPercentage": money(policy.pass_percentage),
        "bands": policy.grade_bands,
        "examOrder": policy.exam_order,
    }


@router.get("/grading-policy")
def get_grading_policy(session: Db, tenant: TenantId, year: str) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    policy = grading_policy(session, tenant, year)
    if policy is None:
        raise HTTPException(status_code=404, detail="Grading policy is not configured for this year")
    return _policy_wire(policy)


@router.put("/grading-policy")
def save_grading_policy(data: GradingPolicyInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        year = session.scalar(select(AcademicYearRecord).where(
            AcademicYearRecord.tenant_id == tenant,
            AcademicYearRecord.year == data.academic_year,
        ).with_for_update())
        if year is None:
            raise HTTPException(status_code=409, detail="Set up the academic year before its grading policy")
        bands = [item.model_dump(mode="json", by_alias=True) for item in data.bands]
        unchanged = (year.grade_bands == bands and year.pass_percentage == data.pass_percentage
                     and year.exam_order == data.exam_order)
        if not unchanged:
            published = session.scalar(select(ResultRecord.id).join(Enrollment).where(
                ResultRecord.tenant_id == tenant, ResultRecord.is_published.is_(True),
                ResultRecord.voided_at.is_(None), Enrollment.tenant_id == tenant,
                Enrollment.academic_year == data.academic_year,
            ).limit(1))
            if published:
                raise HTTPException(status_code=409, detail="Published results lock the grading policy")
            year.grade_bands = bands
            year.pass_percentage = data.pass_percentage
            year.exam_order = data.exam_order
        session.flush()
        result = _policy_wire(year)
    return result


@router.put("/{result_id}")
def update_result(result_id: str, data: ResultUpdateInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        require_tenant(session, tenant)
        record = session.scalar(select(ResultRecord).where(
            ResultRecord.id == result_id,
            ResultRecord.tenant_id == tenant,
            ResultRecord.voided_at.is_(None),
        ).with_for_update())
        if record is None:
            raise HTTPException(status_code=404, detail="Result not found")
        if record.is_published:
            raise HTTPException(status_code=409, detail="Published marks cannot be changed")
        record.marks_obtained = data.marks_obtained
        record.max_marks = data.max_marks
        record.teacher_remarks = data.teacher_remarks
        record.updated_at = datetime.now(timezone.utc)
        session.flush()
        result = _wire(session, record)
    return result


@router.delete("/{result_id}", status_code=204)
def void_result(result_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        require_tenant(session, tenant)
        record = session.scalar(select(ResultRecord).where(
            ResultRecord.id == result_id,
            ResultRecord.tenant_id == tenant,
            ResultRecord.voided_at.is_(None),
        ).with_for_update())
        if record is None:
            raise HTTPException(status_code=404, detail="Result not found")
        if record.is_published:
            raise HTTPException(status_code=409, detail="Published marks cannot be deleted")
        record.voided_at = datetime.now(timezone.utc)
    return Response(status_code=204)


def _config_wire(config: ExamConfig) -> dict:
    return {
        "id": config.id,
        "academicYear": config.academic_year,
        "examType": config.exam_type,
        "displayName": config.display_name,
        "weightagePercent": config.weightage_percent,
        "maxMarksDefault": money(config.max_marks_default),
        "isActive": config.is_active,
    }


@router.get("/exam-config")
def list_exam_configs(session: Db, tenant: TenantId, year: str) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    return [_config_wire(item) for item in session.scalars(select(ExamConfig).where(
        ExamConfig.tenant_id == tenant, ExamConfig.academic_year == year,
    ).order_by(ExamConfig.exam_type))]


@router.post("/exam-config")
def save_exam_config(data: ExamConfigInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        config = session.scalar(select(ExamConfig).where(
            ExamConfig.tenant_id == tenant,
            ExamConfig.academic_year == data.academic_year,
            ExamConfig.exam_type == data.exam_type,
        ))
        published = session.scalar(select(ResultRecord.id).join(Enrollment).where(
            ResultRecord.tenant_id == tenant,
            ResultRecord.is_published.is_(True),
            ResultRecord.voided_at.is_(None),
            Enrollment.tenant_id == tenant,
            Enrollment.academic_year == data.academic_year,
        ).limit(1))
        if published:
            raise HTTPException(status_code=409, detail="Published results lock the year's exam configuration")
        if config is None:
            if data.id:
                raise HTTPException(status_code=404, detail="Exam config not found")
            config = ExamConfig(tenant_id=tenant, academic_year=data.academic_year, exam_type=data.exam_type)
            session.add(config)
        elif data.id and data.id != config.id:
            raise HTTPException(status_code=409, detail="Exam config ID does not match year and exam")
        config.display_name = data.display_name
        config.weightage_percent = data.weightage_percent
        config.max_marks_default = data.max_marks_default
        config.is_active = data.is_active
        session.flush()
        result = _config_wire(config)
    return result


def _coscholastic_wire(assessment: CoscholasticAssessment) -> dict:
    enrollment = assessment.enrollment
    return {
        "id": assessment.id,
        "studentId": enrollment.student_id,
        "studentName": enrollment.student.full_name,
        "className": enrollment.class_name,
        "academicYear": enrollment.academic_year,
        "term": assessment.term,
        "areas": assessment.areas,
    }


@router.get("/coscholastic/student/{student_id}")
def get_coscholastic(student_id: str, session: Db, tenant: TenantId, year: str) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    return [_coscholastic_wire(item) for item in session.scalars(
        select(CoscholasticAssessment).join(Enrollment).where(
            CoscholasticAssessment.tenant_id == tenant,
            Enrollment.tenant_id == tenant,
            Enrollment.student_id == student_id,
            Enrollment.academic_year == year,
        ).order_by(CoscholasticAssessment.term)
    )]


@router.post("/coscholastic")
def save_coscholastic(data: CoscholasticInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        enrollment = session.scalar(select(Enrollment).where(
            Enrollment.tenant_id == tenant,
            Enrollment.student_id == data.student_id,
            Enrollment.class_name == data.class_name,
            Enrollment.academic_year == data.academic_year,
        ))
        if enrollment is None:
            raise HTTPException(status_code=409, detail="Student is outside selected class and year")
        assessment = session.scalar(select(CoscholasticAssessment).where(
            CoscholasticAssessment.tenant_id == tenant,
            CoscholasticAssessment.enrollment_id == enrollment.id,
            CoscholasticAssessment.term == data.term,
        ))
        if assessment is None:
            if data.id:
                raise HTTPException(status_code=404, detail="Assessment not found")
            assessment = CoscholasticAssessment(tenant_id=tenant, enrollment=enrollment, term=data.term)
            session.add(assessment)
        elif data.id and data.id != assessment.id:
            raise HTTPException(status_code=409, detail="Assessment ID does not match student and term")
        assessment.areas = [area.model_dump(by_alias=True) for area in data.areas]
        assessment.updated_at = datetime.now(timezone.utc)
        session.flush()
        result = _coscholastic_wire(assessment)
    return result


@router.get("/student/{student_id}/report")
def get_report_card(student_id: str, session: Db, tenant: TenantId, year: str) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    enrollment = session.scalar(select(Enrollment).where(
        Enrollment.tenant_id == tenant,
        Enrollment.student_id == student_id,
        Enrollment.academic_year == year,
    ))
    if enrollment is None:
        raise HTTPException(status_code=404, detail="Enrollment not found for year")
    return report_card(session, tenant, enrollment)


@router.get("/class/{class_name}/analytics")
def get_class_analytics(
    class_name: str, session: Db, tenant: TenantId, year: str,
    exam_type: str | None = Query(None, alias="examType"),
) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    return class_analytics(session, tenant, class_name, year, exam_type)
