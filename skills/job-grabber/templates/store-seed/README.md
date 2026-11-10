# job-intel — persistent job market memory

This directory is the memory of the `job-grabber` skill. It exists so a job posting is never
researched twice, and so every weekly report can be compared against what was already known.

## Files

| Path | Contents |
|---|---|
| `ledger.json` | Every posting ever seen, with its current state, score and artifacts |
| `sources.json` | Per-run source coverage audit and rolling channel performance |
| `skills-gap.json` | Requirements that keep appearing without candidate evidence |
| `runs/` | One dated weekly report per run |
| `fits/<company>_<role>/` | `jd.md` (verbatim job description) and `fit.md` (tailoring audit) |
| `inbox/` | Exported job-alert emails awaiting processing |
| `inbox/processed/` | Alerts already parsed this run |

## Rules

- Everything here is committed to git. It is an audit trail, not a cache.
- `runs[]` in `sources.json` is append-only. A re-run on the same date replaces that run's entry.
- A posting is never deleted. Closure is `status: closed`, not removal.
- A posting enters `ledger.json` only after it was verified at the employer's own source.
- Raw alert emails in `inbox/` are also committed — they may contain personal address data.

## Alert emails

Save saved-search notification emails from LinkedIn, Naukri, Instahyre, Cutshort, Hirist,
Wellfound, Indeed or Foundit as `.eml`, `.txt` or `.md` into `inbox/`. The next run parses them,
extracts company / title / location / URL, treats them purely as leads, and moves the file to
`inbox/processed/YYYY-MM-DD-<name>`.

## Tooling

```bash
python3 ~/dotfiles/skills/job-grabber/scripts/ledger.py stats    --store ~/job-search/my_resumes/job-intel
python3 ~/dotfiles/skills/job-grabber/scripts/ledger.py lookup   --store ~/job-search/my_resumes/job-intel \
        --company "Google" --title "Software Engineer II" --url "https://..."
python3 ~/dotfiles/skills/job-grabber/scripts/ledger.py upsert   --store ~/job-search/my_resumes/job-intel --json record.json
python3 ~/dotfiles/skills/job-grabber/scripts/ledger.py mark-closed --store ~/job-search/my_resumes/job-intel --id <id> --reason "requisition 404"
python3 ~/dotfiles/skills/job-grabber/scripts/ledger.py coverage --store ~/job-search/my_resumes/job-intel --run 2026-11-06
```
