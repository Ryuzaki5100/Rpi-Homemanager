---
name: job-search-resume-tailor
description: Full Phase 1–10 playbook for job-search-resume-tailor. Loaded by the SKILL.md router.
---

# Job-search resume tailoring — playbook

Covers input capture, source hierarchy, candidate guardrails, content engineering, structure,
LaTeX generation, page balancing, file output, and reporting. Keyword/ATS depth lives in
`references/keyword-strategy.md`; evidence auditing and validation commands live in
`references/evidence-and-validation.md`. Read a section only when the workflow step calls for it.

- §1 Input and sources
- §2 Content engineering
- §3 Structure and positioning
- §4 LaTeX generation
- §5 Page length and balancing
- §6 File generation
- §7 Final report

---

## §1 Input and sources

### §1.1 Capture the job description

Accept the JD as pasted text, or as a `.txt` / `.md` / `.pdf` path.

- Read text files with the file reader.
- Parse PDFs with a PDF-capable tool (`firecrawl_parse` when available). If extraction is garbled
  or partial, re-inspect the document visually before concluding anything from it.
- Never infer a JD from its filename or a snippet.

Extract:

| Field | Notes |
|---|---|
| Company | Required for the output path |
| Exact role title | Preserve the employer's wording, including level |
| Location | City/country or remote |
| Minimum experience | Years, or "new grad" |
| Employment type | Full-time / intern / contract, if stated |
| Mandatory qualifications | Explicit must-haves |
| Preferred qualifications | Bonus items |
| Responsibilities | The real substance of the role |
| Technical stack | Languages, frameworks, cloud, data, AI tooling |
| Application URL | If supplied |

If the JD is incomplete, name what is missing. If the **company or role** cannot be identified
confidently, ask one concise clarification question and stop. Do not interrogate the user for
details already present in the JD or the knowledge base.

### §1.2 Read the candidate's authoritative material

Read, in order:

1. `~/job-search/my_resumes/knowledge_base.md` — before drafting anything.
2. The existing `.tex` files in `~/job-search/my_resumes/`
   (`resume_devops.tex`, `resume_backend_devops.tex`, `resume_ai_devops_backend.tex`) for the
   preamble, section structure, contact block, education wording, and formatting conventions.
3. `~/job-search/my_resumes/description.txt` — optional extra context.

You are reading for two different things: **facts** from the knowledge base, and **form** from the
`.tex` files. Keep them separate.

### §1.3 Source-of-truth hierarchy

1. `knowledge_base.md` — verified experience, technologies, dates, metrics, project detail.
2. Existing `.tex` files — established presentation and supplementary descriptions.
3. Clarifications supplied by the candidate in the current conversation.

When they conflict, the knowledge base wins. If a fact is missing, omit it or ask — never fill the
gap with a plausible invention.

### §1.4 Candidate-specific guardrails

The core rules in `SKILL.md` cover the hard prohibitions. Operationally:

- Classify every item you write as employment, internship, personal project, academic project, or
  prototype, and let that classification survive into the wording.
- "Exposure to X" never becomes "expertise in X". "Participated in" never becomes "led".
  "Prototype" never becomes "production system".
- The Sabre role is `Software Engineer Intern → Software Engineer` from `January 2025 - Present`
  (internship `January 2025 - July 2025`, full-time from `August 2025`). Summaries must state
  professional experience accurately and may separate internship months from full-time months;
  never present the combined span as all full-time.
- The JIRA automation was a **company AI hackathon** — it is a project, and describing it must not
  imply it was a production deliverable unless the knowledge base says so.

### §1.5 Mandatory placements and verified values

| Item | Where it belongs | Verified facts to use |
|---|---|---|
| Agentic AI MCP-Powered Mainframe Workflow Automation (KB §1) | Sabre **Experience** | `2026`, backend layer + monorepo integration, copilot-cli plugin, MCP SDK, `GitHub Copilot CLI`, model-flexible |
| DevDocs | **Projects** | `2025`, `Gemini 3 Pro`, `ParserServer + DAG server`, GitHub Actions parser pipeline |
| Agentic AI JIRA Ownership Automation | **Projects** | `2025`, company hackathon |
| Sub-Optimum Rubik's Cube Solver | **Projects** | as documented |
| Wells Fargo internship | **Experience** | dates and location exactly as in the knowledge base |

Only use details that appear in the knowledge base. This table is a placement reminder, not a
licence to add anything not written down there.

---

## §2 Content engineering

### §2.1 Select the strongest relevant experience and projects

Build the resume around the job, not around the knowledge base's ordering. General guidance, not
quotas: current full-time role ~3–6 bullets; earlier internship ~1–3; each project ~1–3; summary
2–3 lines; skills 2–4 grouped lines.

Project priority by target role:

| Role family | Prioritise |
|---|---|
| Backend / distributed systems | Production services, event-driven workflows, APIs, database design, performance and reliability, backend projects |
| Platform / infrastructure | GitHub Actions migration, JDK upgrades, infrastructure automation, cloud and Kubernetes, developer tooling, CI/CD, reliability |
| Data infrastructure | Data processing, messaging, database integration, pipelines, distributed processing, storage and retrieval architecture |
| AI infrastructure / agentic | Mainframe workflow automation, DevDocs, JIRA automation, MCP integrations, LLM orchestration, retrieval and data-processing workflows, production-oriented architecture |

Do not force every project into every resume. One strongly relevant project beats three weak ones.
A project earns a place only if it strengthens the case for *this* role.

### §2.2 Bullet construction

Formula: **action + specific engineering contribution + technology/context + outcome (only if
verified)**.

- Use the verb that is most accurate, not the most impressive. Implementation ≠ architectural
  ownership; collaboration ≠ leadership; experimentation ≠ production delivery.
- Avoid weak openers: "Responsible for", "Worked on", "Helped", "Involved in", "Assisted with".
- Vary openers naturally across a section, but reuse a verb elsewhere in the document when it is
  genuinely the best word. Do not contort the sentence to achieve stylistic uniqueness.
- Past tense for completed work; present tense for ongoing ownership.
- Aim for one or two rendered lines. Never strip technical context just to hit one line, and never
  write a bullet that could describe any software engineer.

### §2.3 Evidence validation

Run the checklist in `references/evidence-and-validation.md` §3 against every bullet before it is
written into the document. A bullet that fails is rewritten or dropped, not softened.

### §2.4 ATS keyword optimization

Follow `references/keyword-strategy.md` for requirement buckets, Tier 1–4 prioritisation, exact
terminology and synonym rules, placement, and the coverage report. The short version: use the
employer's exact wording where it truthfully describes documented work, expand acronyms on first
mention, place important terms in bullets (not only in Skills), and never include a technology the
candidate has not used.

---

## §3 Structure and positioning

### §3.1 Professional summary

`\section{Professional Summary}` immediately below the contact header and above Education.

Two to three rendered lines covering: the candidate's actual professional identity, the relevant
engineering experience, two or three differentiators, and the target domain's key technologies.
Vary it per role — backend, platform, data, and AI-infrastructure framings are genuinely different
documents.

Avoid generic personality claims, empty adjectives, unsupported seniority, claims of ML expertise
without evidence, and verbatim reuse of experience bullets. Do not hardcode an experience figure:
compute it from the documented dates and keep internship and full-time years distinct.

### §3.2 Skills section

`\section{Skills}` with grouped, plain-text, comma-separated categories. Choose only relevant
categories from: Languages, Frameworks, Backend, Cloud & Infrastructure, Databases & Messaging,
AI / Developer Tools, Engineering Practices.

- Only technologies the knowledge base supports.
- Most relevant first; exact JD terminology where truthful.
- No synonym soup, no duplicate entries, no whitespace filler.
- Skills reinforce evidence demonstrated elsewhere; they never substitute for it.

### §3.3 Section order

Default order:

1. Professional Summary
2. Education
3. Experience
4. Projects
5. Skills
6. Honors & Awards

Deviate only when the evidence clearly favours a different conventional order, and never to be
creative. Keep standard headings that parsers recognise. Do not add a Certifications section —
it was deliberately removed from the templates.

Do not drop relevant verified scholarships or honours without a real space reason.

### §3.4 Identity and contact information

Copy unchanged from the source resume: name, email, phone, LinkedIn, GitHub, institution, degree and
specialisation, GPA, dates, honours. Never invent or alter contact details. Keep them as visible
plain text in the header — never only in PDF metadata, headers, footers, or link destinations.

---

## §4 LaTeX generation

### §4.1 Preserve and improve the template

Start from an existing `.tex` file. Preserve the document class, geometry, fonts, section
formatting, list spacing, hyperlink styling, and overall visual identity. Preserve the preamble
unless a change is needed for text extraction, font encoding, or ATS parsing.

### §4.2 Layout requirements

Required: single-column, conventional headings, readable typography, consistent spacing, standard
fonts, clear employer/title/location/date lines, plain-text contact details.

Forbidden: `tabular`/`tabularx` for core content, `multicol`, images, logos, icons, skill bars,
decorative boxes, multi-column layouts, critical content in headers/footers, excessive rules.

Bold technology names with `\textbf{...}` for human readability where it helps — but bolding never
replaces plain-text keywords.

### §4.3 Dates and locations

One consistent, machine-readable format everywhere: `June 2024 - July 2024`. Include city and
country on every employment entry where the knowledge base records them. Never invent a location.

### §4.4 Encoding and extraction safety

Where compatible with the template, use `\input{glyphtounicode}` and `\pdfgentounicode=1`. Avoid
unusual glyphs, decorative packages, and anything that mutates extracted text. Prefer standard
characters over emoji, ligature tricks, or icon fonts.

---

## §5 Page length and balancing

### §5.1 One-page target

Prefer a complete, readable one-page A4 resume for early-career applications, using the template's
existing geometry and type size as the baseline.

### §5.2 If under-filled

In order: check for an omitted relevant bullet; clarify an existing technical detail; add a
genuinely relevant project; add a relevant skill already documented; adjust spacing modestly.
Never add irrelevant projects, redundant skills, duplicated achievements, or filler adjectives.

### §5.3 If over-filled

In order: drop the least relevant bullet; shorten verbose descriptions; remove redundant
technologies; drop the lowest-priority project; consolidate overlapping achievements; adjust
spacing modestly. Do not sacrifice readability or important evidence for an arbitrary line count.

### §5.4 Acceptable exception

If important, relevant evidence genuinely cannot fit on one page without harming readability,
prefer content quality and explain why a second page is justified. Never ship an accidental second
page holding one or two lines.

---

## §6 File generation

Write two artifacts:

```
~/job-search/my_resumes/<company>/<company>_<role>.tex      # source, editable
~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf # compiled, ready to view
```

- Company folder: lowercase letters, digits, `_`, `-`. Create if absent.
- Role: lowercase snake_case (`google/google_backend_engineer.tex`).
- If the file exists, do not overwrite — add `_2`, `_3`, …
- Leave the source resumes and `knowledge_base.md` untouched.
- Write the complete, ready-to-compile document. Then compile it: two `pdflatex` passes,
  `-interaction=nonstopmode -halt-on-error`.
- The PDF goes into the mirrored `pdfs/` tree, never beside the `.tex`. Mirror rule: same relative
  path, extension swapped. A root-level `.tex` compiles to `pdfs/<name>.pdf`.
- Keep both files; delete only `.aux`/`.log`/`.out` and other intermediates.
- If compilation fails, still deliver the `.tex`, report the compiler error verbatim, and do not
  claim a PDF.
- `batch-resume-tailor` overrides the filename with a `_<DD-MM-YYYY>` suffix when it delegates.

---

## §7 Final report

Use the template in `references/evidence-and-validation.md` §5. Report company, exact role, fit
verdict, both file paths, tailoring highlights, what validation actually ran, and genuine skill gaps.

Never state a "pass probability", a guaranteed ATS score, or an unverified page count.
