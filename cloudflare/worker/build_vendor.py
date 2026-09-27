"""Reproducible dependency builder for Cloudflare Python Worker.

Derives the vendor bundle in `src/vendor` strictly from `uv.lock` and `pyproject.toml`.
Removes build metadata and non-runtime files to keep bundle size minimal.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys


WORKER_DIR = Path(__file__).resolve().parent
VENDOR_DIR = WORKER_DIR / "src" / "vendor"
LOCK_FILE = WORKER_DIR / "uv.lock"
PYPROJECT = WORKER_DIR / "pyproject.toml"


def build_vendor() -> None:
    if not LOCK_FILE.exists():
        raise FileNotFoundError(f"uv.lock not found at {LOCK_FILE}")
    if not PYPROJECT.exists():
        raise FileNotFoundError(f"pyproject.toml not found at {PYPROJECT}")

    print(f"Building reproducible vendor packages from {LOCK_FILE.name}...")

    # Step 1: Export locked production requirements
    export_cmd = [
        "uv", "export",
        "--frozen",
        "--no-dev",
        "--no-emit-project",
        "--no-hashes",
    ]
    res = subprocess.run(export_cmd, cwd=str(WORKER_DIR), capture_output=True, text=True, check=True)
    requirements = res.stdout.strip()

    # Step 2: Clean existing vendor directory
    if VENDOR_DIR.exists():
        shutil.rmtree(VENDOR_DIR)
    VENDOR_DIR.mkdir(parents=True, exist_ok=True)

    # Step 3: Write temporary requirements file and install
    temp_reqs = WORKER_DIR / ".temp_vendor_requirements.txt"
    try:
        temp_reqs.write_text(requirements, encoding="utf-8")
        install_cmd = [
            "uv", "pip", "install",
            "-r", str(temp_reqs),
            "--target", str(VENDOR_DIR),
            "--no-compile",
        ]
        subprocess.run(install_cmd, cwd=str(WORKER_DIR), check=True)
    finally:
        if temp_reqs.exists():
            temp_reqs.unlink()

    # Step 4: Prune non-runtime metadata (*.dist-info, __pycache__, bin)
    pruned_count = 0
    for item in list(VENDOR_DIR.iterdir()):
        if item.is_dir() and (item.name.endswith(".dist-info") or item.name == "bin"):
            shutil.rmtree(item)
            pruned_count += 1
    for pycache in VENDOR_DIR.rglob("__pycache__"):
        if pycache.is_dir():
            shutil.rmtree(pycache)
            pruned_count += 1

    # Step 5: Verification of standard pure-Python packages
    # Note: workers-runtime-sdk imports pyodide and js, which exist only inside Cloudflare Pyodide runtime.
    test_env = os.environ.copy()
    test_env["PYDANTIC_PURE_PYTHON"] = "1"
    verify_script = (
        "import sys, os; sys.path.insert(0, sys.argv[1]); "
        "import fastapi; import pydantic; import starlette; import multipart; "
        "assert pydantic.__version__.startswith('1.'), f'Expected pydantic 1.x, got {pydantic.__version__}'; "
        "print(f'Verified: FastAPI {fastapi.__version__}, Pydantic {pydantic.__version__}, Starlette {starlette.__version__}')"
    )
    subprocess.run([sys.executable, "-c", verify_script, str(VENDOR_DIR)], env=test_env, check=True)

    # Verify workers package structure exists
    workers_pkg = VENDOR_DIR / "workers" / "asgi.py"
    assert workers_pkg.exists(), f"Expected workers.asgi at {workers_pkg}"

    module_count = sum(1 for _ in VENDOR_DIR.rglob("*.py"))
    print(f"Vendor build complete: {module_count} Python modules in {VENDOR_DIR.name} (pruned {pruned_count} metadata items).")


if __name__ == "__main__":
    build_vendor()
