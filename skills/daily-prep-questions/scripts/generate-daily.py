#!/usr/bin/env python3
"""
generate-daily.py — deterministic, no-repeat daily question selector.

Usage:
  python3 generate-daily.py            # generate today's session (8 questions)
  python3 generate-daily.py --date 2026-09-15   # for a specific date
  python3 generate-daily.py --reset    # clear progress (cycle restarts)
  python3 generate-daily.py --show     # show today's saved session without regenerating

Design:
  - deterministic: same date -> same selection (seeded by date)
  - no repeats: each bank keeps an index cycled via a per-bank pointer; a full
    pointer cycle is fine (every problem has been seen once before repeating).
  - 8 questions/day = 3 LC, 2 SD, 1 Behavioral, 1 SQL, 1 LLD.
"""

import argparse
import datetime
import json
import os
import random

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(SKILL_DIR, "data")
PROGRESS_FILE = os.path.join(SKILL_DIR, "progress.json")

BANKS = {
    "lc":  (os.path.join(DATA_DIR, "lc-bank.json"), 3),
    "sd":  (os.path.join(DATA_DIR, "sd-bank.json"), 2),
    "behavior": (os.path.join(DATA_DIR, "behavior-bank.json"), 1),
    "sql": (os.path.join(DATA_DIR, "sql-bank.json"), 1),
    "lld": (os.path.join(DATA_DIR, "lld-bank.json"), 1),
}


def today_str():
    return datetime.date.today().isoformat()


def load_progress():
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {}


def save_progress(p):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(p, f, indent=2, ensure_ascii=False)


def load_bank(key):
    path, _ = BANKS[key]
    with open(path) as f:
        data = json.load(f)
    return data.get("problems") or data.get("questions") or []


def pick(key, problems, pointer, rng):
    """Pick `count` problems starting at pointer (cyclically), no repeats within day."""
    _, count = BANKS[key]
    if len(problems) == 0:
        return []
    start = pointer % len(problems)
    chosen = problems[start:start + count]
    # handle wrap
    if len(chosen) < count:
        chosen += problems[0:count - len(chosen)]
    new_pointer = (start + count) % len(problems)
    return chosen, new_pointer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", default=today_str())
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()

    prog = load_progress()

    if args.reset:
        prog = {}
        save_progress(prog)
        print("Progress cleared. Next run starts a fresh cycle.")
        return

    if args.show:
        if args.date in prog.get("days", {}):
            print(json.dumps(prog["days"][args.date], indent=2, ensure_ascii=False))
        else:
            print(f"No session recorded for {args.date}.")
        return

    # seed: deterministic per date
    seed = int(datetime.date.fromisoformat(args.date).strftime("%Y%m%d"))
    rng = random.Random(seed)

    days = prog.setdefault("days", {})
    pointers = prog.setdefault("pointers", {})

    # if this date already has a session, just re-render it (stable)
    if args.date in days:
        session = days[args.date]
    else:
        session = {}
        for key, (path, _count) in BANKS.items():
            problems = load_bank(key)
            ptr = pointers.get(key, 0)
            chosen, new_ptr = pick(key, problems, ptr, rng)
            pointers[key] = new_ptr
            session[key] = [p["id"] for p in chosen]
        days[args.date] = session
        save_progress(prog)

    # Render human-readable output
    rendered = []
    labels = {
        "lc": "LeetCode (3)",
        "sd": "System Design (2)",
        "behavior": "Behavioral (1)",
        "sql": "SQL (1)",
        "lld": "Low Level Design (1)",
    }
    for key, ids in session.items():
        problems = load_bank(key)
        by_id = {p["id"]: p for p in problems}
        rendered.append((key, labels[key], [by_id[i] for i in ids if i in by_id]))

    print(f"\n=== Daily Prep — {args.date} ===")
    for key, label, items in rendered:
        print(f"\n[{label}]")
        for it in items:
            if key == "lc":
                print(f"  #{it.get('id')} {it['title']} | {it.get('pattern')} | {it.get('company')} | {it.get('difficulty')}")
            elif key == "behavior":
                print(f"  Q{it.get('id')} — {it['title']} | {it.get('company')}")
            else:
                extra = f" | {it.get('topic')}" if it.get("topic") else ""
                print(f"  #{it.get('id')} {it['title']} | {it.get('company')}{extra}")

    print("\nHint: to track progress while solving, update lc-tracker.csv in Documents after LC solves.")
    print("Weekly rhythm for company rotation: Meta -> Amazon -> Google -> Apple.")


if __name__ == "__main__":
    main()