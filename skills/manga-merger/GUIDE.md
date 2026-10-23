---
name: manga-merger
description: Playbook for manga-merger — input discovery, numeric chapter/page ordering, EPUB 3 fixed-layout structure, builder CLI, validation, and troubleshooting. Loaded on demand by the manga-merger SKILL.md router.
---

# Manga → EPUB build guide

Reference for the `manga-merger` skill. The always-on rules live in `SKILL.md`; this file
holds the details the builder implements so the agent can preflight, run, and verify correctly.

- §1 Input discovery
- §2 Ordering
- §3 EPUB structure produced
- §4 Builder CLI
- §5 Validation and expected output
- §6 Edge cases and troubleshooting

---

## §1 Input discovery

The builder accepts one manga root directory. Two layouts are supported:

**Chapter-folder layout (typical)**

```
Manga Name/
  Vol.01 Ch.0000 - Prologue (en) [Group]/   01.png 02.png ... 
  Vol.01 Ch.0001.1 - Title (en) [Group]/    01.jpg ...
  ...
```

- Every immediate subdirectory that contains at least one image is a **chapter**.
- Images may sit directly in the chapter folder or in nested subfolders; nested images are
  collected recursively and sorted by their relative path.
- An immediate root-level image set is treated as a chapter too (named after the root) if
  root images exist; when chapter folders also exist it is placed first.

**Flat layout**

```
Manga Name/
  001.png 002.png 003.jpg ...
```

- The root itself becomes the single chapter. A flat folder produces no chapter TOC entries
  beyond the book entry.

Rules that apply in both layouts:

| Item | Behavior |
|---|---|
| Extensions | `.png`, `.jpg`, `.jpeg` only, case-insensitive |
| Ignored files | hidden names (leading `.`), `.DS_Store`, `Thumbs.db`, `desktop.ini`, anything not an image |
| Ignored dirs | hidden dirs, `__MACOSX` |
| Empty dirs | skipped; if nothing is found, the build aborts |
| Symlinks | followed |
| Chapter display name | folder name with a trailing `(en)`/`(eng)` and a trailing `[scanlator]` removed for the TOC; the EPUB title keeps the full root name |

Preflight by listing the root and a sample chapter before building. The builder also prints
discovered chapters/pages, so the two views can be compared.

## §2 Ordering

### Chapters

Each chapter name is sorted by a tuple, not by raw string comparison:

1. **Volume number** parsed from `vol`, `volume`, or `v` plus an optional dot, e.g.
   `Vol.01`, `Volume 12`, `v3`.
2. **Chapter number** parsed from `ch` or `chapter` plus optional dot, e.g.
   `Ch.0001.1`, `Chapter 46.5`.
3. Natural-sort of the full name as the tie-breaker.

Missing volume sorts after numbered volumes; missing chapter sorts after numbered chapters
within the same volume. This keeps `Ch.0000` (prologue) first and `Ch.0046.5` between
`0046` and `0047`.

If neither marker exists, the chapter name is natural-sorted and placed after numbered
chapters. Do not rely on shell glob order: `Vol.10` sorts before `Vol.2` in a plain `sort`.

### Pages

Pages use natural sort of the filename stem, then the full filename. Split digit runs and
compare the numeric parts numerically:

- `1.jpg`, `2.jpg`, `10.jpg`, `11.jpg` — correct numeric order.
- `01.png` … `36.png` — correct.
- `Ch.0001` vs `Ch.0001.1` — the volume/chapter parser handles the decimal.
- Non-numeric names fall back to case-insensitive lexicographic order.

The builder assigns internal names `p0001.ext`, `p0002.ext`, … in spine order, so duplicate
source names across chapters can never collide.

### Direction

The default is `--direction ltr`, matching the user's chosen behavior. Pass `--direction rtl`
only when asked; it sets `page-progression-direction="rtl"` while keeping the spine in
filename order (`01` first). Never reverse the page list to fake RTL.

## §3 EPUB structure produced

The output is an **EPUB 3 fixed-layout** book:

```
mimetype                              application/epub+zip (first entry, stored)
META-INF/container.xml                points at OEBPS/content.opf
OEBPS/content.opf                     package: metadata, manifest, spine
OEBPS/nav.xhtml                       EPUB 3 chapter TOC + landmarks
OEBPS/toc.ncx                         EPUB 2 fallback TOC for older readers
OEBPS/style.css                       full-bleed page styles
OEBPS/pages/p0001.xhtml …             one XHTML document per image
OEBPS/images/p0001.png …              images, no recompression
```

Key package details:

- `dc:title` defaults to the manga root folder name; `dc:identifier` is a generated UUID;
  `dc:language` defaults to `en`; `dc:creator` is included only when `--author` is given.
- `meta property="dcterms:modified"` is set to the build time (required by EPUB 3).
- `meta property="rendition:layout"` is `pre-paginated`; orientation is `auto` and spread is
  `none` so readers show one page at a time.
- The first image carries `properties="cover-image"` and a `<meta name="cover">` reference.
- **One uniform page canvas for the whole book.** Apple Books treats fixed-layout dimensions as
  book-wide and requires every XHTML document to declare the same viewport, with `<body>`
  matching. Per-page viewport sizes cause taller pages to be clipped. The builder computes a
  canvas from the median source aspect ratio (1200 px short edge, e.g. `1200×1722` for a
  portrait manga) and uses it for every page. `--page-size WxH` overrides it.
- Each page XHTML declares `<meta name="viewport" content="width=CW, height=CH">`, and both
  `<html>` and `<body>` carry the same pixel dimensions. A black SVG canvas with matching
  `viewBox` contains one `<image>`, scaled and centered to fit. The image rectangle is computed
  from the PNG IHDR / JPEG SOF dimensions; differing page aspects are letterboxed, never
  cropped. If a header cannot be parsed, the builder falls back to `1200×1600`.
- Page XHTML manifest items declare `properties="svg"` because the page content includes inline
  SVG.
- Images are written with `ZIP_STORED` because JPEG/PNG are already compressed. Only
  `mimetype` must be stored; storing the rest keeps the 790 MB-class build fast.
- The TOC lists one entry per chapter, linking to that chapter's first page. A flat folder
  gets a single "Start" entry. `toc.ncx` mirrors the same targets for EPUB 2 readers.

Pages are not resized, re-encoded, or rewritten. The builder only reads headers and copies
bytes into the archive.

## §4 Builder CLI

Run it with the system `python3` from the invocation directory:

```
python3 <skill-base-dir>/scripts/build_epub.py <manga_dir> [options]
```

| Flag | Default | Meaning |
|---|---|---|
| `manga_dir` | required | Manga root (chapter folders or flat images) |
| `--output PATH` | `./<manga-name>.epub` | Explicit output file; parent must exist |
| `--title TITLE` | folder name | `dc:title` |
| `--author NAME` | omitted | `dc:creator` |
| `--language LANG` | `en` | `dc:language` |
| `--direction {ltr,rtl}` | `ltr` | Reading progression |
| `--page-size WxH` | auto | Uniform page canvas; auto uses median aspect + 1200 px short edge |
| `--no-toc` | off | Suppress chapter navigation entries |

Output naming sanitizes `/` and `:` in the manga name. The builder writes to a temporary file
in the destination directory and atomically renames it on success, so an interrupted build
never leaves a half-written `.epub` at the target path.

Exit codes: `0` success, `1` build/validation error, `2` usage or existing-output error.

## §5 Validation and expected output

On success the builder itself checks:

1. The ZIP opens and `mimetype` is the **first** entry, stored, with exactly
   `application/epub+zip`.
2. `OEBPS/content.opf` parses as XML.
3. Every manifest `href` resolves to an archive member.
4. Every spine `idref` maps to a manifest item.
5. The number of `OEBPS/images/*` entries equals the number of discovered pages.
6. Every page XHTML document shares exactly one viewport and matching `<html>`/`<body>`
   dimensions equal to the chosen canvas.
7. Every SVG image rectangle lies fully inside the canvas (no overflow or crop).

It then prints a summary like:

```
Built ./Future Diary.epub
  chapters: 64
  pages:    2227
  size:     790.0 MB
  direction: ltr
  canvas:   1200x1722
```

Optional extra checks (no extra dependencies):

```
python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); print(z.testzip()); print(z.namelist()[:3])" "./Future Diary.epub"
```

If `epubcheck` happens to be installed, run it; do not install it as part of this skill.
Report success only after the built-in validation prints the summary. Never claim success from
the presence of a file alone.

## §6 Edge cases and troubleshooting

| Symptom | Cause / fix |
|---|---|
| `no images found` | Wrong root, or images live in a sibling directory. Confirm extensions and that the root is the manga folder, not its parent. |
| `output already exists` | Chosen policy is fail, not overwrite. Report the path; the user must move/delete it or pass a different `--output`. |
| Chapters out of order | Names lack `Vol`/`Ch` markers; fall back to natural sort and inspect the printed order. Rename or pass a directory with recognizable markers. |
| Prologue at end | Name lacks volume/chapter markers, so it naturally sorts after `Ch.0000` entries. Confirm the parser matched its name. |
| Missing pages | Non-image or hidden files are intentionally skipped. Compare the discovered page count with the folder listing. |
| Huge EPUB / slow build | Expected for image-heavy series; images are stored, not recompressed. Build time is dominated by copying bytes. |
| Reader shows blank pages | Check that the page SVG contains an image and that the viewport matches the canvas. If headers were unreadable the fallback size may cause extra letterboxing. |
| Apple Books clips every page at the bottom | Fixed-layout viewports differed per page. Rebuild with the current builder; it emits one uniform canvas and matching body dimensions. Do not hand-edit per-page viewport sizes. |
| Pages look narrower/taller with black bars | Intentional letterboxing from a non-matching page aspect. Use `--page-size` only if you need a different book-wide aspect. |
| TOC entries wrong | Chapter display names are cleaned of trailing `(en)`/`(eng)` and `[scanlator]`. Edit the source folder names if the TOC must be exact. |
| Permission denied | The destination directory is unwritable. Choose a writable `--output` directory; keep it outside the manga source unless the CWD is the source root. |

Never modify or delete source images. The builder is read-only with respect to the manga
directory; only the EPUB and its temporary sibling are written.
