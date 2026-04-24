#!/usr/bin/env python3
"""
Merge ``completed`` edge lists from one or more ``lookbook_likes_seed_checkpoint.json``-style
files, grouped by ``plan_fingerprint``.

Same fingerprint → union of ``completed`` (dedupe). Different fingerprints stay separate output
files - you cannot merge two plans into one resume file meaningfully.

Examples::

  # All checkpoints in scripts/data matching the default glob
  python3 scripts/merge_lookbook_likes_checkpoints.py

  # Named files
  python3 scripts/merge_lookbook_likes_checkpoints.py a.json b.json backups/c.json

  # Write merged checkpoint for one plan to the path the seed script reads
  python3 scripts/merge_lookbook_likes_checkpoints.py --fingerprint 91a81d7d --output scripts/data/lookbook_likes_seed_checkpoint.json
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

CHECKPOINT_VERSION = 1
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
DEFAULT_GLOB = "lookbook_likes_seed_checkpoint*.json"


def load_one(path: Path) -> tuple[str | None, set[str], str | None]:
    """Returns (fingerprint, completed_set, error_message)."""
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        return None, set(), str(e)
    if raw.get("version") != CHECKPOINT_VERSION:
        return None, set(), f"bad version in {path.name}"
    fp = raw.get("plan_fingerprint")
    if not isinstance(fp, str) or not fp:
        return None, set(), f"missing plan_fingerprint in {path.name}"
    done = raw.get("completed") or []
    if not isinstance(done, list):
        return None, set(), f"bad completed in {path.name}"
    return fp, {str(x) for x in done}, None


def main() -> None:
    parser = argparse.ArgumentParser(description="Merge lookbook like checkpoint JSON files by plan_fingerprint.")
    parser.add_argument(
        "inputs",
        nargs="*",
        type=Path,
        help=f"Checkpoint files (default: {DATA_DIR}/{DEFAULT_GLOB})",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Write merged checkpoint for the fingerprint chosen with --fingerprint (single plan only).",
    )
    parser.add_argument(
        "--fingerprint",
        "-f",
        metavar="PREFIX_OR_FULL",
        help="Which plan to write to --output (hex prefix match ok if unique). Required with -o if merged has multiple plans.",
    )
    parser.add_argument(
        "--write-all",
        action="store_true",
        help=f"Write merged_<fp[:16]>.json per fingerprint under {DATA_DIR}.",
    )
    args = parser.parse_args()

    paths = list(args.inputs) if args.inputs else sorted(DATA_DIR.glob(DEFAULT_GLOB))
    if not paths:
        print(f"No inputs and no files matching {DATA_DIR}/{DEFAULT_GLOB}", file=sys.stderr)
        sys.exit(1)

    per_file: list[tuple[Path, str | None, set[str], str | None]] = []
    for p in paths:
        fp, done, err = load_one(p)
        per_file.append((p, fp, done, err))

    # Group contributions by fingerprint
    by_fp: dict[str, list[tuple[Path, set[str]]]] = defaultdict(list)
    errors = 0
    for p, fp, done, err in per_file:
        if err:
            print(f"SKIP {p}: {err}", file=sys.stderr)
            errors += 1
            continue
        assert fp is not None
        by_fp[fp].append((p, done))

    merged: dict[str, set[str]] = {fp: set() for fp in by_fp}
    for fp, items in by_fp.items():
        for _p, s in items:
            merged[fp] |= s

    print("Per-file counts:")
    for p, fp, done, err in per_file:
        if err:
            print(f"  {p.name}: ERROR")
        else:
            print(f"  {p.name}: fp={fp[:16]}… edges={len(done)}")
    print()
    print("Merged by plan_fingerprint:")
    for fp in sorted(merged.keys()):
        n = len(merged[fp])
        print(f"  {fp[:16]}… ({n} unique edges from {len(by_fp[fp])} file(s))")

    if args.write_all:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        for fp, done in merged.items():
            out = DATA_DIR / f"lookbook_likes_seed_checkpoint_merged_{fp[:16]}.json"
            out.write_text(
                json.dumps(
                    {"version": CHECKPOINT_VERSION, "plan_fingerprint": fp, "completed": sorted(done)},
                    separators=(",", ":"),
                ),
                encoding="utf-8",
            )
            print(f"Wrote {out} ({len(done)} edges)")

    if args.output:
        if not args.fingerprint:
            if len(merged) == 1:
                fp_only = next(iter(merged.keys()))
            else:
                print(
                    "Multiple fingerprints merged; pass --fingerprint <prefix> with -o.",
                    file=sys.stderr,
                )
                sys.exit(1)
        else:
            want = args.fingerprint.strip().lower()
            matches = [fp for fp in merged if fp.lower().startswith(want) or want == fp.lower()]
            if len(matches) != 1:
                print(f"--fingerprint {want!r} matches {len(matches)} plans: {matches}", file=sys.stderr)
                sys.exit(1)
            fp_only = matches[0]

        done = merged[fp_only]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(
                {"version": CHECKPOINT_VERSION, "plan_fingerprint": fp_only, "completed": sorted(done)},
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )
        print(f"Wrote {args.output} ({len(done)} edges, fp {fp_only[:16]}…)")


if __name__ == "__main__":
    main()
