import os
from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.access import authorize_request
from app.db import engine
from app.routers import ai, attendance, auth, chat, expenses, fees, hr, master_data, notifications, payments, platform, portals, public, reports, results, rollover, school_profile, school_workflows, site_content, students, timetable, transport, users, videos

app = FastAPI(title="School API (migration preview)", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[item.strip() for item in os.getenv("CORS_ORIGINS", "").split(",") if item.strip()],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Tenant-ID", "Idempotency-Key"],
)
app.middleware("http")(authorize_request)
app.include_router(auth.router)
app.include_router(public.router)
app.include_router(site_content.router)
app.include_router(school_profile.router)
app.include_router(users.router, prefix="/api")
app.include_router(platform.router)
app.include_router(portals.student_router, prefix="/api")
app.include_router(portals.parent_router, prefix="/api")
app.include_router(students.router, prefix="/api")
app.include_router(fees.router, prefix="/api")
app.include_router(payments.router, prefix="/api")
app.include_router(rollover.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(expenses.router, prefix="/api")
app.include_router(attendance.router, prefix="/api")
app.include_router(results.router, prefix="/api")
app.include_router(timetable.router, prefix="/api")
app.include_router(hr.staff_router, prefix="/api")
app.include_router(hr.leave_router, prefix="/api")
app.include_router(hr.salary_router, prefix="/api")
app.include_router(hr.attendance_router, prefix="/api")
app.include_router(transport.router, prefix="/api")
app.include_router(school_workflows.homework_router, prefix="/api")
app.include_router(school_workflows.student_homework_router, prefix="/api")
app.include_router(school_workflows.incident_router, prefix="/api")
app.include_router(school_workflows.certificate_router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(videos.router, prefix="/api")
app.include_router(videos.student_router, prefix="/api")
app.include_router(master_data.router, prefix="/api")
app.include_router(ai.config_router, prefix="/api")
app.include_router(ai.chat_router, prefix="/api")


@app.get("/health/live")
def live() -> dict:
    return {"status": "ok"}


@app.get("/health/ready")
def ready() -> dict:
    config = Config()
    config.set_main_option("script_location", str(Path(__file__).resolve().parents[1] / "migrations"))
    expected = ScriptDirectory.from_config(config).get_current_head()
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            installed = connection.execute(text("SELECT version_num FROM alembic_version")).scalars().all()
    except SQLAlchemyError as error:
        raise HTTPException(status_code=503, detail="Database or schema unavailable") from error
    if installed != [expected]:
        raise HTTPException(status_code=503, detail="Database migration is not at the required revision")
    return {"status": "ready"}
