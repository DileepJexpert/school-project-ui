import os


def database_url() -> str:
    return os.getenv(
        "DATABASE_URL", "postgresql+psycopg://school:local-only@localhost:5432/school"
    )


def school_year_start_month() -> int:
    raw = os.getenv("SCHOOL_YEAR_START_MONTH", "4").strip()
    month = int(raw)
    if not 1 <= month <= 12:
        raise ValueError("SCHOOL_YEAR_START_MONTH must be between 1 and 12")
    return month


def video_storage_dir() -> str:
    return os.getenv("VIDEO_STORAGE_DIR", "./data/videos")
