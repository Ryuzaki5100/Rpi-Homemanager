---
name: single-resume-tailor
description: Use when the user provides a job description (pasted in chat or as a file path) and wants a tailored resume. Reads the source of truth in ~/my_resumes/knowledge_base.md and the existing .tex resumes in ~/my_resumes, curates a professional, eye-catching, ATS-optimized LaTeX resume that fills exactly one full page (keyword-matched content, a Professional Summary, a dedicated Skills section, document-wide unique action verbs, and an ATS-safe single-column layout), and saves it to ~/my_resumes/<company>/<company>_<role>.tex. Use when the user mentions tailoring a resume for a specific company, job, or application.
---

# single-resume-tailor

Given a job description, curate a polished, ATS-optimized LaTeX resume that **fills exactly one full page** and matches the job description, using only the real experience recorded in `~/my_resumes/knowledge_base.md`. Save it under a company-named folder in `~/my_resumes/`.

Act as a **professional resume tailor**: every bullet is a unique, high-impact achievement line; every section earns its place; the final page is full — never short, never spilling to a near-empty second page.

## Steps

1. **Capture the job description**
   - If the user provides a file path (`.txt`, `.md`, or `.pdf`), read it: use `read` for text files, or `firecrawl_parse` for a PDF.
   - If the user pastes the description directly, treat the message as the job description.
   - Extract the **company** and the **role** from the description. If either cannot be determined confidently, ask the user once before continuing.

2. **Read the source material and build the JD keyword list**
   - Read `~/my_resumes/knowledge_base.md` — this is the single source of truth for projects, metrics, and tech stacks. Do not invent details not present here.
   - Read the existing `.tex` files in `~/my_resumes/` (e.g. `resume_devops.tex`, `resume_ai_devops_backend.tex`) to reuse the exact LaTeX preamble and section structure.
   - Optionally skim `~/my_resumes/description.txt` for extra context.
   - Extract a **structured keyword list from the job description**, grouped into: (a) required technologies/languages, (b) tools & platforms, (c) domain terms, (d) soft skills. Use this list to drive keyword placement in Steps 3–8.

3. **Curate the resume content (ATS keyword matching)**
   - Match projects, experience, and skills from the knowledge base against the job description's responsibilities, keywords, and required tech stack. Select the most relevant items and drop irrelevant ones.
   - **Placement rule:** the Agentic AI MCP-Powered Mainframe Workflow Automation (knowledge base section 1) is company work — always place it under the Work Experience section at **Sabre**, never under Projects.
   - **Fill real values from the knowledge base instead of leaving placeholders:** dates (employer `January 2025 - Present` as `Software Engineer Intern $\rightarrow$ Software Engineer`, DevDocs `2025`, mainframe automation `2026`, JIRA `2025`), DevDocs LLM/platform (`Gemini 3 Pro`, `ParserServer + DAG server`), and the mainframe LLM note (`GitHub Copilot CLI`, model-flexible). No `[Date]`, `[LLM ...]`, or `[Tool/Platform]` placeholders should remain in the final .tex.
   - Order experience/project bullets **most relevant first**.

4. **Action-verb discipline (STRICT guardrail)**
   - **Document-wide uniqueness (hard rule):** every bulleted achievement across the ENTIRE document (all Experience roles + all Projects) must begin with a **unique past-tense action verb**. The same leading verb may NEVER be used twice anywhere in the file. Before drafting, list every bullet's intended leading verb and check for collisions; if a verb is already used, swap it from the bank below.
   - **Verb bank (choose distinct verbs from these categories):**
     - Leadership: Architected, Spearheaded, Championed, Directed, Orchestrated, Steered, Led
     - Delivery/Launch: Delivered, Launched, Shipped, Rolled Out, Established, Deployed, Released
     - Engineering/Building: Engineered, Built, Constructed, Crafted, Developed, Implemented, Forged
     - Design/Modeling: Designed, Modeled, Formulated, Structured, Authored, Blueprinted
     - Optimization/Performance: Optimized, Accelerated, Streamlined, Tuned, Refined, Hardened
     - Automation: Automated, Orchestrated, Programmed, Scripted
     - Migration/Upgrade: Migrated, Upgraded, Modernized, Refactored, Consolidated, Replatformed
     - Data/Infrastructure: Configured, Provisioned, Integrated, Maintained, Standardized, Instrumented
     - Analysis/Research: Analyzed, Diagnosed, Investigated, Evaluated, Benchmarked, Traced
     - Collaboration/People: Collaborated, Partnered, Facilitated, Mentored, Organized, Championed
   - **Swap pairs (when a target verb is already taken):** Designed → Architected / Structured / Formulated / Modeled; Developed → Built / Engineered / Crafted / Constructed; Implemented → Integrated / Deployed / Configured / Installed; Automated → Orchestrated / Scripted / Programmed; Improved → Optimized / Streamlined / Accelerated; Created → Established / Forged / Built.
   - **Banned openers (weak or passive):** "Responsible for", "Worked on", "Helped", "Involved in", "Assisted with", "Led efforts to", "Managed to", "Handled", "Tasked with".
   - **Bullet formula:** `unique Verb + specific action + bolded technology (\textbf{...}) + measurable outcome (if grounded in the knowledge base)`. Write in past tense; keep each bullet to 1–2 rendered lines.
   - Bullets must be factual and grounded — never fabricate a verb's implied achievement, metric, or tech.

5. **Mirror JD keywords and format bullets**
   - **Mirror the job description's exact terminology, spelling, and casing** in bullets and the Skills section (e.g. if the JD says "CI/CD", write "CI/CD"). This is what ATS keyword screens match against.
   - On first mention, use the **full form followed by the acronym** (e.g. "Model Context Protocol (MCP)") so both variants are present for screening.
   - Weave JD keywords into **Experience and Project bullets**, not just the Skills section — keyword density in achievement lines scores higher.
   - Bold key technologies with `\textbf{...}` for human readability; bolding does not affect ATS extraction.

6. **Include a Professional Summary**
   - Add a 2–3 line `\section{Professional Summary}` immediately under the contact header, before Education — a standard, ATS-recognized heading.
   - Write 2–3 dense sentences: role + seniority, 2–3 top differentiators (with metrics), and the target stack — all drawn from the knowledge base and the JD keyword list. Example: "Software Engineer with 1.5+ years building high-throughput, event-driven microservices and agentic AI automation on GCP, delivering ~70% time savings for QA teams and a ~50% cut in CI build time."
   - Do not repeat bullet content verbatim; summarize the strongest 2–3 points.

7. **Include a dedicated Skills section (keyword block)**
   - Add a `\section{Skills}` between Projects and Honors & Awards (standard ATS-recognized heading).
   - Write it as a dense, grouped, comma-separated keyword block (e.g. "Languages: Python, Java, Golang \quad Cloud: GCP, Terraform \quad ..."), drawn **only** from the knowledge base and mirroring the JD's keyword list from Step 2.
   - Group by category (Languages, Frameworks, Cloud & DevOps, Tools, etc.) but keep it plain-text and single-flow — no tables, columns, or visual boxes.
   - **Use the Skills block as the length filler:** grow it (add grounded synonyms/categories) or shrink it to hit the one-page budget in Step 9.

8. **Preserve the template and enforce the one-page structure**
   - Copy the LaTeX preamble from an existing `.tex` file unchanged (geometry, titlesec, enumitem, hyperref, fonts).
   - Keep the contact header, Education, and Honors & Awards sections exactly as they appear in the existing resumes (name, email, phone, LinkedIn, GitHub, GPA, dates). Do **not** add a Certifications section — it was removed from the templates.
   - **Mandatory section order:** Professional Summary, Education, Experience, Projects, Skills, Honors & Awards.
   - **Content floors (minimums, to guarantee a full page):**
     - Sabre role: 6–8 bullets **plus a `Technologies:` line** (plain-text, comma-separated, grounded in the KB) directly under the role.
     - Wells Fargo: 2 bullets plus a `Technologies:` line.
     - Projects: **at least 2 entries** — always DevDocs (2 bullets: the GitHub Actions parser pipeline + the ParserServer/DAG/Gemini detail) and Sub-Optimum Rubik's Cube Solver; **add Agentic AI JIRA Ownership Automation** when the JD is AI/agentic-oriented. Each project has a tech + date subheading line and at least 1 bullet (DevDocs gets 2).
     - Skills: dense keyword block (4–6 lines).
     - Honors & Awards: 2 entries.
   - Use **standard, ATS-recognized section headings only** — no creative or decorative heading names that parsers won't map to Summary/Education/Experience/Projects/Skills/Honors.
   - Keep the body **single-column and text-only**: no `tabular`/`tabularx`, no `multicol`, no images, logos, icons, or decorative rules. Content must extract cleanly as plain text.
   - Use a **consistent, machine-parseable date format** across all entries (e.g. `June 2024 - July 2024`). Include city/country on every role entry.
   - Keep contact details as plain text in the header block; do not place any critical content in headers/footers.
   - Prefer standard fonts; avoid exotic packages that could break text extraction.

9. **Tune length to exactly one page (STRICT guardrail)**
   - Target **~95–100% of one A4 page** at 10pt with 0.4in margins. Rough rendered-line budget: Header 4, Summary 3, Education 3, Experience (Sabre) 20–24, Experience (Wells Fargo) 6–7, Projects 12–16, Skills 4–6, Honors 5–6 → total ~57–66 lines.
   - **If under-filled:** add grounded content — expand the lowest-detail project to 2 bullets, add the JIRA project (AI/agentic JDs), enrich a thin experience bullet with a grounded metric (e.g. CI ~50% time cut, JDK 6-service migration, 333-day check-in window, ~70% QA time savings, cache-aside/PubSub design), or grow the Skills block.
   - **If over-filled (would spill to page 2):** drop the least-relevant experience bullet, trim a project to its strongest bullet, or shrink the Skills block. Never let the resume spill more than a line or two onto page 2.
   - Balance sections so no single section monopolizes the page; keep the most JD-relevant content visible.

10. **Determine the output location**
    - Sanitize the company name to lowercase (letters, digits, underscores/hyphens) and use it as the folder: `~/my_resumes/<company>/`. Create the folder if it does not exist.
    - Sanitize the role to lowercase snake_case and name the file `<company>_<role>.tex` (e.g. `google_backend_engineer.tex` for a backend-engineer role at Google).
    - If a file with that name already exists, add a numeric suffix (e.g. `_2`) instead of overwriting.

11. **Write the .tex file**
    - Write the fully tailored resume to `~/my_resumes/<company>/<company>_<role>.tex`.
    - Do **not** attempt to compile to PDF as a deliverable — the deliverable is the `.tex` file only.

12. **Verify (structure + ATS readiness + uniqueness + page fill)**
    - Confirm the file was created and report its full path.
    - Spot-check the LaTeX is structurally balanced: every `\begin{itemize}`/`\begin{enumerate}` has a matching `\end{...}`, and the document opens with `\begin{document}` and closes with `\end{document}`.
    - **Verb-uniqueness check (hard):** run `rg -o '\\item [A-Z][a-z]+' <file>.tex | sort | uniq -d` — the output MUST be empty. If any verb repeats, rewrite those bullets with distinct verbs before finishing.
    - **Page-fill check (hard):** estimate rendered lines from the budget in Step 9; confirm the resume lands in the one-page window. Fix under-fill or over-fill before reporting done.
    - **Keyword coverage check:** every JD-mandated skill/term from Step 2 appears somewhere in the resume (Skills section or bullets). Flag any required keyword that could not be grounded in the knowledge base rather than inventing it.
    - **Layout check:** confirm no tables/images/non-text elements, only standard section headings, a consistent date format, and no banned openers ("Responsible for", "Worked on", etc.).
    - **Optional ATS extraction check:** if a LaTeX toolchain is available, compile the file to PDF and run `pdftotext <out.pdf> -` to confirm the text extracts cleanly and contains the target keywords. If the toolchain is not available, skip this step — it is verification only, never a deliverable.

## Notes

- `~/my_resumes/knowledge_base.md` is authoritative — when the job description conflicts with it, trust the knowledge base.
- Contact details and education are personal facts and must stay identical across all resumes.
- ATS scoring favors exact keyword mirroring, a dense Skills block, document-wide unique action verbs, and clean plain-text extraction — always optimize for these, never sacrifice them for visual flair.
- The resume must fill exactly one page: short resumes look thin, and over-long resumes get truncated or penalized. Never ship a resume that is visibly less than a full page.
- Every leading verb is used at most once in the entire document. If you catch yourself reusing a verb, rewrite the later bullet.
- Never fabricate keywords, metrics, verbs, or tech to inflate the match; only reflect what the knowledge base supports.
