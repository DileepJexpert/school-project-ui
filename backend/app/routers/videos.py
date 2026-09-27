"""Video metadata and bounded local-volume uploads/streams."""

import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, Response, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.admissions import require_open_class_year
from app.auth import aware
from app.config import video_storage_dir
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Student, TutorialVideo, User
from app.years import academic_year_for_date

router = APIRouter(prefix="/videos", tags=["videos"])
student_router = APIRouter(prefix="/student-portal", tags=["student-portal"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]
MAX_VIDEO_BYTES = 250 * 1024 * 1024


def _video(session: Session, tenant: str, video_id: str) -> TutorialVideo:
    item = session.get(TutorialVideo, video_id)
    if item is None or item.tenant_id != tenant or item.deleted_at:
        raise HTTPException(status_code=404, detail="Video not found")
    return item


def _check_viewer(session: Session, request: Request, item: TutorialVideo) -> None:
    if request.state.user_role not in ("STUDENT", "PARENT"):
        return
    user = session.get(User, request.state.user_id)
    ids = {part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()}
    if not any((student := session.get(Student, student_id)) and student.tenant_id == item.tenant_id and student.class_name == item.class_name and student.academic_year == item.academic_year for student_id in ids):
        raise HTTPException(status_code=403, detail="Video not assigned to linked student")


def _wire(item: TutorialVideo) -> dict:
    return {
        "id": item.id, "title": item.title, "description": item.description,
        "subject": item.subject, "className": item.class_name,
        "academicYear": item.academic_year, "chapter": item.chapter,
        "teacherId": item.teacher_id, "teacherName": item.teacher_name,
        "gridFsFileId": None, "fileName": item.file_name,
        "contentType": item.content_type, "fileSize": item.file_size,
        "status": item.status, "createdAt": aware(item.created_at).isoformat(),
    }


@router.get("")
def videos(
    session: Db, tenant: TenantId,
    class_name: str | None = Query(default=None, alias="className"),
    subject: str | None = None,
) -> list[dict]:
    require_tenant(session, tenant)
    query = select(TutorialVideo).where(TutorialVideo.tenant_id == tenant, TutorialVideo.deleted_at.is_(None))
    if class_name:
        query = query.where(TutorialVideo.class_name == class_name)
    if subject:
        query = query.where(TutorialVideo.subject == subject)
    return [_wire(item) for item in session.scalars(query.order_by(TutorialVideo.created_at.desc()))]


@student_router.get("/videos")
def student_videos(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    user = session.get(User, request.state.user_id)
    if user.role != "STUDENT" or not user.linked_entity_id:
        raise HTTPException(status_code=403, detail="Linked student required")
    student = session.get(Student, user.linked_entity_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    return [_wire(item) for item in session.scalars(select(TutorialVideo).where(
        TutorialVideo.tenant_id == tenant, TutorialVideo.class_name == student.class_name,
        TutorialVideo.academic_year == student.academic_year, TutorialVideo.status == "ACTIVE",
        TutorialVideo.deleted_at.is_(None),
    ).order_by(TutorialVideo.created_at.desc()))]


@router.get("/{video_id}")
def get_video(video_id: str, request: Request, session: Db, tenant: TenantId) -> dict:
    item = _video(session, tenant, video_id)
    _check_viewer(session, request, item)
    return _wire(item)


@router.get("/{video_id}/stream", response_model=None)
def stream_video(video_id: str, request: Request, session: Db, tenant: TenantId) -> FileResponse:
    item = _video(session, tenant, video_id)
    _check_viewer(session, request, item)
    path = Path(video_storage_dir()).resolve() / item.storage_key
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Video file missing from storage")
    return FileResponse(path, media_type=item.content_type, filename=item.file_name, content_disposition_type="inline")


@router.post("", status_code=201)
async def upload_video(
    request: Request, session: Db, tenant: TenantId,
    file: UploadFile = File(...), title: str = Form(...), subject: str = Form(...),
    class_name: str = Form(..., alias="className"), description: str = Form(""),
    chapter: str = Form(""),
) -> dict:
    if not title.strip() or not subject.strip() or not class_name.strip() or any(len(value) > limit for value, limit in ((title, 200), (subject, 120), (class_name, 80), (description, 4000), (chapter, 200))):
        raise HTTPException(status_code=422, detail="Invalid video metadata")
    storage = Path(video_storage_dir()).resolve()
    storage.mkdir(parents=True, exist_ok=True)
    storage_key = f"{uuid.uuid4().hex}.video"
    temporary = storage / f".{storage_key}.upload"
    final = storage / storage_key
    size = 0
    try:
        with temporary.open("xb") as target:
            first = await file.read(1024 * 1024)
            if first[4:8] == b"ftyp":
                media_type = "video/mp4"
            elif first[:4] == b"\x1aE\xdf\xa3":
                media_type = "video/webm"
            else:
                raise HTTPException(status_code=422, detail="Only MP4 or WebM video supported")
            chunk = first
            while chunk:
                size += len(chunk)
                if size > MAX_VIDEO_BYTES:
                    raise HTTPException(status_code=413, detail="Video exceeds 250 MB limit")
                target.write(chunk)
                chunk = await file.read(1024 * 1024)
        original_name = Path((file.filename or "video").replace("\\", "/")).name[:255]
        with session.begin():
            lock_tenant(session, tenant)
            year = academic_year_for_date(datetime.now(timezone.utc).date())
            require_open_class_year(session, tenant, class_name.strip(), year)
            user = session.get(User, request.state.user_id)
            os.replace(temporary, final)
            item = TutorialVideo(
                tenant_id=tenant, title=title.strip(), description=description,
                subject=subject.strip(), class_name=class_name.strip(), academic_year=year,
                chapter=chapter, teacher_id=user.id, teacher_name=user.full_name,
                storage_key=storage_key, file_name=original_name, content_type=media_type,
                file_size=size, status="ACTIVE", created_at=datetime.now(timezone.utc),
            )
            session.add(item)
            session.flush()
            result = _wire(item)
        return result
    except BaseException:
        temporary.unlink(missing_ok=True)
        final.unlink(missing_ok=True)
        raise
    finally:
        await file.close()


@router.delete("/{video_id}", status_code=204)
def delete_video(video_id: str, request: Request, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = _video(session, tenant, video_id)
        if request.state.user_role == "TEACHER" and item.teacher_id != request.state.user_id:
            raise HTTPException(status_code=403, detail="Can delete only own video")
        item.deleted_at = datetime.now(timezone.utc)
        storage_key = item.storage_key
    (Path(video_storage_dir()).resolve() / storage_key).unlink(missing_ok=True)
    return Response(status_code=204)
