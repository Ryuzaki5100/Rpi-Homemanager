---
name: batch-resume-tailor
description: Use when the user pastes several job posting URLs (Naukri, LinkedIn, company career pages, etc.) and wants a tailored resume for each. First asks the user which fetching mechanism to use — the agent itself (curl through the r.jina.ai rendering proxy) or the firecrawl MCP server — then fetches every job description with the chosen method, invokes the single-resume-tailor skill per role, saves each resume as a date-stamped .tex in ~/my_resumes/<company>/ (e.g. cisco_software_engineer_11-08-2026.tex), and stores each fetched job description in ~/my_resumes/job_descriptions/ with the matching base name so duplicate tailoring for the same company+role can be detected and reviewed before regenerating.
---

# batch-resume-tailor

Given a list of job posting URLs, fetch each job description, tailor one resume per role using the source of truth in `~/my_resumes/knowledge_base.md`, and save date-stamped `.tex` files alongside their source job descriptions.

## Steps

1. **Collect the URLs**
   - Take every URL the user pasted. If none are given, ask for them.
   - If the user pasted descriptions instead of links, delegate directly to the `single-resume-tailor` skill and stop.

2. **Choose the fetching mechanism (ask the user first)**
   - Before fetching anything, prompt the user to pick one of two ways to retrieve the job descriptions:
     1. **Agent-fetched** — the agent itself runs `bash` + `curl` through the rendering proxy (same approach as the Naukri fetch): `curl -sL -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" "https://r.jina.ai/<full-original-url>"`. Fall back to `webfetch` on the original URL if the proxy returns empty or useless output.
     2. **Firecrawl MCP** — invoke the already-enabled `firecrawl` MCP server (`firecrawl_scrape`) to fetch each URL. This may have better bot/JS handling on some sites.
   - Apply the chosen mechanism consistently to all URLs. If a URL fails with the chosen mechanism, briefly try the other one before giving up.

3. **Fetch each job description**
   - Using the chosen mechanism, fetch the page content for each URL.
   - Extract the **job description body** (the responsibilities + qualifications). Keep the plain text; discard layout cruft.
   - Record the **company** and the **role** — from the description text, and confirm with the URL slug if present (e.g. `...-software-engineer-cisco-bengaluru-...`).

4. **Determine names and dates**
   - Sanitize the company to lowercase (letters, digits, `_`/`-`) → folder `~/my_resumes/<company>/`.
   - Sanitize the role to lowercase snake_case.
   - Compute today's date as `DD-MM-YYYY`.
   - Target file name: `<company>_<role>_<DD-MM-YYYY>.tex` (e.g. `cisco_software_engineer_11-08-2026.tex`).
   - Job-description file name mirrors the `.tex` base name with a `.md` extension: `~/my_resumes/job_descriptions/<company>_<role>_<DD-MM-YYYY>.md`.

5. **Check for an existing tailored resume (dedup)**
   - Look for any file matching `<company>_<role>_*.tex` in `~/my_resumes/<company>/`. Use `glob` to be safe.
   - If **none** exists → go straight to step 6 (tailor).
   - If one exists for the **same company AND same role** (ignore the date):
     a. Find its matching stored job description in `~/my_resumes/job_descriptions/` (same base name). If the stored JD is missing, note that and still proceed to compare against whatever is available.
     b. Read both the stored JD and the newly fetched JD.
     c. **Analyze similarity yourself first**: identify the overlapping responsibilities, tech stack, experience range, and key keywords. List the 3–5 most important shared aspects in a short bullet summary, then give the user a concise full-similarity comparison so they can review everything.
     d. Present the finding and ask the user whether to **keep** the existing tailored resume (skip this role) or **discard/regenerate** it (produce a fresh dated `.tex` + JD file). Do not overwrite or duplicate without an explicit answer.

6. **Tailor the resume (per role)**
   - Load the `single-resume-tailor` skill with the `skill` tool and provide it the fetched job description as pasted text.
   - Instruct it to read `~/my_resumes/knowledge_base.md` and reuse the LaTeX preamble from the existing `.tex` files in `~/my_resumes/`.
   - **Override the naming step of single-resume-tailor**: the file must be written to `~/my_resumes/<company>/<company>_<role>_<DD-MM-YYYY>.tex` (date suffix included), NOT the plain `<company>_<role>.tex`. Skip its "add numeric suffix on collision" behavior in favor of the date suffix.

7. **Save the source job description**
   - Write the fetched job description to `~/my_resumes/job_descriptions/<company>_<role>_<DD-MM-YYYY>.md` (create the folder if missing). Include a small header with the original URL, company, role, and fetch date, followed by the description body.

8. **Verify**
   - Confirm each `.tex` file exists at its expected path and report the full path(s).
   - Spot-check LaTeX structure: every `\begin{itemize}`/`\begin{enumerate}` has a matching `\end{...}`; document opens with `\begin{document}` and closes with `\end{document}`.
   - Confirm each JD file exists in `~/my_resumes/job_descriptions/`.
   - Report a final summary: per role — company, role, .tex path, and whether it was tailored fresh or reused from an existing file.

3. **Determine names and dates**
   - Sanitize the company to lowercase (letters, digits, `_`/`-`) → folder `~/my_resumes/<company>/`.
   - Sanitize the role to lowercase snake_case.
   - Compute today's date as `DD-MM-YYYY`.
   - Target file name: `<company>_<role>_<DD-MM-YYYY>.tex` (e.g. `cisco_software_engineer_11-08-2026.tex`).
   - Job-description file name mirrors the `.tex` base name with a `.md` extension: `~/my_resumes/job_descriptions/<company>_<role>_<DD-MM-YYYY>.md`.

4. **Check for an existing tailored resume (dedup)**
   - Look for any file matching `<company>_<role>_*.tex` in `~/my_resumes/<company>/`. Use `glob` to be safe.
   - If **none** exists → go straight to step 5 (tailor).
   - If one exists for the **same company AND same role** (ignore the date):
     a. Find its matching stored job description in `~/my_resumes/job_descriptions/` (same base name). If the stored JD is missing, note that and still proceed to compare against whatever is available.
     b. Read both the stored JD and the newly fetched JD.
     c. **Analyze similarity yourself first**: identify the overlapping responsibilities, tech stack, experience range, and key keywords. List the 3–5 most important shared aspects in a short bullet summary, then give the user a concise full-similarity comparison so they can review everything.
     d. Present the finding and ask the user whether to **keep** the existing tailored resume (skip this role) or **discard/regenerate** it (produce a fresh dated `.tex` + JD file). Do not overwrite or duplicate without an explicit answer.

5. **Tailor the resume (per role)**
   - Load the `single-resume-tailor` skill with the `skill` tool and provide it the fetched job description as pasted text.
   - Instruct it to read `~/my_resumes/knowledge_base.md` and reuse the LaTeX preamble from the existing `.tex` files in `~/my_resumes/`.
   - **Override the naming step of single-resume-tailor**: the file must be written to `~/my_resumes/<company>/<company>_<role>_<DD-MM-YYYY>.tex` (date suffix included), NOT the plain `<company>_<role>.tex`. Skip its "add numeric suffix on collision" behavior in favor of the date suffix.

6. **Save the source job description**
   - Write the fetched job description to `~/my_resumes/job_descriptions/<company>_<role>_<DD-MM-YYYY>.md` (create the folder if missing). Include a small header with the original URL, company, role, and fetch date, followed by the description body.

7. **Verify**
   - Confirm each `.tex` file exists at its expected path and report the full path(s).
   - Spot-check LaTeX structure: every `\begin{itemize}`/`\begin{enumerate}` has a matching `\end{...}`; document opens with `\begin{document}` and closes with `\end{document}`.
   - Confirm each JD file exists in `~/my_resumes/job_descriptions/`.
   - Report a final summary: per role — company, role, .tex path, and whether it was tailored fresh or reused from an existing file.

## Notes

- `~/my_resumes/knowledge_base.md` is authoritative — never invent facts, metrics, employers, or tech not present there.
- Contact details and education must stay identical across all resumes.
- The date suffix exists so the agent can tell at a glance whether a tailored resume for a role already exists — reuse it, don't duplicate.
- The fetching-mechanism choice applies to the whole batch — ask once up front, not per URL.
- If fetching one URL fails repeatedly, tell the user and continue with the remaining URLs.
