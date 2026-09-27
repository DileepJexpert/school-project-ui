import uuid
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import BigInteger, CheckConstraint, Date, DateTime, ForeignKey, Index, JSON, Numeric, String, Time, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def new_id() -> str:
    return str(uuid.uuid4())


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    active: Mapped[bool] = mapped_column(default=True)
    city: Mapped[str] = mapped_column(String(120), default="")
    board: Mapped[str] = mapped_column(String(120), default="")


class ContactEnquiry(Base):
    __tablename__ = "contact_enquiries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    email: Mapped[str] = mapped_column(String(320))
    phone: Mapped[str] = mapped_column(String(40))
    grade_interested: Mapped[str] = mapped_column(String(80), default="")
    message: Mapped[str] = mapped_column(String(4000))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SchoolSiteContent(Base):
    __tablename__ = "school_site_content"

    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), primary_key=True)
    content: Mapped[dict] = mapped_column(JSON, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("scope", "email"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    scope: Mapped[str] = mapped_column(String(64), index=True)
    tenant_id: Mapped[str | None] = mapped_column(ForeignKey("tenants.id"), nullable=True)
    email: Mapped[str] = mapped_column(String(320))
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(200))
    phone: Mapped[str] = mapped_column(String(40), default="")
    role: Mapped[str] = mapped_column(String(40))
    linked_entity_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    extra_permissions: Mapped[list[str]] = mapped_column(JSON, default=list)
    active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    access_hash: Mapped[str] = mapped_column(String(64), unique=True)
    refresh_hash: Mapped[str] = mapped_column(String(64), unique=True)
    access_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    refresh_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    user: Mapped[User] = relationship()


class Student(Base):
    __tablename__ = "students"
    __table_args__ = (UniqueConstraint("tenant_id", "admission_number"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    full_name: Mapped[str] = mapped_column(String(200))
    date_of_birth: Mapped[date] = mapped_column(Date)
    gender: Mapped[str] = mapped_column(String(32))
    blood_group: Mapped[str] = mapped_column(String(16), default="")
    nationality: Mapped[str] = mapped_column(String(80), default="")
    religion: Mapped[str] = mapped_column(String(80), default="")
    mother_tongue: Mapped[str] = mapped_column(String(80), default="")
    aadhar_number: Mapped[str] = mapped_column(String(32), default="")
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    date_of_admission: Mapped[date] = mapped_column(Date)
    admission_number: Mapped[str | None] = mapped_column(String(64), nullable=True)
    roll_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    status: Mapped[str] = mapped_column(String(16))
    parent_details: Mapped[dict] = mapped_column(JSON, default=dict)
    contact_details: Mapped[dict] = mapped_column(JSON, default=dict)
    previous_school_details: Mapped[dict] = mapped_column(JSON, default=dict)

    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="student")


class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (UniqueConstraint("tenant_id", "student_id", "academic_year"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.id"), index=True)
    academic_year: Mapped[str] = mapped_column(String(9))
    class_name: Mapped[str] = mapped_column(String(80))
    roll_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    date_of_admission: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(16), default="ACTIVE")

    student: Mapped[Student] = relationship(back_populates="enrollments")
    fee_profile: Mapped["FeeProfile | None"] = relationship(back_populates="enrollment")


class FeeStructure(Base):
    __tablename__ = "fee_structures"
    __table_args__ = (UniqueConstraint("tenant_id", "class_name", "academic_year"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    components: Mapped[list["FeeComponent"]] = relationship(
        back_populates="structure", cascade="all, delete-orphan", order_by="FeeComponent.position"
    )


class FeeComponent(Base):
    __tablename__ = "fee_components"
    __table_args__ = (
        UniqueConstraint("structure_id", "name"),
        CheckConstraint("amount > 0", name="fee_component_amount_positive"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    structure_id: Mapped[str] = mapped_column(ForeignKey("fee_structures.id"))
    position: Mapped[int] = mapped_column(default=0)
    name: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    frequency: Mapped[str] = mapped_column(String(16))
    description: Mapped[str] = mapped_column(String(500), default="")

    structure: Mapped[FeeStructure] = relationship(back_populates="components")


class FeeProfile(Base):
    __tablename__ = "fee_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    enrollment_id: Mapped[str] = mapped_column(
        ForeignKey("enrollments.id"), unique=True
    )
    fee_structure_id: Mapped[str] = mapped_column(ForeignKey("fee_structures.id"))
    enrollment: Mapped[Enrollment] = relationship(back_populates="fee_profile")
    installments: Mapped[list["FeeInstallment"]] = relationship(
        back_populates="profile", cascade="all, delete-orphan", order_by="FeeInstallment.position"
    )
    payments: Mapped[list["Payment"]] = relationship(back_populates="profile")


class FeeInstallment(Base):
    __tablename__ = "fee_installments"
    __table_args__ = (
        UniqueConstraint("profile_id", "name"),
        CheckConstraint("amount_due >= 0", name="fee_installment_amount_nonnegative"),
        CheckConstraint("paid_amount >= 0", name="fee_installment_paid_nonnegative"),
        CheckConstraint("discount_amount >= 0", name="fee_installment_discount_nonnegative"),
        CheckConstraint("paid_amount + discount_amount <= amount_due", name="fee_installment_not_overpaid"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    profile_id: Mapped[str] = mapped_column(ForeignKey("fee_profiles.id"))
    position: Mapped[int] = mapped_column(default=0)
    name: Mapped[str] = mapped_column(String(160))
    amount_due: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    paid_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"))
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"))
    status: Mapped[str] = mapped_column(String(16), default="PENDING")
    profile: Mapped[FeeProfile] = relationship(back_populates="installments")


class Payment(Base):
    __tablename__ = "payments"
    __table_args__ = (
        UniqueConstraint("tenant_id", "receipt_number"),
        UniqueConstraint("tenant_id", "idempotency_key"),
        UniqueConstraint("tenant_id", "payment_mode", "transaction_reference"),
        CheckConstraint("amount_paid >= 0", name="payment_amount_nonnegative"),
        CheckConstraint("discount >= 0", name="payment_discount_nonnegative"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    profile_id: Mapped[str] = mapped_column(ForeignKey("fee_profiles.id"), index=True)
    receipt_number: Mapped[str] = mapped_column(String(64))
    payment_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    amount_paid: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    discount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    payment_mode: Mapped[str] = mapped_column(String(32))
    transaction_reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    cheque_details: Mapped[str | None] = mapped_column(String(200), nullable=True)
    remarks: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True)
    request_fingerprint: Mapped[str | None] = mapped_column(String(64), nullable=True)
    collected_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", name="fk_payments_collected_by_user_id_users"), nullable=True,
    )
    student_name_snapshot: Mapped[str | None] = mapped_column(String(200), nullable=True)
    voided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    void_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    voided_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", name="fk_payments_voided_by_user_id_users"), nullable=True,
    )
    profile: Mapped[FeeProfile] = relationship(back_populates="payments")
    allocations: Mapped[list["PaymentAllocation"]] = relationship(
        back_populates="payment", cascade="all, delete-orphan", order_by="PaymentAllocation.position"
    )


class PaymentAllocation(Base):
    __tablename__ = "payment_allocations"
    __table_args__ = (
        UniqueConstraint("payment_id", "installment_id"),
        CheckConstraint("amount_paid >= 0", name="allocation_amount_nonnegative"),
        CheckConstraint("discount >= 0", name="allocation_discount_nonnegative"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    payment_id: Mapped[str] = mapped_column(ForeignKey("payments.id"), index=True)
    installment_id: Mapped[str] = mapped_column(ForeignKey("fee_installments.id"))
    position: Mapped[int] = mapped_column()
    amount_paid: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    discount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    payment: Mapped[Payment] = relationship(back_populates="allocations")
    installment: Mapped[FeeInstallment] = relationship()


class RolloverRun(Base):
    __tablename__ = "rollover_runs"
    __table_args__ = (UniqueConstraint("tenant_id", "idempotency_key"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    idempotency_key: Mapped[str] = mapped_column(String(128))
    request_fingerprint: Mapped[str] = mapped_column(String(64))
    source_class: Mapped[str] = mapped_column(String(80))
    source_year: Mapped[str] = mapped_column(String(9))
    target_class: Mapped[str | None] = mapped_column(String(80), nullable=True)
    target_year: Mapped[str | None] = mapped_column(String(9), nullable=True)
    student_count: Mapped[int] = mapped_column()
    student_ids: Mapped[list[str]] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ClassYearClosure(Base):
    __tablename__ = "class_year_closures"
    __table_args__ = (UniqueConstraint("tenant_id", "class_name", "academic_year"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    rollover_run_id: Mapped[str] = mapped_column(ForeignKey("rollover_runs.id"))
    closed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Expense(Base):
    __tablename__ = "expenses"
    __table_args__ = (CheckConstraint("amount > 0", name="expense_amount_positive"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    date: Mapped[date] = mapped_column(Date)
    paid_to: Mapped[str] = mapped_column(String(200))
    remarks: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    voided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (UniqueConstraint("tenant_id", "enrollment_id", "date"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    enrollment_id: Mapped[str] = mapped_column(ForeignKey("enrollments.id"), index=True)
    date: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(16))
    marked_by: Mapped[str] = mapped_column(String(200))
    remarks: Mapped[str] = mapped_column(String(1000), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    voided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    enrollment: Mapped[Enrollment] = relationship()


class ResultRecord(Base):
    __tablename__ = "result_records"
    __table_args__ = (
        UniqueConstraint("tenant_id", "enrollment_id", "exam_type", "subject"),
        CheckConstraint("max_marks > 0", name="result_max_marks_positive"),
        CheckConstraint("marks_obtained >= 0", name="result_marks_nonnegative"),
        CheckConstraint("marks_obtained <= max_marks", name="result_marks_within_max"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    enrollment_id: Mapped[str] = mapped_column(ForeignKey("enrollments.id"), index=True)
    exam_type: Mapped[str] = mapped_column(String(80))
    subject: Mapped[str] = mapped_column(String(120))
    marks_obtained: Mapped[Decimal] = mapped_column(Numeric(7, 2))
    max_marks: Mapped[Decimal] = mapped_column(Numeric(7, 2))
    teacher_remarks: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    entered_by: Mapped[str] = mapped_column(String(200))
    is_published: Mapped[bool] = mapped_column(default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    voided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    enrollment: Mapped[Enrollment] = relationship()


class ExamConfig(Base):
    __tablename__ = "exam_configs"
    __table_args__ = (
        UniqueConstraint("tenant_id", "academic_year", "exam_type"),
        CheckConstraint("weightage_percent >= 0 AND weightage_percent <= 100", name="exam_weightage_range"),
        CheckConstraint("max_marks_default > 0", name="exam_max_marks_positive"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    academic_year: Mapped[str] = mapped_column(String(9))
    exam_type: Mapped[str] = mapped_column(String(80))
    display_name: Mapped[str] = mapped_column(String(120))
    weightage_percent: Mapped[int] = mapped_column()
    max_marks_default: Mapped[Decimal] = mapped_column(Numeric(7, 2))
    is_active: Mapped[bool] = mapped_column(default=True)


class CoscholasticAssessment(Base):
    __tablename__ = "coscholastic_assessments"
    __table_args__ = (UniqueConstraint("tenant_id", "enrollment_id", "term"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    enrollment_id: Mapped[str] = mapped_column(ForeignKey("enrollments.id"), index=True)
    term: Mapped[str] = mapped_column(String(80))
    areas: Mapped[list[dict]] = mapped_column(JSON)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    enrollment: Mapped[Enrollment] = relationship()


class TimetableDay(Base):
    __tablename__ = "timetable_days"
    __table_args__ = (UniqueConstraint("tenant_id", "class_name", "academic_year", "day_of_week"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    day_of_week: Mapped[str] = mapped_column(String(16))
    periods: Mapped[list["TimetablePeriod"]] = relationship(
        back_populates="day", cascade="all, delete-orphan", order_by="TimetablePeriod.period_number"
    )


class TimetablePeriod(Base):
    __tablename__ = "timetable_periods"
    __table_args__ = (
        UniqueConstraint("day_id", "period_number"),
        CheckConstraint("period_number > 0", name="timetable_period_number_positive"),
        CheckConstraint("start_time < end_time", name="timetable_time_order"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    day_id: Mapped[str] = mapped_column(ForeignKey("timetable_days.id", ondelete="CASCADE"), index=True)
    period_number: Mapped[int] = mapped_column()
    subject: Mapped[str] = mapped_column(String(120))
    teacher_name: Mapped[str] = mapped_column(String(200))
    start_time: Mapped[time] = mapped_column(Time)
    end_time: Mapped[time] = mapped_column(Time)
    day: Mapped[TimetableDay] = relationship(back_populates="periods")


class Staff(Base):
    __tablename__ = "staff"
    __table_args__ = (
        UniqueConstraint("tenant_id", "employee_id"),
        CheckConstraint("basic_salary >= 0", name="staff_salary_nonnegative"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    employee_id: Mapped[str] = mapped_column(String(64))
    full_name: Mapped[str] = mapped_column(String(200))
    email: Mapped[str] = mapped_column(String(320), default="")
    phone: Mapped[str] = mapped_column(String(40), default="")
    department: Mapped[str] = mapped_column(String(80))
    designation: Mapped[str] = mapped_column(String(120))
    date_of_joining: Mapped[date] = mapped_column(Date)
    date_of_leaving: Mapped[date | None] = mapped_column(Date, nullable=True)
    basic_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(24), default="ACTIVE")
    details: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class LeaveRequest(Base):
    __tablename__ = "leave_requests"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    staff_id: Mapped[str] = mapped_column(ForeignKey("staff.id"), index=True)
    staff_name: Mapped[str] = mapped_column(String(200))
    department: Mapped[str] = mapped_column(String(80))
    leave_type: Mapped[str] = mapped_column(String(32))
    from_date: Mapped[date] = mapped_column(Date)
    to_date: Mapped[date] = mapped_column(Date)
    total_days: Mapped[int] = mapped_column()
    reason: Mapped[str] = mapped_column(String(1000))
    status: Mapped[str] = mapped_column(String(16))
    approved_by: Mapped[str | None] = mapped_column(String(200), nullable=True)
    approver_remarks: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    applied_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SalaryRecord(Base):
    __tablename__ = "salary_records"
    __table_args__ = (
        UniqueConstraint("tenant_id", "staff_id", "month", "year"),
        CheckConstraint("month >= 1 AND month <= 12", name="salary_month_range"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    staff_id: Mapped[str] = mapped_column(ForeignKey("staff.id"), index=True)
    staff_name: Mapped[str] = mapped_column(String(200))
    department: Mapped[str] = mapped_column(String(80))
    designation: Mapped[str] = mapped_column(String(120))
    month: Mapped[int] = mapped_column()
    year: Mapped[int] = mapped_column()
    basic_pay: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    hra: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    da: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    ta: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    other_allowances: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    pf: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    tax: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    other_deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    gross_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    total_deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    net_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(16))
    payment_mode: Mapped[str | None] = mapped_column(String(32), nullable=True)
    transaction_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)
    generated_by: Mapped[str] = mapped_column(String(200))
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class StaffAttendance(Base):
    __tablename__ = "staff_attendance"
    __table_args__ = (UniqueConstraint("tenant_id", "staff_id", "date"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    staff_id: Mapped[str] = mapped_column(ForeignKey("staff.id"), index=True)
    staff_name: Mapped[str] = mapped_column(String(200))
    department: Mapped[str] = mapped_column(String(80))
    date: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(16))
    check_in_time: Mapped[str | None] = mapped_column(String(5), nullable=True)
    check_out_time: Mapped[str | None] = mapped_column(String(5), nullable=True)
    remarks: Mapped[str] = mapped_column(String(1000), default="")
    marked_by: Mapped[str] = mapped_column(String(200))
    marked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class TransportRoute(Base):
    __tablename__ = "transport_routes"
    __table_args__ = (UniqueConstraint("tenant_id", "zone_name"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    zone_name: Mapped[str] = mapped_column(String(120))
    display_name: Mapped[str] = mapped_column(String(200), default="")
    areas_covered: Mapped[str] = mapped_column(String(1000), default="")
    stops: Mapped[list[str]] = mapped_column(JSON, default=list)
    first_pickup_time: Mapped[str] = mapped_column(String(40), default="")
    monthly_fee: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Bus(Base):
    __tablename__ = "buses"
    __table_args__ = (
        UniqueConstraint("tenant_id", "bus_number"),
        CheckConstraint("capacity > 0", name="bus_capacity_positive"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    bus_number: Mapped[str] = mapped_column(String(80))
    driver_name: Mapped[str] = mapped_column(String(200))
    driver_mobile: Mapped[str] = mapped_column(String(40))
    route_id: Mapped[str | None] = mapped_column(ForeignKey("transport_routes.id"), nullable=True)
    capacity: Mapped[int] = mapped_column()
    status: Mapped[str] = mapped_column(String(16), default="ACTIVE")
    insurance_expiry: Mapped[str | None] = mapped_column(String(40), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class TransportAssignment(Base):
    __tablename__ = "transport_assignments"
    __table_args__ = (Index(
        "uq_transport_active_student", "tenant_id", "student_id", unique=True,
        postgresql_where=text("status = 'ACTIVE'"), sqlite_where=text("status = 'ACTIVE'"),
    ),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.id"), index=True)
    student_name: Mapped[str] = mapped_column(String(200))
    class_name: Mapped[str] = mapped_column(String(80))
    roll_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    bus_id: Mapped[str] = mapped_column(ForeignKey("buses.id"), index=True)
    route_id: Mapped[str] = mapped_column(ForeignKey("transport_routes.id"), index=True)
    pickup_stop: Mapped[str | None] = mapped_column(String(200), nullable=True)
    status: Mapped[str] = mapped_column(String(16))
    assigned_date: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Homework(Base):
    __tablename__ = "homework"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(String(4000), default="")
    class_name: Mapped[str] = mapped_column(String(80))
    subject: Mapped[str] = mapped_column(String(120))
    teacher_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    teacher_name: Mapped[str] = mapped_column(String(200))
    due_date: Mapped[date] = mapped_column(Date)
    assigned_date: Mapped[date] = mapped_column(Date)
    academic_year: Mapped[str] = mapped_column(String(9))
    status: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Incident(Base):
    __tablename__ = "incidents"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.id"), index=True)
    student_name: Mapped[str] = mapped_column(String(200))
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    severity: Mapped[str] = mapped_column(String(16))
    category: Mapped[str] = mapped_column(String(32))
    description: Mapped[str] = mapped_column(String(4000))
    action_taken: Mapped[str] = mapped_column(String(2000), default="")
    reported_by: Mapped[str] = mapped_column(String(200))
    incident_date: Mapped[date] = mapped_column(Date)
    parent_notified: Mapped[bool] = mapped_column(default=False)
    parent_notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    follow_up_notes: Mapped[str] = mapped_column(String(2000), default="")
    resolved: Mapped[bool] = mapped_column(default=False)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class CertificateRecord(Base):
    __tablename__ = "certificate_records"
    __table_args__ = (UniqueConstraint("tenant_id", "serial_number"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.id"), index=True)
    student_name: Mapped[str] = mapped_column(String(200))
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    certificate_type: Mapped[str] = mapped_column(String(24))
    serial_number: Mapped[str] = mapped_column(String(80))
    reason: Mapped[str] = mapped_column(String(1000), default="")
    additional_fields: Mapped[dict] = mapped_column(JSON, default=dict)
    generated_by: Mapped[str] = mapped_column(String(200))
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    message: Mapped[str] = mapped_column(String(4000))
    type: Mapped[str] = mapped_column(String(32))
    target_audience: Mapped[str] = mapped_column(String(24))
    target_class: Mapped[str | None] = mapped_column(String(80), nullable=True)
    target_student_id: Mapped[str | None] = mapped_column(ForeignKey("students.id"), nullable=True)
    priority: Mapped[str] = mapped_column(String(16))
    created_by: Mapped[str] = mapped_column(String(200))
    creator_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class NotificationRead(Base):
    __tablename__ = "notification_reads"
    __table_args__ = (UniqueConstraint("notification_id", "user_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    notification_id: Mapped[str] = mapped_column(ForeignKey("notifications.id"), index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ChatRoom(Base):
    __tablename__ = "chat_rooms"
    __table_args__ = (UniqueConstraint("tenant_id", "participant_1_id", "participant_2_id", "student_key"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    participant_1_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    participant_2_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    student_key: Mapped[str] = mapped_column(String(36), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    room_id: Mapped[str] = mapped_column(ForeignKey("chat_rooms.id"), index=True)
    sender_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    message: Mapped[str] = mapped_column(String(4000))
    message_type: Mapped[str] = mapped_column(String(16), default="TEXT")
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class TutorialVideo(Base):
    __tablename__ = "tutorial_videos"
    __table_args__ = (UniqueConstraint("tenant_id", "storage_key"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(String(4000), default="")
    subject: Mapped[str] = mapped_column(String(120))
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    chapter: Mapped[str] = mapped_column(String(200), default="")
    teacher_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    teacher_name: Mapped[str] = mapped_column(String(200))
    storage_key: Mapped[str] = mapped_column(String(80))
    file_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str] = mapped_column(String(80))
    file_size: Mapped[int] = mapped_column(BigInteger)
    status: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AiConfig(Base):
    __tablename__ = "ai_configs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), unique=True)
    enabled: Mapped[bool] = mapped_column(default=False)
    enabled_modes: Mapped[list[str]] = mapped_column(JSON, default=list)
    primary_provider: Mapped[str] = mapped_column(String(32), default="OLLAMA")
    ollama_base_url: Mapped[str] = mapped_column(String(500))
    ollama_model: Mapped[str] = mapped_column(String(120))
    daily_limit_per_student: Mapped[int] = mapped_column(default=20)
    max_conversation_turns: Mapped[int] = mapped_column(default=30)
    updated_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AiConversation(Base):
    __tablename__ = "ai_conversations"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    homework_id: Mapped[str | None] = mapped_column(ForeignKey("homework.id"), nullable=True)
    mode: Mapped[str] = mapped_column(String(16))
    subject: Mapped[str] = mapped_column(String(120), default="")
    class_name: Mapped[str] = mapped_column(String(80), default="")
    messages: Mapped[list[dict]] = mapped_column(JSON, default=list)
    session_active: Mapped[bool] = mapped_column(default=True)
    total_input_tokens: Mapped[int] = mapped_column(default=0)
    total_output_tokens: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AiUsage(Base):
    __tablename__ = "ai_usage"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    conversation_id: Mapped[str | None] = mapped_column(ForeignKey("ai_conversations.id"), nullable=True)
    provider: Mapped[str] = mapped_column(String(32))
    input_tokens: Mapped[int] = mapped_column(default=0)
    output_tokens: Mapped[int] = mapped_column(default=0)
    status: Mapped[str] = mapped_column(String(16))
    request_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AcademicYearRecord(Base):
    __tablename__ = "academic_years"
    __table_args__ = (UniqueConstraint("tenant_id", "year"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    year: Mapped[str] = mapped_column(String(9))
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(16), default="OPEN")
    grade_bands: Mapped[list[dict] | None] = mapped_column(JSON, nullable=True)
    pass_percentage: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    exam_order: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)


class SchoolClass(Base):
    __tablename__ = "school_classes"
    __table_args__ = (UniqueConstraint("tenant_id", "class_name"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    class_name: Mapped[str] = mapped_column(String(80))
    base_class: Mapped[str] = mapped_column(String(80))
    section: Mapped[str] = mapped_column(String(16))
    sort_order: Mapped[int] = mapped_column()
    active: Mapped[bool] = mapped_column(default=True)


class SchoolSubject(Base):
    __tablename__ = "school_subjects"
    __table_args__ = (UniqueConstraint("tenant_id", "name"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    sort_order: Mapped[int] = mapped_column()
    active: Mapped[bool] = mapped_column(default=True)


class ClassSubject(Base):
    __tablename__ = "class_subjects"
    __table_args__ = (UniqueConstraint("tenant_id", "class_name", "academic_year", "subject_name"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.id"), index=True)
    class_name: Mapped[str] = mapped_column(String(80))
    academic_year: Mapped[str] = mapped_column(String(9))
    subject_name: Mapped[str] = mapped_column(String(120))
