#!/usr/bin/env python3
"""Validate a Pebble project before building."""
import json
import re
import sys
from pathlib import Path

RED, GREEN, YELLOW, BLUE, RESET, BOLD = (
    "\033[91m", "\033[92m", "\033[93m", "\033[94m", "\033[0m", "\033[1m"
)
PLATFORMS = {"aplite", "basalt", "chalk", "diorite", "emery", "flint", "gabbro"}

def status(kind, msg):
    sym = {"ok": "✓", "error": "✗", "warning": "!", "info": "ℹ"}[kind]
    color = {"ok": GREEN, "error": RED, "warning": YELLOW, "info": BLUE}[kind]
    print(f"  {color}{sym}{RESET} {msg}")

def validate(root: Path):
    errors, warnings = [], []

    pkg_path = root / "package.json"
    if not pkg_path.exists():
        errors.append("package.json not found")
        return errors, warnings
    try:
        pkg = json.loads(pkg_path.read_text())
    except Exception as exc:
        errors.append(f"package.json is not valid JSON: {exc}")
        return errors, warnings

    if not isinstance(pkg.get("name"), str) or not pkg["name"]:
        errors.append("Missing package.json.name")
    pebble = pkg.get("pebble")
    if not isinstance(pebble, dict):
        errors.append("Missing package.json.pebble")
        return errors, warnings

    uuid = pebble.get("uuid", "")
    if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", uuid, re.I):
        errors.append("pebble.uuid is missing or not a valid UUID")
    if pebble.get("sdkVersion") != "3":
        errors.append('pebble.sdkVersion must be "3" for current SDKs')
    if not pebble.get("displayName"):
        errors.append("Missing pebble.displayName")

    watchapp = pebble.get("watchapp")
    if not isinstance(watchapp, dict) or not isinstance(watchapp.get("watchface"), bool):
        errors.append("pebble.watchapp.watchface must be true or false")
    watchface = isinstance(watchapp, dict) and watchapp.get("watchface") is True

    platforms = pebble.get("targetPlatforms")
    if not isinstance(platforms, list) or not platforms:
        errors.append("pebble.targetPlatforms must be a non-empty array")
        platforms = []
    for p in platforms:
        if p not in PLATFORMS:
            errors.append(f"Unknown target platform: {p}")

    alloy = pebble.get("projectType") == "moddable"
    if alloy:
        if any(p not in {"emery", "gabbro"} for p in platforms):
            errors.append("Alloy projects may target only emery and gabbro")
        if not (root / "src" / "c" / "mdbl.c").exists():
            errors.append("Alloy project is missing src/c/mdbl.c")
        if not (root / "src" / "embeddedjs" / "main.js").exists():
            errors.append("Alloy project is missing src/embeddedjs/main.js")
        if not (root / "src" / "embeddedjs" / "manifest.json").exists():
            errors.append("Alloy project is missing src/embeddedjs/manifest.json")
    else:
        if not list((root / "src").rglob("*.c")):
            errors.append("No C source files under src/")

    keys = pebble.get("messageKeys", [])
    if keys and not isinstance(keys, list):
        errors.append("pebble.messageKeys must be an array")
    caps = pebble.get("capabilities", [])
    if caps and not isinstance(caps, list):
        errors.append("pebble.capabilities must be an array")
    if (root / "src" / "pkjs").exists() and not pebble.get("enableMultiJS"):
        errors.append("src/pkjs exists but pebble.enableMultiJS is not true")
    if (root / "src" / "pkjs" / "config.js").exists() and "configurable" not in caps:
        errors.append('Clay config exists but "configurable" capability is missing')
    if not isinstance(pebble.get("resources", {}).get("media", []), list):
        errors.append("pebble.resources.media must be an array")

    if not (root / "wscript").exists():
        errors.append("wscript not found")

    for cfile in (root / "src").rglob("*.c"):
        text = cfile.read_text(errors="ignore")
        rel = cfile.relative_to(root)
        if "#include <pebble.h>" not in text and "pebble_worker.h" not in text:
            warnings.append(f"{rel}: missing <pebble.h> include")
        if re.search(r"\b(float|double)\b\s+\w+", text):
            warnings.append(f"{rel}: uses floating point")
        if "window_create" in text and "window_destroy" not in text:
            warnings.append(f"{rel}: window_create without window_destroy")
        if "gpath_create" in text and "gpath_destroy" not in text:
            warnings.append(f"{rel}: gpath_create without gpath_destroy")

    status("info", f"type={'watchface' if watchface else 'watchapp'}, language={'Alloy' if alloy else 'C'}")
    status("info", f"platforms={platforms or 'missing'}")
    for e in errors:
        status("error", e)
    for w in warnings:
        status("warning", w)
    return errors, warnings

def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: validate_project.py /path/to/project")
    root = Path(sys.argv[1]).resolve()
    print(f"\n{BOLD}Validating Pebble project{RESET}\n  {root}\n")
    if not root.is_dir():
        sys.exit("Not a directory")
    errors, warnings = validate(root)
    print()
    if errors:
        print(f"{RED}{len(errors)} error(s){RESET}")
        sys.exit(1)
    print(f"{GREEN}All validations passed{RESET}" + (f" ({len(warnings)} warning(s))" if warnings else ""))
    print("Next: pebble build")

if __name__ == "__main__":
    main()
