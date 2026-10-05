"""Finance Worker with lazy route loading to stay below startup CPU limits."""

import os
import sys
from pathlib import Path

vendor_path = Path(__file__).resolve().parent / "vendor"
if vendor_path.is_dir() and str(vendor_path) not in sys.path:
    sys.path.insert(0, str(vendor_path))
os.environ["PYDANTIC_PURE_PYTHON"] = "1"

from workers import WorkerEntrypoint
from workers.asgi import fetch as asgi_fetch


def _build_app():
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    from school_expenses import router as expenses_router

    app = FastAPI(title="School Finance API", version="0.1.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )
    app.include_router(expenses_router)
    return app


class Default(WorkerEntrypoint):
    _app = None

    async def on_fetch(self, request):
        if self._app is None:
            self._app = _build_app()
        return await asgi_fetch(self._app, request, self.env, self.ctx)
