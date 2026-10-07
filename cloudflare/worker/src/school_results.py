"""Results and examination management endpoints for marks entry, report cards, and analytics."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant

router = APIRouter(prefix="/api/results", tags=["results"])
root_router = APIRouter(prefix="/results", tags=["results_root"])


def _calculate_grade(pct: float) -> tuple[str, float, bool]:
    if pct >= 90:
        return "A+", 10.0, True
    if pct >= 80:
        return "A", 9.0, True
    if pct >= 70:
        return "B+", 8.0, True
    if pct >= 60:
        return "B", 7.0, True
    if pct >= 50:
        return "C+", 6.0, True
    if pct >= 40:
        return "C", 5.0, True
    if pct >= 33:
        return "D", 4.0, True
    return "E", 0.0, False


def _wire_result(
    row: dict,
    student_name: str = "",
    roll_number: str = "",
    class_name: str = "",
    academic_year: str = "",
    class_rank: int = 0,
) -> dict:
    marks_obt = float(row.get("marks_obtained") or 0)
    max_m = float(row.get("max_marks") or 100)
    pct = round((marks_obt / max_m * 100.0), 2) if max_m > 0 else 0.0
    grade, gp, passed = _calculate_grade(pct)

    return {
        "id": row.get("id"),
        "studentId": row.get("student_id") or row.get("studentId") or "",
        "studentName": student_name or row.get("student_name") or row.get("studentName") or "",
        "rollNumber": roll_number or row.get("roll_number") or row.get("rollNumber"),
        "className": class_name or row.get("class_name") or row.get("className") or "",
        "academicYear": academic_year or row.get("academic_year") or row.get("academicYear") or "",
        "examType": row.get("exam_type") or row.get("examType") or "",
        "subject": row.get("subject") or "",
        "marksObtained": marks_obt,
        "maxMarks": max_m,
        "percentage": pct,
        "grade": grade,
        "gradePoint": gp,
        "isPassed": passed,
        "classRank": class_rank or int(row.get("class_rank") or row.get("classRank") or 0),
        "teacherRemarks": row.get("teacher_remarks") or row.get("teacherRemarks"),
        "isPublished": bool(row.get("is_published")),
        "enteredBy": row.get("entered_by") or row.get("enteredBy") or "",
    }


class BulkResultEntry(BaseModel):
    studentId: str = Field(min_length=1)
    studentName: str = Field(default="")
    marksObtained: float = Field(ge=0)
    teacherRemarks: str | None = None


class BulkSubmitInput(BaseModel):
    className: str = Field(min_length=1)
    examType: str = Field(min_length=1)
    academicYear: str = Field(min_length=1)
    subject: str = Field(min_length=1)
    maxMarks: float = Field(gt=0)
    enteredBy: str = Field(default="")
    entries: list[BulkResultEntry] = Field(default_factory=list)


class UpdateResultInput(BaseModel):
    marksObtained: float | None = None
    maxMarks: float | None = None
    teacherRemarks: str | None = None
    isPublished: bool | None = None


class ExamConfigInput(BaseModel):
    id: str | None = None
    academicYear: str = Field(min_length=1)
    examType: str = Field(min_length=1)
    displayName: str = Field(min_length=1)
    weightagePercent: int = Field(ge=0, le=100)
    maxMarksDefault: float = Field(gt=0)
    isActive: bool = Field(default=True)


class CoscholasticAreaInput(BaseModel):
    name: str = Field(min_length=1)
    grade: str = Field(min_length=1)
    remarks: str | None = None


class CoscholasticInput(BaseModel):
    id: str | None = None
    studentId: str = Field(min_length=1)
    studentName: str = Field(default="")
    className: str = Field(default="")
    academicYear: str = Field(min_length=1)
    term: str = Field(min_length=1)
    areas: list[CoscholasticAreaInput] = Field(default_factory=list)


async def _get_or_create_enrollment(
    db, tenant: str, student_id: str, academic_year: str, class_name: str = ""
) -> str:
    enr = await _one(
        db,
        "SELECT id FROM enrollments WHERE tenant_id = ? AND student_id = ? AND academic_year = ?",
        tenant, student_id, academic_year,
    )
    if enr and enr.get("id"):
        return str(enr["id"])

    # Fallback to student table class_name if not provided
    stu = await _one(
        db,
        "SELECT class_name, roll_number, date_of_admission FROM students WHERE tenant_id = ? AND id = ?",
        tenant, student_id,
    )
    c_name = class_name or (stu["class_name"] if stu else "General")
    r_num = stu.get("roll_number") if stu else None
    doa = stu.get("date_of_admission") if stu else datetime.now(timezone.utc).date().isoformat()

    new_id = str(uuid.uuid4())
    await db.prepare(
        "INSERT OR IGNORE INTO enrollments (id, tenant_id, student_id, academic_year, class_name, roll_number, date_of_admission, status) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE')"
    ).bind(new_id, tenant, student_id, academic_year, c_name, r_num, doa).run()

    enr_after = await _one(
        db,
        "SELECT id FROM enrollments WHERE tenant_id = ? AND student_id = ? AND academic_year = ?",
        tenant, student_id, academic_year,
    )
    return str(enr_after["id"]) if enr_after else new_id


async def _handle_bulk_submit(
    body: BulkSubmitInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    entered_by = body.enteredBy.strip() or user.get("name") or user.get("username") or "Teacher"
    now_iso = datetime.now(timezone.utc).isoformat()
    max_m_int = int(round(body.maxMarks))

    out_results = []
    for entry in body.entries:
        enr_id = await _get_or_create_enrollment(
            db, tenant, entry.studentId, body.academicYear, body.className
        )
        marks_int = int(round(entry.marksObtained))
        if marks_int > max_m_int:
            marks_int = max_m_int
        if marks_int < 0:
            marks_int = 0

        existing = await _one(
            db,
            "SELECT id FROM result_records WHERE tenant_id = ? AND enrollment_id = ? AND exam_type = ? AND subject = ?",
            tenant, enr_id, body.examType, body.subject,
        )
        rec_id = existing["id"] if existing else str(uuid.uuid4())

        await db.prepare(
            "INSERT INTO result_records (id, tenant_id, enrollment_id, exam_type, subject, marks_obtained, max_marks, teacher_remarks, entered_by, is_published, updated_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?) "
            "ON CONFLICT (tenant_id, enrollment_id, exam_type, subject) DO UPDATE SET "
            "marks_obtained = excluded.marks_obtained, max_marks = excluded.max_marks, teacher_remarks = excluded.teacher_remarks, "
            "entered_by = excluded.entered_by, updated_at = excluded.updated_at, voided_at = NULL"
        ).bind(rec_id, tenant, enr_id, body.examType, body.subject, marks_int, max_m_int, entry.teacherRemarks or "", entered_by, now_iso).run()

        pct = round(marks_int / max_m_int * 100.0, 2) if max_m_int > 0 else 0.0
        grade, gp, passed = _calculate_grade(pct)

        out_results.append({
            "id": rec_id,
            "studentId": entry.studentId,
            "studentName": entry.studentName,
            "rollNumber": None,
            "className": body.className,
            "academicYear": body.academicYear,
            "examType": body.examType,
            "subject": body.subject,
            "marksObtained": float(marks_int),
            "maxMarks": float(max_m_int),
            "percentage": pct,
            "grade": grade,
            "gradePoint": gp,
            "isPassed": passed,
            "classRank": 0,
            "teacherRemarks": entry.teacherRemarks,
            "isPublished": False,
            "enteredBy": entered_by,
        })

    return out_results


async def _handle_get_class_sheet(
    className: str,
    examType: str,
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT r.*, e.student_id, e.class_name, e.academic_year, e.roll_number, s.full_name as student_name "
        "FROM result_records r "
        "JOIN enrollments e ON r.enrollment_id = e.id AND r.tenant_id = e.tenant_id "
        "JOIN students s ON e.student_id = s.id AND e.tenant_id = s.tenant_id "
        "WHERE r.tenant_id = ? AND e.class_name = ? AND r.exam_type = ? AND e.academic_year = ? AND r.voided_at IS NULL "
        "ORDER BY s.roll_number ASC, s.full_name ASC",
        tenant, className, examType, year,
    )
    # Compute rank based on percentage
    scored = []
    for row in rows:
        pct = (float(row.get("marks_obtained") or 0) / float(row.get("max_marks") or 100)) * 100.0
        scored.append((pct, row))
    scored.sort(key=lambda x: x[0], reverse=True)

    results = []
    for rank, (pct, row) in enumerate(scored, 1):
        res = _wire_result(
            row,
            student_name=row.get("student_name") or "",
            roll_number=row.get("roll_number") or "",
            class_name=row.get("class_name") or className,
            academic_year=row.get("academic_year") or year,
            class_rank=rank,
        )
        results.append(res)
    return results


async def _handle_get_student_results(
    studentId: str,
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT r.*, e.student_id, e.class_name, e.academic_year, e.roll_number, s.full_name as student_name "
        "FROM result_records r "
        "JOIN enrollments e ON r.enrollment_id = e.id AND r.tenant_id = e.tenant_id "
        "JOIN students s ON e.student_id = s.id AND e.tenant_id = s.tenant_id "
        "WHERE r.tenant_id = ? AND e.student_id = ? AND e.academic_year = ? AND r.voided_at IS NULL "
        "ORDER BY r.exam_type ASC, r.subject ASC",
        tenant, studentId, year,
    )
    return [
        _wire_result(
            r,
            student_name=r.get("student_name") or "",
            roll_number=r.get("roll_number") or "",
            class_name=r.get("class_name") or "",
            academic_year=r.get("academic_year") or year,
        )
        for r in rows
    ]


async def _handle_get_student_report_card(
    studentId: str,
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    stu = await _one(
        db,
        "SELECT id, full_name, class_name, roll_number FROM students WHERE tenant_id = ? AND id = ?",
        tenant, studentId,
    )
    if not stu:
        raise HTTPException(status_code=404, detail="Student not found")

    rows = await _many(
        db,
        "SELECT r.* FROM result_records r "
        "JOIN enrollments e ON r.enrollment_id = e.id AND r.tenant_id = e.tenant_id "
        "WHERE r.tenant_id = ? AND e.student_id = ? AND e.academic_year = ? AND r.voided_at IS NULL",
        tenant, studentId, year,
    )

    # Group results by subject
    subjects_map: dict[str, dict] = {}
    total_obtained = 0.0
    total_max = 0.0

    for r in rows:
        subj = r.get("subject") or "General"
        if subj not in subjects_map:
            subjects_map[subj] = {"subject": subj, "examResults": {}}
        marks_obt = float(r.get("marks_obtained") or 0)
        max_m = float(r.get("max_marks") or 100)
        pct = round(marks_obt / max_m * 100.0, 2) if max_m > 0 else 0.0
        grade, gp, passed = _calculate_grade(pct)

        subjects_map[subj]["examResults"][r.get("exam_type")] = {
            "marksObtained": marks_obt,
            "maxMarks": max_m,
            "percentage": pct,
            "grade": grade,
            "gradePoint": gp,
            "isPassed": passed,
            "classRank": 1,
            "teacherRemarks": r.get("teacher_remarks"),
        }
        total_obtained += marks_obt
        total_max += max_m

    subject_list = []
    for subj, data in subjects_map.items():
        exam_results = data["examResults"]
        sub_pct = 0.0
        if exam_results:
            sub_pct = round(
                sum(er["marksObtained"] for er in exam_results.values())
                / max(sum(er["maxMarks"] for er in exam_results.values()), 1)
                * 100.0,
                2,
            )
        pred_grade, _, _ = _calculate_grade(sub_pct)
        subject_list.append({
            "subject": subj,
            "examResults": exam_results,
            "weightedPercentage": sub_pct,
            "predictedGrade": pred_grade,
            "trend": "STABLE",
        })

    cumulative_pct = round((total_obtained / total_max * 100.0), 2) if total_max > 0 else 0.0
    overall_grade, overall_gp, _ = _calculate_grade(cumulative_pct)

    # Fetch coscholastic assessments
    coscho_rows = await _many(
        db,
        "SELECT c.* FROM coscholastic_assessments c "
        "JOIN enrollments e ON c.enrollment_id = e.id AND c.tenant_id = e.tenant_id "
        "WHERE c.tenant_id = ? AND e.student_id = ? AND e.academic_year = ?",
        tenant, studentId, year,
    )
    coscho_term1 = None
    coscho_term2 = None
    for cr in coscho_rows:
        try:
            areas = json.loads(cr.get("areas") or "[]")
        except Exception:
            areas = []
        assessment = {
            "id": cr["id"],
            "studentId": studentId,
            "studentName": stu["full_name"],
            "className": stu["class_name"],
            "academicYear": year,
            "term": cr["term"],
            "areas": areas,
        }
        if "1" in cr["term"]:
            coscho_term1 = assessment
        else:
            coscho_term2 = assessment

    return {
        "studentId": studentId,
        "studentName": stu["full_name"],
        "className": stu["class_name"],
        "rollNumber": stu.get("roll_number"),
        "academicYear": year,
        "subjects": subject_list,
        "cumulativePercentage": cumulative_pct,
        "overallGrade": overall_grade,
        "overallGradePoint": overall_gp,
        "classRank": 1,
        "coscholasticTerm1": coscho_term1,
        "coscholasticTerm2": coscho_term2,
    }


async def _handle_get_class_analytics(
    className: str,
    year: str = Query(default="2026-2027"),
    examType: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    query = (
        "SELECT r.*, e.student_id, s.full_name as student_name, s.roll_number "
        "FROM result_records r "
        "JOIN enrollments e ON r.enrollment_id = e.id AND r.tenant_id = e.tenant_id "
        "JOIN students s ON e.student_id = s.id AND e.tenant_id = s.tenant_id "
        "WHERE r.tenant_id = ? AND e.class_name = ? AND e.academic_year = ? AND r.voided_at IS NULL"
    )
    params = [tenant, className, year]
    if examType:
        query += " AND r.exam_type = ?"
        params.append(examType)

    rows = await _many(db, query, *params)
    if not rows:
        return {
            "className": className,
            "examType": examType,
            "academicYear": year,
            "totalStudents": 0,
            "classAverage": 0.0,
            "highestPercentage": 0.0,
            "lowestPercentage": 0.0,
            "passPercentage": 0.0,
            "subjectHeatmap": [],
            "atRiskStudents": [],
            "recognition": [],
        }

    # Aggregate by student
    student_totals: dict[str, dict] = {}
    subject_totals: dict[str, dict] = {}

    for r in rows:
        s_id = r["student_id"]
        if s_id not in student_totals:
            student_totals[s_id] = {
                "name": r["student_name"],
                "rollNumber": r.get("roll_number"),
                "obtained": 0.0,
                "max": 0.0,
                "failed": [],
            }
        obt = float(r.get("marks_obtained") or 0)
        mx = float(r.get("max_marks") or 100)
        pct = (obt / mx * 100.0) if mx > 0 else 0.0
        student_totals[s_id]["obtained"] += obt
        student_totals[s_id]["max"] += mx
        if pct < 33.0:
            student_totals[s_id]["failed"].append(r.get("subject") or "Subject")

        subj = r.get("subject") or "General"
        if subj not in subject_totals:
            subject_totals[subj] = {"obtained": 0.0, "max": 0.0, "passed": 0, "total": 0}
        subject_totals[subj]["obtained"] += obt
        subject_totals[subj]["max"] += mx
        subject_totals[subj]["total"] += 1
        if pct >= 33.0:
            subject_totals[subj]["passed"] += 1

    student_pcts = []
    at_risk = []
    for s_id, s_data in student_totals.items():
        pct = round(s_data["obtained"] / max(s_data["max"], 1.0) * 100.0, 2)
        student_pcts.append((pct, s_id, s_data["name"]))
        if s_data["failed"] or pct < 40.0:
            at_risk.append({
                "studentId": s_id,
                "studentName": s_data["name"],
                "rollNumber": s_data["rollNumber"],
                "failedSubjects": s_data["failed"],
                "droppingSubjects": [],
                "overallPercentage": pct,
                "riskLevel": "CRITICAL" if len(s_data["failed"]) >= 2 else "WARNING",
            })

    student_pcts.sort(key=lambda x: x[0], reverse=True)
    class_avg = round(sum(p[0] for p in student_pcts) / len(student_pcts), 2) if student_pcts else 0.0
    hi_pct = student_pcts[0][0] if student_pcts else 0.0
    lo_pct = student_pcts[-1][0] if student_pcts else 0.0
    passed_students = sum(1 for p in student_pcts if p[0] >= 33.0)
    pass_pct = round(passed_students / len(student_pcts) * 100.0, 2) if student_pcts else 0.0

    heatmap = []
    for subj, s_agg in subject_totals.items():
        s_avg = round(s_agg["obtained"] / max(s_agg["max"], 1.0) * 100.0, 2)
        s_pass_pct = round(s_agg["passed"] / max(s_agg["total"], 1) * 100.0, 2)
        perf = "EXCELLENT" if s_avg >= 75 else ("GOOD" if s_avg >= 60 else ("AVERAGE" if s_avg >= 45 else "NEEDS_IMPROVEMENT"))
        heatmap.append({
            "subject": subj,
            "classAverage": s_avg,
            "passPercentage": s_pass_pct,
            "performance": perf,
            "totalStudents": s_agg["total"],
        })

    recognition = []
    if student_pcts:
        recognition.append({
            "category": "Class Topper",
            "studentName": student_pcts[0][2],
            "detail": f"Scored {student_pcts[0][0]}% overall",
        })

    return {
        "className": className,
        "examType": examType,
        "academicYear": year,
        "totalStudents": len(student_totals),
        "classAverage": class_avg,
        "highestPercentage": hi_pct,
        "lowestPercentage": lo_pct,
        "passPercentage": pass_pct,
        "subjectHeatmap": heatmap,
        "atRiskStudents": at_risk,
        "recognition": recognition,
    }


async def _handle_publish_results(
    className: str = Query(...),
    examType: str = Query(...),
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    await db.prepare(
        "UPDATE result_records SET is_published = 1 "
        "WHERE tenant_id = ? AND exam_type = ? AND enrollment_id IN ("
        "  SELECT id FROM enrollments WHERE tenant_id = ? AND class_name = ? AND academic_year = ?"
        ")"
    ).bind(tenant, examType, tenant, className, year).run()
    return {"success": True, "published": True, "className": className, "examType": examType}


async def _handle_update_result(
    id: str,
    body: UpdateResultInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rec = await _one(db, "SELECT * FROM result_records WHERE tenant_id = ? AND id = ?", tenant, id)
    if not rec:
        raise HTTPException(status_code=404, detail="Result not found")

    new_obt = int(round(body.marksObtained)) if body.marksObtained is not None else rec["marks_obtained"]
    new_max = int(round(body.maxMarks)) if body.maxMarks is not None else rec["max_marks"]
    new_rem = body.teacherRemarks if body.teacherRemarks is not None else rec.get("teacher_remarks") or ""
    new_pub = 1 if body.isPublished is True else (0 if body.isPublished is False else rec["is_published"])
    now_iso = datetime.now(timezone.utc).isoformat()

    await db.prepare(
        "UPDATE result_records SET marks_obtained = ?, max_marks = ?, teacher_remarks = ?, is_published = ?, updated_at = ? "
        "WHERE tenant_id = ? AND id = ?"
    ).bind(new_obt, new_max, new_rem, new_pub, now_iso, tenant, id).run()

    updated = await _one(
        db,
        "SELECT r.*, e.student_id, e.class_name, e.academic_year, e.roll_number, s.full_name as student_name "
        "FROM result_records r "
        "JOIN enrollments e ON r.enrollment_id = e.id AND r.tenant_id = e.tenant_id "
        "JOIN students s ON e.student_id = s.id AND e.tenant_id = s.tenant_id "
        "WHERE r.tenant_id = ? AND r.id = ?",
        tenant, id,
    )
    return _wire_result(updated, student_name=updated.get("student_name") or "", roll_number=updated.get("roll_number") or "")


async def _handle_delete_result(
    id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    await db.prepare("DELETE FROM result_records WHERE tenant_id = ? AND id = ?").bind(tenant, id).run()
    return {"success": True, "deleted": True}


async def _handle_get_exam_configs(
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT * FROM exam_configs WHERE tenant_id = ? AND academic_year = ? ORDER BY exam_type",
        tenant, year,
    )
    configs = []
    for r in rows:
        configs.append({
            "id": r["id"],
            "academicYear": r["academic_year"],
            "examType": r["exam_type"],
            "displayName": r["display_name"],
            "weightagePercent": r["weightage_percent"],
            "maxMarksDefault": float(r["max_marks_default"]),
            "isActive": bool(r["is_active"]),
        })
    return configs


async def _handle_save_exam_config(
    body: ExamConfigInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    cfg_id = body.id or str(uuid.uuid4())
    is_active_int = 1 if body.isActive else 0
    max_m = int(round(body.maxMarksDefault))

    await db.prepare(
        "INSERT INTO exam_configs (id, tenant_id, academic_year, exam_type, display_name, weightage_percent, max_marks_default, is_active) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(tenant_id, academic_year, exam_type) DO UPDATE SET "
        "display_name = excluded.display_name, weightage_percent = excluded.weightage_percent, "
        "max_marks_default = excluded.max_marks_default, is_active = excluded.is_active"
    ).bind(cfg_id, tenant, body.academicYear, body.examType, body.displayName, body.weightagePercent, max_m, is_active_int).run()

    return {
        "id": cfg_id,
        "academicYear": body.academicYear,
        "examType": body.examType,
        "displayName": body.displayName,
        "weightagePercent": body.weightagePercent,
        "maxMarksDefault": float(max_m),
        "isActive": body.isActive,
    }


async def _handle_get_coscholastic(
    studentId: str,
    year: str = Query(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT c.*, s.full_name as student_name, e.class_name FROM coscholastic_assessments c "
        "JOIN enrollments e ON c.enrollment_id = e.id AND c.tenant_id = e.tenant_id "
        "JOIN students s ON e.student_id = s.id AND e.tenant_id = s.tenant_id "
        "WHERE c.tenant_id = ? AND e.student_id = ? AND e.academic_year = ?",
        tenant, studentId, year,
    )
    result = []
    for r in rows:
        try:
            areas = json.loads(r.get("areas") or "[]")
        except Exception:
            areas = []
        result.append({
            "id": r["id"],
            "studentId": studentId,
            "studentName": r.get("student_name") or "",
            "className": r.get("class_name") or "",
            "academicYear": year,
            "term": r["term"],
            "areas": areas,
        })
    return result


async def _handle_save_coscholastic(
    body: CoscholasticInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    enr_id = await _get_or_create_enrollment(db, tenant, body.studentId, body.academicYear, body.className)
    rec_id = body.id or str(uuid.uuid4())
    areas_json = json.dumps([a.model_dump() for a in body.areas])
    now_iso = datetime.now(timezone.utc).isoformat()

    await db.prepare(
        "INSERT INTO coscholastic_assessments (id, tenant_id, enrollment_id, term, areas, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(tenant_id, enrollment_id, term) DO UPDATE SET "
        "areas = excluded.areas, updated_at = excluded.updated_at"
    ).bind(rec_id, tenant, enr_id, body.term, areas_json, now_iso).run()

    return {
        "id": rec_id,
        "studentId": body.studentId,
        "studentName": body.studentName,
        "className": body.className,
        "academicYear": body.academicYear,
        "term": body.term,
        "areas": [a.model_dump() for a in body.areas],
    }


# Bind endpoints to both /api/results and /results
for rtr in (router, root_router):
    rtr.add_api_route("/bulk", _handle_bulk_submit, methods=["POST"])
    rtr.add_api_route("/class/{className}/exam/{examType}", _handle_get_class_sheet, methods=["GET"])
    rtr.add_api_route("/class/{className}/analytics", _handle_get_class_analytics, methods=["GET"])
    rtr.add_api_route("/student/{studentId}/report", _handle_get_student_report_card, methods=["GET"])
    rtr.add_api_route("/student/{studentId}", _handle_get_student_results, methods=["GET"])
    rtr.add_api_route("/publish", _handle_publish_results, methods=["PUT"])
    rtr.add_api_route("/exam-config", _handle_get_exam_configs, methods=["GET"])
    rtr.add_api_route("/exam-config", _handle_save_exam_config, methods=["POST"])
    rtr.add_api_route("/coscholastic/student/{studentId}", _handle_get_coscholastic, methods=["GET"])
    rtr.add_api_route("/coscholastic", _handle_save_coscholastic, methods=["POST"])
    rtr.add_api_route("/{id}", _handle_update_result, methods=["PUT"])
    rtr.add_api_route("/{id}", _handle_delete_result, methods=["DELETE"])
