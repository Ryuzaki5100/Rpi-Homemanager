#!/usr/bin/env python3
"""retrocrt - turn a video into a curved-bezel CRT / VHS style clip.

The heavy lifting is done by ffmpeg; this script only probes the input,
renders (and caches) the bezel/scanline assets with Pillow, then assembles
the filtergraph and runs the encode.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from fractions import Fraction
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
except ImportError:  # pragma: no cover - handled at runtime for --help/--dump-filter
    Image = None
    ImageChops = ImageDraw = ImageFilter = ImageFont = None

FFMPEG = os.environ.get("RETROCRT_FFMPEG", "ffmpeg")
FFPROBE = os.environ.get("RETROCRT_FFPROBE", "ffprobe")
FONT = os.environ.get("RETROCRT_FONT", "")
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "retrocrt"
DEFAULT_STAMP = datetime(1994, 6, 1, 23, 58, 0, tzinfo=timezone.utc)
ASSET_VERSION = 1

# Effect parameters per preset. Values are scaled by --intensity at runtime.
PRESETS = {
    "subtle": dict(
        pixel=0.80, pixel_smooth=True, scan=0.10, grain=3, bloom=0.10,
        chroma=1, wobble=1.0, glitch=0.004, k1=0.03, vignette=0.16,
        timestamp=False, rec=False, band=False,
    ),
    "classic": dict(
        pixel=0.55, pixel_smooth=False, scan=0.20, grain=6, bloom=0.22,
        chroma=2, wobble=2.0, glitch=0.012, k1=0.07, vignette=0.28,
        timestamp=True, rec=False, band=False,
    ),
    "vhs": dict(
        pixel=0.40, pixel_smooth=False, scan=0.30, grain=12, bloom=0.35,
        chroma=4, wobble=4.0, glitch=0.030, k1=0.12, vignette=0.40,
        timestamp=True, rec=True, band=True,
    ),
}


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #

def die(msg: str, code: int = 1) -> "NoReturn":
    print(f"retrocrt: {msg}", file=sys.stderr)
    raise SystemExit(code)


def even(n: float) -> int:
    n = int(round(n))
    return n if n % 2 == 0 else n + 1


def hex_rgb(value: str):
    s = value.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        die(f"bad color {value!r} (expected #rrggbb)")
    try:
        return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        die(f"bad color {value!r} (expected #rrggbb)")


def scale_color(rgb, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def probe(path: Path) -> dict:
    raw = subprocess.check_output([
        FFPROBE, "-v", "error", "-print_format", "json",
        "-show_streams", "-show_format", str(path),
    ])
    data = json.loads(raw)
    streams = data.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video"), None)
    if not video:
        die(f"no video stream in {path}")
    w, h = int(video["width"]), int(video["height"])
    rotation = 0
    for side in video.get("side_data_list", []):
        if "rotation" in side:
            rotation = int(float(side["rotation"])) % 360
    if rotation in (90, 270):
        w, h = h, w
    rate = video.get("avg_frame_rate") or video.get("r_frame_rate") or "25/1"
    if rate in ("0/0", "0/1"):
        rate = "25/1"
    fps = Fraction(rate)
    duration = float(data.get("format", {}).get("duration") or 0)
    audio = next((s for s in streams if s.get("codec_type") == "audio"), None)
    has_audio = audio is not None
    audio_codec = audio.get("codec_name", "") if audio else ""
    return dict(w=w, h=h, fps=fps, duration=duration, audio=has_audio,
                audio_codec=audio_codec)


def resolve_font(explicit: str | None) -> str | None:
    candidates = [
        explicit, FONT,
        "/System/Library/Fonts/Supplemental/Andale Mono.ttf",
        "/System/Library/Fonts/Menlo.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for path in candidates:
        if path and Path(path).is_file():
            return path
    return None


def font_width(font_path: str, size: int, text: str) -> float:
    if ImageFont is None or not font_path:
        return 0.602 * size * len(text)
    try:
        return ImageFont.truetype(font_path, size).getlength(text)
    except Exception:
        return 0.602 * size * len(text)


# --------------------------------------------------------------------------- #
# cached assets
# --------------------------------------------------------------------------- #

def cached(name: str, build):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / name
    if not path.is_file():
        build(path)
    return path


def superellipse(cx, cy, rx, ry, exponent, steps=480):
    pts = []
    for i in range(steps):
        a = 2.0 * math.pi * i / steps
        ca, sa = math.cos(a), math.sin(a)
        x = math.copysign(abs(ca) ** (2.0 / exponent), ca) * rx
        y = math.copysign(abs(sa) ** (2.0 / exponent), sa) * ry
        pts.append((cx + x, cy + y))
    return pts


def rounded_rect_points(cx, cy, rx, ry, radius, steps=24):
    r = max(0.0, min(radius, rx, ry))
    pts = []
    corners = [
        (-rx + r, -ry + r, 180, 270),
        (rx - r, -ry + r, 270, 360),
        (rx - r, ry - r, 0, 90),
        (-rx + r, ry - r, 90, 180),
    ]
    for ccx, ccy, a0, a1 in corners:
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + ccx + r * math.cos(a), cy + ccy + r * math.sin(a)))
    return pts


def draw_gradient(img, top, bottom, style):
    w, h = img.size
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        if style == "wood":
            base = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            wobble = int(6 * math.sin(y * 0.35)) + int(3 * math.sin(y * 1.7))
            color = tuple(max(0, min(255, c + wobble)) for c in base)
        else:
            color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=color)


def build_bezel(path, canvas_w, canvas_h, win_w, win_h, style, color, exponent,
                highlight, radius_scale):
    if Image is None:
        die("Pillow is required to build the bezel asset")

    body = Image.new("RGB", (canvas_w, canvas_h))
    base = hex_rgb(color)
    if style == "wood":
        top, bottom = scale_color(base, 1.30), scale_color(base, 0.50)
    elif style == "metal":
        top, bottom = scale_color(base, 1.55), scale_color(base, 0.55)
    else:
        top, bottom = scale_color(base, 1.55), scale_color(base, 0.45)
    draw_gradient(body, top, bottom, style)

    if style in ("plastic", "metal"):
        noise = Image.effect_noise((canvas_w, canvas_h), 10).convert("L")
        body = ImageChops.add(body, Image.merge("RGB", (noise, noise, noise)), scale=4, offset=-32)
    if style == "metal":
        d = ImageDraw.Draw(body)
        for x in range(0, canvas_w, 3):
            shade = 18 if (x // 3) % 2 else -10
            d.line([(x, 0), (x, canvas_h)], fill=scale_color(base, 1 + shade / 100), width=1)
    if style == "wood":
        d = ImageDraw.Draw(body)
        for y in range(0, canvas_h, 5):
            shade = 20 if random.Random(y).random() > 0.5 else -12
            d.line([(0, y), (canvas_w, y)], fill=scale_color(base, 1 + shade / 200), width=1)

    cx, cy = canvas_w / 2, canvas_h / 2
    rx, ry = win_w / 2, win_h / 2
    if radius_scale > 0:
        hole = rounded_rect_points(cx, cy, rx, ry,
                                   radius_scale * min(win_w, win_h))
    else:
        hole = superellipse(cx, cy, rx, ry, exponent)

    mask = Image.new("L", (canvas_w, canvas_h), 255)
    ImageDraw.Draw(mask).polygon(hole, fill=0)
    body.putalpha(mask)

    # inner shadow: darken the body just outside the opening
    shadow = Image.new("L", (canvas_w, canvas_h), 0)
    sd = ImageDraw.Draw(shadow)
    width = max(2, int(min(win_w, win_h) * 0.018))
    sd.line(hole + [hole[0]], fill=255, width=width)
    shadow = shadow.filter(ImageFilter.GaussianBlur(width * 0.9))
    shadow = ImageChops.multiply(shadow, mask)
    rgb = body.convert("RGB")
    dark = Image.new("RGB", body.size, scale_color(base, 0.15))
    body = Image.composite(dark, rgb, shadow).convert("RGBA")
    body.putalpha(mask)

    if highlight:
        rim = Image.new("L", (canvas_w, canvas_h), 0)
        rd = ImageDraw.Draw(rim)
        rr = max(1, int(min(win_w, win_h) * 0.006))
        if radius_scale > 0:
            outer = rounded_rect_points(
                cx, cy, rx + rr * 2, ry + rr * 2,
                radius_scale * min(win_w, win_h) + rr * 2)
        else:
            outer = superellipse(cx, cy, rx + rr * 2, ry + rr * 2, exponent)
        rd.line(outer + [outer[0]], fill=255, width=rr)
        rim = rim.filter(ImageFilter.GaussianBlur(rr * 0.8))
        rim = ImageChops.multiply(rim, mask)
        light = Image.new("RGB", body.size, scale_color(base, 1.9))
        body = Image.composite(light, body.convert("RGB"), rim).convert("RGBA")
        body.putalpha(mask)

    body.save(path)


def build_scanlines(path, w, h, alpha):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    a = int(255 * max(0.0, min(1.0, alpha)))
    for y in range(2, h, 3):
        d.line([(0, y), (w, y)], fill=(0, 0, 0, a))
    img.save(path)


def build_band(path):
    w, h = 16, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):
        a = int(38 * (math.sin(math.pi * y / (h - 1)) ** 2))
        d.line([(0, y), (w, y)], fill=(255, 255, 255, a))
    img.save(path)


def bezel_asset(canvas_w, canvas_h, win_w, win_h, style, color, exponent,
                highlight, radius_scale):
    key = hashlib.sha1(
        f"v{ASSET_VERSION}:{canvas_w}x{canvas_h}:{win_w}x{win_h}:{style}:{color}:"
        f"{exponent}:{int(highlight)}:{radius_scale}".encode()
    ).hexdigest()[:16]
    return cached(f"bezel-{key}.png", lambda p: build_bezel(
        p, canvas_w, canvas_h, win_w, win_h, style, color, exponent,
        highlight, radius_scale))


def scanline_asset(w, h, alpha):
    key = hashlib.sha1(f"v{ASSET_VERSION}:{w}x{h}:{alpha:.3f}".encode()).hexdigest()[:16]
    return cached(f"scan-{key}.png", lambda p: build_scanlines(p, w, h, alpha))


def band_asset():
    return cached("band.png", build_band)


# --------------------------------------------------------------------------- #
# filtergraph
# --------------------------------------------------------------------------- #

def drawtext(font, size, text, x, y, color="white", border=2, extra=""):
    text = text.replace("'", "\\'")
    return (
        f"drawtext=fontfile='{font}':text='{text}':fontsize={size}:"
        f"fontcolor={color}:borderw={border}:bordercolor=black@0.85:"
        f"x={x}:y={y}:expansion=normal{extra}"
    )


def clock_layers(font, size, x, y, epoch, color):
    """Wall clock: HH : MM : SS AM, split so the colons don't confuse ffmpeg."""
    w2 = font_width(font, size, "00")
    wc = font_width(font, size, ":")
    w6 = font_width(font, size, "00")
    parts = [
        (f"%{{pts\\:gmtime\\:{epoch}\\:%I}}", x),
        ("\\:", x + w2),
        (f"%{{pts\\:gmtime\\:{epoch}\\:%M}}", x + w2 + wc),
        ("\\:", x + w2 + wc + w2),
        (f"%{{pts\\:gmtime\\:{epoch}\\:%S %p}}", x + w2 + wc + w2 + wc),
    ]
    return [drawtext(font, size, text, px, y, color=color) for text, px in parts]


def timecode_layers(font, size, right_x, y, color):
    """Elapsed video time as HH:MM:SS, right-aligned to right_x."""
    w2 = font_width(font, size, "00")
    wc = font_width(font, size, ":")
    x0 = right_x - (3 * w2 + 2 * wc)
    parts = [
        ("%{eif\\:trunc(t/3600)\\:d\\:2}", x0),
        ("\\:", x0 + w2),
        ("%{eif\\:mod(trunc(t/60),60)\\:d\\:2}", x0 + w2 + wc),
        ("\\:", x0 + w2 + wc + w2),
        ("%{eif\\:mod(trunc(t),60)\\:d\\:2}", x0 + w2 + wc + w2 + wc),
    ]
    return [drawtext(font, size, text, px, y, color=color) for text, px in parts]


def build_graph(*, p, preset, args, vid_w, vid_h, canvas_w, canvas_h,
                bezel, scan, band, font, seed, epoch, date_text,
                safe_x, safe_y, offset: float = 0.0):
    pix = preset["pixel"]
    scan_a = preset["scan"]
    grain = max(0, int(round(preset["grain"])))
    bloom = preset["bloom"]
    chroma = max(0, int(round(preset["chroma"])))
    wobble = preset["wobble"]
    glitch = preset["glitch"]
    k1 = preset["k1"]
    vig = preset["vignette"]

    fps = str(p["fps"])
    rng = random.Random(seed)
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)

    chain = []

    # base geometry + mild grade. `offset` keeps time-based effects (glitch,
    # wobble, rolling band, clock, timecode) globally continuous when the clip
    # is encoded as independent parallel segments.
    start_pts = "PTS-STARTPTS"
    if offset > 0:
        start_pts += f"+{offset:.6f}/TB"
    chain.append(
        f"[0:v]setpts={start_pts},fps={fps},"
        f"scale={vid_w}:{vid_h}:force_original_aspect_ratio=decrease:flags=bicubic,"
        f"pad={vid_w}:{vid_h}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1"
    )
    if pix < 0.999:
        small_w, small_h = even(vid_w * pix), even(vid_h * pix)
        up = "bilinear" if preset["pixel_smooth"] else "neighbor"
        chain[-1] += (
            f",scale={small_w}:{small_h}:flags=neighbor,"
            f"scale={vid_w}:{vid_h}:flags={up}"
        )
    chain[-1] += (
        ",eq=contrast=1.05:saturation=0.90:brightness=0.012:gamma=0.97"
    )
    if chroma:
        chain[-1] += f",chromashift=cbh={chroma}:crv={chroma}"
    chain[-1] += ",format=rgba[base]"

    # phosphor bloom
    if bloom > 0:
        chain.append(
            f"[base]split=2[bb][bg];[bg]gblur=sigma=7[bl];"
            f"[bb][bl]blend=all_mode=screen:all_opacity={bloom:.3f}[bloomed]"
        )
        last = "bloomed"
    else:
        last = "base"

    # scanlines
    if scan_a > 0:
        chain.append(f"[{last}][2:v]overlay=0:0:format=auto[scanned]")
        last = "scanned"

    # grain
    if grain:
        chain.append(f"[{last}]noise=alls={grain}:allf=t+u[grained]")
        last = "grained"

    # organic wobble via low-res displacement maps
    if wobble > 0:
        amp = max(0.6, wobble)
        chain.append(
            f"nullsrc=s=64x36:r={fps},format=gray,geq=lum='128+{amp:.2f}*sin(X/9+T*1.1)"
            f"+{amp * 0.5:.2f}*sin(Y/7-T*1.7)',scale={vid_w}:{vid_h}:flags=bilinear,"
            f"format=gray[xmap]"
        )
        chain.append(
            f"nullsrc=s=64x36:r={fps},format=gray,geq=lum='128+{amp:.2f}*sin(Y/8+T*1.4)"
            f"+{amp * 0.5:.2f}*sin(X/11-T*1.3)',scale={vid_w}:{vid_h}:flags=bilinear,"
            f"format=gray[ymap]"
        )
        chain.append(f"[{last}][xmap][ymap]displace=edge=mirror[wobbled]")
        last = "wobbled"

    # occasional glitch: brief RGB split + brightness flash
    if glitch > 0:
        g1 = max(3, int(round(6 * math.sqrt(max(1.0, wobble)))))
        chain.append(
            f"[{last}]rgbashift=rh={g1}:bh=-{g1}:rv={max(1, g1 // 3)}:"
            f"bv=-{max(1, g1 // 3)}:"
            f"enable='lt(abs(sin(t*0.91+{ph1:.3f})),{min(0.5, glitch):.4f})'[glitched]"
        )
        chain.append(
            f"[glitched]eq=brightness=0.10:saturation=1.06:"
            f"enable='lt(abs(sin(t*0.53+{ph2:.3f})),{min(0.5, glitch * 0.5):.4f})'[flashed]"
        )
        last = "flashed"
    else:
        chain.append(f"[{last}]null[flashed]")
        last = "flashed"

    # VHS rolling band
    if preset["band"]:
        chain.append(f"[3:v]scale={vid_w}:128,format=rgba[bandsrc]")
        chain.append(
            f"[{last}][bandsrc]overlay=x=0:y='mod(t*38,{vid_h + 256})-128'"
            f":format=auto[banded]"
        )
        last = "banded"

    # curved tube + vignette
    if k1 > 0:
        chain.append(
            f"[{last}]lenscorrection=cx=0.5:cy=0.5:k1={k1:.4f}:i=bilinear:fc=black[curved]"
        )
        last = "curved"
    if vig > 0:
        chain.append(f"[{last}]vignette=angle=PI/{4.0 + (1.0 - vig) * 4:.3f}[vigned]")
        last = "vigned"

    # timestamp overlay (classic / vhs)
    if preset["timestamp"] and font:
        pad_x = (canvas_w - vid_w) // 2
        pad_y = (canvas_h - vid_h) // 2
        margin_x = max(int(vid_w * 0.03), safe_x - pad_x)
        margin_y = max(int(vid_h * 0.04), safe_y - pad_y)
        size = max(12, int(round(vid_h * 0.045)))
        color = "white"
        layers = []
        date_y = margin_y
        date_layer = drawtext(font, size, date_text, margin_x, date_y, color=color)
        if preset["rec"]:
            rec_x = margin_x + int(font_width(font, size, date_text)) + int(size * 0.6)
            layers.append(drawtext(
                font, size, "\u25CF REC", rec_x, date_y, color="0xFF3B30",
                extra=":enable='lt(mod(t,1.4),0.95)'",
            ))
        layers.insert(0, date_layer)
        layers += clock_layers(
            font, size, margin_x, date_y + int(size * 1.35), epoch, color
        )
        # video timecode, bottom-right (HH:MM:SS)
        layers += timecode_layers(
            font, size, vid_w - margin_x, vid_h - margin_y - size, color
        )
        chain.append(f"[{last}]" + ",".join(layers) + "[stamped]")
        last = "stamped"
        if preset["rec"]:
            chain.append(f"[{last}]rgbashift=rh=1:bh=-1:rv=0:bv=0[stamped2]")
            last = "stamped2"

    # pad to canvas and lay the bezel over the overflow
    pad_x = (canvas_w - vid_w) // 2
    pad_y = (canvas_h - vid_h) // 2
    chain.append(
        f"[{last}]pad={canvas_w}:{canvas_h}:{pad_x}:{pad_y}:color=black[padded]"
    )
    # reset PTS to 0 for this segment so the concat demuxer joins cleanly
    reset = f",setpts=PTS-{offset:.6f}/TB" if offset > 0 else ""
    if getattr(args, "no_bezel", False):
        chain.append(f"[padded]null{reset},format=yuv420p[outv]")
    else:
        chain.append(
            f"[padded][1:v]overlay=0:0:format=auto{reset},format=yuv420p[outv]"
        )

    return ";".join(chain)


# --------------------------------------------------------------------------- #
# encode
# --------------------------------------------------------------------------- #

def double_rate(rate: str) -> str:
    """'1500k' -> '3000k', '2M' -> '4M' (bufsize is twice the maxrate)."""
    rate = rate.strip()
    if rate and rate[-1] in "kKmM":
        try:
            return f"{float(rate[:-1]) * 2:g}{rate[-1]}"
        except ValueError:
            return rate
    try:
        return f"{float(rate) * 2:g}"
    except ValueError:
        return rate


def encode(src: Path, dst: Path, graph: str, bezel: Path, scan: Path, band: Path,
           audio: bool, audio_age: bool, fast: bool, overwrite: bool,
           progress: bool = False, copy_audio: bool = False, crf: int = 22,
           maxrate: str | None = None,
           start: float | None = None, length: float | None = None,
           frames: int | None = None,
           threads: int | None = None, filter_threads: int | None = None,
           faststart: bool = True):
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error"]
    cmd += ["-y" if overwrite else "-n"]
    if start:
        cmd += ["-ss", f"{start:.6f}"]
    if length is not None:
        cmd += ["-t", f"{length:.6f}"]
    cmd += ["-i", str(src)]
    cmd += ["-i", str(bezel), "-i", str(scan), "-i", str(band)]
    cmd += ["-filter_complex", graph, "-map", "[outv]"]
    if audio:
        cmd += ["-map", "0:a?"]
    if fast and sys.platform == "darwin":
        cmd += ["-c:v", "h264_videotoolbox", "-b:v", "12M", "-allow_sw", "1"]
    else:
        cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", str(crf)]
        if maxrate:
            cmd += ["-maxrate", maxrate, "-bufsize", double_rate(maxrate)]
    if audio:
        if audio_age:
            cmd += [
                "-af", "highpass=f=90,lowpass=f=7500,"
                       "aecho=0.8:0.65:14:0.12",
                "-c:a", "aac", "-b:a", "192k",
            ]
        elif copy_audio:
            cmd += ["-c:a", "copy"]
        else:
            # Opus/Vorbis in MP4 play in ffmpeg but not in QuickTime/Apple
            # Books, so default to AAC for universal playback.
            cmd += ["-c:a", "aac", "-b:a", "192k"]
    else:
        cmd += ["-an"]
    if frames is not None:
        cmd += ["-frames:v", str(frames)]
    if threads:
        cmd += ["-threads", str(threads)]
    if filter_threads is not None:
        cmd += ["-filter_complex_threads", str(filter_threads)]
    elif threads:
        cmd += ["-filter_complex_threads", str(threads)]
    if progress:
        cmd += ["-progress", "pipe:1", "-nostats"]
    cmd += ["-pix_fmt", "yuv420p"]
    if faststart:
        cmd += ["-movflags", "+faststart"]
    cmd += [str(dst)]
    return cmd


def fmt_clock(seconds: float) -> str:
    seconds = max(0, int(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h:d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def run_encode(cmd, duration: float, label: str, show_bar: bool) -> int:
    if not show_bar:
        return subprocess.run(cmd).returncode

    width = 30
    started = time.time()
    current = 0.0
    speed = ""
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, text=True, bufsize=1,
    )
    try:
        for raw in proc.stdout:
            line = raw.strip()
            if line.startswith("out_time_us="):
                try:
                    current = int(line.split("=", 1)[1]) / 1_000_000
                except ValueError:
                    continue
            elif line.startswith("out_time_ms=") and current == 0:
                try:
                    current = int(line.split("=", 1)[1]) / 1_000_000
                except ValueError:
                    continue
            elif line.startswith("speed="):
                speed = line.split("=", 1)[1]
                continue
            else:
                continue

            if duration > 0:
                pct = min(1.0, current / duration)
                filled = int(round(width * pct))
                bar = "#" * filled + "-" * (width - filled)
                total = fmt_clock(duration)
                line_out = (
                    f"\r  {label}[{bar}] {pct * 100:5.1f}%  "
                    f"{fmt_clock(current)}/{total}  {speed:>7}"
                )
            else:
                line_out = f"\r  {label}{fmt_clock(current)}  {speed:>7}"
            sys.stderr.write(line_out)
            sys.stderr.flush()
        proc.wait()
    except KeyboardInterrupt:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        sys.stderr.write("\n")
        raise

    sys.stderr.write("\r" + " " * (width + 48) + "\r")
    if proc.returncode == 0 and duration > 0:
        elapsed = time.time() - started
        sys.stderr.write(
            f"  {label}done in {elapsed:.1f}s "
            f"({fmt_clock(duration)} of video)\n"
        )
    sys.stderr.flush()
    return proc.returncode


def resolve_jobs(value: str) -> int:
    cpus = os.cpu_count() or 4
    if str(value).strip().lower() == "auto":
        # Measured sweet spot on Apple Silicon: ~1/3 of the logical cores,
        # never fewer than 2 and rarely more than 6.
        return min(6, max(2, round(cpus / 3)))
    try:
        jobs = int(value)
    except ValueError:
        die(f"--jobs must be an integer or 'auto', got {value!r}")
    if jobs < 1:
        die("--jobs must be >= 1")
    return jobs


def plan_segments(duration: float, fps: Fraction, jobs: int):
    """Frame-aligned (start, length, frame_count) triples covering `duration`."""
    frames = max(1, int(round(duration * float(fps))))
    n = max(1, min(jobs, frames))
    marks = [round(frames * i / n) for i in range(n + 1)]
    rate = float(fps)
    return [
        (marks[i] / rate, (marks[i + 1] - marks[i]) / rate,
         marks[i + 1] - marks[i])
        for i in range(n)
    ]


def concat_line(path: Path) -> str:
    escaped = str(path).replace("'", "'\\''")
    return f"file '{escaped}'\n"


def encode_audio(src: Path, dst: Path, audio_age: bool, copy_audio: bool,
                 codec: str, length: float | None = None):
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y"]
    if length is not None:
        cmd += ["-t", f"{length:.6f}"]
    cmd += ["-i", str(src)]
    cmd += ["-vn", "-map", "0:a:0"]
    if audio_age:
        cmd += ["-af", "highpass=f=90,lowpass=f=7500,aecho=0.8:0.65:14:0.12",
                "-c:a", "aac", "-b:a", "192k"]
    elif copy_audio and codec in {"aac", "mp3", "alac"}:
        cmd += ["-c:a", "copy"]
    else:
        cmd += ["-c:a", "aac", "-b:a", "192k"]
    cmd += ["-movflags", "+faststart", str(dst)]
    return cmd


def run_parallel(cmds, totals, label: str, show_bar: bool) -> int:
    """Run ffmpeg commands concurrently, one progress bar per job."""
    n = len(cmds)
    overall = sum(totals)
    single = n == 1
    width = 30 if single else 22
    times = [0.0] * n
    procs = []
    readers = []
    lock = threading.Lock()
    rendered = False

    def read(idx, proc):
        for raw in proc.stdout:
            line = raw.strip()
            if not line.startswith("out_time_us="):
                continue
            try:
                value = int(line.split("=", 1)[1]) / 1_000_000
            except ValueError:
                continue
            with lock:
                times[idx] = value

    def row(i, elapsed):
        total_i = totals[i]
        cur = times[i]
        pct = min(1.0, cur / total_i) if total_i > 0 else 0.0
        filled = int(round(width * pct))
        bar = "#" * filled + "-" * (width - filled)
        speed = cur / elapsed
        return (
            f"[{bar}] {pct * 100:5.1f}%  "
            f"{fmt_clock(cur)}/{fmt_clock(total_i)}  {speed:5.2f}x"
        )

    def render():
        nonlocal rendered
        if not show_bar:
            return
        elapsed = max(0.001, time.time() - started)
        with lock:
            if single:
                sys.stderr.write(f"\r  {label}{row(0, elapsed)}")
            else:
                lines = [
                    f"  seg {i + 1}/{n} {row(i, elapsed)}" for i in range(n)
                ]
                prefix = f"\x1b[{n}A" if rendered else ""
                sys.stderr.write(
                    prefix + "".join("\x1b[2K" + line + "\n" for line in lines)
                )
                rendered = True
        sys.stderr.flush()

    for idx, cmd in enumerate(cmds):
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)
        procs.append(proc)
        thread = threading.Thread(target=read, args=(idx, proc), daemon=True)
        thread.start()
        readers.append(thread)

    started = time.time()
    failed = None
    try:
        while True:
            if all(p.poll() is not None for p in procs):
                break
            for proc in procs:
                if proc.returncode not in (None, 0):
                    failed = proc.returncode
                    break
            if failed is not None:
                for proc in procs:
                    if proc.poll() is None:
                        proc.terminate()
                break
            render()
            time.sleep(0.25)
    except KeyboardInterrupt:
        for proc in procs:
            if proc.poll() is None:
                proc.terminate()
        for proc in procs:
            proc.wait()
        sys.stderr.write("\n")
        raise

    for proc in procs:
        proc.wait()
    for thread in readers:
        thread.join(timeout=1)
    # Finished segments count as complete even if the last -progress sample
    # landed a fraction of a frame short.
    for i, proc in enumerate(procs):
        if proc.returncode == 0 and totals[i] > 0:
            times[i] = totals[i]

    if show_bar:
        render()
        elapsed = time.time() - started
        if single:
            sys.stderr.write("\r" + " " * (width + 48) + "\r")
        if failed is None and overall > 0:
            if single:
                sys.stderr.write(
                    f"  {label}done in {elapsed:.1f}s "
                    f"({fmt_clock(overall)} of video)\n"
                )
            else:
                sys.stderr.write(
                    f"  total {fmt_clock(overall)} in {elapsed:.1f}s "
                    f"({n} jobs)\n"
                )
        sys.stderr.flush()
    return failed if failed is not None else max((p.returncode or 0) for p in procs)


def encode_single(item, args, show_bar: bool, label: str = "",
                  threads: int | None = None):
    src, dst, p = item["src"], item["dst"], item["probe"]
    if dst.exists() and not args.overwrite:
        die(f"output exists: {dst} (use --overwrite to replace it)")
    tmp = dst.with_name(f"{dst.stem}.part{dst.suffix}")
    try:
        tmp.unlink()
    except FileNotFoundError:
        pass
    cmd = encode(src, tmp, item["graph"], item["bezel"], item["scan"],
                 item["band"], p["audio"], args.audio_age, args.fast, True,
                 progress=show_bar, copy_audio=args.copy_audio, crf=args.crf,
                 maxrate=args.maxrate,
                 length=item["duration"] if args.preview else None,
                 threads=threads)
    try:
        code = run_encode(cmd, item["duration"], label, show_bar)
    except KeyboardInterrupt:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise SystemExit(130)
    if code != 0:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        die(f"ffmpeg failed for {src} (exit {code}); no output written")
    os.replace(tmp, dst)


def encode_segmented(item, args, jobs: int, show_bar: bool):
    src, dst, p = item["src"], item["dst"], item["probe"]
    duration = item["duration"]
    segments = plan_segments(duration, p["fps"], jobs)
    if len(segments) <= 1:
        encode_single(item, args, show_bar)
        return

    tmpdir = Path(tempfile.mkdtemp(prefix=".retrocrt-", dir=str(dst.parent)))
    try:
        env_threads = os.environ.get("RETROCRT_SEG_THREADS")
        env_filter = os.environ.get("RETROCRT_SEG_FILTER_THREADS")
        cpus = os.cpu_count() or 4
        fair = max(1, round(cpus / len(segments)))
        threads = fair
        filter_threads = fair
        if env_threads is not None:
            threads = int(env_threads) or None
        if env_filter is not None:
            filter_threads = int(env_filter) or None
        pieces = []
        cmds = []
        for idx, (start, _length, nframes) in enumerate(segments):
            # Let the final segment run a few frames past the boundary so
            # CFR rounding at the very end does not clip the tail.
            if idx == len(segments) - 1 and args.preview is None:
                nframes += 4
            # Seek 1 microsecond before the boundary so the frame exactly at
            # `start` is included rather than skipped by rounding.
            seek = 0.0 if start <= 0 else max(0, math.floor(start * 1e6) - 1) / 1e6
            graph = build_graph(offset=start, **item["graph_args"])
            piece = tmpdir / f"seg-{idx:03d}.mp4"
            pieces.append(piece)
            cmds.append(encode(
                src, piece, graph, item["bezel"], item["scan"], item["band"],
                audio=False, audio_age=False, fast=args.fast, overwrite=True,
                progress=True, start=seek, frames=nframes, threads=threads,
                filter_threads=filter_threads, crf=args.crf,
                maxrate=args.maxrate, faststart=False,
            ))

        thread_text = f"{threads} threads each" if threads else "auto threads"
        print(f"retrocrt:   splitting into {len(segments)} segments "
              f"({thread_text})", file=sys.stderr)
        code = run_parallel(cmds, [seg[1] for seg in segments], "", show_bar)
        if code != 0:
            die(f"ffmpeg failed for {src} (exit {code}); no output written")

        listing = tmpdir / "segments.txt"
        listing.write_text("".join(concat_line(piece) for piece in pieces))
        draft = tmpdir / "joined.mp4"
        cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
               "-f", "concat", "-safe", "0", "-i", str(listing)]
        if p["audio"]:
            if args.copy_audio and not args.audio_age:
                cmd += ["-i", str(src)]
            else:
                audio_file = tmpdir / "audio.m4a"
                audio_cmd = encode_audio(
                    src, audio_file, args.audio_age, args.copy_audio,
                    p["audio_codec"], length=duration,
                )
                audio_proc = subprocess.run(audio_cmd)
                if audio_proc.returncode != 0:
                    die(f"audio encode failed for {src}")
                cmd += ["-i", str(audio_file)]
            cmd += ["-map", "0:v:0", "-map", "1:a:0?"]
        else:
            cmd += ["-map", "0:v:0"]
        if args.preview:
            cmd += ["-t", f"{duration:.6f}"]
        cmd += ["-c", "copy", "-movflags", "+faststart", str(draft)]
        joined = subprocess.run(cmd)
        if joined.returncode != 0:
            die(f"concat failed for {src} (exit {joined.returncode})")
        os.replace(draft, dst)
    finally:
        if os.environ.get("RETROCRT_KEEP_TMP"):
            print(f"retrocrt: kept temp dir {tmpdir}", file=sys.stderr)
        else:
            shutil.rmtree(tmpdir, ignore_errors=True)


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="retrocrt",
        description="Convert video into a curved-bezel CRT/VHS style clip.",
    )
    ap.add_argument("inputs", nargs="+", type=Path, help="input video(s)")
    ap.add_argument("-o", "--output", type=Path, help="output file (single input only)")
    ap.add_argument("--preset", choices=sorted(PRESETS), default="classic")
    ap.add_argument("--intensity", type=float, default=1.0,
                    help="multiplier for effect strength (0..2, default 1)")
    ap.add_argument("--seed", type=int, default=None,
                    help="seed for wobble/glitch phases (default: random)")
    ap.add_argument("--height", type=int, default=None,
                    help="output canvas height in pixels (default: source height + bezel)")
    ap.add_argument("--bezel-style", choices=["plastic", "wood", "metal"], default="plastic")
    ap.add_argument("--bezel-thickness", type=float, default=0.045,
                    help="bezel thickness as a fraction of canvas height")
    ap.add_argument("--bezel-radius", type=float, default=0.05,
                    help="corner radius as a fraction of the window (default 0.05; 0 = superellipse)")
    ap.add_argument("--bezel-curve", type=float, default=6.0,
                    help="superellipse exponent (2 = ellipse, 4+ = squarer)")
    ap.add_argument("--bezel-color", default=None,
                    help="bezel colour (#rrggbb); defaults per style")
    ap.add_argument("--no-highlight", action="store_true")
    ap.add_argument("--no-scanlines", action="store_true")
    ap.add_argument("--no-bezel", action="store_true", help="skip the bezel overlay")
    ap.add_argument("--no-timestamp", action="store_true")
    ap.add_argument("--stamp-date", default=None, help="date line, e.g. 'JUN 01 1994'")
    ap.add_argument("--stamp-start", default=None,
                    help="clock start, e.g. '1994-06-01 23:58:00'")
    ap.add_argument("--font", default=None, help="TTF path for the timestamp")
    ap.add_argument("--audio-age", action="store_true", help="degrade the audio")
    ap.add_argument("--copy-audio", action="store_true",
                    help="copy the source audio (default: transcode to AAC)")
    ap.add_argument("--crf", type=int, default=22,
                    help="libx264 quality (default 22; lower = bigger/better)")
    ap.add_argument("--maxrate", default=None, metavar="RATE",
                    help="cap video bitrate to keep the file small, e.g. 1500k or 2M")
    ap.add_argument("--fast", action="store_true",
                    help="use VideoToolbox on macOS (faster, lower quality)")
    ap.add_argument("--overwrite", "-y", action="store_true")
    ap.add_argument("--no-progress", action="store_true",
                    help="disable the encode progress bar")
    ap.add_argument("--jobs", default="auto", metavar="N|auto",
                    help="parallel segments/processes (default: auto; 1 disables)")
    ap.add_argument("--preview", type=float, default=None, metavar="SECONDS",
                    help="encode only the first N seconds")
    ap.add_argument("--dump-filter", action="store_true",
                    help="print the filtergraph and exit")
    args = ap.parse_args(argv)

    def _interrupt(_signum, _frame):
        raise KeyboardInterrupt

    for _sig in (signal.SIGTERM, signal.SIGHUP):
        try:
            signal.signal(_sig, _interrupt)
        except (ValueError, OSError):
            pass

    if args.intensity < 0:
        die("--intensity must be >= 0")
    if not 0.0 < args.bezel_thickness < 0.45:
        die("--bezel-thickness must be between 0 and 0.45")
    if len(args.inputs) > 1 and args.output and not args.output.is_dir():
        die("-o with multiple inputs must be an existing directory")

    base = PRESETS[args.preset]
    i = args.intensity
    preset = dict(base)
    preset["pixel"] = max(0.2, 1.0 - (1.0 - base["pixel"]) * i)
    for key in ("scan", "bloom", "chroma", "wobble", "glitch", "k1", "vignette"):
        preset[key] = base[key] * i
    preset["grain"] = base["grain"] * i
    if args.no_scanlines:
        preset["scan"] = 0
    preset["timestamp"] = base["timestamp"] and not args.no_timestamp

    font = resolve_font(args.font)
    if preset["timestamp"] and not font:
        print("retrocrt: no usable font found; timestamp disabled", file=sys.stderr)
        preset["timestamp"] = False

    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    if args.bezel_color:
        bezel_color = args.bezel_color
    else:
        bezel_color = {
            "plastic": "#1b1b20",
            "wood": "#4a2f18",
            "metal": "#3a3d42",
        }[args.bezel_style]
    if args.stamp_start:
        try:
            stamp = datetime.strptime(args.stamp_start, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            die("--stamp-start must look like '1994-06-01 23:58:00'")
    else:
        stamp = DEFAULT_STAMP.replace(tzinfo=None)
    epoch = int(stamp.replace(tzinfo=timezone.utc).timestamp())
    date_text = (args.stamp_date or stamp.strftime("%b %d %Y")).upper()

    jobs = resolve_jobs(args.jobs)
    preview = args.preview
    if preview is not None and preview <= 0:
        die("--preview must be > 0")

    items = []
    for src in args.inputs:
        if not src.is_file():
            die(f"no such file: {src}")
        p = probe(src)
        if p["duration"] <= 0:
            die(f"could not read duration of {src}")

        t = args.bezel_thickness
        if args.no_bezel:
            if args.height:
                canvas_h = even(args.height)
                canvas_w = even(p["w"] * canvas_h / p["h"])
            else:
                canvas_w, canvas_h = even(p["w"]), even(p["h"])
            win_w, win_h = canvas_w, canvas_h
            vid_w, vid_h = canvas_w, canvas_h
        else:
            if args.height:
                canvas_h = even(args.height)
                bezel_px = even(t * canvas_h)
                win_h = even(canvas_h - 2 * bezel_px)
                win_w = even(p["w"] * win_h / p["h"])
                canvas_w = even(win_w + 2 * bezel_px)
            else:
                canvas_h = even(p["h"] * (1 + 2 * t))
                bezel_px = even(t * canvas_h)
                win_h = even(canvas_h - 2 * bezel_px)
                win_w = even(p["w"] * win_h / p["h"])
                canvas_w = even(win_w + 2 * bezel_px)
            overscan = 0.015
            vid_w = min(even(win_w * (1 + overscan)), canvas_w)
            vid_h = min(even(win_h * (1 + overscan)), canvas_h)

        scan = scanline_asset(vid_w, vid_h, preset["scan"])
        band = band_asset()

        if args.no_bezel:
            bezel = band  # unused but keeps input count stable
            safe_x = int(canvas_w * 0.04)
            safe_y = int(canvas_h * 0.05)
        else:
            rx = args.bezel_radius or 0.0
            bezel = bezel_asset(
                canvas_w, canvas_h, win_w, win_h, args.bezel_style,
                bezel_color, args.bezel_curve, not args.no_highlight, rx,
            )
            safe_x = bezel_px + int(win_w * 0.055)
            safe_y = bezel_px + int(win_h * 0.065)

        graph_args = dict(
            p=p, preset=preset, args=args, vid_w=vid_w, vid_h=vid_h,
            canvas_w=canvas_w, canvas_h=canvas_h, bezel=bezel, scan=scan,
            band=band, font=font, seed=seed, epoch=epoch, date_text=date_text,
            safe_x=safe_x, safe_y=safe_y,
        )
        graph = build_graph(**graph_args)

        tag = "-preview" if preview else "-retro"
        if args.output and len(args.inputs) == 1:
            dst = args.output
        elif args.output:
            dst = args.output / f"{src.stem}{tag}.mp4"
        else:
            dst = src.with_name(f"{src.stem}{tag}.mp4")

        duration = p["duration"] if preview is None else min(p["duration"], preview)
        items.append(dict(
            src=src, dst=dst, probe=p, duration=duration, graph=graph,
            graph_args=graph_args, bezel=bezel, scan=scan, band=band,
        ))

    if args.dump_filter:
        for item in items:
            print(f"# {item['src']} -> {item['dst']}\n{item['graph']}\n")
        return

    show_bar = not args.no_progress and sys.stderr.isatty()
    total = len(items)

    if total == 1:
        item = items[0]
        print(f"retrocrt: {item['src'].name} -> {item['dst'].name}",
              file=sys.stderr)
        frames = item["duration"] * float(item["probe"]["fps"])
        if jobs > 1 and frames >= 2:
            encode_segmented(item, args, jobs, show_bar)
        else:
            encode_single(item, args, show_bar)
        return

    if jobs == 1:
        for index, item in enumerate(items, 1):
            label = f"[{index}/{total}] "
            print(f"retrocrt: {label}{item['src'].name} -> {item['dst'].name}",
                  file=sys.stderr)
            encode_single(item, args, show_bar, label)
        return

    from concurrent.futures import ThreadPoolExecutor

    workers = min(jobs, total)
    threads = max(1, (os.cpu_count() or 4) // workers)
    errors = []

    def work(index, item):
        print(f"retrocrt: [{index}/{total}] {item['src'].name} -> "
              f"{item['dst'].name}", file=sys.stderr)
        try:
            encode_single(item, args, False, "", threads)
            print(f"retrocrt: [{index}/{total}] done {item['dst'].name}",
                  file=sys.stderr)
        except SystemExit as exc:
            errors.append((item["src"], exc.code))
        except BaseException as exc:  # noqa: BLE001 - surface worker failures
            errors.append((item["src"], exc))

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(work, i, item) for i, item in enumerate(items, 1)]
        for future in futures:
            future.result()
    if errors:
        die(f"{len(errors)} file(s) failed")


if __name__ == "__main__":
    main()
