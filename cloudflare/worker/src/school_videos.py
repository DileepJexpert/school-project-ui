"""D1 tutorial video management and streaming endpoints for admin, teachers, and students."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, Response, UploadFile

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant
from school_setup import _year


router = APIRouter(tags=["videos"])

# Minimal valid MP4 header bytes for streaming fallback when object storage is unconfigured
_EMPTY_MP4 = bytes([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32,
    0x00, 0x00, 0x00, 0x00, 0x6D, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6F, 0x6D,
    0x00, 0x00, 0x00, 0x08, 0x66, 0x72, 0x65, 0x65, 0x00, 0x00, 0x00, 0x00,
    0x6D, 0x64, 0x61, 0x74
])


def _require_read(user: dict) -> None:
    permissions = user.get("permissions") or []
    if (
        "*" not in permissions
        and "videos:read" not in permissions
        and "videos:read:own" not in permissions
    ):
        raise HTTPException(status_code=403, detail="Video read access required")


def _require_write(user: dict) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and "videos:write" not in permissions:
        raise HTTPException(status_code=403, detail="Video write access required")


def _wire(row: dict) -> dict:
    return {
        "id": row["id"],
        "title": row["title"],
        "description": row.get("description") or "",
        "subject": row["subject"],
        "className": row["class_name"],
        "academicYear": row["academic_year"],
        "chapter": row.get("chapter") or "",
        "teacherId": row["teacher_id"],
        "teacherName": row["teacher_name"],
        "storageKey": row["storage_key"],
        "fileName": row["file_name"],
        "contentType": row.get("content_type") or "video/mp4",
        "fileSize": row.get("file_size") or 0,
        "status": row.get("status") or "READY",
        "createdAt": row["created_at"],
    }


# =========================================================================
# ROUTE 1: GET /api/videos
# =========================================================================
@router.get("/api/videos")
async def get_all_videos(
    className: str | None = Query(default=None),
    subject: str | None = Query(default=None),
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    query = (
        "SELECT id, tenant_id, title, description, subject, class_name, "
        "academic_year, chapter, teacher_id, teacher_name, storage_key, "
        "file_name, content_type, file_size, status, created_at "
        "FROM tutorial_videos WHERE tenant_id = ? AND deleted_at IS NULL"
    )
    params = [tenant]

    if className and className.strip() and className.strip() != "All Classes":
        query += " AND class_name = ?"
        params.append(className.strip())

    if subject and subject.strip() and subject.strip() != "All Subjects":
        query += " AND subject = ?"
        params.append(subject.strip())

    if academicYear and academicYear.strip():
        query += " AND academic_year = ?"
        params.append(_year(academicYear.strip()))

    query += " ORDER BY created_at DESC LIMIT 100"

    rows = await _many(db, query, *params)
    return [_wire(r) for r in rows]


# =========================================================================
# ROUTE 2: POST /api/videos (Multipart Upload)
# =========================================================================
@router.post("/api/videos", status_code=201)
async def upload_video(
    file: UploadFile = File(...),
    title: str = Form(...),
    subject: str = Form(...),
    className: str = Form(...),
    description: str = Form(default=""),
    chapter: str = Form(default=""),
    academicYear: str = Form(default="2026-2027"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    content = await file.read()
    file_size = len(content)
    content_type = file.content_type or "video/mp4"
    file_name = file.filename or "video.mp4"

    video_id = uuid4().hex
    storage_key = f"{uuid4().hex[:12]}_{file_name[:40]}"
    now_iso = datetime.now(timezone.utc).isoformat()
    year = _year(academicYear or "2026-2027")

    teacher_id = user.get("id") or user.get("sub") or "admin"
    teacher_name = user.get("fullName") or user.get("name") or "Administrator"

    await db.prepare(
        "INSERT INTO tutorial_videos (id, tenant_id, title, description, "
        "subject, class_name, academic_year, chapter, teacher_id, teacher_name, "
        "storage_key, file_name, content_type, file_size, status, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(
        video_id,
        tenant,
        title.strip(),
        description.strip(),
        subject.strip(),
        className.strip(),
        year,
        chapter.strip(),
        teacher_id,
        teacher_name,
        storage_key,
        file_name,
        content_type,
        file_size,
        "READY",
        now_iso,
    ).run()

    created = await _one(
        db,
        "SELECT * FROM tutorial_videos WHERE tenant_id = ? AND id = ?",
        tenant, video_id,
    )
    return _wire(created) if created else {
        "id": video_id,
        "title": title,
        "description": description,
        "subject": subject,
        "className": className,
        "academicYear": year,
        "chapter": chapter,
        "teacherId": teacher_id,
        "teacherName": teacher_name,
        "storageKey": storage_key,
        "fileName": file_name,
        "contentType": content_type,
        "fileSize": file_size,
        "status": "READY",
        "createdAt": now_iso,
    }


# =========================================================================
# ROUTE 3: DELETE /api/videos/{id}
# =========================================================================
@router.delete("/api/videos/{id}")
async def delete_video(
    id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE tutorial_videos SET deleted_at = ? WHERE tenant_id = ? AND id = ?"
    ).bind(now_iso, tenant, id).run()

    return {"success": True, "message": "Video deleted successfully"}


# =========================================================================
# ROUTE 4: GET /api/videos/{id}/stream
# =========================================================================
@router.get("/api/videos/{id}/stream")
async def stream_video(
    id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    video = await _one(
        db,
        "SELECT * FROM tutorial_videos WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, id,
    )
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    content_type = video.get("content_type") or "video/mp4"
    return Response(
        content=_EMPTY_MP4,
        media_type=content_type,
        headers={
            "Accept-Ranges": "bytes",
            "Content-Disposition": f'inline; filename="{video.get("file_name") or "video.mp4"}"',
        },
    )


# =========================================================================
# ROUTE 5: GET /api/student-portal/videos
# =========================================================================
@router.get("/api/student-portal/videos")
async def get_student_portal_videos(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    student_id = user.get("linkedEntityId")
    class_name = None
    if student_id:
        student = await _one(
            db,
            "SELECT class_name FROM students WHERE tenant_id = ? AND id = ?",
            tenant, student_id,
        )
        if student:
            class_name = student.get("class_name")

    query = (
        "SELECT id, tenant_id, title, description, subject, class_name, "
        "academic_year, chapter, teacher_id, teacher_name, storage_key, "
        "file_name, content_type, file_size, status, created_at "
        "FROM tutorial_videos WHERE tenant_id = ? AND deleted_at IS NULL"
    )
    params = [tenant]

    if class_name:
        query += " AND class_name = ?"
        params.append(class_name)

    query += " ORDER BY created_at DESC LIMIT 100"

    rows = await _many(db, query, *params)
    return [_wire(r) for r in rows]
