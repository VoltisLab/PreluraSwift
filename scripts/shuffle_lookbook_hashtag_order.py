#!/usr/bin/env python3
"""
Randomise the **order** of hashtags in lookbook captions (staging GraphQL).

Seed scripts often put anchor tags first (e.g. ``#minimalist``, ``#boho``). This tool logs in
as each post author and calls ``updateLookbookPost`` so the same hashtag set stays intact but
the first slot is not always the anchor:

  • With probability ``--keep-primary-first-prob`` (default **0.1**), the caption is left
    unchanged (anchor can stay first).
  • Otherwise hashtags are shuffled; when possible the **first** hashtag is not one of the
    configured **primary** anchors (so ``#minimalist`` / ``#boho`` move out of position ~90%).

Requires ``STAGING_SEED_PASSWORD`` (same pattern as other seed scripts). Uses any account that
can read the global ``lookbooks`` feed to list posts, then updates as the poster.

  STAGING_SEED_PASSWORD='…' python3 scripts/shuffle_lookbook_hashtag_order.py --dry-run

  STAGING_SEED_PASSWORD='…' python3 scripts/shuffle_lookbook_hashtag_order.py \\
    --probe-username some_seed_user
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import random
import re
import sys
import time
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_PROBE_LIST = SCRIPT_DIR / "data" / "seed-usernames-male.txt"
DEFAULT_PRIMARY_FILE = SCRIPT_DIR / "data" / "primary_hashtag_anchors.txt"
CHECKPOINT_PATH = SCRIPT_DIR / "data" / "shuffle_hashtag_order_checkpoint.json"
SUMMARY_PATH = SCRIPT_DIR / "data" / "shuffle_hashtag_order_summary.json"

# Hashtag token: # then word chars / hyphens (common on IG).
HASHTAG_RE = re.compile(r"#[\w][\w-]*", re.UNICODE)

# Used if ``--primary-file`` is missing or empty.
DEFAULT_PRIMARY_ANCHORS: frozenset[str] = frozenset(
    {
        "minimalist",
        "boho",
        "bohostyle",
        "bohochic",
        "autumn",
        "officewear",
        "activewear",
        "streetwear",
        "vintage",
        "chic",
        "y2k",
        "denim",
        "summerstyles",
        "winteressentials",
        "athleisure",
        "datenight",
        "vacation",
        "resort",
        "loungewear",
        "formal",
        "party",
        "dress",
        "ootd",
        "grwm",
        "fyp",
    }
)

LOOKBOOKS_SIMPLE_CAPTION = """query Lookbooks($first: Int) {
  lookbooks(first: $first) {
    nodes { id username caption }
    edges { node { id username caption } }
  }
}"""

LOOKBOOKS_PAGED_CAPTION = """query LookbooksFeed($first: Int, $after: String) {
  lookbooks(first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { id username caption }
    edges { node { id username caption } }
  }
}"""

UPDATE_LOOKBOOK_POST = """mutation UpdateLookbookPost($postId: UUID!, $caption: String) {
  updateLookbookPost(postId: $postId, caption: $caption) {
    lookbookPost { id caption }
    success
    message
  }
}"""

LOOKBOOKS_SINGLE_REQUEST_CAP = 50_000


def _load_seed_lookbook_likes():
    path = SCRIPT_DIR / "seed_lookbook_likes.py"
    spec = importlib.util.spec_from_file_location("seed_lookbook_likes", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_primary_anchors(path: Path | None) -> frozenset[str]:
    base = set(DEFAULT_PRIMARY_ANCHORS)
    if path is not None and path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            t = line.strip().lower()
            if not t or t.startswith("#"):
                continue
            base.add(t.lstrip("#"))
    return frozenset(base)


def tag_key(token: str) -> str:
    return token[1:].lower() if token.startswith("#") else token.lower()


def is_primary_tag(token: str, primary: frozenset[str]) -> bool:
    return tag_key(token) in primary


def reorder_hashtags_in_caption(
    caption: str,
    rng: random.Random,
    primary: frozenset[str],
    *,
    keep_primary_first_prob: float,
) -> str | None:
    """
    Returns new caption if a reorder applies, else None.
    Preserves all non-hashtag text by replacing tokens in place (right-to-left).
    """
    if not caption or not caption.strip():
        return None
    matches = list(HASHTAG_RE.finditer(caption))
    if len(matches) < 2:
        return None

    tags = [m.group() for m in matches]
    if rng.random() < keep_primary_first_prob:
        return None

    new_tags = tags[:]
    rng.shuffle(new_tags)

    non_primary = [t for t in new_tags if not is_primary_tag(t, primary)]
    # ~90% branch: move a non-primary tag into first position when we can
    if non_primary and is_primary_tag(new_tags[0], primary):
        swap = rng.choice(non_primary)
        i = new_tags.index(swap)
        new_tags[0], new_tags[i] = new_tags[i], new_tags[0]
    elif not non_primary and len(new_tags) > 1:
        # Every token is a configured anchor - still break the always-same-first habit
        rot = rng.randint(1, len(new_tags) - 1)
        new_tags = new_tags[rot:] + new_tags[:rot]

    if new_tags == tags:
        rng.shuffle(new_tags)
        non_primary = [t for t in new_tags if not is_primary_tag(t, primary)]
        if non_primary and is_primary_tag(new_tags[0], primary):
            swap = rng.choice(non_primary)
            i = new_tags.index(swap)
            new_tags[0], new_tags[i] = new_tags[i], new_tags[0]
        elif not non_primary and len(new_tags) > 1:
            rot = rng.randint(1, len(new_tags) - 1)
            new_tags = new_tags[rot:] + new_tags[:rot]

    if new_tags == tags:
        return None

    spans = [(m.start(), m.end(), m.group()) for m in matches]
    out = caption
    for i in range(len(spans) - 1, -1, -1):
        start, end, old = spans[i]
        new = new_tags[i]
        if out[start:end] != old:
            return None
        out = out[:start] + new + out[end:]
    return out


def _extend_conn(
    conn: dict[str, Any],
    merged: list[dict[str, str]],
    seen: set[str],
    max_posts: int,
) -> None:
    batch: list[dict[str, Any]] = []
    if conn.get("nodes"):
        batch = [x for x in conn["nodes"] if x]
    elif conn.get("edges"):
        batch = [e["node"] for e in conn["edges"] if e and e.get("node")]
    for row in batch:
        if len(merged) >= max_posts:
            return
        pid = str(row.get("id") or "").strip()
        un = str(row.get("username") or "").strip()
        cap = row.get("caption")
        cap_s = cap if isinstance(cap, str) else ""
        if not pid:
            continue
        if pid not in seen:
            seen.add(pid)
            merged.append({"id": pid, "username": un, "caption": cap_s})


def fetch_all_lookbook_posts_with_caption(
    graphql_url: str,
    token: str,
    *,
    graphql_json,
    page_size: int,
    max_posts: int,
) -> list[dict[str, str]]:
    merged: list[dict[str, str]] = []
    seen: set[str] = set()
    cursor: str | None = None
    iterations = 0
    while len(merged) < max_posts and iterations < 500:
        iterations += 1
        variables: dict[str, Any] = {"first": min(page_size, max(1, max_posts - len(merged)))}
        variables["after"] = cursor if cursor else None
        r2 = graphql_json(
            graphql_url,
            {
                "query": LOOKBOOKS_PAGED_CAPTION,
                "variables": variables,
                "operationName": "LookbooksFeed",
            },
            token=token,
        )
        if r2.get("errors"):
            err_txt = json.dumps(r2["errors"]).lower()
            if "pageinfo" in err_txt or "cannot query field" in err_txt:
                break
            raise RuntimeError(json.dumps(r2["errors"]))
        conn = (r2.get("data") or {}).get("lookbooks") or {}
        before = len(merged)
        _extend_conn(conn, merged, seen, max_posts)
        if len(merged) >= max_posts:
            return merged
        if len(merged) == before:
            return merged
        pi = conn.get("pageInfo") or {}
        has_next = pi.get("hasNextPage") is True
        end = (pi.get("endCursor") or "").strip()
        if not has_next or not end:
            return merged
        cursor = end

    first_cap = min(max(1, max_posts), LOOKBOOKS_SINGLE_REQUEST_CAP)
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOKS_SIMPLE_CAPTION,
            "variables": {"first": first_cap},
            "operationName": "Lookbooks",
        },
        token=token,
    )
    if r.get("errors"):
        err_txt = json.dumps(r.get("errors") or []).lower()
        if "caption" in err_txt and "cannot query" in err_txt:
            raise RuntimeError(
                "lookbooks query does not expose `caption` on this schema; "
                "backend must return caption for feed listing."
            )
        raise RuntimeError(json.dumps(r["errors"]))
    conn = (r.get("data") or {}).get("lookbooks") or {}
    _extend_conn(conn, merged, seen, max_posts)
    return merged


def update_caption(graphql_url: str, token: str, post_id: str, caption: str, graphql_json) -> dict[str, Any]:
    r = graphql_json(
        graphql_url,
        {
            "query": UPDATE_LOOKBOOK_POST,
            "variables": {"postId": post_id, "caption": caption},
            "operationName": "UpdateLookbookPost",
        },
        token=token,
    )
    return r


def load_checkpoint(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        done = raw.get("updated_post_ids") or []
        return {str(x) for x in done}
    except (json.JSONDecodeError, OSError, TypeError):
        return set()


def save_checkpoint(path: Path, done: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(
        json.dumps({"version": 1, "updated_post_ids": sorted(done)}, separators=(",", ":")),
        encoding="utf-8",
    )
    tmp.replace(path)


def load_probe_username(args: argparse.Namespace) -> str:
    if args.probe_username:
        return args.probe_username.strip()
    mod = _load_seed_lookbook_likes()
    users = mod.load_usernames(Path(args.probe_list))
    if not users:
        raise SystemExit(f"No usernames in {args.probe_list}")
    return users[0]


def main() -> None:
    mod = _load_seed_lookbook_likes()
    parser = argparse.ArgumentParser(description="Shuffle hashtag order in lookbook captions.")
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", mod.DEFAULT_GRAPHQL))
    parser.add_argument("--probe-list", type=Path, default=DEFAULT_PROBE_LIST)
    parser.add_argument(
        "--probe-username",
        default="",
        help="Login as this user only to fetch the lookbooks feed (default: first line of --probe-list).",
    )
    parser.add_argument("--max-posts", type=int, default=50_000)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--keep-primary-first-prob", type=float, default=0.10)
    parser.add_argument(
        "--primary-file",
        type=Path,
        default=DEFAULT_PRIMARY_FILE,
        help=(
            "Merge extra anchor tokens (one per line, optional #) with built-ins. "
            f"Default: {DEFAULT_PRIMARY_FILE} (ignored if missing)."
        ),
    )
    parser.add_argument("--sleep-ms", type=int, default=40)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-checkpoint", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="RNG seed for reproducible shuffle decisions.")
    args = parser.parse_args()

    password = os.environ.get("STAGING_SEED_PASSWORD")
    if not password:
        print("Set STAGING_SEED_PASSWORD", file=sys.stderr)
        sys.exit(1)
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "prelura.com")
    graphql_url = args.graphql_url.rstrip("/") + "/"

    primary_path = args.primary_file if args.primary_file.is_file() else None
    primary = load_primary_anchors(primary_path)
    rng = random.Random(args.seed if args.seed is not None else random.randrange(1 << 30))

    probe = load_probe_username(args)
    probe_tok = mod.login(graphql_url, password, probe, email_domain)
    posts = fetch_all_lookbook_posts_with_caption(
        graphql_url,
        probe_tok,
        graphql_json=mod.graphql_json,
        page_size=args.page_size,
        max_posts=args.max_posts,
    )
    print(f"Fetched {len(posts)} post(s) with caption field.")

    planned: list[dict[str, Any]] = []
    for row in posts:
        cid = row["id"]
        cap = row.get("caption") or ""
        new_cap = reorder_hashtags_in_caption(
            cap,
            rng,
            primary,
            keep_primary_first_prob=args.keep_primary_first_prob,
        )
        if new_cap is not None:
            planned.append({"id": cid, "username": row["username"], "before": cap, "after": new_cap})

    stats = {
        "posts_scanned": len(posts),
        "posts_to_update": len(planned),
        "keep_primary_first_prob": args.keep_primary_first_prob,
        "primary_anchor_count": len(primary),
    }
    print(json.dumps(stats, indent=2))

    if args.dry_run:
        SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
        SUMMARY_PATH.write_text(
            json.dumps({"dry_run": True, "stats": stats, "sample": planned[:30]}, indent=2),
            encoding="utf-8",
        )
        print(f"Wrote {SUMMARY_PATH}")
        return

    done_ids = set() if args.no_checkpoint else load_checkpoint(CHECKPOINT_PATH)
    sleep_s = max(0.0, args.sleep_ms / 1000.0)
    token_cache: dict[str, str] = {}
    errors: list[dict[str, Any]] = []
    ok_n = 0

    for item in planned:
        pid = item["id"]
        if pid in done_ids:
            continue
        user = (item.get("username") or "").strip()
        if not user:
            errors.append({"postId": pid, "error": "missing username"})
            continue
        if user not in token_cache:
            try:
                token_cache[user] = mod.login(graphql_url, password, user, email_domain)
            except Exception as e:
                errors.append({"username": user, "postId": pid, "phase": "login", "error": str(e)})
                continue
        tok = token_cache[user]
        if sleep_s:
            time.sleep(sleep_s)
        r = update_caption(graphql_url, tok, pid, item["after"], mod.graphql_json)
        if r.get("errors"):
            errors.append({"postId": pid, "username": user, "error": json.dumps(r["errors"])})
            continue
        payload = (r.get("data") or {}).get("updateLookbookPost") or {}
        if payload.get("success") is not True:
            errors.append(
                {"postId": pid, "username": user, "message": payload.get("message"), "raw": str(r)[:500]}
            )
            continue
        ok_n += 1
        done_ids.add(pid)
        if not args.no_checkpoint:
            save_checkpoint(CHECKPOINT_PATH, done_ids)

    out = {
        "stats": {**stats, "updated_ok": ok_n, "errors": len(errors)},
        "errors_sample": errors[:50],
        "checkpoint": str(CHECKPOINT_PATH) if not args.no_checkpoint else None,
    }
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps({"updated_ok": ok_n, "errors": len(errors), "summary": str(SUMMARY_PATH)}, indent=2))
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
