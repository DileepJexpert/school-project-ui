from datetime import date, datetime, time
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.years import normalize_year


def camel(name: str) -> str:
    words = name.split("_")
    return words[0] + "".join(word.capitalize() for word in words[1:])


class WireModel(BaseModel):
    model_config = ConfigDict(alias_generator=camel, populate_by_name=True)


class ParentDetails(WireModel):
    father_name: str = ""
    father_occupation: str = ""
    father_mobile: str = ""
    father_email: str = ""
    mother_name: str = ""
    mother_occupation: str = ""
    mother_mobile: str = ""
    mother_email: str = ""


class ContactDetails(WireModel):
    permanent_address: str = ""
    correspondence_address: str = ""
    primary_contact_number: str = ""


class PreviousSchoolDetails(WireModel):
    school_name: str = ""
    last_class: str = ""
    board: str = ""


class StudentInput(WireModel):
    full_name: str = Field(min_length=1, max_length=200)
    date_of_birth: date
    gender: str = ""
    blood_group: str = ""
    nationality: str = ""
    religion: str = ""
    mother_tongue: str = ""
    aadhar_number: str = ""
    class_for_admission: str = Field(min_length=1)
    academic_year: str
    date_of_admission: date
    admission_number: str = ""
    roll_number: str | None = None
    status: Literal["ENQUIRY", "ACTIVE", "INACTIVE"] = "ACTIVE"
    parent_details: ParentDetails = Field(default_factory=ParentDetails)
    contact_details: ContactDetails = Field(default_factory=ContactDetails)
    previous_school_details: PreviousSchoolDetails = Field(
        default_factory=PreviousSchoolDetails
    )

    @field_validator("academic_year")
    @classmethod
    def valid_year(cls, value: str) -> str:
        return normalize_year(value)

    @field_validator("full_name", "class_for_admission")
    @classmethod
    def nonblank_student_fields(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be blank")
        return value


class FeeComponentInput(WireModel):
    fee_name: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    frequency: Literal["YEARLY", "MONTHLY", "ONE_TIME"] = "YEARLY"
    description: str = ""

    @field_validator("fee_name")
    @classmethod
    def nonblank_fee_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("feeName cannot be blank")
        return value


class FeeStructureInput(WireModel):
    class_name: str = Field(min_length=1, max_length=80)
    academic_year: str
    fee_components: list[FeeComponentInput] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_year(cls, value: str) -> str:
        return normalize_year(value)

    @field_validator("class_name")
    @classmethod
    def nonblank_class_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("className cannot be blank")
        return value


class FeePaymentInput(WireModel):
    student_id: str
    academic_year: str | None = None
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    discount: Decimal = Field(default=Decimal("0.00"), ge=0, max_digits=12, decimal_places=2)
    installment_names: list[str] = Field(min_length=1)
    payment_mode: Literal["CASH", "CHEQUE", "DIGITAL_PAYMENT", "CHALLAN"]
    remarks: str | None = Field(default=None, max_length=1000)
    cheque_details: str | None = Field(default=None, max_length=200)
    transaction_id: str | None = Field(default=None, max_length=120)

    @field_validator("academic_year")
    @classmethod
    def valid_optional_year(cls, value: str | None) -> str | None:
        return normalize_year(value) if value else None

    @model_validator(mode="after")
    def validate_references(self):
        if len(set(self.installment_names)) != len(self.installment_names):
            raise ValueError("Duplicate installment names")
        if self.payment_mode == "CHEQUE" and not (self.cheque_details or "").strip():
            raise ValueError("Cheque details are required")
        if self.payment_mode == "DIGITAL_PAYMENT" and not (self.transaction_id or "").strip():
            raise ValueError("Transaction reference is required")
        if self.amount == 0 and self.discount == 0:
            raise ValueError("Payment and discount cannot both be zero")
        return self


class RolloverInput(WireModel):
    source_class: str = Field(min_length=1, max_length=80)
    source_year: str
    action: Literal["PROMOTE", "GRADUATE"]
    target_class: str | None = Field(default=None, max_length=80)
    target_year: str | None = None

    @field_validator("source_year", "target_year")
    @classmethod
    def valid_rollover_year(cls, value: str | None) -> str | None:
        return normalize_year(value) if value else None

    @model_validator(mode="after")
    def validate_target(self):
        if self.action == "PROMOTE":
            start = int(self.source_year[:4])
            if not self.target_class or self.target_class == self.source_class:
                raise ValueError("Promotion requires a different target class")
            if self.target_year != f"{start + 1}-{start + 2}":
                raise ValueError("Promotion requires the next academic year")
        elif self.target_class or self.target_year:
            raise ValueError("Graduation must not specify a target class or year")
        return self


class ExpenseInput(WireModel):
    title: str = Field(min_length=1, max_length=200)
    category: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    date: date
    paid_to: str = Field(min_length=1, max_length=200)
    remarks: str | None = Field(default=None, max_length=1000)


class AttendanceEntryInput(WireModel):
    student_id: str
    student_name: str = ""
    status: Literal["PRESENT", "ABSENT", "LATE", "HALF_DAY"]
    remarks: str = Field(default="", max_length=1000)


class AttendanceBulkInput(WireModel):
    class_name: str = Field(min_length=1, max_length=80)
    academic_year: str
    date: date
    marked_by: str = Field(min_length=1, max_length=200)
    entries: list[AttendanceEntryInput] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_attendance_year(cls, value: str) -> str:
        return normalize_year(value)

    @model_validator(mode="after")
    def unique_entries(self):
        ids = [item.student_id for item in self.entries]
        if len(ids) != len(set(ids)):
            raise ValueError("Duplicate students in attendance roster")
        return self


class ResultEntryInput(WireModel):
    student_id: str
    student_name: str = ""
    roll_number: str = ""
    marks_obtained: Decimal = Field(ge=0, max_digits=7, decimal_places=2)
    teacher_remarks: str = Field(default="", max_length=1000)


class ResultBulkInput(WireModel):
    class_name: str = Field(min_length=1, max_length=80)
    exam_type: str = Field(min_length=1, max_length=80)
    academic_year: str
    subject: str = Field(min_length=1, max_length=120)
    max_marks: Decimal = Field(gt=0, max_digits=7, decimal_places=2)
    entered_by: str = Field(min_length=1, max_length=200)
    entries: list[ResultEntryInput] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_result_year(cls, value: str) -> str:
        return normalize_year(value)

    @field_validator("class_name", "exam_type", "subject", "entered_by")
    @classmethod
    def nonblank_result_fields(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be blank")
        return value

    @model_validator(mode="after")
    def valid_entries(self):
        ids = [item.student_id for item in self.entries]
        if len(ids) != len(set(ids)):
            raise ValueError("Duplicate students in marks request")
        if any(item.marks_obtained > self.max_marks for item in self.entries):
            raise ValueError("Marks cannot exceed maxMarks")
        return self


class ResultUpdateInput(WireModel):
    marks_obtained: Decimal = Field(ge=0, max_digits=7, decimal_places=2)
    max_marks: Decimal = Field(gt=0, max_digits=7, decimal_places=2)
    teacher_remarks: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def valid_marks(self):
        if self.marks_obtained > self.max_marks:
            raise ValueError("Marks cannot exceed maxMarks")
        return self


class ExamConfigInput(WireModel):
    id: str | None = None
    academic_year: str
    exam_type: str = Field(min_length=1, max_length=80)
    display_name: str = Field(min_length=1, max_length=120)
    weightage_percent: int = Field(ge=0, le=100)
    max_marks_default: Decimal = Field(gt=0, max_digits=7, decimal_places=2)
    is_active: bool = True

    @field_validator("academic_year")
    @classmethod
    def valid_exam_year(cls, value: str) -> str:
        return normalize_year(value)

    @field_validator("exam_type", "display_name")
    @classmethod
    def nonblank_exam_fields(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be blank")
        return value


class GradeBandInput(WireModel):
    min_percentage: Decimal = Field(ge=0, le=100, max_digits=5, decimal_places=2)
    grade: str = Field(min_length=1, max_length=20)
    grade_point: int = Field(ge=0, le=10)


class GradingPolicyInput(WireModel):
    academic_year: str
    pass_percentage: Decimal = Field(gt=0, le=100, max_digits=5, decimal_places=2)
    bands: list[GradeBandInput] = Field(min_length=2)
    exam_order: list[str] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_policy_year(cls, value: str) -> str:
        return normalize_year(value)

    @model_validator(mode="after")
    def validate_policy(self):
        thresholds = [item.min_percentage for item in self.bands]
        if thresholds[-1] != 0 or any(a <= b for a, b in zip(thresholds, thresholds[1:])):
            raise ValueError("Grade bands must descend by unique thresholds and end at zero")
        grades = [item.grade.strip() for item in self.bands]
        if any(not grade for grade in grades) or len(set(grades)) != len(grades):
            raise ValueError("Grade labels must be nonblank and unique")
        points = [item.grade_point for item in self.bands]
        if any(a < b for a, b in zip(points, points[1:])):
            raise ValueError("Grade points must not increase as marks fall")
        names = [item.strip() for item in self.exam_order]
        if any(not name or len(name) > 80 for name in names) or len(set(names)) != len(names):
            raise ValueError("examOrder must contain unique nonblank exam types")
        self.exam_order = names
        for item, grade in zip(self.bands, grades):
            item.grade = grade
        return self


class ClassSubjectsInput(WireModel):
    class_name: str = Field(min_length=1, max_length=80)
    academic_year: str
    subjects: list[str] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_class_subject_year(cls, value: str) -> str:
        return normalize_year(value)

    @model_validator(mode="after")
    def valid_subjects(self):
        self.class_name = self.class_name.strip()
        names = [item.strip() for item in self.subjects]
        if not self.class_name or any(not item or len(item) > 120 for item in names):
            raise ValueError("Class and subject names must be nonblank")
        if len(set(names)) != len(names):
            raise ValueError("Subjects must be unique")
        self.subjects = names
        return self


class SchoolSubjectInput(WireModel):
    name: str = Field(min_length=1, max_length=120)

    @field_validator("name")
    @classmethod
    def valid_subject_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Subject name cannot be blank")
        return value


class CoscholasticAreaInput(WireModel):
    name: str = Field(min_length=1, max_length=120)
    grade: str = Field(min_length=1, max_length=20)
    remarks: str | None = Field(default=None, max_length=1000)


class CoscholasticInput(WireModel):
    id: str | None = None
    student_id: str
    student_name: str = ""
    class_name: str = Field(min_length=1, max_length=80)
    academic_year: str
    term: str = Field(min_length=1, max_length=80)
    areas: list[CoscholasticAreaInput]

    @field_validator("academic_year")
    @classmethod
    def valid_coscholastic_year(cls, value: str) -> str:
        return normalize_year(value)

    @model_validator(mode="after")
    def unique_areas(self):
        names = [item.name.strip().lower() for item in self.areas]
        if len(names) != len(set(names)):
            raise ValueError("Duplicate co-scholastic areas")
        return self


class TimetablePeriodInput(WireModel):
    period_number: int = Field(gt=0)
    subject: str = Field(min_length=1, max_length=120)
    teacher_name: str = Field(min_length=1, max_length=200)
    start_time: time
    end_time: time

    @field_validator("subject", "teacher_name")
    @classmethod
    def nonblank_period_fields(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be blank")
        return value

    @model_validator(mode="after")
    def valid_time(self):
        if self.start_time >= self.end_time:
            raise ValueError("startTime must be before endTime")
        return self


class TimetableDayInput(WireModel):
    id: str | None = None
    class_name: str = Field(min_length=1, max_length=80)
    academic_year: str
    day_of_week: Literal["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    periods: list[TimetablePeriodInput] = Field(min_length=1)

    @field_validator("academic_year")
    @classmethod
    def valid_timetable_year(cls, value: str) -> str:
        return normalize_year(value)

    @field_validator("class_name")
    @classmethod
    def nonblank_timetable_class(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("className cannot be blank")
        return value

    @model_validator(mode="after")
    def valid_periods(self):
        numbers = [item.period_number for item in self.periods]
        if len(numbers) != len(set(numbers)):
            raise ValueError("Duplicate period number")
        ordered = sorted(self.periods, key=lambda item: item.start_time)
        if any(left.end_time > right.start_time for left, right in zip(ordered, ordered[1:])):
            raise ValueError("Class periods overlap")
        return self


class LoginInput(WireModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1)


class RefreshInput(WireModel):
    refresh_token: str = Field(min_length=1)


class UserInput(WireModel):
    email: str = Field(min_length=3, max_length=320)
    password: str | None = Field(default=None, min_length=8, max_length=200)
    full_name: str = Field(min_length=1, max_length=200)
    phone: str = Field(default="", max_length=40)
    role: Literal["SCHOOL_ADMIN", "TEACHER", "ACCOUNTANT", "TRANSPORT_MANAGER", "STUDENT", "PARENT"]
    linked_entity_id: str | None = None
    extra_permissions: list[str] = Field(default_factory=list)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        value = value.strip().lower()
        if "@" not in value or value.startswith("@") or value.endswith("@"):
            raise ValueError("Valid email required")
        return value

    @field_validator("full_name")
    @classmethod
    def normalize_user_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("fullName cannot be blank")
        return value


class ChangePasswordInput(WireModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=200)


class SchoolInput(WireModel):
    tenant_id: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=200)
    city: str = ""
    board: str = ""
    active: bool = True


class PlatformUserInput(WireModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=200)
    full_name: str = Field(min_length=1, max_length=200)
    phone: str = Field(default="", max_length=40)
    role: Literal["SUPER_ADMIN"]

    @field_validator("email")
    @classmethod
    def normalize_platform_email(cls, value: str) -> str:
        value = value.strip().lower()
        if "@" not in value or value.startswith("@") or value.endswith("@"):
            raise ValueError("Valid email required")
        return value


class StaffInput(WireModel):
    employee_id: str | None = Field(default=None, max_length=64)
    full_name: str = Field(min_length=1, max_length=200)
    email: str = Field(default="", max_length=320)
    phone: str = Field(default="", max_length=40)
    department: str = Field(min_length=1, max_length=80)
    designation: str = Field(min_length=1, max_length=120)
    date_of_joining: date
    date_of_leaving: date | None = None
    basic_salary: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    status: Literal["ACTIVE", "ON_LEAVE", "RESIGNED", "TERMINATED"] = "ACTIVE"
    gender: str = ""
    date_of_birth: date | None = None
    qualification: str = ""
    specialization: str = ""
    bank_account_number: str = ""
    bank_name: str = ""
    pan_number: str = ""
    address: str = ""
    emergency_contact: str = ""
    emergency_contact_name: str = ""
    blood_group: str = ""
    aadhar_number: str = ""
    profile_photo_url: str = ""

    @field_validator("full_name", "department", "designation")
    @classmethod
    def nonblank_staff_field(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Cannot be blank")
        return value


class LeaveInput(WireModel):
    staff_id: str
    leave_type: Literal["CASUAL", "SICK", "EARNED", "MATERNITY", "PATERNITY", "UNPAID", "OTHER"]
    from_date: date
    to_date: date
    reason: str = Field(min_length=1, max_length=1000)

    @model_validator(mode="after")
    def valid_dates(self):
        if self.to_date < self.from_date:
            raise ValueError("toDate must be on or after fromDate")
        return self


class LeaveDecisionInput(WireModel):
    action: Literal["approve", "reject"] = "approve"
    remarks: str = Field(default="", max_length=1000)


class SalaryGenerateInput(WireModel):
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2000, le=2200)


class SalaryPayInput(WireModel):
    payment_mode: str = Field(default="BANK_TRANSFER", min_length=1, max_length=32)
    transaction_ref: str | None = Field(default=None, max_length=120)


class StaffAttendanceInput(WireModel):
    staff_id: str
    date: date
    status: Literal["PRESENT", "ABSENT", "LATE", "HALF_DAY", "ON_LEAVE"]
    check_in_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    check_out_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    remarks: str = Field(default="", max_length=1000)


class TransportRouteInput(WireModel):
    zone_name: str = Field(min_length=1, max_length=120)
    display_name: str = Field(default="", max_length=200)
    areas_covered: str = Field(default="", max_length=1000)
    stops: list[str] = Field(default_factory=list)
    first_pickup_time: str = Field(default="", max_length=40)
    monthly_fee: Decimal = Field(ge=0, max_digits=12, decimal_places=2)

    @field_validator("stops")
    @classmethod
    def valid_stops(cls, value: list[str]) -> list[str]:
        cleaned = [item.strip() for item in value]
        if any(not item or len(item) > 200 for item in cleaned) or len(cleaned) != len(set(cleaned)):
            raise ValueError("Stops must be nonempty and unique")
        return cleaned


class BusInput(WireModel):
    bus_number: str = Field(min_length=1, max_length=80)
    driver_name: str = Field(min_length=1, max_length=200)
    driver_mobile: str = Field(min_length=1, max_length=40)
    route_id: str | None = None
    capacity: int = Field(gt=0)
    status: Literal["ACTIVE", "MAINTENANCE", "RETIRED"] = "ACTIVE"
    insurance_expiry: str | None = Field(default=None, max_length=40)
    notes: str | None = Field(default=None, max_length=1000)


class TransportAssignmentInput(WireModel):
    student_id: str
    bus_id: str
    route_id: str
    pickup_stop: str | None = Field(default=None, max_length=200)


class HomeworkInput(WireModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=4000)
    class_name: str = Field(min_length=1, max_length=80)
    subject: str = Field(min_length=1, max_length=120)
    due_date: date
    assigned_date: date | None = None
    academic_year: str | None = None
    status: Literal["ACTIVE", "ARCHIVED"] = "ACTIVE"

    @field_validator("academic_year")
    @classmethod
    def valid_homework_year(cls, value: str | None) -> str | None:
        return normalize_year(value) if value else None


class IncidentInput(WireModel):
    student_id: str
    severity: Literal["WARNING", "MINOR", "MAJOR", "CRITICAL"]
    category: Literal["BEHAVIORAL", "ACADEMIC", "ATTENDANCE", "BULLYING", "PROPERTY_DAMAGE", "OTHER"]
    description: str = Field(min_length=1, max_length=4000)
    action_taken: str = Field(default="", max_length=2000)
    incident_date: date | None = None
    academic_year: str | None = None

    @field_validator("academic_year")
    @classmethod
    def valid_incident_year(cls, value: str | None) -> str | None:
        return normalize_year(value) if value else None


class IncidentResolutionInput(WireModel):
    resolution: str = Field(min_length=1, max_length=2000)


class CertificateInput(WireModel):
    student_id: str
    certificate_type: Literal["TRANSFER", "BONAFIDE", "CHARACTER", "STUDY", "ID_CARD"]
    reason: str = Field(default="", max_length=1000)
    additional_fields: dict[str, str] = Field(default_factory=dict)


class NotificationInput(WireModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = Field(min_length=1, max_length=4000)
    type: Literal["GENERAL", "FEE_REMINDER", "EXAM", "EVENT", "HOLIDAY", "EMERGENCY"] = "GENERAL"
    target_audience: Literal["ALL", "CLASS_SPECIFIC", "INDIVIDUAL"] = "ALL"
    target_class: str | None = Field(default=None, max_length=80)
    target_student_id: str | None = None
    priority: Literal["LOW", "MEDIUM", "HIGH"] = "MEDIUM"
    expires_at: datetime | None = None

    @model_validator(mode="after")
    def valid_target(self):
        if self.target_audience == "CLASS_SPECIFIC" and not self.target_class:
            raise ValueError("targetClass required for class notification")
        if self.target_audience == "INDIVIDUAL" and not self.target_student_id:
            raise ValueError("targetStudentId required for individual notification")
        return self


class ChatRoomInput(WireModel):
    user_id1: str
    user_id2: str
    student_id: str = ""
    names: dict[str, str] = Field(default_factory=dict)
    roles: dict[str, str] = Field(default_factory=dict)


class ChatMessageInput(WireModel):
    sender_id: str | None = None
    message: str = Field(min_length=1, max_length=4000)
    message_type: Literal["TEXT"] = "TEXT"


class ChatReadInput(WireModel):
    user_id: str | None = None


class AiConfigInput(WireModel):
    enabled: bool = False
    enabled_modes: list[Literal["TUTOR", "SOLVE", "PRACTICE"]] = Field(default_factory=lambda: ["TUTOR"])
    primary_provider: Literal["OLLAMA"] = "OLLAMA"
    fallback_provider: None = None
    ollama_base_url: str = Field(default="http://localhost:11434", min_length=1, max_length=500)
    ollama_model: str = Field(default="llama3", min_length=1, max_length=120)
    gemini_api_key: str | None = None
    claude_api_key: str | None = None
    daily_limit_per_student: int = Field(default=20, ge=1, le=100)
    max_conversation_turns: int = Field(default=30, ge=1, le=100)

    @model_validator(mode="after")
    def supported_provider(self):
        if not self.enabled_modes:
            raise ValueError("At least one AI mode is required")
        if self.gemini_api_key or self.claude_api_key:
            raise ValueError("Cloud AI keys are not supported by this backend")
        return self


class AiChatInput(WireModel):
    homework_id: str | None = None
    conversation_id: str | None = None
    message: str = Field(min_length=1, max_length=2000)
    mode: Literal["TUTOR", "SOLVE", "PRACTICE"] = "TUTOR"
    language: Literal["en", "hi", "hinglish"] = "en"
