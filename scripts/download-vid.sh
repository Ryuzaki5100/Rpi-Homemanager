#!/usr/bin/env bash
set -euo pipefail

read -r -p "Enter video URL: " url

if [ -z "$url" ]; then
    echo "No URL provided."
    exit 1
fi

dest="$HOME/Videos"

mkdir -p "$dest"

yt-dlp -f "bestvideo[height<=2160][vcodec*=avc1]+bestaudio/bestvideo[height<=2160][vcodec*=vp9]+bestaudio/best[height<=2160]" \
    --merge-output-format mp4 \
    -o "$dest/%(title)s.%(ext)s" \
    "$url"
