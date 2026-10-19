#!/usr/bin/env python3
"""Check an LTX-2.3 video dataset before you pay for GPU time.

Usage: python3 check_dataset.py DATASET_DIR [--frames 49] [--fps 24]

Checks every clip for exact frame count, constant fps and a non-empty caption
next to it. Warns on short captions or captions without [trigger] (the trigger
is prepended anyway, but placing it yourself keeps captions consistent).
Exits non-zero if anything would break training.
"""
import argparse
import json
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".webm", ".avi"}


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
         "-show_entries", "stream=width,height,r_frame_rate,avg_frame_rate,nb_read_frames",
         "-of", "json", str(path)],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)["streams"][0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset")
    ap.add_argument("--frames", type=int, default=49)
    ap.add_argument("--fps", type=float, default=24)
    args = ap.parse_args()

    clips = sorted(p for p in Path(args.dataset).iterdir() if p.suffix.lower() in VIDEO_EXTS)
    if not clips:
        sys.exit(f"no video clips in {args.dataset}")

    errors, warnings = 0, 0
    for clip in clips:
        problems, notes = [], []
        s = probe(clip)
        frames = int(s.get("nb_read_frames", 0))
        rate = float(Fraction(s["r_frame_rate"]))
        avg = float(Fraction(s["avg_frame_rate"])) if s["avg_frame_rate"] != "0/0" else 0
        if frames != args.frames:
            problems.append(f"{frames} frames, expected {args.frames}")
        if abs(rate - args.fps) > 0.01 or abs(avg - args.fps) > 0.05:
            problems.append(f"fps {rate:.3f} (avg {avg:.3f}), expected constant {args.fps:g}")

        cap = clip.with_suffix(".txt")
        if not cap.exists():
            problems.append("missing caption .txt")
        else:
            text = cap.read_text(encoding="utf-8").strip()
            if not text:
                problems.append("empty caption")
            else:
                if "[trigger]" not in text:
                    notes.append("caption has no [trigger]")
                if len(text.split()) < 25:
                    notes.append(f"caption is short ({len(text.split())} words)")

        status = "FAIL" if problems else ("warn" if notes else "ok  ")
        print(f"{status} {clip.name} {s['width']}x{s['height']} " + "; ".join(problems + notes))
        errors += bool(problems)
        warnings += bool(notes)

    print(f"\n{len(clips)} clips, {errors} failing, {warnings} with warnings")
    if len(clips) < 25:
        print("note: fewer than 25 clips; aim for 30-60 varied interactions")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
