#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [VIDEO.mp4] [SUBTITLES.srt]"
    echo "  Embeds subtitles into a video as a soft subtitle track."
    echo "  Outputs VIDEO [with subtitles].mp4 in the same directory."
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

video="$1"
subtitles="$2"

if [ ! -f "$video" ]; then
    echo "Error: video file not found: $video"
    exit 1
fi

if [ ! -f "$subtitles" ]; then
    echo "Error: subtitle file not found: $subtitles"
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found in PATH."
    exit 1
fi

dir="$(dirname "$video")"
base="$(basename "$video")"
name="${base%.*}"
ext="${base##*.}"

output="$dir/$name [with subtitles].$ext"

ffmpeg -y -i "$video" -i "$subtitles" \
    -map 0 -map 1 -c copy -c:s mov_text \
    -metadata:s:s:0 language=eng \
    "$output"

echo "Done: $output"