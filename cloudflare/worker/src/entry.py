"""Thin Cloudflare bootstrap; the FastAPI route graph loads on first request."""

import os
import sys
from pathlib import Path

vendor_path = Path(__file__).resolve().parent / "vendor"
if vendor_path.is_dir() and str(vendor_path) not in sys.path:
    sys.path.insert(0, str(vendor_path))
os.environ["PYDANTIC_PURE_PYTHON"] = "1"

from workers import WorkerEntrypoint, Response
from workers.asgi import fetch as asgi_fetch


class Default(WorkerEntrypoint):
    _app = None
    _full = None

    async def on_fetch(self, request):
        if request.method == "OPTIONS":
            return Response(
                "",
                status=204,
                headers={
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*",
                    "Access-Control-Max-Age": "86400",
                },
            )

        if self._app is None:
            import full_entry

            full_entry._load_routers()
            self._full = full_entry
            self._app = full_entry.app
        path = str(request.url).split("?", 1)[0]
        if "/api/expenses" in path:
            finance = getattr(self.env, "FINANCE", None)
            if finance is not None:
                return await finance.fetch(request)
        return await asgi_fetch(self._app, request, self.env, self.ctx)
