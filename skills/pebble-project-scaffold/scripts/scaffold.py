#!/usr/bin/env python3
"""Create a Pebble C or Alloy project skeleton."""
import argparse, json, shutil, sys, uuid
from pathlib import Path

SKILLS = Path(__file__).resolve().parent.parent.parent
C_TEMPLATES = SKILLS / "pebble-c-dev" / "templates"
ALLOY_TEMPLATES = SKILLS / "pebble-alloy-dev" / "templates"
CORE_TEMPLATES = SKILLS / "pebble-core" / "templates"

def slug(s): return s.lower().replace(" ", "-").replace("_", "-")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--face", action="store_true")
    ap.add_argument("--app", action="store_true")
    ap.add_argument("--c", action="store_true")
    ap.add_argument("--alloy", action="store_true")
    ap.add_argument("--platforms", default="emery")
    ap.add_argument("--author", default="Author")
    ap.add_argument("--display")
    ap.add_argument("--phone", choices=["none", "pkjs", "clay"], default="none")
    ap.add_argument("--output", default=".")
    args = ap.parse_args()

    is_face = args.face or not args.app
    is_alloy = args.alloy
    platforms = [p.strip() for p in args.platforms.split(",") if p.strip()]
    if is_alloy and any(p not in ("emery", "gabbro") for p in platforms):
        sys.exit("Alloy supports only emery and gabbro")
    name = slug(args.name)
    root = Path(args.output).resolve() / name
    if root.exists():
        sys.exit(f"Refusing to overwrite existing directory: {root}")

    (root / "src").mkdir(parents=True)
    (root / "resources" / "fonts").mkdir(parents=True)
    (root / "resources" / "images").mkdir(parents=True)

    pebble = {
        "displayName": args.display or args.name,
        "uuid": str(uuid.uuid4()),
        "sdkVersion": "3",
        "enableMultiJS": args.phone != "none",
        "targetPlatforms": platforms,
        "watchapp": {"watchface": is_face},
        "resources": {"media": []},
    }
    if is_alloy:
        pebble["projectType"] = "moddable"
    if args.phone != "none":
        pebble["messageKeys"] = ["REQUEST_DATA", "DATA_VALUE"]
    if args.phone == "clay":
        pebble["messageKeys"] += ["ShowDate", "BackgroundColor"]
        pebble["capabilities"] = ["configurable"]

    pkg = {
        "name": name,
        "author": args.author,
        "version": "1.0.0",
        "keywords": ["pebble-app"],
        "private": True,
        "dependencies": {},
        "pebble": pebble,
    }
    (root / "package.json").write_text(json.dumps(pkg, indent=2) + "\n")
    shutil.copy(CORE_TEMPLATES / "wscript.template", root / "wscript")
    (root / ".gitignore").write_text("build/\n.pebble/\n")

    if is_alloy:
        (root / "src" / "c").mkdir()
        (root / "src" / "embeddedjs").mkdir()
        shutil.copy(ALLOY_TEMPLATES / "alloy-mdbl.c", root / "src" / "c" / "mdbl.c")
        shutil.copy(ALLOY_TEMPLATES / "alloy-manifest.json", root / "src" / "embeddedjs" / "manifest.json")
        shutil.copy(ALLOY_TEMPLATES / "alloy-watchface.js", root / "src" / "embeddedjs" / "main.js")
    else:
        (root / "src" / "c").mkdir()
        template = C_TEMPLATES / ("static-watchface.c" if is_face else "watchapp.c")
        shutil.copy(template, root / "src" / "c" / "main.c")

    if args.phone != "none":
        pkjs = root / "src" / "pkjs"
        pkjs.mkdir()
        (pkjs / "index.js").write_text(
            "Pebble.addEventListener('ready', function () {\n"
            "  console.log('PebbleKit JS ready');\n"
            "});\n"
        )
        if args.phone == "clay":
            (pkjs / "config.js").write_text(
                "module.exports = [\n"
                "  { \"type\": \"heading\", \"defaultValue\": \"Settings\" },\n"
                "  { \"type\": \"submit\", \"defaultValue\": \"Save\" }\n"
                "];\n"
            )

    print(f"Created {root}")
    print("Next: pebble-ui-design, then the implementation skill, then pebble-build-test")

if __name__ == "__main__":
    main()
