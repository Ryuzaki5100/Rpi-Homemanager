---
name: job-grabber
description: Per-portal reference for job-grabber — the eight mandatory job portals and seven secondary sources, each with its indexed URL pattern, alert-email support, direct-access expectation, and fallback chain. Loaded when searching a specific portal.
---

# Portals

Scope: what each portal is good for, how to reach its listings without direct browsing, and what to
record when it blocks. Blocking behaviour changes; treat the "expected access" column as a starting
assumption to be corrected by what actually happens this run.

## 1. Mandatory primary portals (8)

| Portal | Domain | Best for | Indexed URL pattern | Alerts | Expected direct access |
|---|---|---|---|---|---|
| LinkedIn Jobs | linkedin.com/jobs | MNCs, GCCs, recruiters, startups | `site:linkedin.com/jobs/view` | Yes | **Directly searchable** — guest search + guest job pages over a plain HTTP fetch, no login (§4) |
| Naukri | naukri.com | Indian employers, GCCs, enterprise backend | `site:naukri.com/job-listings` | Yes | **Directly searchable** — search and detail pages render through Firecrawl, no login (§4) |
| Instahyre | instahyre.com | Curated product-company roles | `site:instahyre.com/job-` | Limited | Usually login-walled |
| Cutshort | cutshort.io | Startups and product companies | `site:cutshort.io/job` | Yes | Partial |
| Hirist | hirist.tech | Tech-specific engineering roles | `site:hirist.tech/job-` | Yes | Partial |
| Wellfound | wellfound.com | Startups, remote, disclosed comp | `site:wellfound.com/jobs` | Yes | Often login-walled |
| Indeed India | in.indeed.com | Broad discovery, syndicated listings | `site:in.indeed.com/viewjob` | Yes | Often partial |
| Foundit | foundit.in | Enterprise, IT, GCC hiring | `site:foundit.in/job-` | Yes | Partial |

## 2. Secondary portals (7)

| Portal | Domain | Best for | Indexed URL pattern | Alerts | Notes |
|---|---|---|---|---|---|
| Glassdoor | glassdoor.co.in | Discovery + salary/review context | `site:glassdoor.co.in/job-listing` | Yes | Useful for comp context only, never as a verification source |
| Internshala | internshala.com | Fresher / early-career | `site:internshala.com/internship` | Yes | Low priority; check for early-career drives only |
| iimjobs | iimjobs.com | Selective enterprise/finance tech | `site:iimjobs.com/j/` | Yes | Occasionally surfaces strong GCC roles |
| Unstop | unstop.com | Hiring challenges, off-campus drives | `site:unstop.com/jobs` | Limited | Watch for company-hosted drives |
| Google Jobs | google.com | Cross-portal discovery | n/a — query the Jobs surface directly | No | Good for long-tail roles; always resolve to the employer |
| Shine | shine.com | Additional enterprise/IT | `site:shine.com/job` | Yes | High syndication duplication |
| TimesJobs | timesjobs.com | Additional Indian tech roles | `site:timesjobs.com/job-detail` | Yes | High syndication duplication |

## 3. Per-portal fallback chain

For every portal in either table, execute in this order and stop at the first that produces usable
listings:

1. **Indexed sweep** — Google `site:` query from §3.4 of `references/discovery.md`, then the same on
   Bing. Fastest way to enumerate live listings without touching the portal.
2. **Alert emails** — if the user has a saved search for the portal, read the exported mail in
   `job-intel/inbox/`. These usually contain the canonical listing URL and posting date.
3. **Direct attempt** — open the portal's own search URL and run at least one real query (see §3.1
   for the tested tool per portal). Try the portal's documented tool first and the other tool second;
   a tool-level refusal is not a portal block.
4. **Employer resolution** — take whatever listing URL was found, identify the employer, and verify
   at the employer's own requisition. Never report the portal URL as the application link when an
   official one exists.

If all four fail, record `Inaccessible` with the reason and move on.

### 3.1 Tested access methods

Access method is per-portal and per-tool. These were verified live on 2026-11-11 and are the
starting point for every run; re-check if a run disagrees.

| Portal | Works with | Fails with | Notes |
|---|---|---|---|
| LinkedIn | **plain HTTP fetch** (browser user-agent) | Firecrawl ("we do not support this site") | Guest search and guest job-view pages are both fully readable |
| Naukri | **Firecrawl** (search + detail) | `webfetch` (403) | Detail pages are public; only *applying* needs login |
| Instahyre | Firecrawl (partial) | — | JavaScript shell; few cards carry an employer requisition |
| Cutshort | Firecrawl | — | Listing page renders; usually senior-heavy |
| Hirist | Firecrawl (filters only) | — | Rows frequently do not render |
| Wellfound | Firecrawl (indexed role pages) | — | `/role/r/...` paths may 404 |
| Indeed | Firecrawl | — | Syndicated; no employer requisition IDs |
| Foundit | — | both | Cookie-consent shell only; rely on indexing |

**Rule: a tool refusing a domain is not a portal being inaccessible.** Try the other tool before
recording any access classification, and record which tool actually worked in `limitation`.

## 4. Portal-specific notes

**LinkedIn** — the highest-signal source for product companies and direct recruiter postings, and
the best value-per-minute channel in the entire pipeline. The **guest** surfaces are public and need
no login:

- Search: `https://in.linkedin.com/jobs/search?keywords=<q>&location=<loc>&f_TPR=r604800&f_E=2,3`
  — `f_TPR` filters to the past week (`r604800`), `f_E=2,3` restricts to entry level and associate,
  `f_WT=2` to remote. Returns ~25 cards per page with title, company, location and posting date.
- Job page: `https://in.linkedin.com/jobs/view/<id>` — full JD, seniority level, employment type,
  relative posting age and applicant count.

Both respond to a plain HTTP fetch with a normal browser user-agent. Firecrawl refuses the domain, so
do not conclude the portal is blocked from a Firecrawl failure. Extract cards from
`data-entity-urn="urn:li:jobPosting:<id>"` blocks. The undocumented `jobs-guest/...` JSON endpoints
remain off-limits; the public HTML pages above are not. Keep volume modest — a handful of queries per
run, no pagination crawls.

**Naukri** — strongest for GCCs and enterprise Java/Spring roles, and its listings expose experience
bands explicitly, which makes the experience gate easy to apply. Search by experience range rather
than title, e.g. `naukri.com/software-engineer-jobs-in-bangalore?experience=2&jobAge=7`. Listing URLs
carry the company, band and a date stamp (`...-company-city-1-to-3-years-091126007243`), so a result
page can be triaged before opening anything. Both search and detail pages render through Firecrawl;
`webfetch` gets a 403. The detail page gives company, band, posted age, applicant count and the full
JD, but **applying requires login** — treat Naukri as a lead source and verify at the employer, which
is where the requisition and the apply link must come from.

**Instahyre** — curated and product-focused, but almost entirely behind a candidate login. Expect
`Inaccessible` and rely on indexing plus employer resolution.

**Cutshort** — startup-heavy; posting quality varies. Indexed listing pages usually carry the
employer name and experience band.

**Hirist** — developer-specific; good for Java backend and infrastructure titles. Heavy duplication
with Naukri and Indeed — dedup before counting.

**Wellfound** — the only major portal that routinely discloses compensation ranges. When it does,
record the exact range and label it as portal-disclosed.

**Indeed India** — enormous volume, worst signal-to-noise, heavy syndication. Use for coverage, then
aggressively deduplicate by employer + requisition. Never treat an Indeed card as verification.

**Foundit** — enterprise and GCC coverage; useful for roles that never surface on LinkedIn.

**Glassdoor** — salary and review context, plus discovery. Never the verification source, and never
quote a salary estimate as if it were a disclosed range.

**Internshala / Unstop** — early-career drives and company challenges. Check only for exceptional
full-time product roles; ignore stipend-only internships.

**Shine / TimesJobs** — syndication. Expect the same role under three different employer names.
Deduplicate by requisition ID and by canonical employer URL.

## 5. Recording

For each portal, write into `sources.json`:

- `access_status` — one of the seven classifications, with `limitation` filled when not "Directly
  searched".
- `indexed` — true if a `site:` sweep was actually run, false otherwise.
- `alerts` — true if inbox emails from this portal were processed.
- `direct_attempted` — true if a direct fetch was made, regardless of outcome.
- `queries[]` — the actual queries executed. This is the evidence that the source was searched.
- `found` / `verified` — counts, deduplicated.

A portal with zero found is not a failure — record it accurately and keep going.
