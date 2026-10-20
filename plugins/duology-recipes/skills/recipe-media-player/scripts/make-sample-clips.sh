#!/bin/bash
# Makes the six sample clips the recipe's template plays, on this Mac, with ffmpeg.
# Nothing is downloaded: each clip is a moving colour gradient, the show and episode
# title, a seconds counter and quiet brown noise, 12 seconds, 640 x 360, about 110 KB.
#
#   make-sample-clips.sh [dest-dir]
#
#   dest-dir   where the .mp4 files go. Default: the template's Media folder.
#
# The template already ships these clips. Run this only to change them, for example
# to make them longer (CLIP_SECONDS=60) or larger (CLIP_SIZE=1280x720). If you change
# the length, update "duration" in Catalog.json to match.
set -euo pipefail

command -v ffmpeg >/dev/null || { echo "error: ffmpeg not found (brew install ffmpeg)" >&2; exit 69; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$SCRIPT_DIR/../template/__APP_NAME__/Media}"
SECONDS_LONG="${CLIP_SECONDS:-12}"
SIZE="${CLIP_SIZE:-640x360}"
mkdir -p "$DEST"

# A font for the titles. Avenir Next ships with macOS; elsewhere fontconfig picks a sans.
FONT="/System/Library/Fonts/Avenir Next.ttc"
if [[ -f "$FONT" ]]; then FONTARG="fontfile='$FONT'"; else FONTARG="font=Sans"; fi

# id | show title | episode number | episode title | three gradient colours | seed
CLIPS=(
  "small-repairs-1|SMALL REPAIRS|1|A wobbly chair leg|0xF08A4B,0x8C3414,0x3B1208|7"
  "small-repairs-2|SMALL REPAIRS|2|The zip that won't close|0xE8743B,0x6E2A10,0x2E0F06|11"
  "small-repairs-3|SMALL REPAIRS|3|Truing a bicycle wheel|0xF2A05C,0x7A2E12,0x331306|19"
  "night-sky-notes-1|NIGHT SKY NOTES|1|Finding the Pole Star|0x5B6CFF,0x23296B,0x0B0D26|5"
  "night-sky-notes-2|NIGHT SKY NOTES|2|One face of the Moon|0x7484FF,0x1B1F4A,0x08091C|13"
  "night-sky-notes-3|NIGHT SKY NOTES|3|Watching a meteor shower|0x4C5BE8,0x2A2F7A,0x0A0B22|23"
)

for clip in "${CLIPS[@]}"; do
  IFS='|' read -r id show number title colours seed <<<"$clip"
  IFS=',' read -r c0 c1 c2 <<<"$colours"
  # drawtext ends the text at a straight quote, so titles use a curly one.
  safe_title="${title//\'/’}"
  fade_out=$((SECONDS_LONG - 1))
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "gradients=s=$SIZE:c0=$c0:c1=$c1:c2=$c2:n=3:type=radial:speed=0.015:d=$SECONDS_LONG:r=24:seed=$seed" \
    -f lavfi -i "anoisesrc=color=brown:amplitude=0.05:d=$SECONDS_LONG:r=44100:seed=$seed" \
    -filter_complex "[0:v]drawtext=$FONTARG:text='$show  ·  EPISODE $number':fontcolor=white@0.85:fontsize=h*0.047:x=w*0.056:y=h*0.094,drawtext=$FONTARG:text='$safe_title':fontcolor=white:fontsize=h*0.117:x=w*0.056:y=(h-text_h)/2-h*0.017,drawtext=$FONTARG:text='Sample clip, made with ffmpeg':fontcolor=white@0.7:fontsize=h*0.044:x=w*0.056:y=h*0.583,drawtext=$FONTARG:text='0\:%{eif\:t\:d\:2}':fontcolor=white@0.85:fontsize=h*0.05:x=w-tw-w*0.056:y=h-h*0.144[v];[1:a]lowpass=f=500,afade=t=in:d=1,afade=t=out:st=$fade_out:d=1[a]" \
    -map "[v]" -map "[a]" \
    -c:v libx264 -preset veryslow -crf 31 -pix_fmt yuv420p -profile:v main \
    -c:a aac -b:a 40k -ac 1 -movflags +faststart \
    "$DEST/$id.mp4"
  echo "made $DEST/$id.mp4"
done
