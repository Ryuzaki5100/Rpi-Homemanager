---
name: job-grabber
description: Full weekly playbook for job-grabber — candidate profile, targeting tiers, experience gates, multi-channel discovery pipeline, 100-point scoring rubric, continuity rules and the pre-publish checklist. Loaded on demand by the job-grabber SKILL.md router.
---

# job-grabber — weekly playbook

Scope: everything needed to run one weekly cycle end to end. Channel mechanics live in
`references/discovery.md`, `references/portals.md` and `references/ats.md`; verification, reporting
and storage mechanics live in their own references. This file is the *what* and *why*; the
references are the *how*.

- §1 Candidate profile
- §2 Targeting: roles, companies, geography, experience gates
- §3 The weekly pipeline
- §4 Scoring and bucketing
- §5 Continuity and history
- §6 Pre-publish checklist

---

## §1 Candidate profile

### 1.1 Professional facts

| Fact | Value |
|---|---|
| Current employer | Sabre |
| Current title | Software Engineer |
| Full-time experience | ~1 year (full-time from August 2025) |
| Internships | Sabre (~6 months, Jan–Jul 2025), Wells Fargo (~2 months) |
| Total exposure including internships | ~1.5 years |
| Education | B.Tech CSE, Information Security specialisation, VIT Vellore |
| Current location | Bengaluru, India |

**Never treat internships as full-time experience** in eligibility reasoning. When an employer's
filter plausibly counts total experience, say so explicitly in the "potential concerns" field.

### 1.2 Engineering evidence (what may be claimed)

Backend: Java (primary professional language), Spring Boot / Spring Cloud microservices, REST APIs,
event-driven architecture, distributed service workflows, Redis (request sequencing, cache-aside),
Google Cloud Pub/Sub, Google Cloud Spanner, Couchbase, SQL.

Cloud & platform: GCP, Kubernetes, Docker, Terraform, GitHub Actions, CI/CD pipelines,
infrastructure automation, Nix / devenv reproducible builds, production deployment and on-call.

Data: Pub/Sub message flows, batch processing with thread pools, GCS dual-bucket archival and diffing,
schedule/override data modelling, 333-day schedule windows, data-consistency comparison work.

AI engineering (engineering side, **not** ML research): Google ADK agent orchestration
(main-agent/sub-agent routing over JIRA + GCP logs), MCP server + playbook-driven tool routing,
GitHub Copilot CLI plugin, LLM-powered documentation generation, RAG/knowledge-graph/vector-DB
interests without production RAG delivery on record.

Developer productivity: 12–13 repos migrated to GitHub Actions CI (~50% build-time reduction),
6 services upgraded JDK 8 → 17, nixvim monorepo IDE with Bazel/Maven dependency graph scoping.

**Do not claim:** model training, ML research, deep-learning frameworks, production RAG systems,
Kafka/Spark/Flink in production, or any technology absent from `knowledge_base.md`.

### 1.3 Career direction (ranking used when scores tie)

1. Backend engineering at strong product companies.
2. Distributed systems / large-scale backend.
3. Platform engineering and cloud infrastructure.
4. Data infrastructure and data platforms.
5. AI infrastructure and production RAG engineering.
6. Backend-oriented AI engineering and agentic systems.

Language flexibility is real: a Go or Python infrastructure role can outrank a Java role if the
systems work is stronger. Never score down solely for a non-Java stack.

---

## §2 Targeting

### 2.1 Role categories

| Tier | Category | Representative titles |
|---|---|---|
| 1 | Core backend | Software Engineer, SDE-1, SDE-2 (if compatible), Backend Engineer, Java Developer, Microservices Engineer, Distributed Systems Engineer, API Platform Engineer |
| 2 | Platform / infra | Platform Engineer, Infrastructure Software Engineer, Cloud Engineer, Developer Productivity, Internal Developer Platform, CI/CD Platform, Kubernetes Platform, engineering-heavy SRE |
| 3 | Data infrastructure | Data Platform Engineer, Data Infrastructure Engineer, Streaming Infrastructure, Distributed Data Systems, Database Infrastructure, Data Pipeline Engineer |
| 4 | AI infrastructure | AI Infrastructure, AI Platform, RAG Engineer, Retrieval Infrastructure, LLM Infrastructure, Agentic Systems Engineer, Knowledge Graph Engineer, ML Platform (infra-oriented), Applied AI with real backend depth |

For Tier 4, demand engineering substance: ingestion, indexing, retrieval/reranking, orchestration,
evaluation, observability, scale, reliability, productionisation. A thin "call an LLM API and build
CRUD around it" role is **not** Tier 4 — score it low or exclude it.

Avoid as primary targets: manual ops, IT support, routine sysadmin, ticket-based infrastructure
maintenance, QA-only roles, and consultancies placing engineers on client sites.

### 2.2 Company prioritisation

**Priority A — global product/tech with India engineering:** Google, Microsoft, Amazon, Atlassian,
Adobe, Salesforce, Uber, Intuit, LinkedIn, Stripe, Confluent, Databricks, Snowflake, Rubrik, NVIDIA,
Cisco, ServiceNow, Oracle, SAP, GitHub, Cloudflare, Akamai, Expedia, Booking Holdings, Walmart
Global Tech, Qualcomm, AMD, Broadcom, Bloomberg, JPMorgan, Goldman Sachs, Visa, Mastercard,
Morgan Stanley — plus comparable organisations discovered during the run.

**Priority B — Indian product companies:** PhonePe, Razorpay, Flipkart, Swiggy, Meesho, Groww,
Zepto, CRED, Navi, Dream11, Zomato/Eternal, Paytm, BrowserStack, Postman, Freshworks, Chargebee,
InMobi, Jio Platforms, MakeMyTrip, Juspay, ShareChat, Porter.

**Priority C — engineering-led GCCs and financial institutions:** Wells Fargo, American Express,
Deutsche Bank, Barclays, HSBC, Fidelity, Target, Tesco Technology, Philips, GE HealthCare, Siemens,
Shell, Mercedes-Benz R&D India, Bosch Global Software Technologies. Judge by actual engineering
responsibilities, never by brand alone.

**Priority D — selective startups:** credible product with real customers, meaningful engineering
complexity, strong technical leadership, funding or revenue, competitive pay, real ownership.
Preferred domains: developer infrastructure, AI infrastructure, data platforms, cloud tooling,
fintech infrastructure, enterprise software, distributed systems. Exclude vague early-stage roles
with weak pay or unclear business models.

The list is a starting point, not a boundary. Add comparable employers with India engineering
presence and note them under §F "companies to add to the target list".

### 2.3 Geography

Priority: Bengaluru → Hyderabad → Pune → Chennai → Gurugram/NCR → Noida → Mumbai → other Indian
hubs. Include fully remote roles open to India-based candidates, hybrid, on-site, and multi-city
postings. Record the real location, the work arrangement, and whether remote is *explicitly stated*
— never infer remote from company culture. International roles only when the posting explicitly
accepts India-based candidates.

### 2.4 Experience gates

| Band | Requirement in the listing | Classification |
|---|---|---|
| Excellent | 0–1 years, new grad, early career, "or equivalent demonstrated ability" | Primary |
| Good | 1–2 years, or 2 years where the text is not strict about full-time | Primary |
| Stretch | 2–3 years, or an SDE-2 with a modest gap but strong technical alignment | Section D only, gap stated |
| Poor | 3–5+ years strictly required; Senior/Staff/Principal/Lead/Manager; ML research; mandatory domain expertise absent | Exclude from A–E |

When the requirement is ambiguous, quote the exact phrasing in the report rather than resolving it
in the candidate's favour. Filter on total experience (≈1.5 years) only when you flag that
internships are being counted.

---

## §3 The weekly pipeline

Follow the §H discovery order: cheapest high-signal channels first, blocked portals last.

### 3.1 Bootstrap and state (steps 1–3 of the workflow)

Store at `~/job-search/my_resumes/job-intel/`. Validate `ledger.json`, `sources.json`,
`skills-gap.json`; recreate from `templates/store-seed/` if absent or unparseable. Read the ledger
into working memory as a `url → record` and `company|title → record` index via
`python3 scripts/ledger.py stats`.

Compute the reporting period: from the newest `sources.json` run date to today. On the first run,
the 7 days ending today, stated as the first run.

### 3.2 Channel 1 — ATS feeds and career portals

`references/ats.md` holds the endpoints. Query the public boards for every target company that uses
Greenhouse, Lever, Ashby or SmartRecruiters; hit the official career search for Google, Microsoft,
Amazon, Uber and the rest; apply India location and early-career filters. This channel is both
discovery and verification — a hit here is already at the employer's source.

Record for each company investigated: portal, query used, roles found, roles relevant.

### 3.3 Channel 2 — indexed sweep

For each of the 8 mandatory portals build `site:` queries from the query bank in
`references/discovery.md` (§3) and run them on Google **and** Bing. Record which portals returned
usable indexed listings. This is what keeps discovery coverage high when direct browsing is blocked.

### 3.4 Channel 3 — alert emails

Read every file in `job-intel/inbox/` (`.eml`, `.txt`, `.md`, `.html`). Extract company, title,
location, URL, date. Treat each as a lead only — never as proof of availability. Follow the original
listing, then the employer's requisition. After processing, move the file to
`inbox/processed/YYYY-MM-DD-<original-name>` and record the alert source in `ledger.json` and
`sources.json`. If the inbox is empty, that is a normal state: report the channel as "no alerts
present", not as inaccessible.

### 3.5 Channel 4 — direct portal attempts

Open each portal's own search surface and run a real query. Try **both** tools before judging access
— Firecrawl and a plain fetch fail on different domains, so a refusal from one says nothing about the
portal (`references/portals.md` §3.1 lists the tested method per portal). On a genuine login wall,
CAPTCHA or blocked shell on both tools, record `Partially accessible` or `Inaccessible` with the
concrete reason and stop. Do not retry, do not rotate user agents, do not look for alternate
unauthorised endpoints.

### 3.6 Channel 5 — secondary sources

Glassdoor, Internshala, iimjobs, Unstop, Google Jobs, Shine, TimesJobs, plus public recruiter and
company hiring announcements. Lower weight; use for coverage and for roles missed elsewhere.

### 3.7 Verification, reconciliation, scoring

Verify (see `references/verification.md`), reconcile with `scripts/ledger.py`, then score per §4.
Anything that fails verification moves to "unverified leads", explicitly labelled.

### 3.8 Tailoring dispatch

Per `references/resume-tailoring.md`: score ≥80 → fit analysis plus tailored `.tex`; 70–79 → fit
analysis only; below 70 or Section D → nothing. Cap 5 resumes per run, highest score first.

### 3.9 Publish

Fill `templates/weekly-report.md`, compute both coverage metrics, update all three store files,
then summarise in chat. State plainly which channels were unavailable and what that means for
completeness.

---

## §4 Scoring and bucketing

Score every verified role out of 100. Use judgement, do not inflate.

| Criterion | Weight |
|---|---:|
| Technical alignment with the candidate's evidence | 25 |
| Engineering quality and complexity of the work | 20 |
| Experience-level compatibility | 20 |
| Company reputation and engineering culture | 15 |
| Compensation potential | 10 |
| Career growth and future relevance | 10 |

Bands: 90–100 exceptional · 80–89 strong · 70–79 worth considering · 60–69 moderate · <60 exclude
from the main roundup (may appear as an unverified lead or be dropped silently from the report).

Calibration anchors — apply these before finalising scores:

- A prestigious company with a 3–5 year requirement and thin technical overlap must not outrank a
  genuinely suitable early-career role at a smaller engineering-led company. Experience
  compatibility and technical alignment cap the score regardless of brand.
- A role materially outside the candidate's evidence base scores ≤65 even if the company is ideal.
- A Tier 4 AI role with real retrieval/infrastructure work scores in the 75–90 band; a thin LLM
  wrapper scores ≤55.
- Java/Spring/PubSub/Redis/distributed-systems overlap is the strongest alignment signal; GCP +
  Kubernetes + Terraform platform work is second; data streaming without production evidence is
  partial.
- Compensation never enters the score unless disclosed; "Not disclosed" is neutral, not zero.

Additional qualitative checks that should move a score by ±5 at most: real system ownership,
architecture involvement, distributed-systems exposure, production infrastructure, 5–10 year skill
durability, and a credible path toward senior backend / platform / data / AI infrastructure.

Bucketing:

- **A** — highest priority, ordered by score, only verified.
- **B** — backend, distributed systems and platform roles not already in A.
- **C** — data infrastructure and AI engineering; state whether each is genuine infrastructure work
  or application development with AI API calls.
- **D** — stretch roles, with the exact gap named.
- **E** — selective startups meeting §2.2 Priority D. If none qualify, say so explicitly.
- **F** — market intelligence (§4.2).

### 4.1 Market intelligence inputs

Keep §F evidence-based and short. Answer: which companies are hiring early-career engineers; which
categories produced the most relevant openings; whether Java backend roles are frequent; whether
real AI-infra or data roles exist; which new companies to add; which recurring skills the candidate
should learn; whether the market is tightening or loosening; which portals and channels produced the
most verified results.

Add the recurring-requirements view from `skills-gap.json`: requirements appearing in ≥3 verified
roles that the candidate's evidence does not currently cover.

### 4.2 Never do this

- Never inflate a score to justify including an interesting-but-unsuitable company.
- Never present a stretch role as eligible.
- Never fill Section E with startups that fail the §2.2 criteria.
- Never manufacture roles to make the report look productive.

---

## §5 Continuity and history

The ledger is the memory. Conversation history is not.

For every posting track: company, title, requisition ID, apply URL, location, work mode, category,
experience text, seniority fit, score, first discovered date, original posting date, last verified
date, previous reporting status, discovery channels, verification source, whether it was reported
before, whether it is still open, and any resume/fit artifacts.

Rules per run:

1. Search for genuinely new postings first; do not re-derive the whole market.
2. Recheck high-priority postings only when `last_verified` is older than the TTL in
   `references/ledger.md` (default 14 days), or when the ledger says `status: unknown`.
3. Detect closed or removed postings and `mark-closed` them.
4. Detect meaningful updates (new requisition ID, changed title/location/experience) and report
   them as *Reposted / Updated*, not as new.
5. Keep older still-open roles visible in a clearly labelled section; never re-present them as new.
6. Never delete history — closed records stay for dedup and for market analysis.

Source history lives in `sources.json`: every run appends per-source `direct_status`, `indexed`,
`alerts`, `ats_feed`, `found`, `verified`, plus a rolling `source_performance` block. Use it to
prioritise channels, but never abandon a portal permanently because of one weak week.

---

## §6 Pre-publish checklist

Run this before writing the report. Any unchecked item must be disclosed in the report itself.

- [ ] All three store files read, validated, and updated this run.
- [ ] All 8 primary portals attempted or covered through an alternative channel.
- [ ] Secondary sources investigated where accessible.
- [ ] Public ATS feeds queried for every target company that exposes one.
- [ ] Official career portals checked for Priority A/B companies with India roles.
- [ ] Google **and** Bing indexed sweeps run across the mandatory portals.
- [ ] Alert inbox processed (or reported as empty).
- [ ] Alternative titles and synonyms searched, not just exact titles.
- [ ] Bengaluru and other priority locations covered.
- [ ] Every shortlisted role verified at the employer's source this run.
- [ ] Experience requirements read from the description, not the title.
- [ ] Duplicates collapsed; previously reported roles not re-presented as new.
- [ ] Expired or removed postings excluded and marked closed.
- [ ] Application links opened, not assumed.
- [ ] Compensation only stated when disclosed, with base vs total made explicit.
- [ ] Both coverage metrics computed separately and reported.
- [ ] Unverified leads clearly separated from verified roles.
- [ ] Tailoring dispatched only for score ≥80, cap respected, fit reports persisted.
- [ ] Every dispatched role returned both a `.tex` and a `.pdf`; each PDF verified as one A4 page
      and cleanly text-extractable, or the failure reported.
- [ ] `skills-gap.json` updated from this run's fit matrices.

If a checklist item could not be completed, say so in the report. A transparent 70% coverage report
is worth more than a fabricated 100%.
