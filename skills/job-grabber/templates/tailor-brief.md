# Resume tailoring brief — {{COMPANY}} / {{TITLE}}

You are producing one tailored resume for one verified job. Work only from the job description and
the candidate's knowledge base. Do not ask which resume skill to use.

## Mandatory instruction

**Invoke the `job-search-resume-tailor` skill by name** and follow it end to end. Do not use
`single-resume-tailor`. Do not ask the user to choose a skill — the choice is already made.

## Role

| Field | Value |
|---|---|
| Company | {{COMPANY}} |
| Exact job title | {{TITLE}} |
| Requisition ID | {{REQ_ID}} |
| Location | {{LOCATION}} |
| Work mode | {{WORK_MODE}} |
| Experience requirement | {{EXPERIENCE}} |
| Apply URL | {{APPLY_URL}} |
| Verification source | {{VERIFICATION_SOURCE}} |
| Match score | {{SCORE}}/100 |
| Variant | {{VARIANT}} |
| Secondary domain | {{SECONDARY_DOMAIN}} |

## Job description (verbatim)

```
{{JD_TEXT}}
```

The same text is stored at `{{JD_PATH}}` — read it from there if the fixture above is truncated.

## Variant emphasis

{{VARIANT_NOTES}}

## Candidate sources

- Source of truth: `~/job-search/my_resumes/knowledge_base.md`
- Existing LaTeX templates: `.tex` files in `~/job-search/my_resumes/`
- Supporting context: `~/job-search/my_resumes/description.txt`

The knowledge base wins on every fact. Internships are never presented as full-time experience.

## Output

| Artifact | Path |
|---|---|
| Resume `.tex` | `~/job-search/my_resumes/{{COMPANY_SLUG}}/{{COMPANY_SLUG}}_{{ROLE_SLUG}}.tex` |
| Resume `.pdf` | `~/job-search/my_resumes/pdfs/{{COMPANY_SLUG}}/{{COMPANY_SLUG}}_{{ROLE_SLUG}}.pdf` |
| Fit report | `{{FIT_REPORT_PATH}}` |

- Never overwrite an existing resume or PDF; the skill's numeric-suffix rule applies.
- Compile after writing: two `pdflatex` passes with `-interaction=nonstopmode -halt-on-error`.
- If `job-grabber`'s `scripts/compile_resume.sh` is available, use
  `bash ~/dotfiles/skills/job-grabber/scripts/compile_resume.sh <tex-file>` — it enforces the mirrored
  `pdfs/` path, checks page count and A4 size, and cleans intermediates.
- Keep both artifacts. Delete only `.aux`, `.log`, `.out`.
- Verify with `pdfinfo`: expect 1 page and A4 (595×842 pt). Report the real numbers; do not guess.

## Return contract

Reply with exactly these parts:

1. `RESUME_PATH: <absolute .tex path>` — or `RESUME_PATH: none` if nothing was written.
2. `RESUME_PDF_PATH: <absolute .pdf path>` — or `RESUME_PDF_PATH: none` if compilation failed.
3. `PDF_PAGES: <N>` and `PDF_SIZE: <A4|other>` from `pdfinfo`.
4. `FIT_REPORT:` followed by the skill's complete final report, verbatim — job fit, critical
   keywords, keyword coverage matrix, resume changes, ATS assessment, missing requirements, and
   interview preparation.
5. `MISSING_KEYWORDS: <comma-separated list>` — requirements with no defensible evidence.
6. `PARTIAL_KEYWORDS: <comma-separated list>` — requirements covered only by projects or partial
   exposure.
7. `BLOCKED: <one focused question>` only if a material fact is missing and guessing would
   fabricate. Otherwise omit.

## Hard constraints

- No invented metrics, technologies, dates, ownership or impact.
- No technology added merely because the job description mentions it.
- No production-RAG, vector-database or model-training claims — the knowledge base does not support
  them.
- Preserve the distinction between full-time work, internship, and project.
- Single column, standard headings, no tables or graphics in the resume body.
- If the role turns out to be a weak fit on re-reading the JD, say so and return the fit report
  without forcing a resume.
