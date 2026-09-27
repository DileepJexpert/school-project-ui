"""Give each Flutter Pages build unique script URLs to bypass stale service workers."""

from __future__ import annotations

import hashlib
from pathlib import Path

repo = Path(__file__).resolve().parent
out = repo / "build/web"
main = out / "main.dart.js"
bootstrap = out / "flutter_bootstrap.js"
index = out / "index.html"

main_bytes = main.read_bytes()
version = hashlib.sha256(main_bytes).hexdigest()[:12]
main_name = f"main.{version}.dart.js"
bootstrap_name = f"flutter_bootstrap.{version}.js"
(out / main_name).write_bytes(main_bytes)

boot_text = bootstrap.read_text(encoding="utf-8")
assert boot_text.count('"mainJsPath":"main.dart.js"') == 1
boot_text = boot_text.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"{main_name}"', 1)
(out / bootstrap_name).write_text(boot_text, encoding="utf-8")

html = index.read_text(encoding="utf-8")
assert html.count('src="flutter_bootstrap.js"') == 1
html = html.replace('src="flutter_bootstrap.js"', f'src="{bootstrap_name}"', 1)
index.write_text(html, encoding="utf-8")

print(f"Prepared versioned Flutter release: {bootstrap_name} -> {main_name}")
