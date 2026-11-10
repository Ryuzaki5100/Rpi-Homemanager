#!/usr/bin/env python3
"""job-grabber persistent store helper.

Stdlib only. Keeps job-intel/ consistent so a posting is never researched twice.

Commands:
    init        --store DIR
    lookup      --store DIR --company C --title T [--url U] [--requisition R]
    upsert      --store DIR --json FILE
    mark-closed --store DIR (--id ID | --url URL) [--reason TEXT]
    stats       --store DIR
    coverage    --store DIR --run YYYY-MM-DD
    skills-gap  --store DIR --json FILE
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

DEFAULT_STORE = Path.home() / "job-search" / "my_resumes" / "job-intel"
SEED_DIR = Path(__file__).resolve().parent.parent / "templates" / "store-seed"

STATUS_OPEN = "open"
STATUS_CLOSED = "closed"
STATUS_UNKNOWN = "unknown"
VALID_STATUS = {STATUS_OPEN, STATUS_CLOSED, STATUS_UNKNOWN}

SEARCHED = {
    "directly_searched",
    "indirectly_searched",
    "searched_via_alerts",
    "searched_via_ats",
    "partially_accessible",
}
NOT_SEARCHED = {"inaccessible", "not_searched"}

LEGAL_SUFFIXES = [
    "private limited", "pvt ltd", "pvt. ltd.", "technologies", "technology",
    "solutions", "india", "inc", "ltd", "llc", "corp", "corporation", "limited",
]
TRACKING_PARAMS = re.compile(
    r"^(utm_.*|ref|refid|src|source|trk|trackingid|gh_src|lever-source|fbclid|gclid)$",
    re.IGNORECASE,
)


# --------------------------------------------------------------------------- io

def store_paths(store: Path) -> dict:
    return {
        "ledger": store / "ledger.json",
        "sources": store / "sources.json",
        "gaps": store / "skills-gap.json",
    }


def die(msg: str, code: int = 2):
    print(json.dumps({"error": msg}, indent=2))
    sys.exit(code)


def read_json(path: Path):
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=path.name, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


# -------------------------------------------------------------------- helpers

def today() -> str:
    return dt.date.today().isoformat()


def slugify(text: str) -> str:
    text = (text or "").lower().strip()
    for suffix in LEGAL_SUFFIXES:
        text = re.sub(rf"\b{re.escape(suffix)}\b", " ", text)
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "unknown"


def normalize_url(url: str) -> str:
    if not url:
        return ""
    url = url.strip()
    url = re.sub(r"^https?://", "", url, flags=re.IGNORECASE)
    host, _, rest = url.partition("/")
    path, _, query = rest.partition("?")
    kept = [
        part for part in query.split("&")
        if part and not TRACKING_PARAMS.match(part.split("=", 1)[0])
    ]
    rebuilt = host.lower().rstrip("/")
    if path:
        rebuilt += "/" + path.rstrip("/")
    if kept:
        rebuilt += "?" + "&".join(sorted(kept))
    return rebuilt


def make_id(company: str, title: str, requisition: str | None) -> str:
    base = f"{slugify(company)}--{slugify(title)}"
    if requisition:
        tail = slugify(str(requisition))
    else:
        tail = hashlib.sha1(f"{company}|{title}".encode()).hexdigest()[:8]
    return f"{base}--{tail}"


def load_ledger(store: Path) -> dict:
    paths = store_paths(store)
    data = read_json(paths["ledger"])
    if data is None:
        die(f"no ledger at {paths['ledger']} — run `init` first")
    data.setdefault("schema_version", 1)
    data.setdefault("postings", [])
    data.setdefault("last_updated", None)
    return data


def find_match(postings, company, title, url, requisition):
    req = str(requisition).strip() if requisition else ""
    if req:
        for rec in postings:
            if str(rec.get("requisition_id") or "").strip() == req and \
                    slugify(rec.get("company", "")) == slugify(company):
                return rec, "requisition"
    target = normalize_url(url or "")
    if target:
        for rec in postings:
            if normalize_url(rec.get("apply_url", "")) == target:
                return rec, "url"
    if company and title:
        cs, ts = slugify(company), slugify(title)
        for rec in postings:
            if slugify(rec.get("company", "")) == cs and slugify(rec.get("title", "")) == ts:
                return rec, "title"
    return None, None


def merge_list(old, new):
    out = list(old or [])
    for item in new or []:
        if item not in out:
            out.append(item)
    return out


# ------------------------------------------------------------------- commands

def cmd_init(args):
    store = Path(args.store).expanduser()
    for sub in ("runs", "fits", "inbox/processed"):
        (store / sub).mkdir(parents=True, exist_ok=True)
    created = []
    for name in ("ledger.json", "sources.json", "skills-gap.json", "README.md"):
        dest = store / name
        if dest.exists():
            continue
        src = SEED_DIR / name
        if src.exists():
            shutil.copyfile(src, dest)
        else:
            if name.endswith(".json"):
                write_json(dest, json.loads((SEED_DIR / name).read_text()))
        created.append(name)
    for keep in ("runs/.gitkeep", "fits/.gitkeep", "inbox/.gitkeep", "inbox/processed/.gitkeep"):
        p = store / keep
        p.parent.mkdir(parents=True, exist_ok=True)
        p.touch()
    print(json.dumps({"store": str(store), "created": created}, indent=2))


def cmd_lookup(args):
    store = Path(args.store).expanduser()
    ledger = load_ledger(store)
    rec, match_by = find_match(
        ledger["postings"], args.company, args.title, args.url, args.requisition
    )
    if rec is None:
        result = {"result": "new", "record": None, "match_by": None}
    else:
        result = {"result": "known", "record": rec, "match_by": match_by}
    print(json.dumps(result, indent=2, ensure_ascii=False))


def cmd_upsert(args):
    store = Path(args.store).expanduser()
    payload = read_json(Path(args.json).expanduser())
    if payload is None:
        die(f"cannot read record file {args.json}")
    rec = payload.get("record", payload)

    required = ["company", "title", "apply_url", "verification_source"]
    missing = [field for field in required if not str(rec.get(field) or "").strip()]
    if missing:
        die(f"refusing to store a record without {', '.join(missing)} — "
            "a posting may only enter the ledger after verification", code=3)
    if rec.get("status", STATUS_OPEN) != STATUS_OPEN:
        die("upsert only stores open, verified postings; use `mark-closed` to close one", code=3)

    ledger = load_ledger(store)
    postings = ledger["postings"]
    existing, match_by = find_match(
        postings, rec["company"], rec["title"], rec["apply_url"], rec.get("requisition_id")
    )

    now = today()
    if existing is None:
        new = {
            "id": rec.get("id") or make_id(rec["company"], rec["title"], rec.get("requisition_id")),
            "company": rec["company"],
            "title": rec["title"],
            "requisition_id": rec.get("requisition_id"),
            "apply_url": rec["apply_url"],
            "location": rec.get("location"),
            "work_mode": rec.get("work_mode"),
            "category": rec.get("category"),
            "experience_text": rec.get("experience_text"),
            "seniority_fit": rec.get("seniority_fit"),
            "score": rec.get("score"),
            "first_seen": rec.get("first_seen") or now,
            "posted_date": rec.get("posted_date"),
            "last_verified": rec.get("last_verified") or now,
            "status": STATUS_OPEN,
            "reported_runs": merge_list([], rec.get("reported_runs")),
            "discovery_channels": merge_list([], rec.get("discovery_channels")),
            "discovery_portals": merge_list([], rec.get("discovery_portals")),
            "verification_source": rec["verification_source"],
            "compensation": rec.get("compensation")
            or {"disclosed": False, "kind": None, "text": "Not disclosed"},
            "jd_path": rec.get("jd_path"),
            "fit_report_path": rec.get("fit_report_path"),
            "resume_path": rec.get("resume_path"),
            "resume_pdf_path": rec.get("resume_pdf_path"),
            "tailored_run": rec.get("tailored_run"),
            "notes": rec.get("notes", ""),
        }
        postings.append(new)
        action, target = "created", new
    else:
        existing["apply_url"] = rec.get("apply_url") or existing.get("apply_url")
        for field in (
            "location", "work_mode", "category", "experience_text", "seniority_fit",
            "score", "posted_date", "verification_source", "jd_path",
            "fit_report_path", "resume_path", "resume_pdf_path", "tailored_run",
        ):
            if rec.get(field) is not None:
                existing[field] = rec[field]
        if rec.get("requisition_id"):
            existing["requisition_id"] = rec["requisition_id"]
        existing["last_verified"] = rec.get("last_verified") or now
        existing["status"] = STATUS_OPEN
        existing["reported_runs"] = merge_list(existing.get("reported_runs"), rec.get("reported_runs"))
        existing["discovery_channels"] = merge_list(
            existing.get("discovery_channels"), rec.get("discovery_channels")
        )
        existing["discovery_portals"] = merge_list(
            existing.get("discovery_portals"), rec.get("discovery_portals")
        )
        if rec.get("compensation"):
            existing["compensation"] = rec["compensation"]
        if rec.get("notes"):
            existing["notes"] = (existing.get("notes") or "").strip()
            joined = [existing["notes"], rec["notes"].strip()]
            existing["notes"] = " | ".join(part for part in joined if part)
        action, target = "updated", existing

    postings.sort(key=lambda item: (item.get("first_seen") or "", item.get("id") or ""))
    ledger["last_updated"] = now
    write_json(store_paths(store)["ledger"], ledger)
    print(json.dumps({"action": action, "match_by": match_by, "record": target},
                     indent=2, ensure_ascii=False))


def cmd_mark_closed(args):
    store = Path(args.store).expanduser()
    ledger = load_ledger(store)
    target = None
    if args.id:
        target = next((r for r in ledger["postings"] if r.get("id") == args.id), None)
    elif args.url:
        wanted = normalize_url(args.url)
        target = next(
            (r for r in ledger["postings"] if normalize_url(r.get("apply_url", "")) == wanted),
            None,
        )
    if target is None:
        die("no matching posting to close", code=4)
    target["status"] = STATUS_CLOSED
    note = f"closed {today()}: {args.reason}" if args.reason else f"closed {today()}"
    target["notes"] = " | ".join(part for part in [(target.get("notes") or "").strip(), note] if part)
    ledger["last_updated"] = today()
    write_json(store_paths(store)["ledger"], ledger)
    print(json.dumps({"action": "closed", "record": target}, indent=2, ensure_ascii=False))


def cmd_stats(args):
    store = Path(args.store).expanduser()
    ledger = load_ledger(store)
    sources = read_json(store_paths(store)["sources"]) or {"runs": []}
    postings = ledger["postings"]
    verified = [r for r in postings if r.get("status") == STATUS_OPEN]
    by_status, by_category, by_band = {}, {}, {}
    for rec in postings:
        by_status[rec.get("status") or "unknown"] = by_status.get(rec.get("status") or "unknown", 0) + 1
        if rec.get("status") == STATUS_OPEN:
            cat = rec.get("category") or "unset"
            by_category[cat] = by_category.get(cat, 0) + 1
            score = rec.get("score")
            if isinstance(score, (int, float)):
                band = "90+" if score >= 90 else "80-89" if score >= 80 else \
                       "70-79" if score >= 70 else "60-69" if score >= 60 else "<60"
                by_band[band] = by_band.get(band, 0) + 1
    runs = sources.get("runs") or []
    out = {
        "store": str(store),
        "last_updated": ledger.get("last_updated"),
        "total_postings": len(postings),
        "open": len(verified),
        "by_status": by_status,
        "open_by_category": by_category,
        "open_by_score_band": by_band,
        "runs_recorded": len(runs),
        "last_run": runs[-1].get("date") if runs else None,
        "tailored": sum(1 for r in postings if r.get("resume_path")),
        "with_fit_report": sum(1 for r in postings if r.get("fit_report_path")),
    }
    print(json.dumps(out, indent=2, ensure_ascii=False))


def cmd_coverage(args):
    store = Path(args.store).expanduser()
    sources = read_json(store_paths(store)["sources"])
    if sources is None:
        die(f"no sources.json at {store_paths(store)['sources']} — run `init` first")
    run = next((r for r in sources.get("runs", []) if r.get("date") == args.run), None)
    if run is None:
        die(f"no run recorded for {args.run}; record the run in sources.json first", code=4)

    rows = run.get("sources", [])
    primary = [s for s in rows if (s.get("tier") or "").lower() == "primary"]
    secondary = [s for s in rows if (s.get("tier") or "").lower() == "secondary"]

    def investigated(source):
        status = (source.get("access_status") or "").lower()
        return status in SEARCHED or bool(source.get("indexed")) or bool(source.get("alerts")) \
            or bool(source.get("ats_feed"))

    ledger = load_ledger(store)
    in_run = [
        r for r in ledger["postings"]
        if args.run in (r.get("reported_runs") or []) or r.get("first_seen") == args.run
    ]
    open_in_run = [r for r in in_run if r.get("status") == STATUS_OPEN]

    channels = ["ats", "career_portal", "indexed", "alerts", "direct", "secondary"]
    effectiveness = {}
    for channel in channels:
        hit = [r for r in in_run if channel in (r.get("discovery_channels") or [])]
        eff = {
            "discovered": len(hit),
            "verified": len([r for r in hit if r.get("status") == STATUS_OPEN]),
        }
        effective = eff["discovered"]
        eff["conversion"] = round(eff["verified"] / eff["discovered"], 3) if effective else 0.0
        effectiveness[channel] = eff

    output = {
        "run": args.run,
        "portal_discovery_coverage": len([s for s in primary if investigated(s)]),
        "primary_portals_tracked": len(primary),
        "direct_portal_access": len(
            [s for s in primary if (s.get("access_status") or "").lower() == "directly_searched"]
        ),
        "secondary_coverage": len([s for s in secondary if investigated(s)]),
        "secondary_sources_tracked": len(secondary),
        "indexed_portals": len([s for s in primary if s.get("indexed")]),
        "alert_portals": len([s for s in primary if s.get("alerts")]),
        "ats_feeds": len([s for s in rows if s.get("ats_feed")]),
        "career_portals": len([s for s in rows if (s.get("tier") or "").lower() == "career"]),
        "unique_discovered": len(in_run),
        "verified": len(open_in_run),
        "reported_in_run_entry": run.get("metrics", {}),
        "channel_effectiveness": effectiveness,
    }
    recorded_dupes = (run.get("metrics") or {}).get("duplicates_eliminated")
    output["duplicates_eliminated"] = recorded_dupes if recorded_dupes is not None else None
    if recorded_dupes is None:
        output["note"] = ("duplicates_eliminated is not derivable from the ledger alone; "
                          "store it in the run entry's metrics when writing the report")
    print(json.dumps(output, indent=2, ensure_ascii=False))


def cmd_skills_gap(args):
    store = Path(args.store).expanduser()
    path = store_paths(store)["gaps"]
    gaps = read_json(path) or {
        "schema_version": 1, "updated": None, "total_roles_seen": 0,
        "seen_roles": [], "requirements": {},
    }
    payload = read_json(Path(args.json).expanduser())
    if payload is None:
        die(f"cannot read {args.json}")

    role = payload.get("role")
    if not role:
        die("skills-gap input needs a `role` slug")
    requirements = payload.get("requirements") or {}
    seen = gaps.setdefault("seen_roles", [])
    if role not in seen:
        seen.append(role)
        gaps["total_roles_seen"] = len(seen)

    bucket = gaps.setdefault("requirements", {})
    for name, classification in requirements.items():
        entry = bucket.setdefault(name, {
            "occurrences": 0, "strong": 0, "partial": 0, "missing": 0,
            "coverage_ratio": 0.0, "roles": [], "last_seen": None,
        })
        classification = (classification or "").lower()
        if classification in ("strong", "partial", "missing"):
            entry[classification] = entry.get(classification, 0) + 1
        else:
            entry["partial"] = entry.get("partial", 0) + 1
        entry["occurrences"] = entry.get("partial", 0) + entry.get("missing", 0)
        total = sum(entry.get(k, 0) for k in ("strong", "partial", "missing"))
        entry["coverage_ratio"] = round(entry.get("strong", 0) / total, 3) if total else 0.0
        entry["roles"] = merge_list(entry.get("roles"), [role])
        entry["last_seen"] = payload.get("date") or today()

    gaps["updated"] = today()
    write_json(path, gaps)

    recurring = [
        {"requirement": name, **entry}
        for name, entry in gaps["requirements"].items()
        if entry.get("occurrences", 0) >= 3 and entry.get("coverage_ratio", 0) < 0.5
    ]
    recurring.sort(key=lambda item: (-item["occurrences"], item["coverage_ratio"]))
    print(json.dumps({"updated_requirements": len(requirements),
                      "seen_roles": gaps["total_roles_seen"],
                      "recurring_gaps": recurring}, indent=2, ensure_ascii=False))


# ----------------------------------------------------------------------- main

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def add(name, help_text):
        p = sub.add_parser(name, help=help_text)
        p.add_argument("--store", default=str(DEFAULT_STORE),
                       help="job-intel store directory")
        return p

    add("init", "create the store layout and seed files")

    p = add("lookup", "check whether a posting is already known")
    p.add_argument("--company", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--url", default="")
    p.add_argument("--requisition", default="")

    p = add("upsert", "insert or update a verified open posting")
    p.add_argument("--json", required=True)

    p = add("mark-closed", "mark a posting closed")
    p.add_argument("--id", default="")
    p.add_argument("--url", default="")
    p.add_argument("--reason", default="")

    add("stats", "summarise the store")

    p = add("coverage", "compute both coverage metrics for a run")
    p.add_argument("--run", required=True)

    p = add("skills-gap", "merge one role's keyword classifications")
    p.add_argument("--json", required=True)

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    handlers = {
        "init": cmd_init,
        "lookup": cmd_lookup,
        "upsert": cmd_upsert,
        "mark-closed": cmd_mark_closed,
        "stats": cmd_stats,
        "coverage": cmd_coverage,
        "skills-gap": cmd_skills_gap,
    }
    handlers[args.command](args)


if __name__ == "__main__":
    main()
