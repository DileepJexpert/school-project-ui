from contextlib import contextmanager
from collections.abc import Iterator

from fastapi import Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.auth import active_session, permissions
from app.db import SessionLocal, get_session
from app.models import User


@contextmanager
def _request_session(request: Request) -> Iterator[Session]:
    override = request.app.dependency_overrides.get(get_session)
    if override is None:
        with SessionLocal() as session:
            yield session
    else:
        generator = override()
        try:
            yield next(generator)
        finally:
            generator.close()


def _required_permission(path: str, method: str) -> str | None:
    action = "read" if method in ("GET", "HEAD") else "write"
    segments = path.split("/")
    section = segments[2] if len(segments) > 2 else ""
    resources = {
        "students": "students", "academic-years": "students",
        "feestructures": "fees", "student-fee-profiles": "fees", "fees": "fees",
        "reports": "reports", "expenses": "expenses", "attendance": "attendance",
        "results": "results", "timetable": "timetable", "staff": "staff",
        "transport": "transport", "notifications": "notifications",
        "leave": "staff", "salary": "payroll", "staff-attendance": "staff",
        "homework": "homework", "discipline": "discipline", "certificates": "certificates",
        "videos": "videos",
    }
    resource = resources.get(section)
    return f"{resource}:{action}" if resource else None


async def authorize_request(request: Request, call_next):
    path = request.url.path
    if request.method == "OPTIONS":
        return await call_next(request)
    public = (
        path.startswith("/health/") or path in ("/docs", "/redoc", "/openapi.json", "/api/auth/login", "/api/auth/refresh", "/platform/auth/login", "/api/contact/enquiry")
        or (request.method == "GET" and path.startswith("/platform/schools/") and path.endswith("/validate"))
        or (request.method == "GET" and path == "/api/site-content")
    )
    if public or not (path.startswith("/api/") or path.startswith("/platform/")):
        return await call_next(request)
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer "):
        return JSONResponse(status_code=401, content={"detail": "Bearer token required"})
    with _request_session(request) as session:
        record = active_session(session, authorization[7:])
        if record is None:
            return JSONResponse(status_code=401, content={"detail": "Invalid or expired token"})
        user = record.user
        request.state.user_id = user.id
        request.state.user_role = user.role
        request.state.user_tenant = user.tenant_id
        granted = permissions(user)

        if path.startswith("/platform/"):
            if user.role != "SUPER_ADMIN":
                return JSONResponse(status_code=403, content={"detail": "Platform administrator required"})
        else:
            tenant = (request.headers.get("x-tenant-id") or "").strip().lower()
            if not tenant:
                return JSONResponse(status_code=400, content={"detail": "X-Tenant-ID is required"})
            if user.role != "SUPER_ADMIN" and tenant != user.tenant_id:
                return JSONResponse(status_code=403, content={"detail": "Tenant does not match token"})
            if path.startswith("/api/student-portal/") and user.role != "STUDENT":
                return JSONResponse(status_code=403, content={"detail": "Student role required"})
            if path.startswith("/api/parent/") and user.role != "PARENT":
                return JSONResponse(status_code=403, content={"detail": "Parent role required"})
            if path.startswith("/api/ai/") and user.role != "STUDENT":
                return JSONResponse(status_code=403, content={"detail": "Student role required"})
            if path.startswith("/api/ai-config") and user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                return JSONResponse(status_code=403, content={"detail": "School administrator required"})
            if path.startswith("/api/users/") or path == "/api/users":
                if path not in ("/api/users/change-password", "/api/users") and user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                    return JSONResponse(status_code=403, content={"detail": "School administrator required"})
                if path == "/api/users" and request.method != "GET" and user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                    return JSONResponse(status_code=403, content={"detail": "School administrator required"})
            if path in ("/api/discipline/summary",) or (path.startswith("/api/discipline/") and path.endswith("/resolve")):
                if user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                    return JSONResponse(status_code=403, content={"detail": "School administrator required"})
            if path == "/api/results/grading-policy" and request.method != "GET":
                if user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                    return JSONResponse(status_code=403, content={"detail": "School administrator required"})
            if path.startswith("/api/master-data/") and request.method not in ("GET", "HEAD"):
                if user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
                    return JSONResponse(status_code=403, content={"detail": "School administrator required"})
            if path == "/api/leave/apply" or path.startswith("/api/leave/staff/"):
                if user.role not in ("SUPER_ADMIN", "SCHOOL_ADMIN", "TEACHER", "ACCOUNTANT", "TRANSPORT_MANAGER"):
                    return JSONResponse(status_code=403, content={"detail": "Staff role required"})
                required = None
            elif request.method in ("GET", "HEAD") and (
                path in ("/api/transport/buses", "/api/transport/routes")
                or path.startswith("/api/transport/assignments/student/")
            ) and user.role in ("STUDENT", "PARENT"):
                required = None
            elif request.method in ("GET", "HEAD") and user.role in ("STUDENT", "PARENT") and path.startswith("/api/homework/"):
                required = None
            elif request.method in ("GET", "HEAD") and user.role in ("STUDENT", "PARENT") and path.startswith("/api/videos/"):
                required = None
            elif request.method in ("GET", "HEAD") and user.role == "PARENT" and path.startswith("/api/discipline/student/"):
                required = None
            elif user.role in ("STUDENT", "PARENT") and request.method in ("GET", "HEAD") and path.startswith("/api/notifications"):
                required = None
            elif request.method == "PUT" and path.startswith("/api/notifications/") and path.endswith("/read"):
                required = None
            elif path == "/api/users" and request.method == "GET":
                required = None
            else:
                required = _required_permission(path, request.method)
            if required and "*" not in granted and required not in granted:
                return JSONResponse(status_code=403, content={"detail": f"Permission {required} required"})
    return await call_next(request)


def current_user(request: Request, session: Session = Depends(get_session)) -> User:
    user_id = getattr(request.state, "user_id", None)
    user = session.get(User, user_id) if user_id else None
    if user is None or not user.active:
        raise HTTPException(status_code=401, detail="Authenticated user required")
    return user
