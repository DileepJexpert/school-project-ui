import re
from datetime import date

from app.config import school_year_start_month


def normalize_year(value: str) -> str:
    match = re.fullmatch(r"(\d{4})-(\d{2}|\d{4})", value.strip())
    if not match:
        raise ValueError("academicYear must be YYYY-YYYY or YYYY-YY")
    start = int(match.group(1))
    suffix = int(match.group(2))
    expected = (start + 1) % 100 if len(match.group(2)) == 2 else start + 1
    if suffix != expected:
        raise ValueError("academicYear must contain consecutive years")
    return f"{start}-{start + 1}"


def academic_year_for_date(value: date) -> str:
    start = value.year if value.month >= school_year_start_month() else value.year - 1
    return f"{start}-{start + 1}"
