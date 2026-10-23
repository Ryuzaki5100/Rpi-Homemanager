---
name: manga-merger
description: Merge a manga directory of chapter/volume folders containing PNG/JPG/JPEG page scans into one Apple Books-compatible fixed-layout EPUB in correct reading order, saved in the current working directory. Use when the user asks to merge, combine, compile, bundle, package, or convert manga chapters, volumes, or image folders into a single EPUB or ebook.
---

# manga-merger

Turn a folder of per-chapter image directories into one validated, pre-paginated EPUB.
Each image becomes one page; chapters become a table of contents.

## Step 0 — Read the guide first (mandatory)

Read the full workflow, ordering rules, and edge cases before acting:

```
read <skill-base-dir>/GUIDE.md
```

## Core rules (always apply)

1. **Read `GUIDE.md` before discovering or building.** Do not improvise an EPUB layout.
2. **Use the bundled builder** at `scripts/build_epub.py`; do not hand-assemble a ZIP or
   require Calibre, Pillow, ImageMagick, or any third-party package. Python 3 stdlib only.
3. **Write one EPUB to the invocation directory (CWD)**, named after the manga folder
   (e.g. `./Future Diary.epub`). Do not write inside the manga source tree — unless the CWD
   *is* that source root, in which case the default output necessarily sits beside the images.
4. **Never overwrite.** If the target exists, stop and report its path; let the user decide.
5. **Order by numbers, not raw strings.** Volumes and chapters parse numerically
   (`Ch.0001.1` < `Ch.0001.2` < `Ch.0002` < `Ch.0046.5`); pages use natural sort so
   `2.jpg` < `10.jpg`. Verify the first and last page of the discovery output.
6. **Accept only `.png`, `.jpg`, `.jpeg`** (case-insensitive). Ignore hidden files,
   `.DS_Store`, `Thumbs.db`, and non-image files; skip empty folders.
7. **Use one uniform page canvas for every page.** Never emit per-page viewport sizes:
   Apple Books requires consistent fixed-layout dimensions and clips pages that differ.
   The builder derives a canvas from the median source aspect (1200 px short edge) and
   letterboxes each image inside it; use `--page-size WxH` to override. Never crop.
8. **Default is left-to-right** (`page-progression-direction="ltr"`). Use right-to-left
   only when the user asks for manga-style RTL or the series clearly requires it.
9. **Validate before declaring success:** ZIP integrity, stored first `mimetype`, all
   spine/manifest targets present, one shared viewport, and image count equals discovery.
10. **Report** the absolute EPUB path, chapter count, page count, canvas, and file size.

## Files & routing

| When you need to… | Read | Purpose |
|---|---|---|
| Understand discovery, ordering, EPUB structure, CLI flags, validation, or failures | `GUIDE.md` | Full build playbook and edge cases |
| Build the EPUB | `scripts/build_epub.py` | Stdlib-only EPUB 3 builder (run it) |

## Workflow

1. Identify the manga directory: use the path the user gave; otherwise, if the CWD contains
   exactly one directory of chapter folders, use it. If ambiguous, ask.
2. Read `GUIDE.md`.
3. Preflight-read the directory names and confirm chapter/page ordering and image count.
4. Run the builder from the invocation directory:
   ```
   python3 <skill-base-dir>/scripts/build_epub.py "<manga-dir>" --direction ltr
   ```
   Add `--output`, `--title`, `--author`, `--language`, `--page-size`, or `--no-toc`
   only when needed.
5. Confirm the builder's self-validation and summary succeeded. If it fails, follow the
   troubleshooting section in `GUIDE.md`; never report a partial build as done.
6. Report the result concisely.

## Output location / deployment

The generated EPUB goes to the directory where the agent was invoked. The skill itself lives
in `~/dotfiles/skills/manga-merger/`; deploy with `home-manager switch` in `~/dotfiles/`.

## Tools

`read` (GUIDE and preflight), `glob`/`grep` (inspect page folders), `bash` (run the builder,
inspect output), `write`/`edit` (only to fix the skill itself), `question` (ambiguity).
