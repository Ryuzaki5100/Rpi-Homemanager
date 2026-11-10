---
name: job-grabber
description: Report specification for job-grabber — the header block, Sections A through G, per-role field list, source-coverage audit table, dual coverage metrics, channel-effectiveness table and unverified-lead section. Loaded when writing the weekly report.
---

# Weekly report specification

Scope: the exact structure of `job-intel/runs/<YYYY-MM-DD>-weekly-report.md`. Fill
`templates/weekly-report.md`; this file defines what each part must contain.

## 1. Header block

```
# Weekly Engineering Opportunities Report

**Reporting period:** <start> – <end>
**Research date:** <today>
**Run:** first run | run #N (previous: <date>)
**Candidate profile:** ~1 year full-time product-company experience (Sabre) + ~8 months internships
**Locations prioritised:** Bengaluru, Hyderabad, Pune, Chennai, NCR, Mumbai, remote India
**Total verified opportunities:** X
**Newly posted:** X | **Still open (previously reported):** X | **Stretch:** X
**Portal discovery coverage:** X/8 | **Direct portal access coverage:** X/8
**Sources inaccessible:** <list or none>
```

On the first run, `Run:` says `first run` and the comparison fields are omitted — do not invent a
previous period.

## 2. Per-role fields

Every role in Sections A–D carries these fields, in this order:

- **Priority:** High / Medium.
- **Match score:** XX/100.
- **Role category:** Backend / Platform / Infrastructure / Data / AI.
- **Location:** city, state. Multi-city roles list all.
- **Work mode:** Remote / Hybrid / On-site / Not disclosed — only as stated in the posting.
- **Experience requirement:** quoted or closely paraphrased from the description.
- **Posting date:** exact date, or `Posting date not disclosed`.
- **Status:** NEW / RECENT / OLDER — STILL OPEN / REPOSTED / UPDATED.
- **Technical stack:** technologies named in the listing.
- **Why it fits:** specific overlap with documented candidate evidence.
- **Potential concerns:** experience gap, mandatory skills, domain requirements.
- **Compensation:** disclosed range only, labelled base vs total, else `Not disclosed`.
- **Job requisition ID:** or `Not disclosed`.
- **Discovery source:** channel + portal (e.g. `indexed (LinkedIn)`).
- **Verification source:** the employer page actually opened.
- **Application:** direct employer link.
- **Resume:** `path` or `eligible — not tailored this run`.
- **PDF:** `path` (N pages) or `compile failed — <error>` or `—`.
- **Fit report:** `path` or `—`.

Followed by two or three sentences on why the role deserves attention.

## 3. Sections

### Section A — Highest priority

Verified roles scoring highest, ordered strongest to weakest. Only roles that pass the verification
gate. This is the section the user reads first, so keep the prose tight and specific.

### Section B — Backend, distributed systems and platform

Verified roles not already in A. Focus: Java/Spring, microservices, event-driven systems, messaging,
caching, databases, cloud infrastructure, Kubernetes, CI/CD platform work, developer infrastructure.

### Section C — Data infrastructure and AI engineering

Data platforms, streaming, pipelines, RAG, knowledge graphs, vector databases, AI infrastructure,
LLM orchestration, agentic systems. For each, state explicitly whether the work is **genuine
infrastructure/data engineering** or **application development with AI API integration**.

### Section D — Stretch opportunities

Roles with strong alignment but a higher stated requirement. Each entry names the exact gap and why
it is still worth attempting. No tailored resumes here unless the user asks.

### Section E — Selective startups

Only those meeting `GUIDE.md` §2.2 Priority D. For each: company and product, funding/revenue if
reliably known, engineering opportunity, technical fit, experience requirement, location,
compensation if disclosed, direct link. If none qualify, write
"No qualifying startup opportunities this week."

### Section F — Market intelligence

Short and evidence-based. Answer:

1. Which companies are actively hiring early-career engineers?
2. Which engineering categories produced the most relevant openings?
3. Are Java/Spring backend roles appearing frequently?
4. Are there meaningful AI-infrastructure or data-engineering openings, or mostly wrappers?
5. Which new companies should be added to the target list?
6. Which recurring skills should be learned next — the `skills-gap.json` view
   (`occurrences ≥ 3`, `coverage_ratio < 0.5`).
7. Is the market tightening or loosening for ~1 year of full-time experience?
8. Which portals and which channels produced the most verified listings?

### Section G — Weekly conclusion

- Top 3 opportunities to prioritise, with one line of justification each.
- Companies worth monitoring even if nothing is open today.
- Skill gaps observed across the week's listings.
- A brief assessment of the hiring landscape.
- If nothing new verified: **"No verified new matches this week."** followed by genuinely relevant
  still-open older roles, clearly marked as older.

### Unverified leads

Separate, explicitly labelled, never counted in totals. For each: what was found, where, why it could
not be verified, and what would resolve it.

## 4. Source-coverage audit table

Mandatory in every report. One row per source, including sources that were not searched.

| Source | Tier | Channels used | Direct status | Indexed | Alerts | ATS feed | Found | Verified |
|---|---|---|---|---|---|---|---|---|
| LinkedIn Jobs | Primary | Direct, Indexed, Alerts | Directly searched | Yes | Yes | No | 4 | 2 |
| Greenhouse boards | ATS | ATS feed | Directly searched | No | No | Yes | 6 | 6 |
| … | | | | | | | | |

- **Channels used** lists every channel that actually produced something.
- **Direct status** is the access classification from `references/discovery.md` §6.
- **Indexed / Alerts / ATS feed** are Yes/No facts about what was done, not outcomes.
- **Found** = relevant roles discovered via that source, de-duplicated.
- **Verified** = roles from that source that passed the gate.

Then, for each source that is not `Directly searched`, one line explaining the limitation — exact
failure mode, not "blocked".

## 5. Coverage metrics

Report both, always separately:

```
Portal discovery coverage : X/8   (investigated through at least one legitimate channel)
Direct portal access      : X/8   (successfully searched directly)
Secondary coverage        : X/7
Channels in use           : indexed X/8 · alerts X/8 · ATS feeds N · career portals N
Unique opportunities      : N discovered · N verified · N duplicates eliminated · N expired excluded
```

### Channel effectiveness

| Channel | Discovered | Verified | Conversion | Notes |
|---|---|---|---|---|
| ATS feeds | | | | |
| Career portals | | | | |
| Indexed search | | | | |
| Alert emails | | | | |
| Direct portals | | | | |
| Secondary sources | | | | |

Conversion = verified / discovered for that channel. This table is the evidence for next week's
channel ordering — keep it honest even when a channel performs badly.

## 6. Completeness disclosure

Every report ends with a short disclosure:

- Which mandatory portals were not directly searched and why.
- Whether indexed and alert channels closed that gap.
- Which checklist items in `GUIDE.md` §6 could not be completed.
- An explicit statement that discovery may be incomplete if coverage is below 8/8.

Never write "comprehensive", "exhaustive" or "full coverage" unless direct access is 8/8 and every
secondary source was searched.

## 7. Style

- Compact, high-signal, no filler.
- No role appears twice across sections.
- Numbers only when measured; estimates are labelled as estimates, or omitted.
- Every claim about a role traceable to a field captured during verification.
