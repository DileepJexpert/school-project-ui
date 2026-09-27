"""Finance routes hosted separately to stay within Python Worker startup limits."""

import os
import sys
from pathlib import Path

vendor_path = Path(__file__).resolve().parent / "vendor"
if vendor_path.is_dir() and str(vendor_path) not in sys.path:
    sys.path.insert(0, str(vendor_path))
os.environ["PYDANTIC_PURE_PYTHON"] = "1"

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from workers import asgi

from school_expenses import router as expenses_router

app = FastAPI(title="School Finance API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://school-staging.pages.dev", "https://schools.katixo.com"],
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Tenant-ID"],
)
app.include_router(expenses_router)

Default = asgi.entrypoint(app)
