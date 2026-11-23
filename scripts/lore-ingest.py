#!/usr/bin/env python3
"""lore-ingest — turn the Backrooms Wiki into a queryable Obsidian corpus.

The wiki is a MediaWiki install, so the bulk path is its own public API, not
HTML scraping: 50 article titles per request with wikitext included. Firecrawl
is only needed for rendered pages and spot checks.

    lore-ingest enumerate   # titles -> .cache/index.json (classify by category)
    lore-ingest fetch       # wikitext -> .cache/raw (batched, revid-stamped)
    lore-ingest render      # wikitext -> <vault>/60-lore/**/*.md
    lore-ingest sync        # enumerate + fetch (changed revids only) + render
    lore-ingest verify      # coverage, empty bodies, unresolved links

Everything is idempotent and resumable. Property edits to a rendered note
(`game_hooks:`) survive a re-render because only `revid`/`body` are replaced.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://backrooms.fandom.com/api.php"
USER_AGENT = "noclip-lore-ingest/0.1 (+https://github.com/Ryuzaki5100/noclip-protocol-vault)"
LICENSE = "CC-BY-SA-3.0"
WIKI_BASE = "https://backrooms.fandom.com/wiki/"

# One folder per content type. Order is priority: the first category a page
# belongs to decides its type, so a level that is also a tale stays a level.
CATEGORY_TYPE = [
    ("Levels", "level"),
    ("Entities", "entity"),
    ("Objects", "object"),
    ("Phenomena", "phenomenon"),
    ("Tales", "tale"),
    ("Groups", "group"),
    ("Canons", "canon"),
    ("Guides", "guide"),
]

# Index pages whose outbound links are content, not prose.
LIST_TYPE = {
    "Areas of Interest List": "aoi",
    "Area of Interest List": "aoi",
    "Persons of Interest": "person",
    "Esoteric Category List": "esoteric",
    "Phenomenon List": "phenomenon",
    "Object List": "object",
    "Level List": "level",
    "Entity List": "entity",
    "Tales List": "tale",
}

FOLDER = {
    "level": "levels",
    "entity": "entities",
    "object": "objects",
    "phenomenon": "phenomena",
    "tale": "tales",
    "group": "groups",
    "canon": "canons",
    "poi": "poi",
    "aoi": "aoi",
    "person": "persons-of-interest",
    "esoteric": "esoteric",
    "guide": "guides",
    "rule": "rules",
    "misc": "misc",
}

# Templates that carry content: unwrap them instead of dropping them.
UNWRAP = {
    "collapse", "collapse top", "quote", "blockquote", "underline", "color",
    "center", "font", "small", "big", "nowrap", "code", "spoiler", "tabber",
}
# Templates that describe the page rather than being prose.
INFOBOXES = {"level", "entity", "object", "phenomenon", "class", "class 0", "class 1",
             "class 2", "class 3", "class 4", "class 5", "class custom",
             "class custom image", "class custom image 2", "difficulty"}
# Templates that describe the page rather than being prose. Dropping them at
# the AST level (not by regex) matters: their parameters contain braces that a
# regex cannot balance.
DROP_TEMPLATES = {"css", "seo", "voidedtheme", "theme", "darkmode", "notoc",
                  "toc", "clear", "clr", "reflist", "references", "navbox"}
# Templates whose only value is an image reference.
IMAGE_TEMPLATES = {"blurimage", "blurbackground", "simple image block", "image",
                   "infobox image", "gallery"}

DIFFICULTY_WORDS = {
    "class 0": 0, "class 1": 1, "class 2": 2, "class 3": 3, "class 4": 4, "class 5": 5,
}


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


# --------------------------------------------------------------------- http

def api(params: dict, retries: int = 5) -> dict:
    query = {"format": "json", "formatversion": "2", "maxlag": "5"}
    query.update(params)
    url = API + "?" + urllib.parse.urlencode(query)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    delay = 1.0
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if "error" in payload:
                code = payload["error"].get("code", "")
                if code in {"maxlag", "ratelimited"}:
                    raise urllib.error.HTTPError(url, 429, code, {}, None)
                raise RuntimeError(f"API error: {payload['error']}")
            return payload
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as exc:
            if attempt == retries - 1:
                raise
            wait = delay * (2 ** attempt)
            log(f"  retry {attempt + 1}/{retries} after {exc} — sleeping {wait:.0f}s")
            time.sleep(wait)
    raise RuntimeError("unreachable")


def paginate(key: str, params: dict, cont_key: str):
    cont = {}
    while True:
        payload = api({**params, **cont})
        for row in payload.get("query", {}).get(key, []):
            yield row
        if "continue" not in payload:
            return
        cont = payload["continue"]
        time.sleep(0.5)


# ------------------------------------------------------------------ paths

def vault_path(args) -> Path:
    if args.vault:
        return Path(args.vault).expanduser()
    env = os.environ.get("NOCLIP_VAULT") or os.environ.get("LORE_VAULT")
    if env:
        return Path(env).expanduser()
    return Path.home() / "roblox" / "noclip-protocol-vault"


def cache_dir(vault: Path) -> Path:
    return vault / ".cache"


def load_index(vault: Path) -> dict:
    path = cache_dir(vault) / "index.json"
    if not path.exists():
        raise SystemExit("no index: run `lore-ingest enumerate` first")
    return json.loads(path.read_text())


# -------------------------------------------------------------- enumerate

def cmd_enumerate(args) -> int:
    vault = vault_path(args)
    cache = cache_dir(vault)
    cache.mkdir(parents=True, exist_ok=True)

    log("enumerating all articles (ns 0)")
    titles: dict[str, str] = {}
    for row in paginate("allpages", {"action": "query", "list": "allpages",
                                     "apnamespace": "0", "aplimit": "500"}, "apcontinue"):
        titles[row["title"]] = "misc"
    log(f"  {len(titles)} articles")

    for category, kind in CATEGORY_TYPE:
        found = 0
        for row in paginate("categorymembers",
                            {"action": "query", "list": "categorymembers",
                             "cmtitle": f"Category:{category}", "cmnamespace": "0",
                             "cmlimit": "500"}, "cmcontinue"):
            title = row["title"]
            # First category wins, but `misc` is a placeholder, not a claim.
            if title not in titles or titles[title] == "misc":
                titles[title] = kind
                found += 1
        log(f"  Category:{category} -> {found} ({kind})")
        time.sleep(0.5)

    log("reading list pages")
    for page, kind in LIST_TYPE.items():
        try:
            payload = api({"action": "parse", "page": page, "prop": "links"})
        except Exception as exc:  # a list page may not exist under this name
            log(f"  {page}: {exc}")
            continue
        added = 0
        for link in payload.get("parse", {}).get("links", []):
            if link.get("ns") != 0:
                continue
            title = link["title"]
            if title not in titles or titles[title] == "misc":
                titles[title] = kind
                added += 1
        log(f"  {page} -> +{added} ({kind})")

    index = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source": WIKI_BASE,
        "license": LICENSE,
        "count": len(titles),
        "pages": {title: {"type": kind, "slug": slugify(title)}
                  for title, kind in sorted(titles.items())},
    }
    (cache / "index.json").write_text(json.dumps(index, indent=1, sort_keys=True))
    counts: dict[str, int] = {}
    for kind in (p["type"] for p in index["pages"].values()):
        counts[kind] = counts.get(kind, 0) + 1
    log(f"indexed {len(titles)} pages: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return 0


# -------------------------------------------------------------------- fetch

def raw_path(cache: Path, title: str) -> Path:
    digest = hashlib.sha1(title.encode("utf-8")).hexdigest()[:16]
    return cache / "raw" / f"{digest}.wiki"


def cmd_fetch(args) -> int:
    vault = vault_path(args)
    cache = cache_dir(vault)
    index = load_index(vault)
    (cache / "raw").mkdir(parents=True, exist_ok=True)

    meta_path = cache / "meta.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}

    titles = list(index["pages"])
    if args.only:
        wanted = set(args.only.split(","))
        titles = [t for t in titles if index["pages"][t]["type"] in wanted]
    if args.titles:
        requested = [t.strip() for t in args.titles.split("|") if t.strip()]
        missing = [t for t in requested if t not in index["pages"]]
        if missing:
            log(f"not in index (skipped): {', '.join(missing)}")
        titles = [t for t in requested if t in index["pages"]]
    if args.limit:
        titles = titles[: args.limit]

    if args.changed_only:
        # One cheap request per 50 titles to find what actually moved.
        stale = []
        for batch in chunk(titles, 50):
            payload = api({"action": "query", "prop": "revisions", "rvprop": "ids",
                           "titles": "|".join(batch)})
            for page in payload.get("query", {}).get("pages", []):
                title = page.get("title", "")
                revid = (page.get("revisions") or [{}])[0].get("revid")
                if not title or revid is None:
                    continue
                if meta.get(title, {}).get("revid") != revid:
                    stale.append(title)
            time.sleep(0.5)
        titles = stale
        log(f"{len(titles)} pages changed")

    batches = list(chunk(titles, 50))
    log(f"fetching {len(titles)} pages in {len(batches)} batched requests")
    for i, batch in enumerate(batches, 1):
        payload = api({
            "action": "query", "prop": "revisions",
            "rvprop": "ids|content|timestamp", "rvslots": "main",
            "titles": "|".join(batch),
        })
        for page in payload.get("query", {}).get("pages", []):
            title = page.get("title")
            revision = (page.get("revisions") or [{}])[0]
            slots = revision.get("slots", {}).get("main", {})
            content = slots.get("content")
            if not title or content is None:
                log(f"  missing: {title or page.get('title')}")
                continue
            entry = {
                "revid": revision.get("revid"),
                "timestamp": revision.get("timestamp"),
                "file": str(raw_path(cache, title).relative_to(cache)),
                "chars": len(content),
                "redirect": content.lstrip().lower().startswith("#redirect"),
            }
            write_text(raw_path(cache, title), content)
            meta[title] = entry
        meta_path.write_text(json.dumps(meta, indent=1, sort_keys=True))
        if i % 5 == 0 or i == len(batches):
            log(f"  {i}/{len(batches)} batches ({sum(1 for m in meta.values())} pages cached)")
        time.sleep(0.5)
    return 0


def chunk(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i:i + size]


# ------------------------------------------------------------------- render

def slugify(title: str) -> str:
    slug = title.lower().replace("'", "")
    slug = slug.replace("!", "-excl").replace("?", "-q").replace("&", "-and")
    slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")
    return slug or "page"


def yaml_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) or value is None:
        return str(value).lower() if value is None else str(value)
    return yaml_quote(str(value))


def yaml_quote(text: str) -> str:
    """Quote only when YAML needs it, matching what Obsidian's formatter writes."""
    lower = text.strip().lower()
    plain = (
        text != ""
        and not text.startswith((" ", "-", "?", ":", "#", "&", "*", "!", "|", ">", "%", "@", "`"))
        and not text.endswith(":")
        and ": " not in text
        and " #" not in text
        and not any(ch in text for ch in "\n\t[]{},\"'")
        and lower not in {"true", "false", "null", "yes", "no", "on", "off", "~"}
    )
    if plain:
        return text
    return "'" + text.replace("'", "''") + "'"


def frontmatter(fields: dict) -> str:
    lines = ["---"]
    for key, value in fields.items():
        if isinstance(value, list):
            if not value:
                lines.append(f"{key}: []")
            else:
                lines.append(f"{key}:")
                lines.extend(f"  - {yaml_value(item)}" for item in value)
        elif value is None:
            lines.append(f"{key}:")
        else:
            lines.append(f"{key}: {yaml_value(value)}")
    lines.append("---")
    return "\n".join(lines)


REDIRECT = re.compile(r"^\s*#redirect\s*:?\s*\[\[([^\]|#]+)", re.I | re.M)
HEADING = re.compile(r"^(={1,6})\s*(.+?)\s*\1\s*$", re.M)


def redirect_target(wikitext: str) -> str | None:
    match = REDIRECT.search(wikitext)
    return match.group(1).strip() if match else None
TABLE = re.compile(r"^\{\|.*?^\|\}\s*$", re.M | re.S)
FILE_LINK = re.compile(r"\[\[(?:File|Image):([^|\]]+)(?:\|[^\]]*)?\]\]", re.I)
CHROME_IMAGE = re.compile(r"(site-logo|wiki-wordmark|favicon|badge|placeholder)", re.I)
MEDIA_EXT = {
    "png": "image", "jpg": "image", "jpeg": "image", "gif": "image",
    "webp": "image", "bmp": "image", "svg": "image",
    "mp3": "audio", "wav": "audio", "ogg": "audio", "m4a": "audio", "flac": "audio",
    "mp4": "video", "webm": "video", "mov": "video", "ogv": "video",
}


def media_kind(name: str) -> str | None:
    return MEDIA_EXT.get(Path(name).suffix.lower().lstrip("."))


def is_content_image(name: str) -> bool:
    lower = name.strip().lower()
    if not lower or lower in {"none", "no", "image"}:
        return False
    if media_kind(name) is None:      # rejects `150px`, captions, template tokens
        return False
    if any(ch in name for ch in "{}[]<>"):
        return False
    return not CHROME_IMAGE.search(name)


def strip_braced(text: str, names: set[str]) -> str:
    """Remove `{{name|...}}` blocks by brace depth, for markup the AST chokes on.

    CSS parameters contain raw `{`/`}`, and a malformed `{{DISPLAYTITLE:` can
    swallow following blocks. A depth scanner handles both; a regex cannot.
    """
    out: list[str] = []
    i = 0
    length = len(text)
    while i < length:
        if text.startswith("{{", i):
            depth = 0
            j = i
            closed = False
            while j < length - 1:
                if text.startswith("{{", j):
                    depth += 1
                    j += 2
                    continue
                if text.startswith("}}", j):
                    depth -= 1
                    j += 2
                    if depth == 0:
                        closed = True
                        break
                    continue
                j += 1
            inner = text[i + 2: j - 2] if closed else text[i + 2:]
            head = inner.split("|")[0].split(":")[0].strip().lower()
            if head in names or head.startswith(("#", "user:", "template:")):
                i = j
                continue
        out.append(text[i])
        i += 1
    return "".join(out)


def wiki_to_markdown(wikitext: str, images: list[str]) -> str:
    from mwparserfromhell.nodes import Heading, Tag, Template, Wikilink
    import mwparserfromhell

    code = mwparserfromhell.parse(wikitext)

    for template in reversed(list(code.filter_templates(recursive=True))):
        name = str(template.name).strip().lower()
        replacement = None
        if name.startswith("displaytitle"):
            replacement = ""
        elif name in DROP_TEMPLATES:
            replacement = ""
        elif name in IMAGE_TEMPLATES:
            for param in template.params:
                key = str(param.name).strip().lower()
                if key in {"file", "image", "filename", "1"}:
                    value = str(param.value).strip()
                    if value and is_content_image(value):
                        images.append(value)
            replacement = ""
        elif name in UNWRAP:
            kept = []
            for param in template.params:
                key = str(param.name).strip().lower()
                if not param.showkey or key in {"body", "content", "text", "1"}:
                    value = str(param.value).strip()
                    if value:
                        kept.append(value)
            replacement = " ".join(kept)
        if replacement is not None:
            try:
                code.replace(template, replacement)
            except ValueError:
                pass  # nested inside a template we already replaced

    text = str(code)
    # Malformed or brace-bearing blocks that the AST leaves behind: CSS, theme
    # and DISPLAYTITLE all end up here.
    text = strip_braced(text, DROP_TEMPLATES | {"displaytitle", "css", "seo"})

    # Tables: flatten to one bullet per row. A faithful pipe-table round-trip is
    # not worth it; losing the cell text would be.
    def table_repl(match):
        rows = []
        for line in match.group(0).splitlines():
            line = line.strip()
            if line.startswith("|") and not line.startswith(("|}", "|-", "|+")):
                cells = [c.strip() for c in line.lstrip("|").split("||")]
                cells = [c for c in cells if c]
                if cells:
                    rows.append("- " + " | ".join(cells))
        return "\n".join(rows)

    text = TABLE.sub(table_repl, text)
    text = re.sub(r"\{\{\s*(?:DEFAULTSORT|NOGALLERY|NOTOC|TOC)\s*:?[^}]*\}\}", "", text,
                  flags=re.I)

    for match in FILE_LINK.finditer(text):
        name = match.group(1).strip()
        if is_content_image(name):
            images.append(name)
    text = FILE_LINK.sub("", text)
    text = text.replace("__NOTOC__", "").replace("__NOEDITSECTION__", "")

    # Wiki list markers become markdown list markers BEFORE heading conversion,
    # so a later `#`-to-`##` pass cannot confuse them.
    text = re.sub(r"^\*+\s*", "- ", text, flags=re.M)
    text = re.sub(r"^#+\s*", "1. ", text, flags=re.M)

    # Emphasis, then headings, before cleanup strips wiki markers.
    text = re.sub(r"'''(.*?)'''", r"**\1**", text, flags=re.S)
    text = re.sub(r"''(.*?)''", r"*\1*", text, flags=re.S)

    def heading_repl(match):
        level = len(match.group(1))
        return "\n" + "#" * max(2, min(level, 6)) + " " + match.group(2).strip() + "\n"

    text = HEADING.sub(heading_repl, text)

    code = mwparserfromhell.parse(text)
    for link in reversed(list(code.filter_wikilinks(recursive=True))):
        target = str(link.title).strip()
        display = str(link.text).strip() if link.text else target
        if target.lower().startswith(("file:", "image:", "category:")):
            replacement = ""
        else:
            replacement = display
        try:
            code.replace(link, replacement)
        except ValueError:
            pass

    text = str(code)
    # Footnotes: keep the text, drop the ref mechanism.
    text = re.sub(r"<ref[^>]*?/>", "", text, flags=re.I)
    text = re.sub(r"<ref[^>]*>(.*?)</ref>", lambda m: " (" + m.group(1).strip() + ")", text,
                  flags=re.S | re.I)

    text = cleanup(text)

    lines = [line.rstrip() for line in text.splitlines()]
    text = "\n".join(lines)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text


def cleanup(text: str) -> str:
    """Strip residual wiki markup without letting it eat the markdown we emitted.

    `strip_code` is not used here: it treats leading `#`/`*` as list markup and
    deletes our headings and bold markers.
    """
    # Light/dark alternate blocks are hidden on one theme; keep one copy.
    text = re.sub(r'<div[^>]*class="onlydark"[^>]*>.*?</div>', "", text, flags=re.S | re.I)

    # Templates that survived the targeted pass, innermost first. A template
    # with a long positional argument is prose in disguise; keep that argument,
    # unless the template is infrastructure (CSS, SEO, theme, user namespace).
    drop = {"css", "seo", "voidedtheme", "theme", "darkmode", "dark mode",
            "notoc", "toc", "clear", "clr", "nbsp", "reflist", "references"}
    for _ in range(6):
        def template_repl(match):
            inner = match.group(1)
            name = inner.split("|")[0].strip().lower()
            if name.startswith(("#", "user:")) or name in drop:
                return ""
            if "|" in inner:
                parts = inner.split("|")[1:]
                keep = [p.strip() for p in parts
                        if len(p.strip()) > 25 and "=" not in p]
                if keep:
                    return " ".join(keep)
            return ""

        updated = re.sub(r"\{\{([^{}]*)\}\}", template_repl, text)
        if updated == text:
            break
        text = updated

    text = re.sub(r"</?gallery[^>]*>", "", text, flags=re.I)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)                      # residual html
    text = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", text)  # [[a|b]] -> b
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)             # [[a]] -> a
    text = re.sub(r"\[https?://\S+\s+([^\]]+)\]", r"\1", text)  # [url label] -> label
    text = re.sub(r"\[https?://\S+\]", "", text)                # bare url ref
    text = text.replace("'''", "**").replace("''", "*")
    # Interlanguage links collected by Fandom at the end of an article.
    text = re.sub(r"^[a-z]{2,3}(?:-[a-z]{2,4})?:\S.*$", "", text, flags=re.M)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text


def plain(text: str) -> str:
    """Strip wiki markup and HTML from a short inline value (infobox fields)."""
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\{\{[^{}]*\}\}", "", text)
    text = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", text)
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
    text = text.replace("'''", "").replace("''", "")
    return re.sub(r"\s+", " ", text).strip()


def extract_infobox(wikitext: str) -> dict:
    import mwparserfromhell

    info: dict = {"difficulty": None, "security": None, "entity_class": None,
                  "images": [], "display_title": None}
    display = re.search(r"\{\{\s*DISPLAYTITLE\s*:\s*(.+?)\}\}", wikitext, re.I | re.S)
    if display:
        pretty = re.sub(r"\{\{[^{}]*\}\}", "", display.group(1))
        pretty = re.sub(r"<[^>]+>", "", pretty).replace("'''", "").replace("''", "")
        pretty = re.sub(r"\s+", " ", pretty).strip()
        if pretty and "{" not in pretty and "}" not in pretty and len(pretty) <= 120:
            info["display_title"] = pretty
    for template in mwparserfromhell.parse(wikitext).filter_templates(recursive=True):
        name = str(template.name).strip().lower()
        if name in DIFFICULTY_WORDS and info["difficulty"] is None:
            info["difficulty"] = DIFFICULTY_WORDS[name]
        params = {str(p.name).strip().lower(): str(p.value).strip()
                  for p in template.params if p.showkey}
        if name.startswith("class"):
            for key, target in (("security", "security"), ("entity", "entity_class"),
                                ("entities", "entity_class")):
                if key in params and not info[target]:
                    info[target] = plain(params[key])
            if "difficulty" in params and info["difficulty"] is None:
                digits = re.search(r"\d", params["difficulty"])
                if digits:
                    info["difficulty"] = int(digits.group(0))
            if name in DIFFICULTY_WORDS and info["difficulty"] is None:
                info["difficulty"] = DIFFICULTY_WORDS[name]
        if name in {"blurimage", "image", "simple image block"}:
            for key in ("file", "image", "filename"):
                if key in params and is_content_image(params[key]):
                    info["images"].append(params[key])
    return info


def cmd_render(args) -> int:
    vault = vault_path(args)
    cache = cache_dir(vault)
    index = load_index(vault)
    meta_path = cache / "meta.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    lore = vault / "60-lore"
    lore.mkdir(parents=True, exist_ok=True)

    # Redirects are not dropped: they become `aliases:` on the real note, so a
    # search for "Almond Water" lands on Object 1.
    redirect_of: dict[str, str] = {}
    aliases: dict[str, list[str]] = {}
    for title in index["pages"]:
        source = raw_path(cache, title)
        if not source.exists():
            continue
        target = redirect_target(source.read_text())
        if target:
            redirect_of[title] = target
            aliases.setdefault(target.lower(), []).append(title)

    used_slugs: set[str] = set()
    written = 0
    skipped = 0

    # Media sections come from the committed manifest, so a fresh clone already
    # has the links and only needs the bytes fetched into 60-lore/_media/.
    manifest = load_manifest(vault)
    media_by_note: dict[str, list[tuple[str, str]]] = {}
    if manifest:
        for name, entry in manifest["files"].items():
            for note in entry.get("notes", []):
                media_by_note.setdefault(note, []).append((name, entry["local"]))

    for title, entry in sorted(index["pages"].items()):
        kind = entry["type"]
        if args.only and kind not in set(args.only.split(",")):
            continue
        cached = meta.get(title)
        source = raw_path(cache, title)
        if not cached or not source.exists():
            skipped += 1
            continue
        if title in redirect_of:
            skipped += 1
            continue
        wikitext = source.read_text()
        info = extract_infobox(wikitext)
        body = wiki_to_markdown(wikitext, info["images"])

        slug = entry["slug"]
        if slug in used_slugs:
            slug = f"{slug}-{hashlib.sha1(title.encode()).hexdigest()[:5]}"
        used_slugs.add(slug)

        folder = lore / FOLDER.get(kind, "misc")
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{slug}.md"
        existing = read_existing_hooks(target)

        fields = {
            "id": slug,
            "title": title,
            "type": kind,
            "source": WIKI_BASE + urllib.parse.quote(title.replace(" ", "_")),
            "revid": cached.get("revid"),
            "retrieved": time.strftime("%Y-%m-%d", time.gmtime()),
            "license": LICENSE,
        }
        if info["display_title"]:
            fields["display_title"] = info["display_title"]
        if info["difficulty"] is not None:
            fields["difficulty"] = info["difficulty"]
        if info["security"]:
            fields["security"] = info["security"]
        if info["entity_class"]:
            fields["entity_class"] = info["entity_class"]
        images = list(dict.fromkeys(info["images"]))[:12]
        if images:
            fields["images"] = images
        page_aliases = sorted(aliases.get(title.lower(), []))
        if page_aliases:
            fields["aliases"] = page_aliases[:12]
        fields["game_hooks"] = existing.get("game_hooks", [])
        fields["tags"] = [kind]

        note = frontmatter(fields) + "\n\n" + f"# {title}\n\n" + body + "\n"
        media = media_by_note.get(str(target.relative_to(vault)), [])
        if media:
            seen = []
            for name, local in media:
                if name not in [n for n, _ in seen]:
                    seen.append((name, local))
            shown = seen[:12]
            block = ["", "## Media", ""]
            block += [f"![{name}](../_media/{local})" for name, local in shown]
            if len(seen) > len(shown):
                block += ["", f"_{len(seen) - len(shown)} more in `_media-index.md`._"]
            note += "\n".join(block) + "\n"
        write_text(target, note)
        written += 1

    log(f"rendered {written} notes ({skipped} not fetched)")
    write_index(vault, index, meta, lore)
    return 0


def natural_key(title: str):
    """Sort 'Level 9' before 'Level 10', and keep sublevels near their parent."""
    parts = re.split(r"(\d+(?:\.\d+)?)", title.lower())
    key = []
    for part in parts:
        try:
            key.append(float(part))
        except ValueError:
            key.append(part)
    return key


def write_index(vault: Path, index: dict, meta: dict, lore: Path) -> None:
    by_slug = {path.stem: path for path in lore.rglob("*.md")}
    heads = {slug: path.read_text().split("\n---", 1)[0]
             for slug, path in by_slug.items()}

    rows: list[dict] = []
    for title, entry in sorted(index["pages"].items()):
        cached = meta.get(title)
        if not cached or cached.get("redirect"):
            continue
        path = by_slug.get(entry["slug"])
        if path is None:
            continue
        head = heads[entry["slug"]]
        rows.append({
            "title": title,
            "type": entry["type"],
            "path": str(path.relative_to(vault)),
            "difficulty": field(head, "difficulty"),
            "security": field(head, "security"),
            "entity_class": field(head, "entity_class"),
            "revid": field(head, "revid"),
        })

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["type"]] = counts.get(row["type"], 0) + 1

    (lore / "_index.json").write_text(json.dumps({
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source": WIKI_BASE,
        "license": LICENSE,
        "counts": dict(sorted(counts.items())),
        "pages": rows,
    }, indent=1, sort_keys=True))

    lines = [
        "---",
        "tags: [lore, moc]",
        "---",
        "",
        "# Lore index",
        "",
        f"{len(rows)} transcribed articles from the Backrooms Wiki. Bodies are",
        "reference, not design; see `_attribution.md` for licence and method.",
        "",
        "## Counts",
        "",
        "| Type | Notes | Folder |",
        "|---|---:|---|",
    ]
    for kind, count in sorted(counts.items(), key=lambda kv: -kv[1]):
        lines.append(f"| {kind} | {count} | `{FOLDER.get(kind, 'misc')}/` |")

    levels = [r for r in rows if r["type"] == "level"]
    lines += ["", f"## Levels ({len(levels)})", "",
              "| Level | Difficulty | Security | Entities |", "|---|---|---|---|"]
    for row in sorted(levels, key=lambda r: natural_key(r["title"]))[:400]:
        lines.append(
            f"| [{row['title']}]({row['path']}) | {row['difficulty'] or '—'} | "
            f"{row['security'] or '—'} | {row['entity_class'] or '—'} |"
        )
    if len(levels) > 400:
        lines.append(f"| … {len(levels) - 400} more in `levels/` | | | |")

    lines += ["", "## How to query", "",
              "```sh",
              "rg -l \"difficulty: 4\" 60-lore/levels",
              "rg -n 'almond water' 60-lore --glob '!tales/**'",
              "jq -r '.pages[] | select(.type==\"level\" and .difficulty>=4) | .title' \\",
              "  60-lore/_index.json",
              "```", ""]
    (lore / "_index.md").write_text("\n".join(lines))
    log(f"index: {len(rows)} notes, {len(levels)} levels")


def field(head: str, key: str) -> str | None:
    prefix = f"{key}: "
    for line in head.splitlines():
        if line.startswith(prefix):
            value = plain(line[len(prefix):].strip().strip("'"))
            if value in {"None", "null", ""}:
                return None
            return value
    return None


def read_existing_hooks(path: Path) -> dict:
    """Read `game_hooks` back before a re-render, tolerating either YAML style."""
    if not path.exists():
        return {}
    head = path.read_text().split("\n---", 1)[0]
    hooks: list[str] = []
    in_list = False
    for line in head.splitlines():
        if line.startswith("game_hooks:"):
            rest = line.split(":", 1)[1].strip()
            if rest.startswith("["):
                try:
                    hooks = json.loads(rest)
                except json.JSONDecodeError:
                    hooks = []
                in_list = False
            elif rest:
                in_list = False
            else:
                in_list = True
        elif in_list and line.strip().startswith("- "):
            hooks.append(line.strip()[2:].strip().strip("'\""))
        elif in_list and line and not line.startswith((" ", "\t")):
            in_list = False
    return {"game_hooks": hooks}


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


# ------------------------------------------------------------------- media

# The manifest is the only committed artifact of the media pipeline: filenames,
# resolved URLs, sizes and which notes reference them. The bytes live in
# 60-lore/_media/ which is gitignored, so a clone stays small and `media fetch`
# materialises the cache from the manifest alone (no wiki re-crawl).

def local_name(name: str) -> str:
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:10]
    stem = re.sub(r"[^a-z0-9]+", "-", Path(name).stem.lower()).strip("-")[:60] or "file"
    suffix = Path(name).suffix.lower()
    return f"{digest}-{stem}{suffix}"


def norm_title(name: str) -> str:
    return name.replace("_", " ").strip().lower()


def iter_note_images(vault: Path):
    """Yield (note path, [image names]) for every note that references media.

    Handles both flow (`images: ["a"]`) and block (`images:\\n  - a`) YAML,
    because Obsidian or an external formatter may rewrite the frontmatter.
    """
    for path in sorted((vault / "60-lore").rglob("*.md")):
        if path.name.startswith("_"):
            continue
        head = path.read_text().split("\n---", 1)[0]
        names: list[str] = []
        in_list = False
        for line in head.splitlines():
            if line.startswith("images:"):
                rest = line[len("images:"):].strip()
                if rest.startswith("["):
                    try:
                        names.extend(json.loads(rest))
                    except json.JSONDecodeError:
                        names.extend(re.findall(r"['\"]([^'\"]+)['\"]", rest))
                    in_list = False
                else:
                    in_list = True
            elif in_list and line.strip().startswith("- "):
                names.append(line.strip()[2:].strip().strip("'\""))
            elif in_list and line and not line.startswith((" ", "\t")):
                in_list = False
        if names:
            yield (str(path.relative_to(vault)),
                   [n for n in names if n and media_kind(n)])


def load_manifest(vault: Path):
    path = vault / "60-lore" / "_media.json"
    if not path.exists():
        return None
    return json.loads(path.read_text())


def media_manifest(vault: Path, width: int) -> int:
    lore = vault / "60-lore"
    notes: dict[str, list[str]] = {}
    for rel, names in iter_note_images(vault):
        for name in names:
            notes.setdefault(name, []).append(rel)

    requested = sorted(notes)
    # Several spellings can normalise to the same MediaWiki title. Map the
    # normalised form to every variant so a resolved page covers all of them.
    by_norm: dict[str, list[str]] = {}
    for name in requested:
        by_norm.setdefault(norm_title(name), []).append(name)
    log(f"resolving {len(requested)} media references")

    entries: dict[str, dict] = {}
    unresolved: list[str] = []
    batches = list(chunk(requested, 50))
    for i, batch in enumerate(batches, 1):
        payload = api({
            "action": "query", "prop": "imageinfo",
            "iiprop": "url|size|mime", "iiurlwidth": str(width),
            "titles": "|".join("File:" + n for n in batch),
        })
        for page in payload.get("query", {}).get("pages", []):
            title = page.get("title", "")
            canonical = title.split(":", 1)[-1]
            variants = by_norm.get(norm_title(canonical), [])
            if not variants:
                continue
            info = (page.get("imageinfo") or [None])[0]
            if not info:
                unresolved.extend(variants)
                continue
            merged_notes = sorted({n for v in variants for n in notes.get(v, [])})
            entries[canonical] = {
                "local": local_name(canonical),
                "aliases": variants,
                "mime": info.get("mime"),
                "bytes": info.get("size", 0),
                "url": info.get("url"),
                "thumb": info.get("thumburl") or info.get("url"),
                "notes": merged_notes,
            }
        if i % 20 == 0 or i == len(batches):
            log(f"  {i}/{len(batches)} batches")
        time.sleep(0.3)

    covered = {v for entry in entries.values() for v in entry["aliases"]}
    for name in requested:
        if name not in covered and name not in unresolved:
            unresolved.append(name)

    total = sum(e["bytes"] for e in entries.values())
    manifest = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source": WIKI_BASE,
        "license": "see 60-lore/_attribution.md (per-file licences are not exposed by Fandom)",
        "thumb_width": width,
        "count": len(entries),
        "bytes": total,
        "unresolved": sorted(set(unresolved)),
        "files": entries,
    }
    (lore / "_media.json").write_text(json.dumps(manifest, indent=1, sort_keys=True))
    write_media_index(vault, manifest)
    log(f"manifest: {len(entries)} files, {total / 1024 / 1024:.0f} MB estimated, "
        f"{len(manifest['unresolved'])} unresolved")
    return 0


def write_media_index(vault: Path, manifest: dict) -> None:
    by_note: dict[str, list[tuple[str, dict]]] = {}
    for name, entry in manifest["files"].items():
        for note in entry.get("notes", []):
            by_note.setdefault(note, []).append((name, entry))

    lines = [
        "---", "tags: [lore, media]", "---", "",
        "# Media index", "",
        f"{manifest['count']} files referenced by {len(by_note)} notes.",
        "The bytes are **not** in git: run `lore-ingest media fetch` to materialise",
        "`_media/` locally. See `FETCH-MEDIA.md`.", "",
        "| Note | Media |", "|---|---|",
    ]
    for note in sorted(by_note):
        names = sorted({n for n, _ in by_note[note]})
        links = ", ".join(names[:4])
        more = f" +{len(names) - 4}" if len(names) > 4 else ""
        lines.append(f"| [{Path(note).stem}]({Path(note).relative_to('60-lore')}) | {links}{more} |")
        lines.append(f"| [{Path(note).stem}]({Path(note).relative_to('60-lore')}) | {links}{more} |")
    (vault / "60-lore" / "_media-index.md").write_text("\n".join(lines) + "\n")


def media_fetch(vault: Path, manifest: dict, missing_only: bool, width: int,
                jobs: int) -> int:
    from concurrent.futures import ThreadPoolExecutor, as_completed

    dest = vault / "60-lore" / "_media"
    dest.mkdir(parents=True, exist_ok=True)

    work = []
    skipped = 0
    for name, entry in manifest["files"].items():
        target = dest / entry["local"]
        if target.exists() and target.stat().st_size > 0:
            skipped += 1
            if missing_only:
                continue
            continue
        url = entry["url"]
        if entry.get("mime", "").startswith("image/") and entry.get("thumb"):
            url = entry["thumb"]
        work.append((name, url, target))

    log(f"fetching {len(work)} files ({skipped} already present) with {jobs} workers")

    def download(item):
        name, url, target = item
        if not url:
            return (name, "no url")
        for attempt in range(3):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(request, timeout=90) as response:
                    data = response.read()
                if not data:
                    raise ValueError("empty body")
                tmp = target.with_suffix(target.suffix + ".part")
                tmp.write_bytes(data)
                tmp.replace(target)
                return (name, None)
            except Exception as exc:  # network, 404, throttle
                if attempt == 2:
                    return (name, str(exc))
                time.sleep(2 * (attempt + 1))
        return (name, "exhausted")

    failures = {}
    done = 0
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = [pool.submit(download, item) for item in work]
        for future in as_completed(futures):
            name, error = future.result()
            done += 1
            if error:
                failures[name] = error
            if done % 250 == 0 or done == len(work):
                log(f"  {done}/{len(work)} ({len(failures)} failed)")

    fail_path = dest / "failures.json"
    if failures:
        fail_path.write_text(json.dumps(failures, indent=1, sort_keys=True))
        log(f"{len(failures)} failures recorded in {fail_path.relative_to(vault)}")
    elif fail_path.exists():
        fail_path.unlink()
    return 0 if not failures else 1


def media_verify(vault: Path, manifest: dict) -> int:
    dest = vault / "60-lore" / "_media"
    present = 0
    missing = []
    for name, entry in manifest["files"].items():
        target = dest / entry["local"]
        if target.exists() and target.stat().st_size > 0:
            present += 1
        else:
            missing.append(name)
    on_disk = sum(p.stat().st_size for p in dest.glob("*") if p.is_file()) if dest.exists() else 0
    print(f"manifest entries : {manifest['count']}")
    print(f"present          : {present}")
    print(f"missing          : {len(missing)}")
    print(f"unresolved (wiki): {len(manifest.get('unresolved', []))}")
    print(f"on disk          : {on_disk / 1024 / 1024:.0f} MB")
    if missing[:5]:
        print("  e.g. " + ", ".join(missing[:5]))
    return 0 if not missing else 1


def cmd_media(args) -> int:
    vault = vault_path(args)
    if args.action == "manifest":
        return media_manifest(vault, args.width)

    manifest = load_manifest(vault)
    if manifest is None:
        raise SystemExit("no 60-lore/_media.json: run `lore-ingest media manifest` first")

    if args.action == "fetch":
        return media_fetch(vault, manifest, args.missing, args.width, args.jobs)
    if args.action == "verify":
        return media_verify(vault, manifest)
    raise SystemExit(f"unknown media action: {args.action}")


# ------------------------------------------------------------------- verify

def cmd_verify(args) -> int:
    vault = vault_path(args)
    cache = cache_dir(vault)
    index = load_index(vault)
    meta = json.loads((cache / "meta.json").read_text()) if (cache / "meta.json").exists() else {}
    lore = vault / "60-lore"

    notes = {path.stem: path for path in lore.rglob("*.md")}
    empty, missing, redlinks, redirects = [], [], [], [];
    for title, entry in index["pages"].items():
        cached = meta.get(title)
        if not cached:
            redlinks.append(title)          # linked from an index page, never created
            continue
        if cached.get("redirect"):
            redirects.append(title)
            continue
        path = notes.get(entry["slug"])
        if path is None:
            missing.append(title)
            continue
        body = path.read_text().split("\n---", 2)[-1]
        if len(body.strip()) < 120:
            empty.append(title)

    print(f"indexed titles : {index['count']}")
    print(f"fetched pages  : {len(meta)}")
    print(f"redirects      : {len(redirects)} (folded into aliases)")
    print(f"redlinks       : {len(redlinks)} (listed on the wiki, no article)")
    print(f"rendered notes : {len(notes)}")
    print(f"missing notes  : {len(missing)}")
    print(f"thin bodies    : {len(empty)}")
    if missing[:5]:
        print("  missing e.g. " + ", ".join(missing[:5]))
    if empty[:5]:
        print("  thin e.g.    " + ", ".join(empty[:5]))
    return 0 if not missing else 1


# --------------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(prog="lore-ingest", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--vault", help="vault root (default: ~/roblox/noclip-protocol-vault)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("enumerate", help="build .cache/index.json from the wiki")
    p.set_defaults(func=cmd_enumerate)

    p = sub.add_parser("fetch", help="download wikitext for indexed pages")
    p.add_argument("--only", help="comma-separated types (level,entity,...)")
    p.add_argument("--titles", help="pipe-separated exact titles (testing / targeted)")
    p.add_argument("--limit", type=int, help="stop after N pages (testing)")
    p.add_argument("--changed-only", action="store_true", help="skip unchanged revids")
    p.set_defaults(func=cmd_fetch)

    p = sub.add_parser("render", help="convert cached wikitext into vault notes")
    p.add_argument("--only", help="comma-separated types")
    p.set_defaults(func=cmd_render)

    p = sub.add_parser("sync", help="enumerate + changed fetch + render")

    def cmd_sync(args):
        rc = cmd_enumerate(args)
        args.changed_only = True
        rc |= cmd_fetch(args)
        return rc | cmd_render(args)

    p.set_defaults(func=cmd_sync)

    p = sub.add_parser("verify", help="coverage and quality report")
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("media", help="resolve, fetch and verify wiki media")
    p.add_argument("action", choices=["manifest", "fetch", "verify"])
    p.add_argument("--jobs", type=int, default=4, help="parallel downloads (default 4)")
    p.add_argument("--width", type=int, default=800, help="thumbnail width (default 800)")
    p.add_argument("--missing", action="store_true", help="fetch only absent files")
    p.set_defaults(func=cmd_media)

    args = parser.parse_args()
    if args.command == "sync":
        args.only = None
        args.limit = None
        args.titles = None
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
