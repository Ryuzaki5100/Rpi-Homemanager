---
name: job-grabber
description: Multi-channel discovery model for job-grabber — channel definitions, search-engine site: query grammar for Google and Bing, direct-access attempt limits, prohibited access methods, and the source access classification vocabulary. Loaded when choosing or sequencing discovery channels.
---

# Discovery channels

Scope: how a vacancy may be *found*, and how each finding is labelled. Verification — proving it is
open — is a separate step and lives in `references/verification.md`.

## 1. The five channels

| # | Channel | What it is | Trust level |
|---|---|---|---|
| 1 | Public ATS feeds and official career portals | Greenhouse/Lever/Ashby/SmartRecruiters board APIs, company career search | Discovery **and** verification |
| 2 | Search-engine indexing | Google and Bing `site:` queries targeting job portals | Discovery only |
| 3 | Alert emails | Saved-search notifications exported to the inbox | Discovery only |
| 4 | Direct portal browsing | Opening the portal itself | Discovery only |
| 5 | Secondary sources and announcements | Glassdoor, iimjobs, Unstop, recruiter/company posts | Discovery only |

Channel 1 is preferred for two reasons: it yields structured fields, and the record it returns is
already at the employer's own source, so verification is often a re-read rather than a second lookup.

## 2. Channel ordering

Always run in this order and stop escalating once a role is verified:

1. ATS feeds + career portals → 2. indexed sweep → 3. alert emails → 4. direct portals →
5. secondary sources.

Rationale: the order is roughly the inverse of blocking risk. Spending the first hour of a run on
LinkedIn direct browsing wastes the budget that ATS queries would have used productively.

## 3. Query bank

### 3.1 Titles

Software Engineer · Software Development Engineer · SDE-1 · SDE-2 · Software Engineer I ·
Software Engineer II · Backend Engineer · Backend Software Engineer · Java Developer ·
Java Backend Engineer · Platform Engineer · Infrastructure Engineer · Cloud Engineer ·
Distributed Systems Engineer · Microservices Engineer · Data Platform Engineer ·
Data Infrastructure Engineer · AI Infrastructure Engineer · AI Platform Engineer · RAG Engineer ·
Retrieval Engineer · Applied AI Engineer · Agentic Systems Engineer · Member of Technical Staff ·
Product Engineer · Systems Software Engineer · Developer Productivity Engineer ·
Site Reliability Engineer

### 3.2 Technologies

Java · Spring Boot · Go · Python · Kubernetes · Docker · Terraform · GCP · AWS · Azure ·
Kafka · Pub/Sub · Redis · Spanner · PostgreSQL · distributed systems · event-driven ·
microservices · data pipelines · vector database · RAG · embeddings · knowledge graph ·
LLM orchestration · observability

### 3.3 Locations

Bengaluru · Bangalore · Hyderabad · Pune · Chennai · Gurugram · Gurgaon · Noida · Mumbai ·
India · Remote India

### 3.4 Indexed query grammar

Combine with `OR` and site restriction. Keep queries short — long Boolean strings get truncated or
ignored by both engines.

```
site:<portal-domain> "<title>" ("Bengaluru" OR "Bangalore" OR "Hyderabad") after:<YYYY-MM-DD>
site:<portal-domain> ("Java" OR "Spring Boot") ("SDE-1" OR "Software Engineer")
site:<portal-domain> "early career" "India" backend
site:<company-domain>/careers "<title>" India
```

- `after:` on Google is reliable for recency; Bing honours it loosely — cross-check the posting date.
- Run each portal's queries on **both** engines; results differ substantially, and a portal blocked
  to direct browsing is frequently still fully indexed.
- Add one `site:` query per Priority A/B company domain alongside the portal sweeps.
- De-duplicate across engines by canonical URL before opening anything.

Where a portal has a working direct surface, prefer its own filters over `site:` — they are fresher
and complete. LinkedIn guest search is the clearest case:

```
https://in.linkedin.com/jobs/search?keywords=<q>&location=<city>&f_TPR=r604800&f_E=2,3
```

`f_TPR=r604800` = past week, `f_E=2,3` = entry level + associate, `f_WT=2` = remote. Naukri exposes
the experience band directly: `naukri.com/<title>-jobs-in-<city>?experience=2&jobAge=7`.

## 4. Direct-access attempts

- **One attempt per portal per run** means one access *session*: open the portal's search surface and
  run the queries that matter. It does not mean one HTTP request — reading several result cards or
  job pages within that session is normal browsing.
- **Try both tools before calling a portal blocked.** Firecrawl and a plain fetch fail on different
  domains; a refusal from one is evidence about the tool, not about the portal. LinkedIn only works
  with a plain fetch, Naukri only with Firecrawl (`references/portals.md` §3.1).
- A login wall, CAPTCHA, "verify you are human", or an empty JS shell on **both** tools counts as the
  attempt used.
- Record the exact failure mode and **which tool** produced it. "Firecrawl refuses the domain" and
  "login required to search" are different findings, and only the second is a portal limitation.
- After a genuine block, never retry in the same run, never rotate user agents or IPs, never seek an
  alternate undocumented endpoint.
- **Public guest surfaces are fair game; authenticated ones are not.** LinkedIn's guest search and
  guest job pages are public HTML. Its `jobs-guest/...` JSON endpoints, and anything reached with
  exported cookies, are not.

## 5. Prohibited access — absolute

Do not:

- solve or outsource CAPTCHAs;
- authenticate with the user's credentials, session cookies, or tokens;
- use private, undocumented or internal APIs, or scraped API keys;
- evade rate limits by rotating identity, proxies, or timing;
- scrape behind a paywall, login, or "members only" gate;
- retrieve unpublished, internal, or restricted vacancies;
- contact recruiters or candidates to obtain listings.

If legitimate discovery cannot reach a vacancy, it does not go in the report. That is the correct
outcome, not a limitation to work around.

## 6. Access classification

Assign exactly one per source per run:

| Classification | Meaning |
|---|---|
| Directly searched | The source was opened and real queries were run there |
| Indirectly searched through indexed listings | The portal was covered via Google/Bing `site:` queries only |
| Searched through email alerts | Coverage came from exported alert emails |
| Searched through public ATS feeds | Coverage came from the organisation's public ATS board |
| Partially accessible | Opened, but search/auth/index limits reduced real coverage |
| Inaccessible | Could not be accessed or investigated at all |
| Not searched | Not attempted this run |

Rules:

- A portal is **not** "directly searched" because its homepage loaded. A real query must have run.
- "Indirectly searched" **counts** toward discovery coverage and **never** toward direct access.
- Opening a page and reading zero usable listings is `Partially accessible`, not `Directly searched`.
- "Not searched" is a legitimate, honest value. Never upgrade it.
- **Never record `Inaccessible` on the strength of one tool's failure.** Retest with the other tool
  first; a Firecrawl refusal and a site-level block are different findings (see §4 and
  `references/portals.md` §3.1). Mis-classifying a readable portal costs the whole run's coverage
  metric and its best leads.
- When access is partial, name the precise limiter — login wall on detail pages, JS-rendered result
  rows, syndicated cards with no employer requisition — not just "partial".

## 7. Channel bookkeeping

Per source, record: direct status, whether indexing was investigated, whether alerts were processed,
whether an ATS feed was used, roles discovered, roles verified. These six fields feed the audit table
in `references/reporting.md` and the `sources.json` schema in `references/ledger.md`.

For each *vacancy*, keep every channel it was seen on in `discovery_channels[]`. Three channels
finding the same requisition is one record with three channels — it is not three discoveries and must
not inflate the unique-opportunity count.
