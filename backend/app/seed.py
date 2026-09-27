"""Repeatable first-run school, admin and catalogue setup."""

import argparse
import getpass
import json
from datetime import date, datetime, timezone
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import password_hash
from app.db import SessionLocal
from app.master_data import ensure_catalog
from app.models import AcademicYearRecord, ClassSubject, FeeComponent, FeeStructure, SchoolClass, SchoolSiteContent, SchoolSubject, Tenant, User
from app.schemas import ClassSubjectsInput, FeeStructureInput, GradingPolicyInput
from app.routers.site_content import SiteContentInput
from app.years import academic_year_for_date


def bootstrap_school(
    session: Session, tenant_id: str, name: str, year: str, *, city: str = "", board: str = "",
    admin_email: str | None = None, admin_name: str = "School Admin",
    admin_password: str | None = None, fee_structures: list[FeeStructureInput] | None = None,
    grading_policy: GradingPolicyInput | None = None,
    class_subjects: list[ClassSubjectsInput] | None = None,
    additional_subjects: list[str] | None = None,
    site_content: dict | None = None,
) -> dict:
    tenant_id = tenant_id.strip().lower()
    if not tenant_id or len(tenant_id) > 64 or not name.strip():
        raise ValueError("School code and name are required")
    school = session.get(Tenant, tenant_id)
    if school is None:
        school = Tenant(id=tenant_id, name=name.strip(), city=city.strip(), board=board.strip(), active=True)
        session.add(school)
        session.flush()
    else:
        school.name = name.strip()
        if city:
            school.city = city.strip()
        if board:
            school.board = board.strip()
    catalogue = ensure_catalog(session, tenant_id, year)
    if site_content is not None:
        validated = SiteContentInput(content=site_content).content
        existing_site = session.get(SchoolSiteContent, tenant_id)
        if existing_site is not None and existing_site.content != validated:
            raise ValueError("Existing website content differs; use the admin API to edit it")
        if existing_site is None:
            session.add(SchoolSiteContent(
                tenant_id=tenant_id, content=validated,
                updated_at=datetime.now(timezone.utc),
            ))
    year_record = session.scalar(select(AcademicYearRecord).where(
        AcademicYearRecord.tenant_id == tenant_id,
        AcademicYearRecord.year == catalogue["year"],
    ))
    if grading_policy is not None:
        if grading_policy.academic_year != catalogue["year"]:
            raise ValueError(f"Grading policy year must match {catalogue['year']}")
        requested_bands = [item.model_dump(mode="json", by_alias=True) for item in grading_policy.bands]
        if year_record.grade_bands is not None and (
            year_record.grade_bands != requested_bands
            or year_record.pass_percentage != grading_policy.pass_percentage
            or year_record.exam_order != grading_policy.exam_order
        ):
            raise ValueError("Existing grading policy differs; use the admin API before publishing results")
        year_record.grade_bands = requested_bands
        year_record.pass_percentage = grading_policy.pass_percentage
        year_record.exam_order = grading_policy.exam_order
    if admin_email:
        email = admin_email.strip().lower()
        if "@" not in email:
            raise ValueError("Valid admin email required")
        existing = session.scalar(select(User).where(User.scope == tenant_id, User.email == email))
        if existing is None:
            if not admin_password or len(admin_password) < 8:
                raise ValueError("Initial admin password must have at least 8 characters")
            session.add(User(
                scope=tenant_id, tenant_id=tenant_id, email=email,
                password_hash=password_hash(admin_password), full_name=admin_name.strip(),
                phone="", role="SCHOOL_ADMIN", linked_entity_id=None,
                extra_permissions=[], active=True, created_at=datetime.now(timezone.utc),
            ))
        elif existing.role != "SCHOOL_ADMIN":
            raise ValueError("Admin email belongs to another role")

    configured = 0
    for data in fee_structures or []:
        if data.academic_year != catalogue["year"]:
            raise ValueError(f"Fee structure year must match {catalogue['year']}")
        if session.scalar(select(SchoolClass.id).where(
            SchoolClass.tenant_id == tenant_id, SchoolClass.class_name == data.class_name,
        )) is None:
            raise ValueError(f"Unknown class in fee structure: {data.class_name}")
        structure = session.scalar(select(FeeStructure).where(
            FeeStructure.tenant_id == tenant_id,
            FeeStructure.class_name == data.class_name,
            FeeStructure.academic_year == data.academic_year,
        ))
        requested = [(item.fee_name, item.amount, item.frequency, item.description) for item in data.fee_components]
        if structure is not None:
            current = [(item.name, item.amount, item.frequency, item.description) for item in structure.components]
            if current != requested:
                raise ValueError(f"Existing fee structure differs: {data.class_name} {data.academic_year}")
        else:
            structure = FeeStructure(
                tenant_id=tenant_id, class_name=data.class_name,
                academic_year=data.academic_year,
            )
            structure.components = [FeeComponent(
                position=index, name=item.fee_name, amount=item.amount,
                frequency=item.frequency, description=item.description,
            ) for index, item in enumerate(data.fee_components)]
            session.add(structure)
        configured += 1
    existing_subject_names = {item.lower() for item in session.scalars(select(SchoolSubject.name).where(
        SchoolSubject.tenant_id == tenant_id,
    ))}
    next_subject_order = session.scalar(select(func.max(SchoolSubject.sort_order)).where(
        SchoolSubject.tenant_id == tenant_id,
    )) or 0
    for raw_name in additional_subjects or []:
        name = raw_name.strip()
        if not name or len(name) > 120:
            raise ValueError("Additional subject names must be 1–120 characters")
        if name.lower() not in existing_subject_names:
            next_subject_order += 1
            session.add(SchoolSubject(
                tenant_id=tenant_id, name=name, sort_order=next_subject_order, active=True,
            ))
            existing_subject_names.add(name.lower())
    session.flush()
    subject_sets = 0
    for data in class_subjects or []:
        if data.academic_year != catalogue["year"]:
            raise ValueError(f"Class subjects year must match {catalogue['year']}")
        if session.scalar(select(SchoolClass.id).where(
            SchoolClass.tenant_id == tenant_id, SchoolClass.class_name == data.class_name,
        )) is None:
            raise ValueError(f"Unknown class in subject assignment: {data.class_name}")
        known_subjects = set(session.scalars(select(SchoolSubject.name).where(
            SchoolSubject.tenant_id == tenant_id,
        )))
        if not set(data.subjects).issubset(known_subjects):
            raise ValueError(f"Unknown subject in {data.class_name} assignment")
        existing_subjects = set(session.scalars(select(ClassSubject.subject_name).where(
            ClassSubject.tenant_id == tenant_id, ClassSubject.class_name == data.class_name,
            ClassSubject.academic_year == data.academic_year,
        )))
        if existing_subjects and existing_subjects != set(data.subjects):
            raise ValueError(f"Existing class subjects differ: {data.class_name} {data.academic_year}")
        if not existing_subjects:
            session.add_all(ClassSubject(
                tenant_id=tenant_id, class_name=data.class_name,
                academic_year=data.academic_year, subject_name=subject,
            ) for subject in data.subjects)
        subject_sets += 1
    session.flush()
    total_subjects = session.scalar(select(func.count()).select_from(SchoolSubject).where(
        SchoolSubject.tenant_id == tenant_id,
    ))
    return {"tenantId": tenant_id, "academicYear": catalogue["year"],
            "classes": catalogue["classes"], "subjects": total_subjects,
            "feeStructures": configured,
            "additionalSubjects": len(additional_subjects or []),
            "classSubjectSets": subject_sets,
            "gradingPolicyConfigured": grading_policy is not None or year_record.grade_bands is not None}


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap school, admin and first-year master data")
    parser.add_argument("id", help="School code used in X-Tenant-ID")
    parser.add_argument("name", help="School display name")
    parser.add_argument("--city", default="")
    parser.add_argument("--board", default="")
    parser.add_argument("--year", default=academic_year_for_date(date.today()), help="Academic year, e.g. 2026-2027")
    parser.add_argument("--admin-email", help="Create a first SCHOOL_ADMIN account")
    parser.add_argument("--admin-name", default="School Admin")
    parser.add_argument("--fees-file", type=Path, help="JSON fee structures and grading policy with real school values")
    args = parser.parse_args()

    fee_structures = None
    grading_policy = None
    class_subjects = None
    additional_subjects = None
    site_content = None
    if args.fees_file:
        try:
            contents = json.loads(args.fees_file.read_text(encoding="utf-8"))
            fee_structures = [FeeStructureInput.model_validate(item) for item in contents.get("feeStructures", [])]
            class_subjects = [ClassSubjectsInput.model_validate(item) for item in contents.get("classSubjects", [])]
            additional_subjects = contents.get("additionalSubjects", [])
            site_content = contents.get("siteContent")
            if not isinstance(additional_subjects, list) or any(not isinstance(item, str) for item in additional_subjects):
                raise ValueError("additionalSubjects must be a list of names")
            if contents.get("gradingPolicy") is not None:
                grading_policy = GradingPolicyInput.model_validate(contents["gradingPolicy"])
        except (OSError, ValueError, KeyError, TypeError) as error:
            parser.error(f"Invalid fees file: {error}")

    password = None
    if args.admin_email:
        with SessionLocal() as session:
            existing = session.scalar(select(User.id).where(
                User.scope == args.id.strip().lower(), User.email == args.admin_email.strip().lower(),
            ))
        if existing is None:
            password = getpass.getpass("Initial school admin password: ")
    try:
        with SessionLocal.begin() as session:
            result = bootstrap_school(
                session, args.id, args.name, args.year, city=args.city, board=args.board,
                admin_email=args.admin_email, admin_name=args.admin_name,
                admin_password=password, fee_structures=fee_structures,
                grading_policy=grading_policy, class_subjects=class_subjects,
                additional_subjects=additional_subjects,
                site_content=site_content,
            )
    except ValueError as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
