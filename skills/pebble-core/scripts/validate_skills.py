#!/usr/bin/env python3
"""Validate the Pebble skill suite structure."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

def main():
    errors = []
    skills = sorted(p for p in ROOT.iterdir() if p.is_dir() and p.name.startswith("pebble-"))
    if not skills:
        sys.exit("No pebble-* skills found")

    for skill in skills:
        skill_md = skill / "SKILL.md"
        if not skill_md.exists():
            errors.append(f"{skill.name}: missing SKILL.md")
            continue
        text = skill_md.read_text()
        if not text.startswith("---"):
            errors.append(f"{skill.name}: missing frontmatter")
            continue
        parts = text.split("---", 2)
        front = parts[1] if len(parts) > 2 else ""
        name = re.search(r"^name:\s*(\S+)", front, re.M)
        desc = re.search(r"^description:\s*(.+)$", front, re.M)
        if not name or name.group(1) != skill.name:
            errors.append(f"{skill.name}: frontmatter name mismatch")
        if not NAME_RE.fullmatch(skill.name):
            errors.append(f"{skill.name}: invalid directory name")
        if not desc or not (1 <= len(desc.group(1)) <= 1024):
            errors.append(f"{skill.name}: description missing or too long")
        if "## Files & routing" not in text and skill.name != "pebble-core":
            errors.append(f"{skill.name}: missing Files & routing table")

        for path in sorted(skill.rglob("*")):
            if path.is_dir() or path.name in {"SKILL.md", "GUIDE.md"}:
                continue
            rel = path.relative_to(skill).as_posix()
            if rel not in text:
                errors.append(f"{skill.name}: orphan file not referenced in SKILL.md: {rel}")

    if errors:
        print("FAIL")
        for e in errors:
            print(" -", e)
        sys.exit(1)
    print(f"OK: {len(skills)} Pebble skills validated")

if __name__ == "__main__":
    main()
