---
name: job-grabber
description: Persistent store specification for job-grabber — the on-disk layout under job-intel/, the ledger.json, sources.json and skills-gap.json schemas, the re-verification TTL, deduplication identity rules and the read/upsert/close protocol. Loaded before reading or writing the store.
---

# Persistent store

Scope: the on-disk memory of the whole system. The store is the reason a posting is never researched
twice. Conversation history is not memory; this is.

## 1. Layout

```
~/job-search/my_resumes/job-intel/
├── README.md                 human explanation of the store
├── ledger.json               every posting ever seen, current state
├── sources.json              per-run source coverage + rolling source performance
├── skills-gap.json           recurring requirements vs candidate evidence
├── runs/<YYYY-MM-DD>-weekly-report.md
├── fits/<company>_<role>/{jd.md,fit.md}
└── inbox/{,processed/}       exported alert emails
```

All of it is committed to the repo, including raw alert emails. Nothing here is generated output to
be discarded — it is the audit trail.

## 2. ledger.json

```json
{
  "schema_version": 1,
  "last_updated": "2026-11-06",
  "postings": [
    {
      "id": "google--software-engineer-ii--1234",
      "company": "Google",
      "title": "Software Engineer II, Early Career",
      "requisition_id": "1234",
      "apply_url": "https://careers.google.com/jobs/results/1234",
      "location": "Bengaluru, Karnataka, India",
      "work_mode": "Hybrid",
      "category": "backend",
      "experience_text": "1 year of software engineering experience",
      "seniority_fit": "good",
      "score": 84,
      "first_seen": "2026-11-06",
      "posted_date": null,
      "last_verified": "2026-11-06",
      "status": "open",
      "reported_runs": ["2026-11-06"],
      "discovery_channels": ["indexed", "ats"],
      "discovery_portals": ["linkedin"],
      "verification_source": "https://careers.google.com/jobs/results/1234",
      "compensation": {"disclosed": false, "kind": null, "text": "Not disclosed"},
      "jd_path": null,
      "fit_report_path": null,
      "resume_path": null,
      "resume_pdf_path": null,
      "tailored_run": null,
      "notes": ""
    }
  ]
}
```

Field rules:

- `id` — `<company-slug>--<title-slug>--<requisition_or_8char_hash>`. Stable; never regenerate.
- `status` — `open` | `closed` | `unknown`. Only `open` records may appear in Sections A–E.
- `category` — `backend` | `platform` | `data` | `ai`. Lowercase.
- `seniority_fit` — `excellent` | `good` | `stretch` | `poor`.
- `discovery_channels[]` — from `ats`, `career_portal`, `indexed`, `alerts`, `direct`, `secondary`.
  Append, never overwrite; the union is the history of how the vacancy was found.
- `discovery_portals[]` — portal slugs such as `linkedin`, `naukri`, `greenhouse`.
- `reported_runs[]` — run dates in which the role appeared in the report. Empty means discovered but
  never published (e.g. dropped for score or verification).
- `compensation.disclosed` — true only when the posting states a number. Never estimate.
- `jd_path` / `fit_report_path` / `resume_path` / `resume_pdf_path` — absolute paths, or null.
  `resume_path` points at `<company>/<company>_<role>.tex`; `resume_pdf_path` points at the mirrored
  `pdfs/<company>/<company>_<role>.pdf`. A record with a `resume_path` but no `resume_pdf_path`
  must carry the compile failure in `notes`.
- `posted_date` — ISO date from the ATS when available, else null. Never inferred.

## 3. sources.json

```json
{
  "schema_version": 1,
  "runs": [
    {
      "date": "2026-11-06",
      "period_start": "2026-10-30",
      "period_end": "2026-11-06",
      "run_number": 1,
      "sources": [
        {
          "name": "LinkedIn Jobs",
          "tier": "primary",
          "access_status": "partially_accessible",
          "limitation": "Search requires login; indexed listing pages reachable",
          "indexed": true,
          "alerts": true,
          "direct_attempted": true,
          "ats_feed": false,
          "queries": ["site:linkedin.com/jobs/view \"backend engineer\" Bengaluru"],
          "found": 4,
          "verified": 2
        }
      ],
      "metrics": {
        "portal_discovery_coverage": 6,
        "direct_portal_access": 2,
        "secondary_coverage": 4,
        "indexed_portals": 7,
        "alert_portals": 2,
        "ats_feeds": 9,
        "career_portals": 12,
        "unique_discovered": 23,
        "verified": 7,
        "duplicates_eliminated": 15,
        "expired_excluded": 3
      },
      "channel_effectiveness": {
        "ats_feed": {"discovered": 6, "verified": 6},
        "indexed": {"discovered": 11, "verified": 3}
      }
    }
  ],
  "source_performance": {
    "LinkedIn Jobs": {"runs_seen": 3, "discovered": 9, "verified": 4, "last_run": "2026-11-06"}
  }
}
```

- `runs[]` is append-only. Never edit a previous run.
- `access_status` values: `directly_searched`, `indirectly_searched`, `searched_via_alerts`,
  `searched_via_ats`, `partially_accessible`, `inaccessible`, `not_searched`.
- `metrics.portal_discovery_coverage` counts portals investigated via **any** channel.
  `metrics.direct_portal_access` counts only `directly_searched`. They must never be equal by
  construction.

## 4. skills-gap.json

```json
{
  "schema_version": 1,
  "updated": "2026-11-06",
  "total_roles_seen": 12,
  "seen_roles": ["google--software-engineer-ii--1234"],
  "requirements": {
    "distributed systems": {
      "occurrences": 5,
      "strong": 1,
      "partial": 2,
      "missing": 2,
      "coverage_ratio": 0.2,
      "roles": ["google--software-engineer-ii--1234"],
      "last_seen": "2026-11-06"
    }
  }
}
```

- `occurrences` counts roles where the requirement was classified partial or missing.
- `coverage_ratio` = roles with a Strong classification / roles analysed.
- `seen_roles` is the dedup set behind `total_roles_seen`; a role counted twice is not analysed twice.
- This file informs learning priorities only. It never justifies adding a technology to a resume.

## 5. Identity and deduplication

Resolve in this order:

1. `requisition_id` + company slug.
2. Normalised `apply_url` — lowercase host, strip `utm_*`/`ref`/`src`/`trk`, strip trailing slash,
   resolve redirects.
3. `(company, title, location)` only to *flag* a possible duplicate, never to auto-merge.

Company slug: lowercase, strip legal suffixes (`pvt ltd`, `india`, `technologies`, `inc`, `ltd`),
collapse whitespace to single hyphens.

## 6. Re-verification TTL

- Default **14 days**. A record verified more recently is not re-opened unless the current listing
  differs from the stored one, or `status` is `unknown`.
- Records with `status: open` and `last_verified` older than 14 days are re-verified before being
  reported in the still-open section.
- Records unverified for more than 60 days with no trace on the employer board are marked `closed`
  with a note.
- Never delete a postings entry. Closure is a status, not a removal.

## 7. Protocol

**Read** — always start here:

```
python3 scripts/ledger.py stats --store ~/job-search/my_resumes/job-intel
```

**Check a candidate** before spending any verification effort:

```
python3 scripts/ledger.py lookup --store <store> \
  --company "Google" --title "Software Engineer II" --url "<url>" --requisition "1234"
```

Returns `{"result": "known"|"new", "record": {...}|null, "match_by": "requisition|url|title"}`.

**Write** — only after verification:

```
python3 scripts/ledger.py upsert --store <store> --json /tmp/record.json
```

The script refuses a record that lacks `company`, `title`, `apply_url`, `verification_source`, or
that has `status != open`. That guard is the only thing standing between the store and a fabricated
entry — do not bypass it with a manual edit.

**Close**:

```
python3 scripts/ledger.py mark-closed --store <store> --id <id> --reason "requisition 404"
```

**Coverage** — compute metrics for the run being published:

```
python3 scripts/ledger.py coverage --store <store> --run 2026-11-06
```

**Skills gap**:

```
python3 scripts/ledger.py skills-gap --store <store> --json /tmp/gap.json
```

## 8. Integrity rules

- Atomic writes only (temp file + rename). A half-written ledger loses the dedup memory.
- Validate JSON after every write; abort and restore from `templates/store-seed/` if corrupt, but
  never silently drop postings.
- One run = one `runs[]` entry. Re-running on the same date replaces that entry rather than
  appending a duplicate.
- Manually editing the store is allowed for corrections, but a correction must keep every record's
  `verification_source` intact.
