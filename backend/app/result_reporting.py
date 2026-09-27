from collections import defaultdict
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AcademicYearRecord, CoscholasticAssessment, Enrollment, ExamConfig, ResultRecord
from app.serializers import money

ZERO = Decimal("0.00")


def grading_policy(session: Session, tenant: str, year: str) -> AcademicYearRecord | None:
    cache = session.info.setdefault("grading_policies", {})
    key = (tenant, year)
    if key in cache:
        return cache[key]
    record = session.scalar(select(AcademicYearRecord).where(
        AcademicYearRecord.tenant_id == tenant, AcademicYearRecord.year == year,
    ))
    policy = record if record is not None and record.grade_bands and record.pass_percentage is not None else None
    cache[key] = policy
    return policy


def grade(percentage: Decimal, policy: AcademicYearRecord | None) -> tuple[str, int]:
    if policy is None:
        return "", 0
    for band in policy.grade_bands:
        if percentage >= Decimal(str(band["minPercentage"])):
            return band["grade"], band["gradePoint"]
    raise ValueError("Grading policy must contain a zero-percent band")


def published_records(session: Session, tenant: str, class_name: str, year: str, exam_type: str | None = None) -> list[ResultRecord]:
    statement = select(ResultRecord).join(Enrollment).where(
        ResultRecord.tenant_id == tenant,
        ResultRecord.is_published.is_(True),
        ResultRecord.voided_at.is_(None),
        Enrollment.tenant_id == tenant,
        Enrollment.class_name == class_name,
        Enrollment.academic_year == year,
    )
    if exam_type:
        statement = statement.where(ResultRecord.exam_type == exam_type)
    return list(session.scalars(statement.order_by(ResultRecord.exam_type, ResultRecord.subject)))


def exam_weights(session: Session, tenant: str, year: str) -> dict[str, Decimal]:
    configs = session.scalars(select(ExamConfig).where(
        ExamConfig.tenant_id == tenant,
        ExamConfig.academic_year == year,
        ExamConfig.is_active.is_(True),
    ))
    return {item.exam_type: Decimal(item.weightage_percent) for item in configs}


def subject_summaries(
    records: list[ResultRecord], weights: dict[str, Decimal], policy: AcademicYearRecord | None,
) -> list[dict]:
    by_subject = defaultdict(list)
    for record in records:
        by_subject[record.subject].append(record)
    summaries = []
    for subject, subject_records in sorted(by_subject.items()):
        exams = {}
        weighted_total = ZERO
        weight_total = ZERO
        percentages = []
        exam_positions = {name: index for index, name in enumerate(policy.exam_order or [])} if policy else {}
        for record in sorted(subject_records, key=lambda item: (exam_positions.get(item.exam_type, 1000), item.exam_type)):
            percentage = record.marks_obtained * 100 / record.max_marks
            letter, point = grade(percentage, policy)
            exams[record.exam_type] = {
                "marksObtained": money(record.marks_obtained),
                "maxMarks": money(record.max_marks),
                "percentage": round(float(percentage), 2),
                "grade": letter,
                "gradePoint": point,
                "isPassed": policy is not None and percentage >= policy.pass_percentage,
                "classRank": 0,
                "teacherRemarks": record.teacher_remarks,
            }
            weight = weights.get(record.exam_type, Decimal(1))
            if weight <= 0:
                continue
            weighted_total += percentage * weight
            weight_total += weight
            percentages.append(percentage)
        weighted = weighted_total / weight_total if weight_total else ZERO
        predicted, _ = grade(weighted, policy)
        delta = percentages[-1] - percentages[0] if len(percentages) > 1 else ZERO
        trend = "IMPROVING" if delta >= 5 else "DECLINING" if delta <= -5 else "STABLE"
        summaries.append({
            "subject": subject,
            "examResults": exams,
            "weightedPercentage": round(float(weighted), 2),
            "predictedGrade": predicted,
            "trend": trend,
        })
    return summaries


def overall_percentage(subjects: list[dict]) -> Decimal:
    if not subjects:
        return ZERO
    return sum((Decimal(str(item["weightedPercentage"])) for item in subjects), ZERO) / len(subjects)


def class_scores(
    records: list[ResultRecord], weights: dict[str, Decimal], policy: AcademicYearRecord | None,
) -> dict[str, tuple[list[dict], Decimal]]:
    by_student = defaultdict(list)
    for record in records:
        by_student[record.enrollment.student_id].append(record)
    scores = {}
    for student_id, student_records in by_student.items():
        subjects = subject_summaries(student_records, weights, policy)
        scores[student_id] = (subjects, overall_percentage(subjects))
    return scores


def report_card(session: Session, tenant: str, enrollment: Enrollment) -> dict:
    records = published_records(session, tenant, enrollment.class_name, enrollment.academic_year)
    policy = grading_policy(session, tenant, enrollment.academic_year)
    if records and policy is None:
        raise HTTPException(status_code=409, detail="Grading policy is missing for published results")
    weights = exam_weights(session, tenant, enrollment.academic_year)
    scores = class_scores(records, weights, policy)
    subjects, overall = scores.get(enrollment.student_id, ([], ZERO))
    for subject in subjects:
        for exam_type, exam_result in subject["examResults"].items():
            peer_percentages = [
                item.marks_obtained * 100 / item.max_marks
                for item in records
                if item.subject == subject["subject"] and item.exam_type == exam_type
            ]
            own_record = next(
                item for item in records
                if item.enrollment_id == enrollment.id
                and item.subject == subject["subject"] and item.exam_type == exam_type
            )
            own = own_record.marks_obtained * 100 / own_record.max_marks
            exam_result["classRank"] = 1 + sum(value > own for value in peer_percentages)
    letter, point = grade(overall, policy) if subjects else ("", 0)
    rank = 1 + sum(1 for _, score in scores.values() if score > overall) if subjects else 0
    assessments = list(session.scalars(select(CoscholasticAssessment).where(
        CoscholasticAssessment.tenant_id == tenant,
        CoscholasticAssessment.enrollment_id == enrollment.id,
    )))
    terms = {item.term.replace(" ", "").upper(): item for item in assessments}

    def term_wire(item: CoscholasticAssessment | None) -> dict | None:
        if item is None:
            return None
        return {
            "id": item.id,
            "studentId": enrollment.student_id,
            "studentName": enrollment.student.full_name,
            "className": enrollment.class_name,
            "academicYear": enrollment.academic_year,
            "term": item.term,
            "areas": item.areas,
        }

    return {
        "studentId": enrollment.student_id,
        "studentName": enrollment.student.full_name,
        "className": enrollment.class_name,
        "rollNumber": enrollment.roll_number,
        "academicYear": enrollment.academic_year,
        "subjects": subjects,
        "cumulativePercentage": round(float(overall), 2),
        "overallGrade": letter,
        "overallGradePoint": point,
        "classRank": rank,
        "coscholasticTerm1": term_wire(terms.get("TERM1")),
        "coscholasticTerm2": term_wire(terms.get("TERM2")),
    }


def class_analytics(session: Session, tenant: str, class_name: str, year: str, exam_type: str | None) -> dict:
    enrollments = list(session.scalars(select(Enrollment).where(
        Enrollment.tenant_id == tenant,
        Enrollment.class_name == class_name,
        Enrollment.academic_year == year,
    )))
    records = published_records(session, tenant, class_name, year, exam_type)
    policy = grading_policy(session, tenant, year)
    if records and policy is None:
        raise HTTPException(status_code=409, detail="Grading policy is missing for published results")
    scores = class_scores(records, exam_weights(session, tenant, year), policy)
    overall_values = [score for _, score in scores.values()]
    by_subject = defaultdict(list)
    for record in records:
        by_subject[record.subject].append(record)
    heatmap = []
    for subject, items in sorted(by_subject.items()):
        values = [item.marks_obtained * 100 / item.max_marks for item in items]
        average = sum(values, ZERO) / len(values)
        heatmap.append({
            "subject": subject,
            "classAverage": round(float(average), 2),
            "passPercentage": round(100 * sum(value >= policy.pass_percentage for value in values) / len(values), 2),
            "performance": "STRONG" if average >= 75 else "AVERAGE" if average >= 50 else "NEEDS_ATTENTION",
            "totalStudents": len({item.enrollment_id for item in items}),
        })
    by_id = {item.student_id: item for item in enrollments}
    at_risk = []
    for student_id, (subjects, score) in scores.items():
        if score >= 50:
            continue
        enrollment = by_id[student_id]
        at_risk.append({
            "studentId": student_id,
            "studentName": enrollment.student.full_name,
            "rollNumber": enrollment.roll_number,
            "failedSubjects": [item["subject"] for item in subjects if item["weightedPercentage"] < policy.pass_percentage],
            "droppingSubjects": [item["subject"] for item in subjects if item["trend"] == "DECLINING"],
            "overallPercentage": round(float(score), 2),
            "riskLevel": "HIGH" if score < policy.pass_percentage else "WARNING",
        })
    recognition = [
        {
            "category": "Top performer",
            "studentName": by_id[student_id].student.full_name,
            "detail": f"{round(float(score), 2)}%",
        }
        for student_id, (_, score) in sorted(scores.items(), key=lambda item: item[1][1], reverse=True)[:3]
    ]
    return {
        "className": class_name,
        "examType": exam_type,
        "academicYear": year,
        "totalStudents": len(enrollments),
        "gradedStudents": len(scores),
        "classAverage": round(float(sum(overall_values, ZERO) / len(overall_values)), 2) if overall_values else 0.0,
        "highestPercentage": round(float(max(overall_values)), 2) if overall_values else 0.0,
        "lowestPercentage": round(float(min(overall_values)), 2) if overall_values else 0.0,
        "passPercentage": round(100 * sum(score >= policy.pass_percentage for score in overall_values) / len(overall_values), 2) if overall_values else 0.0,
        "subjectHeatmap": heatmap,
        "atRiskStudents": at_risk,
        "recognition": recognition,
    }
