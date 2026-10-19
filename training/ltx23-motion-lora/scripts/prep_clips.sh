#!/usr/bin/env bash
# Cut raw footage into LTX-2.3 training clips: constant 24 fps, exactly N frames
# (N = 8k+1), short side scaled to 576 px, silent H.264 MP4.
#
# Usage:
#   prep_clips.sh RAW_DIR OUT_DIR [CUTS_CSV]
#
# With CUTS_CSV (recommended): one line per clip, "file,start_seconds", e.g.
#   fight_take3.mp4,12.40
#   dance_02.mov,3
# Each line yields one clip of N frames starting at start_seconds. Pick starts
# where the interaction begins, so the whole action fits inside the window.
#
# Without CUTS_CSV: every file is split back-to-back into N-frame windows and
# the leftover tail is dropped. Review the output and delete windows with no
# interaction in them.
#
# Env overrides: FRAMES=49 FPS=24 SHORT_SIDE=576 KEEP_AUDIO=0
set -euo pipefail

RAW_DIR=${1:?raw clip folder}
OUT_DIR=${2:?output folder}
CUTS_CSV=${3:-}
FRAMES=${FRAMES:-49}
FPS=${FPS:-24}
SHORT_SIDE=${SHORT_SIDE:-576}
KEEP_AUDIO=${KEEP_AUDIO:-0}

if (( (FRAMES - 1) % 8 != 0 )); then
  echo "FRAMES must be 8k+1 (17, 25, 33, 49, 73, 97, 121); got $FRAMES" >&2
  exit 1
fi
command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || {
  echo "ffmpeg/ffprobe not found (apt-get install -y ffmpeg)" >&2; exit 1; }

mkdir -p "$OUT_DIR"
WINDOW=$(awk -v f="$FRAMES" -v r="$FPS" 'BEGIN { printf "%.6f", f / r }')
# scale the short side to SHORT_SIDE, keep aspect, force even dimensions
SCALE="scale='if(gt(iw,ih),-2,$SHORT_SIDE)':'if(gt(iw,ih),$SHORT_SIDE,-2)':flags=lanczos"
if [[ $KEEP_AUDIO == 1 ]]; then
  AUDIO=(-c:a aac -b:a 192k -ar 48000 -t "$WINDOW")
else
  AUDIO=(-an)
fi

cut_one() {  # src start out
  ffmpeg -nostdin -loglevel error -y -ss "$2" -i "$1" \
    -vf "fps=$FPS,$SCALE,setsar=1" -frames:v "$FRAMES" \
    -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -g "$FRAMES" \
    "${AUDIO[@]}" "$3"
  local got
  got=$(ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of csv=p=0 "$3")
  if [[ $got != "$FRAMES" ]]; then
    echo "  drop $(basename "$3"): $got frames (source ran out)" >&2
    rm -f "$3"
    return
  fi
  echo "  ok   $(basename "$3")"
}

n=0
if [[ -n $CUTS_CSV ]]; then
  while IFS=, read -r file start; do
    [[ -z ${file// } || $file == \#* ]] && continue
    start=${start//[[:space:]]/}
    n=$((n + 1))
    cut_one "$RAW_DIR/$file" "$start" "$OUT_DIR/$(printf 'clip_%04d' "$n").mp4"
  done < "$CUTS_CSV"
else
  shopt -s nullglob nocaseglob
  for src in "$RAW_DIR"/*.{mp4,mov,mkv,webm,avi}; do
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")
    echo "$(basename "$src") (${dur}s)"
    start=0
    while awk -v s="$start" -v w="$WINDOW" -v d="$dur" 'BEGIN { exit !(s + w <= d) }'; do
      n=$((n + 1))
      cut_one "$src" "$start" "$OUT_DIR/$(printf 'clip_%04d' "$n").mp4"
      start=$(awk -v s="$start" -v w="$WINDOW" 'BEGIN { printf "%.6f", s + w }')
    done
  done
fi

echo "Done. Next: write a .txt caption beside every clip, then run check_dataset.py."
