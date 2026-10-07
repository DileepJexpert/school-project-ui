"""Certificate management endpoints for CBSE/State Board school certificates (TC, Bonafide, Character, Study)."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _record, _tenant

router = APIRouter(prefix="/api/certificates", tags=["certificates"])
root_router = APIRouter(prefix="/certificates", tags=["certificates_root"])


def _wire_certificate(row: dict) -> dict:
    additional = {}
    if row.get("additional_fields"):
        try:
            additional = json.loads(row["additional_fields"])
        except Exception:
            additional = {}
    return {
        "id": row["id"],
        "studentId": row["student_id"],
        "studentName": row["student_name"],
        "className": row["class_name"],
        "academicYear": row["academic_year"],
        "certificateType": (row.get("certificate_type") or "BONAFIDE").upper(),
        "serialNumber": row["serial_number"],
        "reason": row.get("reason") or "",
        "generatedBy": row.get("generated_by") or "Administrator",
        "generatedAt": row.get("generated_at") or "",
        "fatherName": additional.get("fatherName") or "",
        "admissionNumber": additional.get("admissionNumber") or "",
        "additionalFields": additional,
    }


class GenerateCertificateInput(BaseModel):
    studentId: str = Field(min_length=1, max_length=100)
    certificateType: str = Field(default="BONAFIDE", max_length=40)
    reason: str = Field(default="", max_length=1000)
    additionalFields: dict | None = Field(default_factory=dict)


async def _handle_list_certificates(
    type: str | None = Query(default=None),
    student_id: str | None = Query(default=None),
    search: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    query = "SELECT * FROM certificate_records WHERE tenant_id = ?"
    params = [tenant]

    if type and type.strip().upper() != "ALL":
        query += " AND UPPER(certificate_type) = ?"
        params.append(type.strip().upper())

    if student_id and student_id.strip():
        query += " AND student_id = ?"
        params.append(student_id.strip())

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query += " AND (LOWER(student_name) LIKE ? OR LOWER(serial_number) LIKE ? OR LOWER(reason) LIKE ?)"
        params.extend([term, term, term])

    query += " ORDER BY generated_at DESC"
    rows = await _many(db, query, *params)
    return [_wire_certificate(r) for r in rows]


async def _handle_generate_certificate(
    data: GenerateCertificateInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    target_student_id = data.studentId.strip()
    cert_type = (data.certificateType or "BONAFIDE").strip().upper()
    valid_types = {"TRANSFER", "BONAFIDE", "CHARACTER", "STUDY"}
    if cert_type not in valid_types:
        cert_type = "BONAFIDE"

    # Lookup student in database
    student = await _one(
        db,
        "SELECT id, full_name, class_name, academic_year, admission_number, parent_details "
        "FROM students WHERE tenant_id = ? AND (id = ? OR admission_number = ?)",
        tenant, target_student_id, target_student_id,
    )
    if not student:
        raise HTTPException(
            status_code=404,
            detail=f"Student with ID or Admission Number '{target_student_id}' not found.",
        )

    parent_details = {}
    if student.get("parent_details"):
        try:
            parent_details = json.loads(student["parent_details"])
        except Exception:
            parent_details = {}

    father_name = parent_details.get("fatherName") or parent_details.get("father_name") or ""
    admission_number = student.get("admission_number") or ""

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    now_date_str = now.strftime("%d %b %Y")
    current_year = now.year

    # Prefix mapping
    prefixes = {
        "TRANSFER": "TC",
        "BONAFIDE": "BON",
        "CHARACTER": "CHR",
        "STUDY": "STU",
    }
    type_prefix = prefixes.get(cert_type, "CERT")

    # Generate sequential serial number for tenant and year
    count_row = await _one(
        db,
        "SELECT COUNT(*) AS total FROM certificate_records WHERE tenant_id = ? AND certificate_type = ?",
        tenant, cert_type,
    )
    seq_num = (count_row.get("total") or 0) + 1
    serial_number = f"{type_prefix}-{current_year}-{seq_num:04d}"

    cert_id = f"cert_{uuid.uuid4().hex[:16]}"
    generated_by = user.get("fullName") or user.get("email") or "School Administrator"

    additional = data.additionalFields or {}
    additional["fatherName"] = father_name
    additional["admissionNumber"] = admission_number
    additional["dateFormatted"] = now_date_str

    await db.prepare(
        "INSERT INTO certificate_records ("
        "id, tenant_id, student_id, student_name, class_name, academic_year, "
        "certificate_type, serial_number, reason, additional_fields, generated_by, generated_at"
        ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(
        cert_id,
        tenant,
        student["id"],
        student["full_name"],
        student.get("class_name") or "General",
        student.get("academic_year") or f"{current_year}-{current_year + 1}",
        cert_type,
        serial_number,
        data.reason.strip() or "Standard Request",
        json.dumps(additional),
        generated_by,
        now_iso,
    ).run()

    created_row = await _one(
        db,
        "SELECT * FROM certificate_records WHERE id = ? AND tenant_id = ?",
        cert_id, tenant,
    )
    return _wire_certificate(created_row)


async def _handle_get_student_certificates(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT * FROM certificate_records WHERE tenant_id = ? AND student_id = ? ORDER BY generated_at DESC",
        tenant, student_id.strip(),
    )
    return [_wire_certificate(r) for r in rows]


async def _handle_get_type_certificates(
    cert_type: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT * FROM certificate_records WHERE tenant_id = ? AND UPPER(certificate_type) = ? ORDER BY generated_at DESC",
        tenant, cert_type.strip().upper(),
    )
    return [_wire_certificate(r) for r in rows]


async def _handle_get_certificate_by_id(
    certificate_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    row = await _one(
        db,
        "SELECT * FROM certificate_records WHERE tenant_id = ? AND id = ?",
        tenant, certificate_id.strip(),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Certificate not found")
    return _wire_certificate(row)


async def _handle_delete_certificate(
    certificate_id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    existing = await _one(
        db,
        "SELECT id FROM certificate_records WHERE tenant_id = ? AND id = ?",
        tenant, certificate_id.strip(),
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Certificate not found")
    await db.prepare(
        "DELETE FROM certificate_records WHERE tenant_id = ? AND id = ?"
    ).bind(tenant, certificate_id.strip()).run()
    return {"message": "Certificate deleted successfully"}


# Register on prefix router (/api/certificates)
router.add_api_route("", _handle_list_certificates, methods=["GET"])
router.add_api_route("/generate", _handle_generate_certificate, methods=["POST"])
router.add_api_route("/student/{student_id}", _handle_get_student_certificates, methods=["GET"])
router.add_api_route("/type/{cert_type}", _handle_get_type_certificates, methods=["GET"])
router.add_api_route("/{certificate_id}", _handle_get_certificate_by_id, methods=["GET"])
router.add_api_route("/{certificate_id}", _handle_delete_certificate, methods=["DELETE"])

# Register on root router (/certificates)
root_router.add_api_route("", _handle_list_certificates, methods=["GET"])
root_router.add_api_route("/generate", _handle_generate_certificate, methods=["POST"])
root_router.add_api_route("/student/{student_id}", _handle_get_student_certificates, methods=["GET"])
root_router.add_api_route("/type/{cert_type}", _handle_get_type_certificates, methods=["GET"])
root_router.add_api_route("/{certificate_id}", _handle_get_certificate_by_id, methods=["GET"])
root_router.add_api_route("/{certificate_id}", _handle_delete_certificate, methods=["DELETE"])
