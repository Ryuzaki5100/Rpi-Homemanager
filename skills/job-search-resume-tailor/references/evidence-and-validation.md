---
name: job-search-resume-tailor
description: Fit assessment, claim validation, and document verification for job-search-resume-tailor — evidence matrix, fit classification, LaTeX structural checks, PDF compile/extract commands, and the final report template.
---

# Evidence, fit, and validation

Decides whether the role is worth applying to, whether a claim is defensible, and whether the built
document actually renders and parses. Keyword prioritisation lives in
`references/keyword-strategy.md`.

## §1 Evidence matrix

Map every important requirement to documented candidate evidence.

| Classification | Meaning | Where it may appear |
|---|---|---|
| **Strong** | Directly demonstrated in professional work | Experience bullets, summary, skills |
| **Partial** | Relevant exposure, limited depth or ownership | Experience bullet with careful wording, or skills only |
| **Project-based** | Demonstrated in a personal/academic/hackathon project | Project bullets — never as employment |
| **Missing** | No defensible evidence | Omitted and reported as a gap |

Build the matrix before drafting:

| JD requirement | Tier | Candidate evidence | KB location | Class | On resume? |
|---|---|---|---|---|---|
| Java | 1 | Sabre backend services | §1, §2 | Strong | Yes |
| Kafka | 3 | none (Pub/Sub only) | — | Missing | No — report gap |

Do not infer equivalence between technologies in the same category.

## §2 Fit classification

Assess, in order:

1. Technical requirement alignment.
2. Experience and seniority alignment.
3. Responsibility alignment.
4. Relevant professional experience.
5. Relevant project experience.
6. Missing mandatory qualifications.
7. Whether the role expects expertise substantially beyond the documented background.

Verdicts:

- **Strong Fit** — most important requirements are backed by relevant experience.
- **Reasonable Stretch** — several important requirements match; meaningful gaps remain. Proceed.
- **Weak Fit** — multiple mandatory requirements unsupported, or the expected seniority is far
  higher. Explain why, and ask whether the candidate still wants the resume before investing
  significant effort.

A slightly higher stated experience requirement does not by itself make a role a Weak Fit if the
actual responsibilities align. Missing *preferred* qualifications never do either.

Never misrepresent the candidate to convert a weak fit into a strong one.

## §3 Claim validation checklist

Run against **every** bullet, summary sentence, and skills entry:

- [ ] The candidate actually did this work.
- [ ] Every named technology was actually used.
- [ ] The verb matches the contribution (built vs. architected vs. collaborated).
- [ ] Every metric is explicitly supported by the knowledge base.
- [ ] No implication of production deployment, scale, ownership, or business impact that the source
      does not support.
- [ ] Experience vs. project vs. internship framing is intact.
- [ ] No placeholder tokens (`[Date]`, `[LLM ...]`, `[Tool/Platform]`) remain.
- [ ] No weak opener ("Responsible for", "Worked on", "Helped", "Involved in", "Assisted with").

If a check fails: rewrite, drop, or ask the candidate. Never soften a false claim into a vaguer
false claim.

## §4 Document verification

### §4.1 Structural checks (always)

- File exists at the expected path.
- Opens with `\begin{document}` and ends with `\end{document}`.
- Every `\begin{itemize}` / `\begin{enumerate}` is matched.
- Braces and commands are balanced; the preamble compiles logically.
- No duplicate sections or repeated bullets.
- No banned openers, no unresolved placeholders.
- Section order matches the chosen structure; headings are standard.
- No `tabular`/`tabularx` for content, no `multicol`, no images or icons.

Inspect the written file — do not trust the drafting process.

### §4.2 PDF compilation and checks (mandatory when a toolchain exists)

Compile from the `.tex` directory, into the mirrored PDF tree:

```bash
cd <company-dir>
pdflatex -interaction=nonstopmode -halt-on-error <file>.tex
pdflatex -interaction=nonstopmode -halt-on-error <file>.tex   # second pass for hyperref
mkdir -p ../pdfs/<company>
mv <file>.pdf ../pdfs/<company>/
pdfinfo ../pdfs/<company>/<file>.pdf | grep -E 'Pages|Page size'
pdftotext ../pdfs/<company>/<file>.pdf - | head -60
rm -f <file>.aux <file>.log <file>.out
```

Prefer `job-grabber`'s `scripts/compile_resume.sh <file>.tex` when it is available — it handles the
two passes, the mirrored output path, the page-size assertion and the cleanup in one step.

- Read the compiler output for errors and meaningful warnings.
- Confirm the actual page count and page size with `pdfinfo` (expect 1 page, A4 595×842 pt).
- Confirm `pdftotext` yields the expected headings, contact block, employers, dates, and keywords.
- Check special characters and bullets extract correctly.
- Inspect the rendered PDF visually when possible for clipping, overlap, or bad wrapping.
- **Keep the PDF** — it is a deliverable. Delete only `.aux`, `.log`, `.out` and other intermediates.

If no toolchain is available, say so explicitly: structural checks passed, rendering and page count
unverified. Do not imply an estimated line count is a rendered page count. A compile failure is
reported with the error and the `.tex` is still delivered.

### §4.3 Readiness review

- **Parsing** — single column, conventional headings, visible contact details, consistent dates,
  correct reading order, no content in graphics.
- **Keywords** — supported terms placed contextually; unsupported skills absent; employment and
  projects distinguishable.
- **Evidence** — every bullet traceable to the knowledge base.
- **Recruiter readability** — most relevant experience immediately visible, summary conveys fit,
  bullets concise, nothing artificially padded.

## §5 Final report template

```
Company: <name>
Role: <exact title>
Role suitability: Strong Fit | Reasonable Stretch | Weak Fit
Resume (source): ~/job-search/my_resumes/<company>/<company>_<role>.tex
Resume (PDF):    ~/job-search/my_resumes/pdfs/<company>/<company>_<role>.pdf

Tailoring highlights:
- Experience emphasised: ...
- Projects selected: ...
- Keywords incorporated: ...

Validation:
- Structural LaTeX checks: passed
- PDF compilation: <ran | failed — <error> | unavailable — not verified>
- Page count: <N, verified via pdfinfo | not verified>
- Page size: <A4 595x842pt, verified | not verified>
- Text extraction: <clean, contains expected headings/keywords | not verified>

Genuine skill gaps:
- <mandatory requirement> — not represented (no supporting evidence)
```

Do not give an ATS pass probability, a guaranteed score, or a page count that was not measured.
