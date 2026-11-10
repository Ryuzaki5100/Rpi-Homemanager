---
name: job-grabber
description: ATS and career-portal mining reference for job-grabber — public Greenhouse, Lever, Ashby and SmartRecruiters board endpoints, Workday/SuccessFactors/iCIMS search patterns, large-employer career search endpoints, and the structured field set to extract. Loaded when mining public ATS feeds and official career portals.
---

# ATS and career portals

Scope: the public, documented-ish interfaces that return structured listings, and how to fall back
when an ATS exposes nothing machine-readable. Public board data only — never internal postings.

**Endpoints drift.** Treat every URL here as a starting point: confirm the response shape on the
first call, and if it fails, fall back to `site:` indexing of the employer's career domain. Never
report a schema you did not actually parse.

## 1. Public ATS APIs

### 1.1 Greenhouse

```
GET https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs?content=true
GET https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{job_id}
```

- `board_token` is the company slug visible in `boards.greenhouse.io/<token>`.
- `content=true` includes the HTML description — usually enough to apply the experience gate without
  a second fetch.
- Response `jobs[]`: `id`, `title`, `location.name`, `absolute_url`, `updated_at`, `content`,
  `metadata` (may include custom fields).
- Requisition ID → `id`.

### 1.2 Lever

```
GET https://api.lever.co/v0/postings/{company}?mode=json
```

- Response is an array of postings: `id`, `text` (title), `categories.location`,
  `categories.team`, `categories.commitment`, `createdAt`, `hostedUrl`, `descriptionPlain`,
  `lists` (requirement bullets).
- `mode=json` returns JSON; without it you get HTML.
- Posting date → `createdAt` (epoch ms).

### 1.3 Ashby

```
GET https://api.ashbyhq.com/posting-api/job-board/{org}
```

- Response `jobs[]`: `id`, `title`, `location`, `secondaryLocations`, `department`, `team`,
  `employmentType`, `jobUrl`, `publishedAt`, `descriptionHtml`.
- Public posting API only surfaces published roles — absence does not always mean closed; confirm
  via the jobUrl.

### 1.4 SmartRecruiters

```
GET https://api.smartrecruiters.com/v1/companies/{company}/postings?limit=100&offset=0
GET https://api.smartrecruiters.com/v1/companies/{company}/postings/{posting_id}
```

- List response `content[]`: `id`, `name`, `location.city/country`, `releasedDate`,
  `ref` (API URL), `company.identifier`.
- The detail call returns the full `jobAd` text; use it for the experience requirement.
- Paginate with `offset`; `totalFound` tells you when to stop.

## 2. Large-employer career endpoints

These are search backends behind the public careers UI. Some are documented, some are not — use them
as discovery, then open the requisition page before treating anything as verified.

| Employer | Pattern | Notes |
|---|---|---|
| Amazon | `GET https://www.amazon.jobs/en/search.json?base_query={q}&loc_query=India&result_limit=100` | Returns `jobs[]` with `title`, `location`, `id`, `posted_date`, `job_path`, `job_schedule_type` |
| Microsoft | `GET https://gcsservices.careers.microsoft.com/search/api/v1/search?q={q}&l=en_us&pg=1&pgSz=20&o=Relevance` | JSON search; `job_path`-style links under `careers.microsoft.com` |
| Google | `site:careers.google.com/jobs/results` | No documented public API; use indexed requisition pages and the careers search UI |
| Uber | `site:www.uber.com/global/en/careers/list` | Indexed requisitions carry the full description |
| Atlassian | `site:atlassian.com/company/careers` | Workday-backed; resolve to the Workday requisition |
| Others | `site:{company-domain}/careers "{title}" India` | Default fallback for every employer |

## 3. Workday

Workday tenants expose a JSON search endpoint behind the career site:

```
POST https://{tenant}.{wd1|wd3|wd5|wd12}.myworkdayjobs.com/wday/cxs/{tenant}/{site}/jobs
Content-Type: application/json

{"appliedFacets":{},"limit":20,"offset":0,"searchText":"backend engineer"}
```

- Response `jobPostings[]`: `title`, `externalPath`, `locationsText`, `postedOn`,
  `bulletFields` (often the requisition ID).
- Application URL = `https://{tenant}.{wdN}.myworkdayjobs.com/{site}{externalPath}`.
- `tenant` and `site` are visible in the public career URL — read them from the page, do not guess.
- Facet payloads vary per tenant; start with an empty `appliedFacets` and filter client-side.

## 4. SuccessFactors, iCIMS and the rest

No universal public API exists. Use these in order:

1. `site:{careers-domain} "{title}"` on Google and Bing — SuccessFactors and iCIMS requisition pages
   are usually indexed and render readably.
2. The public career-site search UI via Firecrawl when it is not JS-gated.
3. The employer's own job index page.

Record the ATS discovered (`successfactors`, `icims`, `workday`, `taleo`, `phenom`, `eightfold`)
so the next run can go straight to the right pattern.

## 5. Extraction field set

For every candidate record, capture:

| Field | Source | Required for verification |
|---|---|---|
| Job title | Posting | Yes |
| Company | Posting | Yes |
| Location (city, state/country) | Posting | Yes |
| Work mode | Posting text | When stated |
| Job description | Posting body | Yes — needed for experience gate |
| Requisition / posting ID | ATS field or URL | When present |
| Application URL | Official posting | Yes |
| Posting date | ATS date field | When present |
| Last updated date | ATS field | When present |
| Compensation | Explicit disclosure only | Never inferred |
| Experience requirement | Description text, quoted | Yes |
| Employment type | Posting | When stated |

If a required field is absent, the record stays an unverified lead.

## 6. Employer board discovery

To find a company's board token without guessing:

```
site:boards.greenhouse.io "{company}"
site:jobs.lever.co "{company}"
site:jobs.ashbyhq.com "{company}"
site:jobs.smartrecruiters.com "{company}"
site:{company}.wd*.myworkdayjobs.com
```

Then confirm the token by fetching the board root and checking the company name in the response —
board tokens are occasionally squatted or stale.

## 7. Rules

- **Public postings only.** No internal job boards, no referral-only links, no employee dashboards.
- **One confirmation open per requisition.** A list-endpoint hit is a lead; the requisition page is
  the verification.
- **Rate politely.** One request per board per run, sequential pagination, no parallel hammering.
- **Never invent a requisition ID** from a URL pattern. If it is not in the response, leave it empty.
- **Record the ATS** per company in `sources.json` so channel performance is measurable over time.
