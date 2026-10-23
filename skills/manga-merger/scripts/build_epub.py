#!/usr/bin/env python3
"""Build a fixed-layout EPUB 3 from a directory of manga page images.

Standard library only: no Pillow, Calibre, or ImageMagick required.

Usage:
    python3 build_epub.py <manga_dir> [--output PATH] [--title TITLE]
                          [--author NAME] [--language LANG]
                          [--direction {ltr,rtl}] [--no-toc]
"""

from __future__ import annotations

import argparse
import html
import os
import re
import statistics
import struct
import sys
import tempfile
import uuid
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from xml.etree import ElementTree

IMAGE_EXTS = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}
IGNORED_NAMES = {".ds_store", "thumbs.db", "desktop.ini"}
IGNORED_DIRS = {"__macosx"}
FALLBACK_SIZE = (1200, 1600)
MIMETYPE = "application/epub+zip"


class BuildError(Exception):
    pass


class ExistingOutputError(BuildError):
    pass


@dataclass
class Page:
    path: str
    ext: str
    width: int
    height: int


@dataclass
class Chapter:
    source: str
    title: str
    pages: list[Page] = field(default_factory=list)


def xml_escape(value: object) -> str:
    return html.escape(str(value), quote=True)


def natural_key(value: str):
    return tuple(
        int(part) if part.isdigit() else part.casefold()
        for part in re.split(r"(\d+)", value)
    )


def chapter_key(name: str):
    volume = re.search(r"(?i)\bvol(?:ume)?\.?\s*(\d+(?:\.\d+)?)", name)
    chapter = re.search(r"(?i)\bch(?:apter)?\.?\s*(\d+(?:\.\d+)?)", name)
    volume_no = float(volume.group(1)) if volume else float("inf")
    chapter_no = float(chapter.group(1)) if chapter else float("inf")
    return (volume_no, chapter_no, natural_key(name))


def display_title(name: str) -> str:
    title = name.strip()
    previous = None
    while title and title != previous:
        previous = title
        title = re.sub(r"\s*\[[^\]]*\]\s*$", "", title).strip()
        title = re.sub(r"\s*\((?:en|eng)\)\s*$", "", title,
                       flags=re.IGNORECASE).strip()
    return title or name


def page_sort_key(path: str):
    return (natural_key(os.path.splitext(os.path.basename(path))[0]), natural_key(path))


def is_image(name: str) -> bool:
    return os.path.splitext(name)[1].lower() in IMAGE_EXTS


def is_ignored_file(name: str) -> bool:
    lowered = name.casefold()
    return name.startswith(".") or lowered in IGNORED_NAMES


def nested_images(directory: str) -> list[str]:
    found: list[str] = []
    for current, dirs, files in os.walk(directory, followlinks=True):
        dirs[:] = sorted(
            d for d in dirs if not d.startswith(".") and d.casefold() not in IGNORED_DIRS
        )
        for name in files:
            path = os.path.join(current, name)
            if is_image(name) and not is_ignored_file(name) and os.path.isfile(path):
                found.append(path)
    found.sort(key=lambda p: natural_key(os.path.relpath(p, directory)))
    return found


def immediate_images(directory: str) -> list[str]:
    found: list[str] = []
    with os.scandir(directory) as entries:
        for entry in entries:
            if entry.is_file(follow_symlinks=True) and is_image(entry.name):
                if not is_ignored_file(entry.name):
                    found.append(entry.path)
    found.sort(key=page_sort_key)
    return found


def png_size(handle) -> tuple[int, int] | None:
    data = handle.read(24)
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR":
        width, height = struct.unpack(">II", data[16:24])
        if width and height:
            return width, height
    return None


def jpeg_size(handle) -> tuple[int, int] | None:
    data = handle.read()
    if len(data) < 4 or data[:2] != b"\xff\xd8":
        return None
    sof_markers = {
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
        0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
    }
    index = 2
    while index + 1 < len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        while index < len(data) and data[index] == 0xFF:
            index += 1
        if index >= len(data):
            break
        marker = data[index]
        index += 1
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            continue
        if index + 1 >= len(data):
            break
        segment_length = struct.unpack(">H", data[index:index + 2])[0]
        if segment_length < 2:
            break
        if marker in sof_markers and index + 7 <= len(data):
            height, width = struct.unpack(">HH", data[index + 3:index + 7])
            if width and height:
                return width, height
            return None
        index += segment_length
    return None


def image_size(path: str, ext: str) -> tuple[int, int]:
    try:
        with open(path, "rb") as handle:
            if ext == ".png":
                size = png_size(handle)
            else:
                size = jpeg_size(handle)
            if size:
                return size
    except OSError as exc:
        raise BuildError(f"cannot read image {path}: {exc}") from exc
    return FALLBACK_SIZE


def discover(manga_dir: str) -> tuple[str, list[Chapter]]:
    root = os.path.abspath(os.path.expanduser(manga_dir))
    if not os.path.isdir(root):
        raise BuildError(f"not a directory: {root}")

    root_images = immediate_images(root)
    chapter_dirs: list[str] = []
    with os.scandir(root) as entries:
        for entry in entries:
            if not entry.is_dir(follow_symlinks=True):
                continue
            if entry.name.startswith(".") or entry.name.casefold() in IGNORED_DIRS:
                continue
            if nested_images(entry.path):
                chapter_dirs.append(entry.path)

    chapters: list[Chapter] = []
    for directory in chapter_dirs:
        chapters.append(
            Chapter(
                source=directory,
                title=display_title(os.path.basename(directory)),
                pages=[],
            )
        )
    chapters.sort(key=lambda c: chapter_key(os.path.basename(c.source)))

    if root_images:
        chapters.insert(
            0,
            Chapter(
                source=root,
                title=display_title(os.path.basename(root)),
                pages=[],
            ),
        )

    if not chapters:
        raise BuildError(
            f"no images found in {root} (expected .png, .jpg, or .jpeg files "
            "in the folder or in chapter subfolders)"
        )

    for chapter in chapters:
        paths = root_images if chapter.source == root else nested_images(chapter.source)
        if not paths:
            continue
        for path in paths:
            ext = os.path.splitext(path)[1].lower()
            width, height = image_size(path, ext)
            chapter.pages.append(Page(path=path, ext=ext, width=width, height=height))

    chapters = [chapter for chapter in chapters if chapter.pages]
    if not chapters:
        raise BuildError(f"no usable images found in {root}")
    return root, chapters


def container_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<container version="1.0" '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        "  <rootfiles>\n"
        '    <rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/>\n'
        "  </rootfiles>\n"
        "</container>\n"
    )


def parse_page_size(value: str) -> tuple[int, int]:
    match = re.fullmatch(r"\s*(\d+)\s*[xX,\s]\s*(\d+)\s*", value)
    if not match:
        raise BuildError(f"invalid --page-size {value!r}; expected WxH, e.g. 1200x1600")
    width, height = int(match.group(1)), int(match.group(2))
    if not (100 <= width <= 10000 and 100 <= height <= 10000):
        raise BuildError("--page-size dimensions must be between 100 and 10000 pixels")
    return width, height


def compute_canvas(pages: list[Page], page_size: str | None = None) -> tuple[int, int]:
    """Pick one canvas for the whole book from the median source aspect ratio.

    Apple Books requires fixed-layout documents to declare consistent viewport
    dimensions; varying sizes cause pages to be clipped.
    """
    if page_size:
        return parse_page_size(page_size)
    ratios = [
        page.width / page.height
        for page in pages
        if page.width > 0 and page.height > 0
    ]
    if not ratios:
        raise BuildError("cannot choose a page canvas: no valid image dimensions")
    ratio = statistics.median(ratios)
    short_edge = 1200
    if ratio >= 1:
        height = short_edge
        width = max(1, round(short_edge * ratio))
    else:
        width = short_edge
        height = max(1, round(short_edge / ratio))
    return width, height


def fit_rect(page: Page, canvas: tuple[int, int]) -> tuple[int, int, int, int]:
    canvas_width, canvas_height = canvas
    scale = min(canvas_width / page.width, canvas_height / page.height)
    width = max(1, round(page.width * scale))
    height = max(1, round(page.height * scale))
    left = (canvas_width - width) // 2
    top = (canvas_height - height) // 2
    return left, top, width, height


def page_xhtml(
    number: int,
    image_href: str,
    page: Page,
    canvas: tuple[int, int],
    language: str,
) -> str:
    lang = xml_escape(language)
    canvas_width, canvas_height = canvas
    left, top, width, height = fit_rect(page, canvas)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<!DOCTYPE html>\n"
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops" '
        f'xml:lang="{lang}" lang="{lang}" '
        f'style="width:{canvas_width}px;height:{canvas_height}px;">\n'
        "<head>\n"
        '  <meta charset="utf-8"/>\n'
        f"  <title>Page {number}</title>\n"
        f'  <meta name="viewport" content="width={canvas_width}, '
        f'height={canvas_height}"/>\n'
        '  <link rel="stylesheet" type="text/css" href="../style.css"/>\n'
        "</head>\n"
        f'<body class="page" style="width:{canvas_width}px;'
        f'height:{canvas_height}px;">\n'
        f'  <svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" '
        f'width="100%" height="100%" viewBox="0 0 {canvas_width} '
        f'{canvas_height}" preserveAspectRatio="xMidYMid meet">\n'
        f'    <rect x="0" y="0" width="{canvas_width}" '
        f'height="{canvas_height}" fill="#000"/>\n'
        f'    <image x="{left}" y="{top}" width="{width}" '
        f'height="{height}" preserveAspectRatio="xMidYMid meet" '
        f'xlink:href="../images/{xml_escape(image_href)}"/>\n'
        "  </svg>\n"
        "</body>\n"
        "</html>\n"
    )


def style_css() -> str:
    return (
        "@page { margin: 0; }\n"
        "html, body { margin: 0; padding: 0; }\n"
        "body.page { overflow: hidden; background: #000; position: relative; }\n"
        "svg { display: block; }\n"
    )



def nav_xhtml(entries: list[tuple[str, str]], title: str, language: str) -> str:
    items = "\n".join(
        f'        <li><a href="{xml_escape(href)}">{xml_escape(label)}</a></li>'
        for label, href in entries
    )
    lang = xml_escape(language)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<!DOCTYPE html>\n"
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops" '
        f'xml:lang="{lang}" lang="{lang}">\n'
        "<head>\n"
        '  <meta charset="utf-8"/>\n'
        "  <title>Contents</title>\n"
        '  <link rel="stylesheet" type="text/css" href="style.css"/>\n'
        "</head>\n"
        "<body>\n"
        '  <nav epub:type="toc" id="toc">\n'
        "    <h1>Contents</h1>\n"
        "    <ol>\n"
        f"{items}\n"
        "    </ol>\n"
        "  </nav>\n"
        '  <nav epub:type="landmarks" id="landmarks" hidden="hidden">\n'
        "    <ol>\n"
        f'      <li><a epub:type="bodymatter" href="{xml_escape(entries[0][1])}">'
        f"Start</a></li>\n"
        "    </ol>\n"
        "  </nav>\n"
        "</body>\n"
        "</html>\n"
    )


def ncx_xml(entries: list[tuple[str, str]], title: str, book_id: str) -> str:
    points = []
    for order, (label, href) in enumerate(entries, start=1):
        points.append(
            f'    <navPoint id="navPoint-{order}" playOrder="{order}">\n'
            f"      <navLabel><text>{xml_escape(label)}</text></navLabel>\n"
            f'      <content src="{xml_escape(href)}"/>\n'
            "    </navPoint>"
        )
    lang = "en"
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" '
        f'xml:lang="{lang}">\n'
        "  <head>\n"
        f'    <meta name="dtb:uid" content="{xml_escape(book_id)}"/>\n'
        '    <meta name="dtb:depth" content="1"/>\n'
        '    <meta name="dtb:totalPageCount" content="0"/>\n'
        '    <meta name="dtb:maxPageNumber" content="0"/>\n'
        "  </head>\n"
        f"  <docTitle><text>{xml_escape(title)}</text></docTitle>\n"
        "  <navMap>\n"
        + "\n".join(points)
        + "\n  </navMap>\n"
        "</ncx>\n"
    )


def content_opf(
    pages: list[Page],
    entries: list[tuple[str, str]],
    title: str,
    author: str | None,
    language: str,
    direction: str,
    book_id: str,
    modified: str,
) -> str:
    metadata = [
        f'    <dc:identifier id="bookid">{xml_escape(book_id)}</dc:identifier>',
        f"    <dc:title>{xml_escape(title)}</dc:title>",
        f"    <dc:language>{xml_escape(language)}</dc:language>",
    ]
    if author:
        metadata.append(f"    <dc:creator>{xml_escape(author)}</dc:creator>")
    metadata += [
        f'    <meta property="dcterms:modified">{modified}</meta>',
        '    <meta property="rendition:layout">pre-paginated</meta>',
        '    <meta property="rendition:orientation">auto</meta>',
        '    <meta property="rendition:spread">none</meta>',
        '    <meta name="cover" content="img0001"/>',
    ]

    manifest = [
        '    <item id="nav" href="nav.xhtml" '
        'media-type="application/xhtml+xml" properties="nav"/>',
        '    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
        '    <item id="css" href="style.css" media-type="text/css"/>',
    ]
    for index, page in enumerate(pages, start=1):
        props = ' properties="cover-image"' if index == 1 else ""
        manifest.append(
            f'    <item id="img{index:05d}" href="images/p{index:05d}{page.ext}" '
            f'media-type="{IMAGE_EXTS[page.ext]}"{props}/>'
        )
        manifest.append(
            f'    <item id="page{index:05d}" href="pages/p{index:05d}.xhtml" '
            'media-type="application/xhtml+xml" properties="svg"/>'
        )

    spine = [
        f'    <itemref idref="page{index:05d}"/>'
        for index in range(1, len(pages) + 1)
    ]

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="bookid" '
        f'xml:lang="{xml_escape(language)}">\n'
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        + "\n".join(metadata)
        + "\n  </metadata>\n"
        "  <manifest>\n"
        + "\n".join(manifest)
        + "\n  </manifest>\n"
        f'  <spine toc="ncx" page-progression-direction="{direction}">\n'
        + "\n".join(spine)
        + "\n  </spine>\n"
        "</package>\n"
    )


def toc_entries(chapters: list[Chapter], page_numbers: list[list[int]], use_toc: bool):
    if use_toc and len(chapters) > 1:
        return [
            (chapter.title, f"pages/p{numbers[0]:05d}.xhtml")
            for chapter, numbers in zip(chapters, page_numbers)
        ]
    return [("Start", "pages/p00001.xhtml")]


def build(
    root: str,
    chapters: list[Chapter],
    output: str,
    title: str,
    author: str | None,
    language: str,
    direction: str,
    use_toc: bool,
    page_size: str | None = None,
) -> dict[str, object]:
    output = os.path.abspath(os.path.expanduser(output))
    output_dir = os.path.dirname(output)
    if not os.path.isdir(output_dir):
        raise BuildError(f"output directory does not exist: {output_dir}")
    if os.path.exists(output):
        raise ExistingOutputError(f"output already exists (will not overwrite): {output}")

    all_pages: list[Page] = []
    page_numbers: list[list[int]] = []
    for chapter in chapters:
        numbers = []
        for page in chapter.pages:
            all_pages.append(page)
            numbers.append(len(all_pages))
        page_numbers.append(numbers)

    entries = toc_entries(chapters, page_numbers, use_toc)
    canvas = compute_canvas(all_pages, page_size)
    book_id = f"urn:uuid:{uuid.uuid4()}"
    modified = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    canvas_ratio = canvas[0] / canvas[1]
    letterboxed = sum(
        1
        for page in all_pages
        if abs(page.width / page.height - canvas_ratio) > 0.01
    )
    print(
        f"Page canvas: {canvas[0]}x{canvas[1]} "
        f"({letterboxed} page(s) letterboxed)",
        file=sys.stderr,
    )

    fd, temp_path = tempfile.mkstemp(
        prefix=".manga-merger-", suffix=".epub.tmp", dir=output_dir
    )
    os.close(fd)
    try:
        with zipfile.ZipFile(
            temp_path, "w", compression=zipfile.ZIP_STORED, allowZip64=True
        ) as archive:
            info = zipfile.ZipInfo("mimetype")
            info.compress_type = zipfile.ZIP_STORED
            archive.writestr(info, MIMETYPE)

            archive.writestr("META-INF/container.xml", container_xml())
            archive.writestr(
                "OEBPS/content.opf",
                content_opf(
                    all_pages, entries, title, author, language, direction,
                    book_id, modified,
                ),
            )
            archive.writestr("OEBPS/nav.xhtml", nav_xhtml(entries, title, language))
            archive.writestr("OEBPS/toc.ncx", ncx_xml(entries, title, book_id))
            archive.writestr("OEBPS/style.css", style_css())

            index = 0
            for chapter_index, (chapter, numbers) in enumerate(
                zip(chapters, page_numbers), start=1
            ):
                print(
                    f"  [{chapter_index:>3}/{len(chapters)}] "
                    f"pages {numbers[0]}-{numbers[-1]}  {chapter.title}",
                    file=sys.stderr,
                )
                for page in chapter.pages:
                    index += 1
                    archive.writestr(
                        f"OEBPS/pages/p{index:05d}.xhtml",
                        page_xhtml(index, f"p{index:05d}{page.ext}",
                                   page, canvas, language),
                    )
                    archive.write(
                        page.path,
                        arcname=f"OEBPS/images/p{index:05d}{page.ext}",
                        compress_type=zipfile.ZIP_STORED,
                    )

        validate(temp_path, all_pages, entries, canvas)
        if os.path.exists(output):
            raise ExistingOutputError(f"output already exists (will not overwrite): {output}")
        current_umask = os.umask(0)
        os.umask(current_umask)
        os.chmod(temp_path, 0o666 & ~current_umask)
        os.replace(temp_path, output)
    except BaseException:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
        raise

    return {
        "output": output,
        "chapters": len(chapters),
        "pages": len(all_pages),
        "size": os.path.getsize(output),
        "direction": direction,
        "title": title,
        "canvas": canvas,
    }


def validate(
    output: str,
    pages: list[Page],
    entries: list[tuple[str, str]],
    canvas: tuple[int, int],
) -> None:
    try:
        with zipfile.ZipFile(output) as archive:
            infos = archive.infolist()
            if not infos or infos[0].filename != "mimetype":
                raise BuildError("validation: mimetype is not the first archive entry")
            if infos[0].compress_type != zipfile.ZIP_STORED:
                raise BuildError("validation: mimetype entry is compressed")
            if archive.read("mimetype") != MIMETYPE.encode("ascii"):
                raise BuildError("validation: mimetype content is wrong")

            opf_path = "OEBPS/content.opf"
            opf = ElementTree.fromstring(archive.read(opf_path))
            ns = {"opf": "http://www.idpf.org/2007/opf"}
            items = {
                item.get("id"): item.get("href")
                for item in opf.findall(".//opf:manifest/opf:item", ns)
            }
            if not items:
                raise BuildError("validation: manifest is empty")

            for item_id, href in items.items():
                if not href or f"OEBPS/{href}" not in archive.namelist():
                    raise BuildError(
                        f"validation: manifest item {item_id} points to missing {href}"
                    )

            spine = [
                ref.get("idref")
                for ref in opf.findall(".//opf:spine/opf:itemref", ns)
            ]
            if len(spine) != len(pages):
                raise BuildError(
                    f"validation: spine has {len(spine)} items, expected {len(pages)}"
                )
            for idref in spine:
                if idref not in items:
                    raise BuildError(
                        f"validation: spine references unknown manifest id {idref}"
                    )

            image_count = sum(
                1 for name in archive.namelist()
                if name.startswith("OEBPS/images/") and not name.endswith("/")
            )
            if image_count != len(pages):
                raise BuildError(
                    f"validation: {image_count} images in archive, expected {len(pages)}"
                )

            canvas_width, canvas_height = canvas
            expected_viewport = f"width={canvas_width}, height={canvas_height}"
            expected_style = (
                f"width:{canvas_width}px;height:{canvas_height}px;"
            )
            viewports = set()
            page_docs = [
                name for name in archive.namelist()
                if name.startswith("OEBPS/pages/") and name.endswith(".xhtml")
            ]
            for name in page_docs:
                text = archive.read(name).decode("utf-8")
                viewport = re.search(
                    r'<meta name="viewport" content="([^"]+)"', text
                )
                if not viewport:
                    raise BuildError(f"validation: {name} has no viewport")
                viewports.add(viewport.group(1))
                if expected_style not in text:
                    raise BuildError(
                        f"validation: {name} body does not match canvas "
                        f"{canvas_width}x{canvas_height}"
                    )
                image = re.search(r"<image\b([^>]*)/>", text)
                if not image:
                    raise BuildError(f"validation: {name} has no SVG image")
                attrs = dict(
                    re.findall(r'(\w+)="([^"]*)"', image.group(1))
                )
                try:
                    left = int(attrs["x"])
                    top = int(attrs["y"])
                    width = int(attrs["width"])
                    height = int(attrs["height"])
                except (KeyError, ValueError) as exc:
                    raise BuildError(
                        f"validation: {name} has an invalid image rectangle"
                    ) from exc
                if (
                    left < 0
                    or top < 0
                    or left + width > canvas_width
                    or top + height > canvas_height
                ):
                    raise BuildError(
                        f"validation: {name} image overflows the page canvas"
                    )
            if viewports != {expected_viewport}:
                raise BuildError(
                    "validation: pages do not share one viewport "
                    f"(found {len(viewports)}; expected {expected_viewport!r})"
                )

            for label, href in entries:
                if f"OEBPS/{href}" not in archive.namelist():
                    raise BuildError(
                        f"validation: TOC entry {label!r} points to missing {href}"
                    )
    except zipfile.BadZipFile as exc:
        raise BuildError(f"validation: built file is not a valid ZIP: {exc}") from exc
    except ElementTree.ParseError as exc:
        raise BuildError(f"validation: content.opf is not valid XML: {exc}") from exc


def human_size(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024.0 or unit == "GB":
            return f"{value:.1f} {unit}"
        value /= 1024.0
    return f"{value:.1f} GB"


def default_output(root: str) -> str:
    name = os.path.basename(os.path.normpath(root)) or "manga"
    name = name.replace("/", "-").replace(":", "-").strip() or "manga"
    return os.path.join(os.getcwd(), f"{name}.epub")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge manga chapter folders of images into one fixed-layout EPUB."
    )
    parser.add_argument("manga_dir", help="Manga root: chapter folders or flat images")
    parser.add_argument("--output", help="Output EPUB path (default: ./<manga-name>.epub)")
    parser.add_argument("--title", help="Book title (default: manga folder name)")
    parser.add_argument("--author", help="Author name (optional)")
    parser.add_argument("--language", default="en", help="Language code (default: en)")
    parser.add_argument(
        "--direction", choices=("ltr", "rtl"), default="ltr",
        help="Reading progression (default: ltr)",
    )
    parser.add_argument("--no-toc", action="store_true", help="Suppress chapter TOC entries")
    parser.add_argument(
        "--page-size",
        help="Uniform page canvas as WxH (default: auto from median page aspect)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        root, chapters = discover(args.manga_dir)
        title = args.title or os.path.basename(os.path.normpath(root)) or "Manga"
        output = args.output or default_output(root)
        print(
            f"Discovered {len(chapters)} chapter(s), "
            f"{sum(len(c.pages) for c in chapters)} page(s) in {root}",
            file=sys.stderr,
        )
        result = build(
            root=root,
            chapters=chapters,
            output=output,
            title=title,
            author=args.author,
            language=args.language,
            direction=args.direction,
            use_toc=not args.no_toc,
            page_size=args.page_size,
        )
    except ExistingOutputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except BuildError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"Built {result['output']}")
    print(f"  chapters: {result['chapters']}")
    print(f"  pages:    {result['pages']}")
    print(f"  size:     {human_size(int(result['size']))}")
    print(f"  direction: {result['direction']}")
    print(f"  canvas:   {result['canvas'][0]}x{result['canvas'][1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
