from decimal import Decimal
from datetime import timezone

from app.models import FeeProfile, FeeStructure, Payment, Student


def student_wire(student: Student) -> dict:
    return {
        "id": student.id,
        "fullName": student.full_name,
        "dateOfBirth": student.date_of_birth.isoformat(),
        "gender": student.gender,
        "bloodGroup": student.blood_group,
        "nationality": student.nationality,
        "religion": student.religion,
        "motherTongue": student.mother_tongue,
        "aadharNumber": student.aadhar_number,
        "classForAdmission": student.class_name,
        "academicYear": student.academic_year,
        "dateOfAdmission": student.date_of_admission.isoformat(),
        "admissionNumber": student.admission_number or "",
        "rollNumber": student.roll_number,
        "status": student.status,
        "parentDetails": student.parent_details,
        "contactDetails": student.contact_details,
        "previousSchoolDetails": student.previous_school_details,
    }


def money(value: Decimal) -> float:
    return float(value)


def structure_wire(structure: FeeStructure) -> dict:
    return {
        "id": structure.id,
        "className": structure.class_name,
        "academicYear": structure.academic_year,
        "feeComponents": [
            {
                "feeName": component.name,
                "amount": money(component.amount),
                "frequency": component.frequency,
                "description": component.description,
            }
            for component in structure.components
        ],
    }


def profile_wire(profile: FeeProfile, student: Student) -> dict:
    total = sum((item.amount_due for item in profile.installments), Decimal("0.00"))
    paid = sum((item.paid_amount for item in profile.installments), Decimal("0.00"))
    discounted = sum((item.discount_amount for item in profile.installments), Decimal("0.00"))
    last_payment = max(
        (item for item in profile.payments if item.voided_at is None),
        key=lambda item: (item.payment_date, item.id), default=None,
    )
    parent = student.parent_details or {}
    return {
        "id": student.id,
        "name": student.full_name,
        "className": profile.enrollment.class_name,
        "academicYear": profile.enrollment.academic_year,
        "rollNumber": profile.enrollment.roll_number or "",
        "parentName": parent.get("fatherName") or parent.get("motherName") or "",
        "feeInstallments": [
            {
                "installmentName": item.name,
                "amountDue": money(item.amount_due - item.paid_amount - item.discount_amount),
                "status": item.status,
            }
            for item in profile.installments
        ],
        "lastPayment": payment_wire(last_payment, student) if last_payment else None,
        "totalFees": money(total),
        "paidFees": money(paid),
        "dueFees": money(total - paid - discounted),
        "totalDiscountGiven": money(discounted),
    }


def payment_wire(payment: Payment, student: Student) -> dict:
    payment_date = payment.payment_date
    if payment_date.tzinfo is None:
        payment_date = payment_date.replace(tzinfo=timezone.utc)
    voided_at = payment.voided_at
    if voided_at is not None and voided_at.tzinfo is None:
        voided_at = voided_at.replace(tzinfo=timezone.utc)
    return {
        "id": payment.id,
        "transactionId": payment.id,
        "receiptNumber": payment.receipt_number,
        "studentId": student.id,
        "studentName": payment.student_name_snapshot or student.full_name,
        "academicYear": payment.profile.enrollment.academic_year,
        "paymentDate": payment_date.isoformat(),
        "amountPaid": money(payment.amount_paid),
        "discount": money(payment.discount),
        "paymentMode": payment.payment_mode,
        "paidForInstallments": [item.installment.name for item in payment.allocations],
        "remarks": payment.remarks,
        "reference": payment.transaction_reference,
        "collectedByUserId": payment.collected_by_user_id,
        "status": "VOIDED" if payment.voided_at is not None else "POSTED",
        "voidedAt": voided_at.isoformat() if voided_at else None,
        "voidReason": payment.void_reason,
        "voidedByUserId": payment.voided_by_user_id,
    }
