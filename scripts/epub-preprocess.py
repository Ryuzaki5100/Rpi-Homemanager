#!/usr/bin/env python3
"""Preprocess one markdown file for EPUB generation.

Fixes that make pandoc/epubcheck (and Apple Books) happy:

  1. Flattens raw HTML Q&A blocks: removes <details>/<summary>/<strong>/<b>
     tags (many are malformed/unclosed in the source) while keeping the text.
  2. Rewrites inter-document markdown links:
       - links to a file that is included in the current EPUB -> internal #id
       - links to anything else (other .md, folders)        -> plain text
     This avoids epubcheck RSC-007 "referenced resource could not be found".
  3. Relabels a ```mermaid fence to ```text (one mislabeled block).
  4. Tags any code fence containing box-drawing glyphs as ```{.diagram} so it
     renders small and unwrapped.

Usage:
  epub-preprocess.py --root SRC --file FILE --available LISTFILE
"""
import argparse
import os
import re
import sys

TAG_RE = re.compile(r"</?(?:details|summary|strong|b)\b[^>\n]*>?", re.I)
LINK_RE = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)]*)\)")
H1_RE = re.compile(r"^#\s+(.*\S)\s*$")
BOX_RE = re.compile(r"[┌└│─├┐┘┤┬┴┼╔╚║═╗╝╠╣╦╩╬]")
FENCE_RE = re.compile(r"^(`{3,})(.*)$")


def slug(relpath: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", relpath.lower()).strip("-")
    return "doc-" + s


def resolve(root: str, cur_rel: str, target: str):
    """Resolve a relative markdown target to a root-relative path."""
    base = os.path.dirname(cur_rel)
    joined = os.path.normpath(os.path.join(base, target))
    if joined.startswith(".."):
        return None
    return joined.replace(os.sep, "/")


def rewrite_links(line: str, root: str, cur_rel: str, id_map: dict) -> str:
    def repl(m):
        label, target = m.group(1), m.group(2).strip()
        # strip an optional link title: (url "title")
        if " " in target and not target.startswith("<"):
            target = target.split(" ", 1)[0]
        low = target.lower()
        if low.startswith(("http://", "https://", "mailto:", "tel:")):
            return m.group(0)
        if target.startswith("#"):
            # Same-document anchors in the source frequently don't match pandoc's
            # generated ids (RSC-012); drop the link, keep the text. Navigation is
            # provided by the generated table of contents instead.
            return label
        path, _, _frag = target.partition("#")
        if path.lower().endswith((".md", ".markdown")):
            resolved = resolve(root, cur_rel, path)
            if resolved and resolved in id_map:
                return f"[{label}](#{id_map[resolved]})"
        return label  # drop non-resolvable / non-md links, keep text
    return LINK_RE.sub(repl, line)


def process(text: str, root: str, cur_rel: str, id_map: dict) -> str:
    lines = text.split("\n")
    out = []
    i = 0
    in_fence = False
    injected = False
    own_id = id_map.get(cur_rel)

    while i < len(lines):
        line = lines[i]
        m = FENCE_RE.match(line)
        if m and not in_fence:
            # collect the whole fenced block
            opener = line
            body = []
            i += 1
            while i < len(lines) and not FENCE_RE.match(lines[i]):
                body.append(lines[i])
                i += 1
            closer = lines[i] if i < len(lines) else "```"
            info = m.group(2).strip()
            if info.split("{", 1)[0].strip() == "mermaid":
                out.append("```text")
            elif any(BOX_RE.search(b) for b in body):
                out.append("```{.diagram}")
            else:
                out.append(opener)
            out.extend(body)
            out.append(closer)
            i += 1
            continue

        # outside fences: sanitize + inject id + rewrite links
        line = TAG_RE.sub("", line)
        if own_id and not injected:
            hm = H1_RE.match(line)
            if hm:
                line = f"# {hm.group(1)} {{#{own_id}}}"
                injected = True
        line = rewrite_links(line, root, cur_rel, id_map)
        out.append(line)
        i += 1

    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--file", required=True)
    ap.add_argument("--available", required=True,
                    help="file listing root-relative paths that may be linked")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    cur_abs = os.path.abspath(args.file)
    cur_rel = os.path.relpath(cur_abs, root).replace(os.sep, "/")

    with open(args.available, encoding="utf-8") as fh:
        available = [l.strip() for l in fh if l.strip()]
    id_map = {rel: slug(rel) for rel in available}

    with open(cur_abs, encoding="utf-8") as fh:
        text = fh.read()

    sys.stdout.write(process(text, root, cur_rel, id_map))


if __name__ == "__main__":
    main()
