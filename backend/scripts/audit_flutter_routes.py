"""Best-effort static check that Flutter's Dio calls have FastAPI routes.

Run from backend/: python -m scripts.audit_flutter_routes
This checks method/path existence; payloads and live browser behavior need separate QA.
"""

import os
import re
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite://")

from app.main import app  # noqa: E402


FLUTTER = Path(__file__).resolve().parents[2] / "lib"
CONSTANT = re.compile(r"static\s+const\s+(?:String\s+)?(_\w+)\s*=\s*['\"]([^'\"]+)['\"]")
LITERAL_CALL = re.compile(r"DioClient(?:\.instance)?\.(get|post|put|delete)\(\s*['\"]([^'\"]+)['\"]", re.I)
VARIABLE_CALL = re.compile(r"DioClient(?:\.instance)?\.(get|post|put|delete)\(\s*(_\w+)\s*[,)]", re.I)


def main() -> int:
    if not FLUTTER.is_dir():
        print(f"Flutter source directory not found: {FLUTTER}")
        return 1
    routes = [
        (method.lower(), re.compile("^" + re.sub(r"\{[^}]+\}", "[^/]+", route.path) + "$"))
        for route in app.routes for method in (getattr(route, "methods", None) or [])
    ]
    missing = []
    checked = 0
    for source in FLUTTER.rglob("*.dart"):
        code = source.read_text(encoding="utf-8")
        constants = dict(CONSTANT.findall(code))
        calls = list(LITERAL_CALL.finditer(code)) + list(VARIABLE_CALL.finditer(code))
        for call in calls:
            method, raw = call.groups()
            if raw.startswith("_") and raw in constants:
                raw = constants[raw]
            for key, value in sorted(constants.items(), key=lambda item: -len(item[0])):
                raw = raw.replace(f"${key}", value)
            if raw.startswith("http://") or raw.startswith("https://"):
                continue
            # Interpolated IDs in Flutter correspond to FastAPI path parameters.
            path = re.sub(r"\$\{[^}]+\}|\$[A-Za-z_]\w*", "value", raw)
            if path.startswith("/api/"):
                candidate = path
            else:
                candidate = "/api" + path
            checked += 1
            if not any(m == method.lower() and pattern.fullmatch(candidate) for m, pattern in routes):
                line = code.count("\n", 0, call.start()) + 1
                missing.append(f"{source.relative_to(FLUTTER)}:{line} {method.upper()} {candidate}")
    print(f"Checked {checked} Flutter Dio calls against FastAPI routes")
    if checked == 0:
        print("No Flutter Dio calls found; route audit cannot pass")
        return 1
    for entry in missing:
        print("MISSING", entry)
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
