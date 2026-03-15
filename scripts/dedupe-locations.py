#!/usr/bin/env python3
"""
Deduplicate LocationSuggestions.json by canonical place name.

- One settlement = one entry. Canonical key = first part of display (before first comma),
  lowercased, with apostrophes removed and spaces collapsed.
- Merges duplicate and variant entries: keeps one display (prefer "Place, County, UK"),
  merges all searchTerms (lowercased, deduplicated).
- Preserves "United Kingdom" and "UK" as separate top-level entries.
- Writes cleaned JSON to the path given (default: overwrite input file).

Usage:
  python3 Scripts/dedupe-locations.py
  python3 Scripts/dedupe-locations.py --input Prelura-swift/Resources/LocationSuggestions.json
  python3 Scripts/dedupe-locations.py --output cleaned.json
"""

import argparse
import json
import re
import sys
from collections import OrderedDict


def canonical_key(display: str) -> str:
    """First part of display (place name), lowercased, normalized for matching."""
    part = display.split(",")[0].strip()
    # Remove apostrophes (King's -> Kings), collapse spaces
    part = part.replace("'", "").replace("’", "")
    part = re.sub(r"\s+", " ", part).strip().lower()
    return part


def main() -> None:
    parser = argparse.ArgumentParser(description="Deduplicate LocationSuggestions.json")
    parser.add_argument(
        "--input",
        default="Prelura-swift/Resources/LocationSuggestions.json",
        help="Input JSON path (relative to repo root)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output JSON path (default: overwrite input)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print stats and merged count only, do not write",
    )
    args = parser.parse_args()
    input_path = args.input
    output_path = args.output or input_path

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {input_path}: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(data, list):
        print("Error: expected JSON array", file=sys.stderr)
        sys.exit(1)

    # Group by canonical key; preserve first occurrence order for display choice
    groups: dict[str, list[dict]] = OrderedDict()
    for entry in data:
        if not isinstance(entry, dict) or "display" not in entry or "searchTerms" not in entry:
            continue
        key = canonical_key(entry["display"])
        if key not in groups:
            groups[key] = []
        groups[key].append(entry)

    # Build merged list: one entry per key
    merged: list[dict] = []
    # Keep "United Kingdom" and "UK" at top if present
    for special in ["united kingdom", "uk"]:
        if special in groups:
            entries = groups[special]
            # Keep display as-is; merge search terms
            all_terms = set()
            for e in entries:
                for t in e.get("searchTerms", []):
                    all_terms.add(t.strip().lower())
            merged.append({
                "display": entries[0]["display"],
                "searchTerms": sorted(all_terms),
            })
            del groups[special]

    # For the rest: prefer display that contains a county (has two commas or ", County," pattern)
    for key, entries in groups.items():
        all_terms = set()
        displays = [e["display"] for e in entries]
        for e in entries:
            for t in e.get("searchTerms", []):
                all_terms.add(t.strip().lower())
        # Prefer "Place, County, UK" over "Place, UK"
        chosen_display = displays[0]
        for d in displays:
            parts = [p.strip() for p in d.split(",")]
            if len(parts) >= 3 and parts[-1].upper() == "UK":
                chosen_display = d
                break
        merged.append({
            "display": chosen_display,
            "searchTerms": sorted(all_terms),
        })

    if args.dry_run:
        print(f"Input entries: {len(data)}")
        print(f"Merged entries: {len(merged)}")
        print(f"Removed: {len(data) - len(merged)}")
        return

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)

    print(f"Wrote {len(merged)} entries to {output_path} (was {len(data)}).")


if __name__ == "__main__":
    main()
