---
name: job-search-resume-tailor
description: Explicit-invocation skill for tailoring a resume to one job description. Use only when the user names this skill or asks for a deeply audited, evidence-backed tailoring (not a quick keyword pass). Reads ~/job-search/my_resumes/knowledge_base.md plus the existing .tex templates, classifies and prioritizes the job requirements, builds a candidate-to-JD evidence matrix with a fit verdict, rewrites only defensible experience and projects, aligns ATS keywords truthfully, generates a single-column ATS-safe LaTeX resume, compiles it to PDF, validates page count/size/text extraction, and writes ~/job-search/my_resumes/<company>/<company>_<role>.tex plus ~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf. If the request could equally match single-resume-tailor, ask the user which skill to run instead of choosing silently.
---

# job-search-resume-tailor

Tailor a resume to a specific job description with an auditable chain from requirement → candidate
evidence → resume bullet. The deliverables are the `.tex` source and its compiled `.pdf`, both of
which the candidate can defend in an interview — not a keyword-maximized document.

## Skill selection (read first)

1. Invoke this skill **only** when the user names it, or asks for a resume with evidence auditing /
   fit assessment / a truthful-only rewrite.
2. If the request is a generic "tailor my resume to this JD", the user has not chosen between this
   skill and `single-resume-tailor`. Ask once: "Which skill should I use —
   `job-search-resume-tailor` (evidence-audited, fit-checked) or `single-resume-tailor`
   (fast one-page keyword pass)?" Then follow the answer. Never pick silently.
3. If the user invoked this skill by name, proceed without asking.

## Step 0 — Read the guide first (mandatory)

`read <base-dir>/GUIDE.md` before touching the job description, then open whichever reference the
routing table calls for.

## Core rules (always apply)

1. **Truth over everything.** `~/job-search/my_resumes/knowledge_base.md` is the only source of
   truth for experience, dates, metrics, technologies, and project details. Existing `.tex` files
   may supply formatting and supplementary wording, but the knowledge base wins on facts.
2. **Never invent.** No fabricated metrics, latency numbers, traffic, cost savings, user counts,
   team sizes, technologies, ownership, or business impact. No technology may be added because the
   JD mentions it.
3. **Preserve the distinction** between full-time employment, internship, personal project,
   academic project, and experimental prototype. Do not merge internship and full-time dates into
   an inflated experience figure.
4. **Mandatory placements.** The Agentic AI MCP-Powered Mainframe Workflow Automation (knowledge
   base section 1) is Sabre company work — always under Experience, never under Projects. DevDocs,
   Agentic AI JIRA Ownership Automation (company hackathon), and the Sub-Optimum Rubik's Cube
   Solver stay under Projects unless the knowledge base says otherwise.
5. **Use verified values, no placeholders.** Employer dates `January 2025 - Present`
   (intern `January 2025 - July 2025`, full-time from `August 2025`); DevDocs `2025`,
   `Gemini 3 Pro`, `ParserServer + DAG server`; mainframe automation `2026`, `GitHub Copilot CLI`,
   model-flexible; JIRA automation `2025`. Never ship `[Date]`, `[LLM ...]`, `[Tool/Platform]`.
6. **All paths live under `~/job-search/my_resumes/`.** Knowledge base, templates, `description.txt`,
   and every output folder. There is no `~/my_resumes/`.
7. **One page is a target, not an excuse.** Never pad with irrelevant projects, inflated adjectives,
   or unsupported keywords; never shrink type or trim real evidence just to hit a line count.
8. **ATS alignment must stay truthful.** Mirror the employer's exact terminology where it accurately
   describes documented work; never manufacture coverage.
9. **When evidence is thin, ask.** If a missing metric or detail would materially strengthen the
   resume and the candidate can supply it, ask one focused question instead of guessing.
10. **Report only what was verified.** Never claim compilation, one-page rendering, or clean text
    extraction unless the commands actually ran and succeeded. A failed compile is reported as a
    failure, never hidden — the `.tex` is still delivered.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Run any tailoring task | `GUIDE.md` | Full Phase 1–10 playbook: sources, positioning, LaTeX, page length, output, reporting |
| Analyze the JD, rank keywords, place ATS terms, report coverage | `references/keyword-strategy.md` | Domain classification, Tier 1–4 prioritization, exact-term/synonym rules, coverage report format |
| Judge fit, validate a claim, verify the built PDF, write the final report | `references/evidence-and-validation.md` | Evidence matrix, fit classification, claim checklist, compile/extract commands, report template |

## Workflow

1. **Capture the JD** — pasted text, or a `.txt`/`.md`/`.pdf` path (parse PDFs). Extract company,
   exact title, location, experience minimum, responsibilities, mandatory and preferred
   qualifications, stack, URL. Ask once if company or role is ambiguous. → `GUIDE.md` §1.1
2. **Read the sources** — knowledge base first, then the existing `.tex` files in
   `~/job-search/my_resumes/`, optionally `description.txt`. → `GUIDE.md` §1.2–1.3
3. **Check the guardrails and placements** against knowledge base section 1 and the verified-value
   list. → `GUIDE.md` §1.4–1.5
4. **Classify and prioritize the JD** — engineering domain(s), requirements into languages,
   cloud/infra, data/distributed, AI, fundamentals, responsibilities; then Tier 1–4.
   → `references/keyword-strategy.md` §2–3
5. **Build the evidence matrix and fit verdict** — Strong / Partial / Project-based / Missing per
   requirement; Strong Fit / Reasonable Stretch / Weak Fit overall. Ask before investing effort on
   a Weak Fit. → `references/evidence-and-validation.md` §1–2
6. **Select experience and projects** for this role, most relevant first, using the per-domain
   priority lists. → `GUIDE.md` §4.1
7. **Write the content** — role-specific Professional Summary, impact bullets, grouped Skills;
   validate every claim before it survives. → `GUIDE.md` §4.2, §5;
   `references/evidence-and-validation.md` §3
8. **Build the `.tex`** — preserve the existing preamble, single column, standard headings,
   verified dates, no tables or graphics. → `GUIDE.md` §6
9. **Balance to one page** — under-fill and over-fill procedures, with the justified-two-page
   exception. → `GUIDE.md` §7
10. **Write, compile, validate, report** — write `~/job-search/my_resumes/<company>/<company>_<role>.tex`,
    compile it to `~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf`, numeric suffix on
    collision, structural checks, page-count/size/text-extraction checks, then the final report.
    → `GUIDE.md` §6–§7; `references/evidence-and-validation.md` §4–§5

## Output location

```
~/job-search/my_resumes/<company>/<company>_<role>.tex    # LaTeX source, editable
~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf  # compiled, ready to view
```

- Company folder: lowercase letters, digits, `_`, `-` only. Create it if absent.
- Role: lowercase snake_case (`google_backend_engineer.tex`).
- On collision, add `_2`, `_3`, … — never overwrite an existing resume.
- The PDF lives in the mirrored `pdfs/` tree, **not** beside the `.tex`. The path mirrors the `.tex`
  path with the extension swapped; a root-level `.tex` produces `pdfs/<name>.pdf`.
- Compile with `pdflatex` (two passes, `-interaction=nonstopmode -halt-on-error`). Use
  `job-grabber`'s `scripts/compile_resume.sh` when available — it enforces the mirrored path and the
  page-size checks.
- Keep both files. Delete only `.aux`, `.log`, `.out` and other intermediates.
- `batch-resume-tailor` may override the filename with a date suffix when it delegates here.

## Deployment

Source of truth is `~/dotfiles/skills/job-search-resume-tailor/`. Run `home-manager switch` in
`~/dotfiles/` to publish it to `~/.config/opencode/skills/`.

## Tools

`read` (JD, knowledge base, templates), `write`/`edit` (author the `.tex`), `shell` (folder creation,
`pdflatex`/`pdfinfo`/`pdftotext` validation), `question` (skill choice, missing facts, weak-fit
confirmation).
