---
name: job-grabber
description: Tailoring dispatch rules for job-grabber — when a role qualifies for a resume variant, the score thresholds and per-run cap, role-category to variant mapping, the self-contained subagent brief for job-search-resume-tailor, persistence paths, blocked-run handling and the skills-gap rollup. Loaded at the tailoring step of a run.
---

# Resume tailoring dispatch

Scope: **who gets a resume, and how the work is handed off.** The tailoring method itself belongs to
the `job-search-resume-tailor` skill — do not reimplement requirement classification, the evidence
matrix, the keyword coverage score, or the LaTeX. This file only decides and dispatches.

## 1. Trigger

| Score | Fit analysis | Tailored `.tex` |
|---|---|---|
| ≥ 80 | Yes | Yes, automatic |
| 70–79 | Yes | No — offer it in the report |
| < 70 | No | No |
| Section D (stretch), any score | No | No |

Additional constraints:

- Verified roles only. A lead never gets a resume.
- **Cap: 5 tailored resumes per run**, highest score first. Roles beyond the cap are listed as
  "eligible — not tailored this run", with their score, so the user can ask for them.
- Never tailor the same role twice. If `resume_path` is already set in the ledger and the JD is
  unchanged, reuse it. If the JD changed materially, generate a new one (the tailor skill adds a
  numeric suffix; it never overwrites).

## 2. Variant mapping

Pick one label per role from the dominant engineering domain in the JD. The label is passed in the
brief; the tailor skill's own domain classification and its per-domain priority lists do the actual
selection. Do not edit or fork those lists here.

| Role category | Variant label | Emphasis the tailor skill should apply |
|---|---|---|
| Core backend (Tier 1) | `backend` | Java/Spring, microservices, Pub/Sub, Redis, distributed service workflows, API design |
| Platform / infra (Tier 2) | `platform` | GitHub Actions CI overhaul, Nix/devenv, Terraform, GCP, Kubernetes, developer productivity, reliability |
| Data infra (Tier 3) | `data` | Pub/Sub pipelines, batch/thread-pool processing, GCS archival and diffing, data consistency, SQL |
| AI infra / RAG / agentic (Tier 4) | `ai-infra` | MCP server + playbook routing, ADK multi-agent orchestration, LLM tooling, retrieval-adjacent work — stated at its real depth |

If a role genuinely straddles two categories, choose the one carrying more of the responsibilities
and say so in the brief (`variant: backend (secondary: platform)`).

Hard boundary for `ai-infra`: the knowledge base supports agentic orchestration, MCP tooling and
LLM-powered documentation. It does **not** support production RAG, vector databases or model
training. The brief must tell the tailor skill not to stretch toward those.

## 3. Subagent brief

One subagent per resume, launched in parallel. Fill `templates/tailor-brief.md` and pass it whole.
The brief is self-contained so the subagent needs no access to this run's transcript.

Required content:

- Company, exact job title, requisition ID, location, work mode, apply URL.
- The full JD text, verbatim (sourced from `fits/<slug>/jd.md`).
- Variant label and any secondary domain.
- The keyword coverage matrix from the fit analysis, if already produced.
- Absolute output paths: `.tex` destination, mirrored `.pdf` destination, plus `fits/<slug>/fit.md`.
- The explicit instruction to **invoke `job-search-resume-tailor` by name** so it does not stop to
  ask which resume skill to use.
- The instruction to **compile the `.tex` to a PDF** and keep both artifacts.
- The return contract.

## 4. Subagent contract

The subagent must return, in one message:

1. `resume_path` — the created `.tex` file at `<company>/<company>_<role>.tex`.
2. `resume_pdf_path` — the compiled PDF at `pdfs/<company>/<company>_<role>.pdf`.
3. The tailor skill's complete final report verbatim — job fit, critical keywords, coverage matrix,
   resume changes, ATS assessment (including page count and page size), missing requirements,
   interview preparation.
4. `missing_keywords[]` — requirements with no defensible evidence, as a flat list.
5. `partial_keywords[]` — requirements covered only through projects or partial exposure.
6. `blocked` — a single focused question if a material fact is missing, instead of guessing.

Failure handling:

- `BLOCKED: <question>` → do not retry, do not invent the answer. Record the role as
  "tailoring blocked — <question>" in the report and leave both paths empty.
- No `.tex` produced → record the failure honestly; never claim a resume exists.
- `.tex` produced but compilation failed → keep the `.tex`, report
  `PDF: compile failed — <compiler error>` and leave `resume_pdf_path` empty. Never claim a PDF.
- PDF produced but not one A4 page → keep both, report the actual page count as a concern, and do not
  auto-trim the content. Page count is a candidate decision, not the pipeline's.
- Subagent tries to tailor a weak-fit role → stop it and keep the fit analysis only.

If the subagent reports success but the PDF is missing on disk, compile it centrally with
`scripts/compile_resume.sh <tex>` before recording anything.

## 5. Persistence

```
job-intel/fits/<company>_<role>/
├── jd.md      verbatim job description + metadata header (source URL, requisition, captured date)
└── fit.md     the tailor skill's final report, verbatim
```

- `<company>_<role>` is lowercase snake_case, matching the tailor skill's resume filename stem.
- Do not copy the `.tex` or PDF into `job-intel/` — they live in
  `~/job-search/my_resumes/<company>/` and `~/job-search/my_resumes/pdfs/<company>/`.
- Update the ledger record with `jd_path`, `fit_report_path`, `resume_path`, `resume_pdf_path`,
  `tailored_run`.
- Link all three artifacts from the weekly report's Section A entry.

## 6. Skills-gap rollup

After all tailoring for the run completes, update `job-intel/skills-gap.json`:

- Increment `occurrences` for every requirement tagged missing or partial.
- Increment `total_roles_seen` for every verified role analysed (fit analysis only, or tailored).
- Keep a `roles[]` list of slugs contributing to each requirement, so a recurring gap can be traced.
- Recompute `coverage_ratio` = roles where the requirement was Strong / roles analysed.

Report in Section F any requirement with `occurrences ≥ 3` and `coverage_ratio < 0.5` — those are the
gaps worth actually learning, as opposed to one-off JD noise.

Do not use this file to justify adding a technology to the resume. It informs learning priorities,
not claims.

## 7. Never

- Never generate a resume for an unverified, stretch, or sub-70 role.
- Never pass a JD you have not stored to `fits/<slug>/jd.md`.
- Never present a tailored resume as application-ready without the tailor skill's ATS assessment.
- Never record a `resume_path` without the matching `resume_pdf_path` unless the compile failure is
  also recorded.
- Never let a subagent silently choose a different resume skill.
- Never overwrite an existing `.tex` or `.pdf`.
- Never claim a resume or a PDF was produced when the subagent failed or was blocked.
