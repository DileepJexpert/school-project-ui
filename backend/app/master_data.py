"""Repeatable first-run catalog seed matching the existing school class labels."""

from datetime import date, timedelta
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import school_year_start_month
from app.models import AcademicYearRecord, SchoolClass, SchoolSubject
from app.years import normalize_year

SUBJECTS = (
    "English", "Hindi", "Mathematics", "Science", "Social Studies",
    "Computer Science", "Physical Education", "Art", "Music", "Sanskrit",
    "EVS", "General Knowledge", "Moral Science",
)


def default_classes() -> list[tuple[str, str, str]]:
    result = [(name, name, "A") for name in ("Nursery", "LKG", "UKG")]
    result.extend((f"Class {grade} - {section}", f"Class {grade}", section)
                  for grade in range(1, 13) for section in ("A", "B"))
    return result


def ensure_catalog(session: Session, tenant: str, year: str) -> dict:
    year = normalize_year(year)
    start = int(year[:4])
    month = school_year_start_month()
    start_date = date(start, month, 1)
    end_date = date(start + 1, month, 1) - timedelta(days=1)
    record = session.scalar(select(AcademicYearRecord).where(
        AcademicYearRecord.tenant_id == tenant, AcademicYearRecord.year == year,
    ))
    if record is None:
        session.add(AcademicYearRecord(
            tenant_id=tenant, year=year, start_date=start_date, end_date=end_date,
            status="OPEN",
        ))
    existing_classes = set(session.scalars(select(SchoolClass.class_name).where(SchoolClass.tenant_id == tenant)))
    for order, (name, base, section) in enumerate(default_classes()):
        if name not in existing_classes:
            session.add(SchoolClass(
                tenant_id=tenant, class_name=name, base_class=base, section=section,
                sort_order=order, active=True,
            ))
    existing_subjects = set(session.scalars(select(SchoolSubject.name).where(SchoolSubject.tenant_id == tenant)))
    for order, subject in enumerate(SUBJECTS):
        if subject not in existing_subjects:
            session.add(SchoolSubject(tenant_id=tenant, name=subject, sort_order=order, active=True))
    return {"year": year, "classes": len(default_classes()), "subjects": len(SUBJECTS)}
