---
name: job-grabber
description: Verification and reconciliation rules for job-grabber — the six-point verification gate, posting-freshness classes, deduplication keys, expiry and repost handling, stretch classification and the unverified-lead rules. Loaded before adding any role to the report.
---

# Verification and reconciliation

Scope: turning a discovered lead into a reportable opportunity, and deciding what state it is in
relative to previous runs.

## 1. The verification gate

A role may appear in Sections A–E only if **all six** hold, checked this run:

1. The requisition page loads at the employer's own domain (or the employer's ATS board).
2. The listing is accepting applications — an active apply control, or explicit open status.
3. Company and title match what was discovered (no substituted or stale role).
4. Location and work arrangement are confirmed from the posting, not inferred.
5. The experience requirement is read from the description and quoted.
6. The apply URL in the report is the one you opened.

Additional confirmations to capture when present: requisition ID, posting date, employment type,
compensation.

**Never sufficient on their own:** search snippets, aggregator cards, LinkedIn "similar jobs",
alert emails, cached pages, recruiter reposts, or a board-list entry without the requisition.

If the official page cannot be reached, try one alternate authoritative source (the employer's ATS
board endpoint, or the employer's own careers search). If still unresolved, the role becomes an
unverified lead — never a verified one.

## 2. Freshness classes

| Class | Definition |
|---|---|
| **NEW** | First posted within the current reporting period |
| **RECENT** | Posted within ~30 days, before the current period |
| **OLDER — STILL OPEN** | Posted >30 days ago, verified open this run |
| **REPOSTED / UPDATED** | Previously known, with a new requisition ID or a meaningful change (title, location, experience, scope) |

- No posting date available → "Posting date not disclosed". Never infer a date from indexing
  artefacts, `lastmod`, or "posted X days ago" widgets you cannot trace to the employer.
- A repost with the **same** requisition ID and no material change is the same vacancy. Do not count
  it as new.
- A repost with a **new** requisition ID for the same team and scope is a genuinely new vacancy —
  note it as reposted with the old ID referenced.

## 3. Duplicate resolution

Keys, in priority order:

1. `requisition_id` + company slug.
2. Normalised `apply_url` — lowercase host, strip tracking params (`utm_*`, `ref`, `src`, `trk`),
   strip trailing slash, resolve redirects to the employer domain.
3. Normalised `(company, title, location)` — last resort, and only to *flag* a possible duplicate
   for human review, never to auto-merge (the same title can legitimately be open twice).

Normalisation rules: company → lowercase, strip legal suffixes (`pvt ltd`, `india`, `technologies`),
collapse whitespace. Title → lowercase, strip seniority noise only when it is not meaningful
(`(remote)`, `- india`), collapse whitespace.

When the same vacancy is found on four portals, that is **one record** with four
`discovery_channels[]` entries. Unique opportunity count increments once. Duplicates eliminated
increments four, and appears in the coverage metrics — a high duplicate count is evidence of a wide
sweep, not of extra opportunities.

## 4. Expiry and removal

- Apply control gone, explicit "no longer accepting applications", 404/410, or a redirect to a
  generic careers page → **expired**. Exclude from all sections and `mark-closed` in the ledger.
- Alert-email links routinely point at expired roles: always re-verify, never trust the email.
- A board that no longer lists a role that the ledger shows as open is weak evidence of closure —
  re-verify from the requisition before marking closed. If the requisition is also unreachable,
  mark `status: unknown` with the observation, not `closed`.
- Closed roles stay in the ledger permanently. They are the dedup memory and the market history.

## 5. Stretch classification

A role is a stretch when technical alignment is strong but the stated requirement exceeds the
candidate's ≈1.5 years total / ≈1 year full-time.

Rules:

- Only Section D may contain stretch roles. Never in A–C.
- State the exact gap: "requires 3+ years; candidate has ~1 year full-time" — not "some experience
  gap".
- A stretch role is never auto-tailored (see `references/resume-tailoring.md`).
- If the requirement is "2–3 years" and the description says "or equivalent experience", say so —
  that is a materially better position than a hard floor.
- Never relabel a 3-year role as "good fit". The report's credibility depends on this gate.

## 6. Unverified leads

Maintain a clearly separated list, at most a handful, for:

- Roles that look excellent but whose official requisition could not be reached.
- Roles found only through an alert or index, with no resolvable employer URL.
- Roles with a suspected but unconfirmed closure.

Each entry states: what was found, where, why it could not be verified, and what would resolve it.
Unverified leads never count toward verified totals and never enter Sections A–E.

## 7. Reconciliation sequence

For each candidate, in order:

1. `python3 scripts/ledger.py lookup --company … --title … --url … --requisition …`
2. If `known`: read the stored record. Re-verify only if `last_verified` exceeds the TTL,
   the stored `status` is `unknown`, or the current listing differs from the stored one.
3. Classify freshness (§2). If `known` and unchanged → *Reposted / Still open*, reported once in the
   still-open section, never in the new-opportunities count.
4. If new: verify (§1), then score.
5. Reconcile the whole set: drop duplicates (§3), drop expired (§4), move stretches to D (§5),
   move unverifiable to leads (§6).
6. Only then write the report and upsert everything.

## 8. Application-link hygiene

- Prefer the employer's own requisition URL over any portal URL.
- Strip tracking parameters before storing and reporting.
- If the employer URL 302s through a tracking domain, store the final resolved URL.
- Never present a shortened URL you have not resolved.
- A link that requires the candidate to log in to the *employer's* ATS is acceptable; a link that
  requires a portal login is not an application link — resolve the employer's instead.
