---
name: job-search-resume-tailor
description: Job-description intelligence for job-search-resume-tailor — domain classification, requirement buckets, Tier 1–4 keyword prioritisation, ATS placement rules, and the keyword-coverage report.
---

# Keyword and ATS strategy

How to turn a job description into a prioritised, evidence-aware keyword plan. Pairs with
`references/evidence-and-validation.md`, which decides what may actually be claimed.

## §1 Classify the position

Assign one or more domains before writing anything:

- Backend / software engineering
- Distributed systems
- Platform engineering
- Cloud / infrastructure engineering
- DevOps / SRE
- Data engineering / data infrastructure
- AI infrastructure / production RAG
- Agentic systems / AI engineering

Multi-domain roles are normal. The domain mix decides which experience and projects lead.

## §2 Extract requirements into buckets

| Bucket | Contents |
|---|---|
| **A. Languages & frameworks** | Java, Python, Go, Spring Boot, Spring AI, Flask, REST, gRPC |
| **B. Cloud & infrastructure** | GCP, AWS, Azure, Kubernetes, Docker, Terraform, CI/CD, IaC, observability |
| **C. Data & distributed systems** | SQL, NoSQL, Spanner, Redis, Couchbase, Kafka, Pub/Sub, event-driven architecture, pipelines, caching, message processing |
| **D. AI & ML engineering** | RAG, vector databases, embeddings, knowledge graphs, MCP, agentic systems, LLM orchestration, evaluation, retrieval, prompt engineering, model serving |
| **E. Engineering fundamentals** | System design, API design, scalability, reliability, fault tolerance, concurrency, performance, security, testing, monitoring, incidents |
| **F. Responsibilities & behaviour** | Ownership, cross-functional collaboration, production operations, troubleshooting, mentoring, documentation, end-to-end delivery |

## §3 Prioritise into four tiers

| Tier | Meaning | Weight |
|---|---|---|
| **1 — Mandatory** | Explicit minimum qualifications and must-have technologies | Highest |
| **2 — Core responsibility** | Skills emphasised in the actual duties | High |
| **3 — Preferred** | Bonus technologies and secondary competencies | Moderate |
| **4 — Incidental** | Generic phrases, one-off mentions | Low; usually omit |

Give Tier 1 and Tier 2 nearly all the attention. Also separate:

- Exact technology names.
- Industry-standard synonyms.
- Acronyms and their expanded forms.
- Conceptual requirements that can be demonstrated with a different but genuinely equivalent
  technology.

**Equivalence discipline:** Google Cloud Pub/Sub demonstrates event-driven messaging experience.
It does **not** demonstrate Kafka. Never upgrade a same-category technology into the named one.

## §4 Map to evidence before choosing placement

For each Tier 1–2 requirement decide the best honest placement:

1. A professional experience bullet (strongest).
2. A project bullet (credible but clearly separate).
3. The Skills section only (weakest; acceptable for genuinely used but undemonstrated tools).
4. Omission with a reported gap.

If nothing supports the requirement, it is omitted from the resume and reported as a gap — never
inserted into Skills to silence the check.

## §5 ATS wording rules

- Mirror the employer's exact terminology, spelling, and casing when it describes real work
  ("CI/CD", "event-driven architecture", "Model Context Protocol (MCP)").
- Expand an acronym on first mention, then use it normally: `Model Context Protocol (MCP)`.
- Weave important terms into experience and project bullets, not only into Skills. Contextual
  mentions carry more weight than a keyword block.
- Use recognised synonyms naturally; do not stack three variants of the same term.
- Put the most role-relevant skills first.
- Do not claim knowledge of any employer's proprietary ranking algorithm. Different ATS platforms
  behave differently; optimise for conventional parsing, real terminology, and human readability.

Never stuff. Never repeat a term unnaturally. Never add a technology because the JD lists it.

## §6 Keyword coverage report

Before finishing, produce a short qualitative coverage section in the final response:

- High-priority keywords identified.
- Represented in professional experience.
- Represented only through projects.
- Represented only in Skills.
- Missing, with the reason (no evidence / deliberately out of scope).

If you give a percentage, compute it over **distinct, applicable, evidence-supported requirements**
and state the limitation. Never count repeated appearances; never present the number as an ATS
score or a hiring probability.
