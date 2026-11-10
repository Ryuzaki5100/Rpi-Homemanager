---
name: job-grabber
description: Use when the user asks for a weekly job search, job-market intelligence report, job discovery sweep, or wants software engineering roles in India found, verified, scored and ranked (backend, distributed systems, platform/infra, data infrastructure, AI infrastructure/RAG). Discovers through public ATS feeds, official company career portals, Google/Bing site indexing of job portals, exported job-alert emails, and direct portal searches; independently verifies every shortlisted role at the employer's own source; dedupes against a persistent job-intel ledger so the same posting is never researched twice; scores fit out of 100; dispatches job-search-resume-tailor for high-priority roles; and writes a dated weekly report with a full source-coverage audit.
---

# job-grabber

Weekly career-intelligence run for an early-career backend engineer in India. Discover broadly
through every legitimate channel, verify narrowly at the employer's own source, and record every
posting in a persistent ledger so nothing is ever researched twice.

The unit of value is a **verified, genuinely open, experience-compatible opportunity** — not a page
opened or a listing scraped.

## Step 0 — Read the guide first (mandatory)

`read <base-dir>/GUIDE.md` before searching anything. It holds the candidate profile, the targeting
and experience gates, the channel pipeline, the scoring rubric, and the continuity rules. Then open
whichever reference the routing table calls for.

## Core rules (always apply)

1. **Never fabricate.** No invented listings, posting dates, compensation, requisition IDs,
   application URLs, or search activity. If a field is unknown, write "Not disclosed".
2. **Discovery is not verification.** A search-engine snippet, an aggregator card, or an alert email
   is a *lead*. A role enters the report only after its official requisition is opened this run and
   confirmed open. Unverified leads go in a clearly separate "unverified leads" list.
3. **Never research the same posting twice.** Read the ledger before searching. Dedup on
   requisition ID first, then on normalized `(company, title, apply_url)`. A known posting is
   reported as *Reposted / Still open*, never as new.
4. **Never claim a channel you did not use.** Every source gets exactly one access classification
   (`Directly searched`, `Indirectly searched through indexed listings`,
   `Searched through email alerts`, `Searched through public ATS feeds`, `Partially accessible`,
   `Inaccessible`, `Not searched`). An indexed discovery is **never** labelled directly searched.
5. **Report discovery coverage and direct-access coverage separately.** A blocked portal that was
   still covered through indexing or alert emails counts toward discovery coverage, not toward
   direct access. Never inflate either.
6. **Respect access controls.** One direct attempt per portal per run; on a block or CAPTCHA, record
   it and switch channel. No CAPTCHA solving, no authentication bypass, no private APIs, no stolen
   sessions or cookies, no rate-limit evasion.
7. **Experience gate.** SDE-1 / Software Engineer / early-career Backend / Platform is primary.
   2–3 years required is a *stretch* only, stated as such. 3+ years or Senior/Staff/Lead/Principal
   is excluded from the main sections. Title alone never decides seniority — read the description.
8. **Truth about the candidate.** `~/job-search/my_resumes/knowledge_base.md` is the only source of
   truth for experience, dates and metrics. Internships are never presented as full-time
   experience. No technology is claimed because a JD mentions it.
9. **Quality over quantity.** Five verified roles beat thirty loose matches. If nothing new
   verifies, write "No verified new matches this week" and list still-open older roles.
10. **Persist in the same run.** The dated report, `ledger.json`, `sources.json` and
    `skills-gap.json` are all written before the run is reported as complete. A run that found
    roles but did not update the ledger is an incomplete run.
11. **Resume work is delegated, not reimplemented.** For roles scoring ≥80, dispatch the
    `job-search-resume-tailor` skill in a subagent with the brief from
    `templates/tailor-brief.md`. It must return a `.tex` **and** a compiled `.pdf`; record both
    paths. Do not build a second tailoring pipeline here.
12. **Research only.** Never apply, contact recruiters, send messages, or touch the LinkedIn
    profile. Writing resumes is the one permitted side effect, and only as specified in rule 11.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Run any part of the weekly cycle | `GUIDE.md` | Profile, targeting tiers, channel pipeline, scoring rubric, continuity, final checklist |
| Choose or sequence discovery channels; build `site:` queries | `references/discovery.md` | Multi-channel model, query grammar, stop-on-block rules, prohibited access |
| Search a specific portal; know its indexing and alert support | `references/portals.md` | All 8 primary + 7 secondary sources, per-portal fallback chains |
| Mine ATS job boards and company career portals | `references/ats.md` | Public Greenhouse/Lever/Ashby/SmartRecruiters APIs, Workday/SF/iCIMS patterns, extraction fields |
| Decide whether a role is verified, fresh, duplicate or a stretch | `references/verification.md` | Verification gate, freshness classes, dedup keys, expiry handling |
| Dispatch resume tailoring for a high-scoring role | `references/resume-tailoring.md` | Trigger, caps, variant mapping, subagent contract, persistence |
| Write the weekly report | `references/reporting.md` | Section A–G templates, audit table, dual coverage metrics |
| Read or write the persistent store | `references/ledger.md` | JSON schemas, read/upsert/close protocol, re-verification TTL |
| Fill the report | `templates/weekly-report.md` | Report skeleton |
| Brief a tailoring subagent | `templates/tailor-brief.md` | Self-contained payload contract |
| Compile and verify a resume | `scripts/compile_resume.sh` | LaTeX → mirrored `pdfs/` output, page/size/text checks, aux cleanup |
| Bootstrap a missing store | `templates/store-seed/` | Valid empty ledger, sources and skills-gap files |
| Query / update the store safely | `scripts/ledger.py` | `lookup`, `upsert`, `mark-closed`, `stats`, `coverage` |

## Workflow

1. **Resolve the store** at `~/job-search/my_resumes/job-intel/`. If any file is missing or invalid,
   recreate it from `templates/store-seed/`. Never abort on a fresh store.
2. **Load state** — `ledger.json`, `sources.json`, `skills-gap.json`. If `runs[]` is empty this is
   the first run: the period is the 7 days ending today and every discovery is new.
3. **Ground the candidate** — read `GUIDE.md`, then
   `~/job-search/my_resumes/description.txt` and `knowledge_base.md`.
4. **Channel 1 — public ATS feeds and company career portals** (`references/ats.md`). Highest yield
   and the only channel that doubles as verification. Target the priority companies with India
   engineering presence.
5. **Channel 2 — indexed sweep** — Google and Bing `site:` queries across all 8 mandatory portals
   for the query bank (`references/discovery.md`, `references/portals.md`).
6. **Channel 3 — alert emails** — parse everything in `job-intel/inbox/`, extract company/title/URL,
   treat as signals only, move files to `inbox/processed/` with a date prefix.
7. **Channel 4 — direct portal attempts** — Firecrawl first, `webfetch` fallback, one attempt per
   portal. Record the block and move on.
8. **Channel 5 — secondary sources** and public recruiter/company hiring announcements.
9. **Verify** every shortlisted role at the employer's official requisition
   (`references/verification.md`). Capture experience text, location, work mode, posting date,
   requisition ID, apply URL, compensation if disclosed.
10. **Reconcile** via `scripts/ledger.py` — dedup, freshness class, still-open vs new, stretch
    labelling, expired/removed exclusion.
11. **Score and bucket** into Sections A–F using `GUIDE.md` §4.
12. **Tailor** — for score ≥80 dispatch `job-search-resume-tailor` per
    `references/resume-tailoring.md`; it must return a `.tex` at
    `<company>/<company>_<role>.tex` and a PDF at `pdfs/<company>/<company>_<role>.pdf`; persist the
    JD and fit report under `job-intel/fits/<slug>/`; verify the PDF is one A4 page; aggregate
    missing keywords into `skills-gap.json`.
13. **Publish** — write `job-intel/runs/<YYYY-MM-DD>-weekly-report.md` from the template, update
    `ledger.json` and `sources.json`, then give a short chat summary that states both coverage
    metrics and any channel you could not use.

## Output location / deployment

Skill source: `~/dotfiles/skills/job-grabber/`. Deploy with `home-manager switch` in `~/dotfiles/`
to publish to `~/.config/opencode/skills/job-grabber/`.

Persistent store: `~/job-search/my_resumes/job-intel/` (committed to the repo).
Resumes and audits: `job-intel/fits/<company>_<role>/{jd.md,fit.md}`; tailored artifacts are written
by the tailor skill to `~/job-search/my_resumes/<company>/<company>_<role>.tex` (source) and
`~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf` (compiled).

## Tools

`read` / `write` / `edit` (store, reports, briefs), `shell` (`scripts/ledger.py`,
`scripts/compile_resume.sh`, inbox moves, directory bootstrap), `glob` / `grep` (inbox and store
inspection), `webfetch` (direct pages, ATS APIs), Firecrawl through `execute` (JS-heavy portals,
structured scrapes), `websearch` (indexed discovery), `question` (ambiguous company/role, missing
facts, blocked-source decisions), `subagent` (one `job-search-resume-tailor` run per high-priority
role).
