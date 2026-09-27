"""Read-only consistency checks for imports and periodic fee audits."""

import json
import sys
from collections import defaultdict
from decimal import Decimal
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.config import video_storage_dir
from app.models import (
    AcademicYearRecord, AiConversation, AiUsage, Attendance, Bus, CertificateRecord,
    ChatMessage, ChatRoom, ClassSubject, ClassYearClosure, Enrollment, FeeInstallment,
    FeeProfile, FeeStructure, Homework,
    Incident, LeaveRequest, Notification, NotificationRead, Payment, PaymentAllocation,
    ResultRecord, RolloverRun, SalaryRecord, SchoolClass, SchoolSubject, Staff, StaffAttendance, Student,
    TransportAssignment, TransportRoute, TutorialVideo, User,
)
from app.years import academic_year_for_date

ZERO = Decimal("0.00")


def audit_session(session: Session, tenant: str | None = None) -> list[str]:
    issues: list[str] = []
    students = {item.id: item for item in session.scalars(select(Student)) if tenant is None or item.tenant_id == tenant}
    enrollments = {item.id: item for item in session.scalars(select(Enrollment)) if tenant is None or item.tenant_id == tenant}
    profiles = {item.id: item for item in session.scalars(select(FeeProfile)) if tenant is None or item.tenant_id == tenant}
    structures = {item.id: item for item in session.scalars(select(FeeStructure)) if tenant is None or item.tenant_id == tenant}
    profile_by_enrollment = {item.enrollment_id: item for item in profiles.values()}
    installments = {item.id: item for item in session.scalars(select(FeeInstallment)) if item.profile_id in profiles}
    payments = {item.id: item for item in session.scalars(select(Payment)) if tenant is None or item.tenant_id == tenant}
    allocations = list(session.scalars(select(PaymentAllocation)))
    allocated_by_installment = defaultdict(lambda: [ZERO, ZERO])
    allocated_by_payment = defaultdict(lambda: [ZERO, ZERO])

    current_enrollments = {(item.student_id, item.academic_year): item for item in enrollments.values()}
    for student in students.values():
        if student.status == "ACTIVE" and (student.id, student.academic_year) not in current_enrollments:
            issues.append(f"student {student.id}: active without current-year enrollment")

    for enrollment in enrollments.values():
        student = students.get(enrollment.student_id)
        if student is None or student.tenant_id != enrollment.tenant_id:
            issues.append(f"enrollment {enrollment.id}: student/tenant mismatch")
        if enrollment.id not in profile_by_enrollment:
            issues.append(f"enrollment {enrollment.id}: fee profile missing")
    for profile in profiles.values():
        enrollment = enrollments.get(profile.enrollment_id)
        if enrollment is None or enrollment.tenant_id != profile.tenant_id:
            issues.append(f"fee profile {profile.id}: enrollment/tenant mismatch")
        structure = structures.get(profile.fee_structure_id)
        if enrollment is not None and (
            structure is None
            or structure.tenant_id != profile.tenant_id
            or structure.class_name != enrollment.class_name
            or structure.academic_year != enrollment.academic_year
        ):
            issues.append(f"fee profile {profile.id}: structure/class/year mismatch")
    for allocation in allocations:
        payment = payments.get(allocation.payment_id)
        installment = installments.get(allocation.installment_id)
        if payment is None and installment is None:
            continue
        if payment is None or installment is None or installment.profile_id != payment.profile_id:
            issues.append(f"allocation {allocation.id}: payment/installment profile mismatch")
            continue
        if payment.voided_at is None:
            allocated_by_installment[installment.id][0] += allocation.amount_paid
            allocated_by_installment[installment.id][1] += allocation.discount
        allocated_by_payment[payment.id][0] += allocation.amount_paid
        allocated_by_payment[payment.id][1] += allocation.discount
    for installment in installments.values():
        allocated = allocated_by_installment[installment.id]
        if installment.paid_amount != allocated[0] or installment.discount_amount != allocated[1]:
            issues.append(f"installment {installment.id}: cached balance differs from allocations")
        balance = installment.amount_due - installment.paid_amount - installment.discount_amount
        if balance < 0:
            issues.append(f"installment {installment.id}: negative balance")
        if (balance == 0) != (installment.status == "PAID"):
            issues.append(f"installment {installment.id}: status differs from balance")
    for payment in payments.values():
        allocated = allocated_by_payment[payment.id]
        if payment.amount_paid != allocated[0] or payment.discount != allocated[1]:
            issues.append(f"payment {payment.id}: totals differ from allocations")
        profile = profiles.get(payment.profile_id)
        if profile is None or profile.tenant_id != payment.tenant_id:
            issues.append(f"payment {payment.id}: profile/tenant mismatch")
    for attendance in session.scalars(select(Attendance)):
        if tenant is not None and attendance.tenant_id != tenant:
            continue
        enrollment = enrollments.get(attendance.enrollment_id)
        if enrollment is None or enrollment.tenant_id != attendance.tenant_id:
            issues.append(f"attendance {attendance.id}: enrollment/tenant mismatch")
        elif academic_year_for_date(attendance.date) != enrollment.academic_year:
            issues.append(f"attendance {attendance.id}: date/year mismatch")
    known_classes = {(item.tenant_id, item.class_name) for item in session.scalars(select(SchoolClass))}
    known_subjects = {(item.tenant_id, item.name) for item in session.scalars(select(SchoolSubject))}
    known_years = {(item.tenant_id, item.year) for item in session.scalars(select(AcademicYearRecord))}
    class_subjects = defaultdict(set)
    for assignment in session.scalars(select(ClassSubject)):
        if tenant is not None and assignment.tenant_id != tenant:
            continue
        context = (assignment.tenant_id, assignment.class_name, assignment.academic_year)
        class_subjects[context].add(assignment.subject_name)
        if ((assignment.tenant_id, assignment.class_name) not in known_classes
                or (assignment.tenant_id, assignment.subject_name) not in known_subjects
                or (assignment.tenant_id, assignment.academic_year) not in known_years):
            issues.append(f"class subject {assignment.id}: catalogue relation missing")
    published_by_context = defaultdict(lambda: defaultdict(set))
    for result in session.scalars(select(ResultRecord)):
        if tenant is not None and result.tenant_id != tenant:
            continue
        enrollment = enrollments.get(result.enrollment_id)
        if enrollment is None or enrollment.tenant_id != result.tenant_id:
            issues.append(f"result {result.id}: enrollment/tenant mismatch")
        elif result.is_published and result.voided_at is None:
            context = (result.tenant_id, enrollment.class_name, enrollment.academic_year, result.exam_type)
            published_by_context[context][result.subject].add(enrollment.id)
    for (tenant_id, class_name, year, exam_type), by_subject in published_by_context.items():
        expected_subjects = class_subjects[(tenant_id, class_name, year)]
        expected_enrollments = {
            item.id for item in enrollments.values()
            if item.tenant_id == tenant_id and item.class_name == class_name and item.academic_year == year
        }
        if set(by_subject) != expected_subjects or any(ids != expected_enrollments for ids in by_subject.values()):
            issues.append(f"published results {class_name} {year} {exam_type}: incomplete subject roster")
    for closure in session.scalars(select(ClassYearClosure)):
        if tenant is not None and closure.tenant_id != tenant:
            continue
        run = session.get(RolloverRun, closure.rollover_run_id)
        if run is None or run.tenant_id != closure.tenant_id or run.source_class != closure.class_name or run.source_year != closure.academic_year:
            issues.append(f"class-year closure {closure.id}: rollover mismatch")
        if any(
            student.status == "ACTIVE" and student.class_name == closure.class_name
            and student.academic_year == closure.academic_year and student.tenant_id == closure.tenant_id
            for student in students.values()
        ):
            issues.append(f"class-year closure {closure.id}: active student remains in closed year")

    users = {item.id: item for item in session.scalars(select(User)) if tenant is None or item.tenant_id == tenant}
    for payment in payments.values():
        if (not payment.student_name_snapshot or payment.collected_by_user_id not in users
                or users[payment.collected_by_user_id].tenant_id != payment.tenant_id):
            issues.append(f"payment {payment.id}: receipt identity audit is incomplete")
        if payment.voided_at is not None and (
            not payment.void_reason or payment.voided_by_user_id not in users
            or users[payment.voided_by_user_id].tenant_id != payment.tenant_id
        ):
            issues.append(f"payment {payment.id}: reversal audit is incomplete")
    staff = {item.id: item for item in session.scalars(select(Staff)) if tenant is None or item.tenant_id == tenant}
    routes = {item.id: item for item in session.scalars(select(TransportRoute)) if tenant is None or item.tenant_id == tenant}
    buses = {item.id: item for item in session.scalars(select(Bus)) if tenant is None or item.tenant_id == tenant}
    bus_load = defaultdict(int)
    student_assignments = defaultdict(int)
    for user in users.values():
        if user.tenant_id and user.scope != user.tenant_id:
            issues.append(f"user {user.id}: scope/tenant mismatch")
        if user.role in ("STUDENT", "PARENT"):
            ids = [part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()]
            if not ids or any(student_id not in students or students[student_id].tenant_id != user.tenant_id for student_id in ids):
                issues.append(f"user {user.id}: linked student/tenant mismatch")
    for item in session.scalars(select(LeaveRequest)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        if item.staff_id not in staff or staff[item.staff_id].tenant_id != item.tenant_id:
            issues.append(f"leave {item.id}: staff/tenant mismatch")
        if item.total_days != (item.to_date - item.from_date).days + 1:
            issues.append(f"leave {item.id}: day count mismatch")
    for item in session.scalars(select(SalaryRecord)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        if item.staff_id not in staff or staff[item.staff_id].tenant_id != item.tenant_id:
            issues.append(f"salary {item.id}: staff/tenant mismatch")
        if item.gross_salary != item.basic_pay + item.hra + item.da + item.ta + item.other_allowances:
            issues.append(f"salary {item.id}: gross mismatch")
        if item.total_deductions != item.pf + item.tax + item.other_deductions or item.net_salary != item.gross_salary - item.total_deductions:
            issues.append(f"salary {item.id}: net mismatch")
        if (item.status == "PAID") != (item.paid_at is not None):
            issues.append(f"salary {item.id}: paid state mismatch")
    for item in session.scalars(select(StaffAttendance)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        if item.staff_id not in staff or staff[item.staff_id].tenant_id != item.tenant_id:
            issues.append(f"staff attendance {item.id}: staff/tenant mismatch")
    for item in buses.values():
        if item.route_id is not None and (item.route_id not in routes or routes[item.route_id].tenant_id != item.tenant_id):
            issues.append(f"bus {item.id}: route/tenant mismatch")
    for item in session.scalars(select(TransportAssignment)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        student = students.get(item.student_id)
        bus = buses.get(item.bus_id)
        route = routes.get(item.route_id)
        if student is None or bus is None or route is None or any(parent.tenant_id != item.tenant_id for parent in (student, bus, route)):
            issues.append(f"transport assignment {item.id}: relation/tenant mismatch")
        elif item.status == "ACTIVE":
            bus_load[item.bus_id] += 1
            student_assignments[item.student_id] += 1
            if bus.route_id != item.route_id or bus.status != "ACTIVE" or bus.deleted_at or route.deleted_at:
                issues.append(f"transport assignment {item.id}: inactive bus or route mismatch")
            if item.pickup_stop and item.pickup_stop not in route.stops:
                issues.append(f"transport assignment {item.id}: pickup stop mismatch")
    for bus_id, count in bus_load.items():
        if count > buses[bus_id].capacity:
            issues.append(f"bus {bus_id}: over capacity")
    for student_id, count in student_assignments.items():
        if count > 1:
            issues.append(f"student {student_id}: multiple active transport assignments")
    for item in session.scalars(select(Homework)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        teacher = users.get(item.teacher_id)
        if teacher is None or teacher.tenant_id != item.tenant_id:
            issues.append(f"homework {item.id}: teacher/tenant mismatch")
    for item in session.scalars(select(Incident)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        student = students.get(item.student_id)
        if student is None or student.tenant_id != item.tenant_id or (item.student_id, item.academic_year) not in current_enrollments:
            issues.append(f"incident {item.id}: student/enrollment/tenant mismatch")
    for item in session.scalars(select(CertificateRecord)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        student = students.get(item.student_id)
        if student is None or student.tenant_id != item.tenant_id:
            issues.append(f"certificate {item.id}: student/tenant mismatch")
    notifications = {item.id: item for item in session.scalars(select(Notification)) if tenant is None or item.tenant_id == tenant}
    for item in notifications.values():
        if item.creator_id not in users or users[item.creator_id].tenant_id != item.tenant_id:
            issues.append(f"notification {item.id}: creator/tenant mismatch")
        if item.target_student_id and (item.target_student_id not in students or students[item.target_student_id].tenant_id != item.tenant_id):
            issues.append(f"notification {item.id}: target/tenant mismatch")
    for item in session.scalars(select(NotificationRead)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        notice = notifications.get(item.notification_id)
        user = users.get(item.user_id)
        if notice is None or user is None or notice.tenant_id != item.tenant_id or user.tenant_id != item.tenant_id:
            issues.append(f"notification read {item.id}: relation/tenant mismatch")
    rooms = {item.id: item for item in session.scalars(select(ChatRoom)) if tenant is None or item.tenant_id == tenant}
    for item in rooms.values():
        first, second = users.get(item.participant_1_id), users.get(item.participant_2_id)
        if first is None or second is None or first.tenant_id != item.tenant_id or second.tenant_id != item.tenant_id or first.id == second.id:
            issues.append(f"chat room {item.id}: participant/tenant mismatch")
        if item.student_key and (item.student_key not in students or students[item.student_key].tenant_id != item.tenant_id):
            issues.append(f"chat room {item.id}: student/tenant mismatch")
    for item in session.scalars(select(ChatMessage)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        room = rooms.get(item.room_id)
        if room is None or room.tenant_id != item.tenant_id or item.sender_id not in (room.participant_1_id, room.participant_2_id):
            issues.append(f"chat message {item.id}: room/sender mismatch")
    storage = Path(video_storage_dir()).resolve()
    for item in session.scalars(select(TutorialVideo)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        teacher = users.get(item.teacher_id)
        if teacher is None or teacher.tenant_id != item.tenant_id:
            issues.append(f"video {item.id}: teacher/tenant mismatch")
        if item.deleted_at is None and not (storage / item.storage_key).is_file():
            issues.append(f"video {item.id}: storage file missing")
    conversations = {item.id: item for item in session.scalars(select(AiConversation)) if tenant is None or item.tenant_id == tenant}
    for item in conversations.values():
        user = users.get(item.user_id)
        if user is None or user.tenant_id != item.tenant_id or user.role != "STUDENT":
            issues.append(f"ai conversation {item.id}: user/tenant mismatch")
    for item in session.scalars(select(AiUsage)):
        if tenant is not None and item.tenant_id != tenant:
            continue
        user = users.get(item.user_id)
        if user is None or user.tenant_id != item.tenant_id:
            issues.append(f"ai usage {item.id}: user/tenant mismatch")
        if item.conversation_id and (item.conversation_id not in conversations or conversations[item.conversation_id].user_id != item.user_id):
            issues.append(f"ai usage {item.id}: conversation/user mismatch")
    return issues


def main() -> int:
    tenant = sys.argv[1] if len(sys.argv) > 1 else None
    with SessionLocal() as session:
        issues = audit_session(session, tenant)
    print(json.dumps({"tenant": tenant, "ok": not issues, "issues": issues}, indent=2))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
